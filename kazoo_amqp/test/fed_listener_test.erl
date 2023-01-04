%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc Test module to work on recovering after AMQP disconnects of
%%% federated listeners
%%%
%%% Specifically for dynamic bindings, ensure that when a federated
%%% listener is restarted, all bindings of the parent gen_listener are
%%% re-bound.
%%%
%%% `make compile-test-direct`
%%% l(fed_listener_test), fed_listener_test:start().
%%% Should return 'ok' or an error with the exit reason
%%%
%%% Assumes localhost has a broker and differs from default connection
%%% (note: I used localhost and NAT IP as two brokers)
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(fed_listener_test).

-export([start/0]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,handle_event/2
        ,terminate/2
        ,code_change/3
        ]).

-include_lib("kazoo_amqp/include/kz_amqp.hrl").

-define(STATIC_BINDINGS, [{'call', [{'callid', <<?MODULE_STRING>>}, 'federate']}]).
-define(DYN_BINDING, {'call', [{'callid', <<?MODULE_STRING"-dyn">>}, 'federate']}).

-define(FED_BROKER, <<"amqp://guest:guest@127.0.0.1:5672">>).

-spec start() -> 'ok' | {'error', any()}.
start() ->
    PidRef = spawn_monitor(fun start_it/0),
    wait(PidRef).

wait({Pid, Ref}) ->
    receive
        {'DOWN', Ref, 'process', Pid, 'normal'} -> 'ok';
        {'DOWN', Ref, 'process', Pid, Reason} -> {'error', Reason}
    after
        5000 -> {'error', 'timeout'}
    end.

start_it() ->
    start_fed_conn(),

    {'ok', GenL} = start_genl(),
    lager:info("~p: started genl ~p", [self(), GenL]),

    wait_for(GenL, 'is_consuming'),

    StaticBindings = gen_listener:bindings(GenL),

    wait_for(GenL, 'fed_consuming'),

    [FedL] = gen_listener:federators(GenL),
    FedStaticBindings = gen_listener:bindings(FedL),
    'true' = matched_bindings(StaticBindings, FedStaticBindings),

    gen_listener:b_add_binding(GenL, ?DYN_BINDING),
    DynBindings = gen_listener:bindings(GenL),

    timer:sleep(1000),

    FedBindings = gen_listener:bindings(FedL),
    'true' = matched_bindings(DynBindings, FedBindings),

    gen_listener:crash(FedL),
    timer:sleep(2000),

    [NewFedL] = gen_listener:federators(GenL),

    NowFedBindings = gen_listener:bindings(NewFedL),
    lager:info("~p: now fed bindings: ~p", [NewFedL, NowFedBindings]),

    'true' = matched_bindings(DynBindings, NowFedBindings),

    stop_fed_conn(),

    gen_listener:stop(GenL).

matched_bindings([], []) -> 'true';
matched_bindings([{Binding, Props} | LHS], [{Binding, Props} | RHS]) ->
    matched_bindings(LHS, RHS);
matched_bindings([{Binding, Props} | LHS], RHS) ->
    Rs = lists:foldl(fun({RBinding, RProps}, Acc) ->
                             case matched_binding(Binding, RBinding, Props, RProps) of
                                 'true' -> Acc;
                                 'false' ->
                                     [{RBinding, RProps} | Acc]
                             end
                     end
                    ,[]
                    ,RHS
                    ),
    matched_bindings(LHS, Rs).

matched_binding(Binding, Binding, Props, RProps) ->
    matched_props(Props, RProps);
matched_binding(_B, _RB, _, _) ->
    'false'.

matched_props(Props, RProps) ->
    lists:usort(props:delete('federate', Props))
        =:= lists:usort(props:delete('federate', RProps)).

wait_for(Pid, Message) ->
    receive
        {Pid, Message} -> 'ok'
    after
        5000 ->
            lager:info("failed to recv ~p: ~p", [Pid, Message]),
            drain(),
            exit('timeout')
    end.

drain() ->
    receive
        Msg ->
            lager:info("drain: ~p", [Msg]),
            drain()
    after 0 -> 'ok'
    end.

start_fed_conn() ->
    handle_started_conn(kz_amqp_connections:new(?FED_BROKER, 'lo')).

handle_started_conn(#kz_amqp_connection{connection=_ConnPid}) -> 'ok';
handle_started_conn({'error', 'exists'}) -> 'ok'.

stop_fed_conn() ->
    handle_removed_conn(kz_amqp_connections:remove(?FED_BROKER)).

handle_removed_conn(_) -> 'ok'.

-type state() :: map().

start_genl() ->
    gen_listener:start_link(?MODULE
                           ,[{'bindings', ?STATIC_BINDINGS}
                            ,{'responders', []}
                            ,{'queue_name', <<?MODULE_STRING>>}
                            ]
                           ,[self()]
                           ).

-spec init(kz_term:pids()) -> {'ok', map()}.
init([TestPid]) ->
    kz_log:put_callid(<<?MODULE_STRING"-consumer">>),
    {'ok', TestPid}.

-spec handle_call(any(), kz_term:pid_ref(), state()) ->
          kz_types:handle_call_ret().
handle_call(_Req, _From, TestPid) ->
    {'noreply', TestPid}.

-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret().
handle_cast({'gen_listener',{'is_consuming','true'}}, TestPid) ->
    lager:info("is consuming to test pid ~p", [TestPid]),
    TestPid ! {self(), 'is_consuming'},
    {'noreply', TestPid};
handle_cast({'gen_listener',{'is_consuming','false'}}, TestPid) ->
    lager:info("channel has gone down"),
    {'noreply', TestPid};
handle_cast({'gen_listener',{'federators_consuming','false'}}, TestPid) ->
    lager:info("federated listener(s) are down"),
    {'noreply', TestPid};
handle_cast({'gen_listener',{'federators_consuming','true'}}, TestPid) ->
    lager:info("federated listener(s) are up"),
    TestPid ! {self(), 'fed_consuming'},
    {'noreply', TestPid};
handle_cast({'gen_listener',{'created_queue', _QueueName}}, TestPid) ->
    {'noreply', TestPid};
handle_cast(Req, TestPid) ->
    lager:info("casted: ~p", [Req]),
    {'noreply', TestPid}.

-spec handle_info(any(), state()) -> kz_types:handle_info_ret().
handle_info(Msg, TestPid) ->
    lager:info("info: ~p state: ~p", [Msg, TestPid]),
    {'noreply', TestPid}.

-spec handle_event(kz_json:object(), state()) -> 'ignore'.
handle_event(_JObj, _TestPid) ->
    'ignore'.

-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _TestPid) ->
    lager:info("terminating: ~p: ~p", [_Reason, _TestPid]).

-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVersion, TestPid, _Extra) ->
    {'ok', TestPid}.
