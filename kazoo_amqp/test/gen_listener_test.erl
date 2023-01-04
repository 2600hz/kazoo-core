%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc Test module to work on recovering after AMQP disconnect in gen_listeners
%%%
%%% Creates a basic publisher and gen_listener consumer and starts
%%% appropriate timers. When the AMQP disconnect/reconnect occurs, the
%%% test checks if publishing resumes and consuming is re-established.
%%%
%%% Run interactively in the shell with:
%%% f(P), P = kz_amqp_test:start().
%%% ... restart rabbit ...
%%% P ! stop.
%%%
%%% 'stop' will terminate both the consumer and producer
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(gen_listener_test).

-export([start/0]).

%% gen_listener callbacks for consumer
-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,handle_event/2
        ,terminate/2
        ,code_change/3
        ]).

-include_lib("kazoo_amqp/include/kz_amqp.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").

-spec start() -> pid().
start() ->
    spawn(fun run_it/0).

run_it() ->
    Pubs = start_publishers(),
    Cons = start_consumers(),
    lager:info("started consumers: ~p", [Cons]),
    lager:info("started publishers: ~p", [Pubs]),
    wait(Cons ++ Pubs).

wait([]) -> 'ok';
wait(PidRefs) ->
    receive
        {'DOWN', Ref, 'process', Pid, _Reason} ->
            case lists:keytake(Pid, 1, PidRefs) of
                'false' ->
                    lager:info("ignoring down pid ~p", [Pid]),
                    wait(PidRefs);
                {'value', {Pid, Ref}, PRs} ->
                    lager:info("pid ~p down: ~p", [Pid, _Reason]),
                    wait(PRs)
            end;
        {Client, 'status'} ->
            Client ! {'status', PidRefs},
            wait(PidRefs);
        'stop' ->
            lager:info("stopping"),
            [P ! 'stop' || {P, _} <- PidRefs]
    end.

start_publishers() ->
    [spawn_monitor(fun() -> run_publisher(Broker) end)
     || Broker <- kz_amqp_connections:uris()
    ].

run_publisher(Broker) ->
    kz_log:put_callid(<<"-pub-"?MODULE_STRING"-", Broker/binary>>),
    lager:info("using broker ~s for publishing", [Broker]),
    'ok' = kz_amqp_channel:requisition(Broker),

    Payload = [{<<"Category">>, <<"amqp">>}
              ,{<<"Key">>, kz_term:to_binary(self())}
              | kz_api:default_headers(Broker, <<"5.0">>)
              ],
    loop_publisher(Payload).

loop_publisher(Payload) ->
    loop_publisher(Payload, 2600).

loop_publisher(Payload, Timeout) ->
    Start = kz_time:start_time(),
    receive
        'stop' -> lager:info("publisher instructed to stop");
        {'kz_amqp_assignment',{'new_channel',_Reconn, Channel}} ->
            _ = kz_amqp_channel:consumer_channel(Channel),

            lager:info("publisher moved to channel ~p (reconn: ~s) ", [Channel, _Reconn]),
            lager:info("publisher broker: ~p", [kz_amqp_channel:consumer_broker()]),

            publish_payload(Payload),
            loop_publisher(Payload);
        {'kz_amqp_assignment', 'lost_channel'} ->
            lager:info("producer has lost its channel, waiting"),
            loop_publisher(Payload, 'infinity');
        Msg ->
            lager:info("publisher recv ~p", [Msg]),
            loop_publisher(Payload, decr(Timeout, Start))
    after
        Timeout ->
            publish_payload(Payload),
            loop_publisher(Payload)
    end.

publish_payload(Payload) ->
    kapi_sysconf:publish_get_req(Payload).

start_consumers() ->
    [proc_lib:spawn_opt(fun run_consumer/0, ['monitor'])
     || _ <- lists:seq(1, 1000)
    ].

%% AMQP URIs
-type state() :: kz_term:ne_binaries().

run_consumer() ->
    gen_listener:enter_loop(?MODULE
                           ,[{'bindings', [{'sysconf', ['federate', {'restrict_to', ['get']}]}]}]
                           ,kz_amqp_connections:uris()
                           ).

-spec init(list()) -> {'ok', state(), 5000}.
init(_) ->
    kz_log:put_callid(<<?MODULE_STRING"-consumer">>),
    {'ok', kz_amqp_connections:uris(), 5 * ?MILLISECONDS_IN_SECOND}.

-spec handle_call(any(), kz_term:pid_ref(), state()) ->
          kz_types:handle_call_ret().
handle_call(_Req, _From, State) ->
    {'noreply', State}.

-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret().
handle_cast({'gen_listener',{'is_consuming','true'}}, _URIs) ->
    lager:info("channel is consuming again"),
    {'noreply', kz_amqp_connections:uris()};
handle_cast({'gen_listener',{'is_consuming','false'}}, _URIs) ->
    lager:info("channel has gone down"),
    {'noreply', kz_amqp_connections:uris()};
handle_cast({'gen_listener',{'federators_consuming','false'}}, _URIs) ->
    lager:info("federated listener(s) are down"),
    {'noreply', kz_amqp_connections:uris()};
handle_cast({'gen_listener',{'federators_consuming','true'}}, _URIs) ->
    lager:info("federated listener(s) are up"),
    {'noreply', kz_amqp_connections:uris()};
handle_cast({'gen_listener',{'created_queue', _QueueName}}, URIs) ->
    {'noreply', URIs};
handle_cast(Req, State) ->
    lager:info("casted: ~p", [Req]),
    {'noreply', State}.

-spec handle_info(any(), state()) -> kz_types:handle_info_ret().
handle_info('timeout', [_|_]=State) ->
    lager:error("failed to hear from publisher(s) after consuming started: ~p", [State]),
    {'stop', 'normal', State};
handle_info('timeout', []) ->
    {'noreply', kz_amqp_connections:uris(), 5 * ?MILLISECONDS_IN_SECOND};
handle_info('stop', State) ->
    {'stop', 'normal', State};
handle_info(Msg, State) ->
    lager:info("info: ~p state: ~p", [Msg, State]),
    {'noreply', State}.

-spec handle_event(kz_json:object(), state()) -> {'ignore', state()}.
handle_event(JObj, URIs) ->
    URI = kz_api:app_name(JObj),
    lager:info("evt from ~s: ~p", [URI, URIs]),

    case lists:delete(URI, URIs) of
        [] -> {'ignore', kz_amqp_connections:uris()};
        StillWaiting -> {'ignore', StillWaiting}
    end.

-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:info("terminating: ~p: ~p", [_Reason, _State]).

-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVersion, State, _Extra) ->
    {'ok', State}.

decr('infinity', _Start) -> 'infinity';
decr(Timeout, Start) ->
    kz_time:decr_timeout(Timeout, Start).

%% WHY a watcher?
