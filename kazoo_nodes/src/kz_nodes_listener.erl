%%%------------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_nodes_listener).
-behaviour(gen_listener).

-compile({'no_auto_import', [nodes/0]}).

-export([start_link/0]).
-export([is_ready/0]).
-export([wait_for_refresh/0]).

-export([flush/0]).
-export([handle_advertise/2]).
-export([notify_new/0
        ,notify_expire/0
        ,notify_heartbeat/0
        ]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,handle_event/2
        ,terminate/2
        ,code_change/3
        ]).

%% ETS Management
-export([find_me/0]).

-type request_info() :: {'app', atom()} |
                        {'media_servers', [{kz_term:ne_binary(), kz_json:object()}]} |
                        {'channels', non_neg_integer()} |
                        {'conferences', non_neg_integer()} |
                        {'registrations', non_neg_integer()} |
                        {'info', kz_types:whapp_info()}.
-type request_acc() :: [request_info()].

-export_type([request_acc/0]).

-include("kazoo_nodes.hrl").

-define(SERVER, ?MODULE).

-define(BINDINGS, [{'nodes', ['federate']}
                  ,{'self', []}
                  ]).
-define(RESPONDERS, [{{?MODULE, 'handle_advertise'}
                     ,[{<<"nodes">>, <<"advertise">>}]
                     }
                    ]).
-define(QUEUE_NAME, <<>>).
-define(QUEUE_OPTIONS, []).
-define(CONSUME_OPTIONS, [{'no_local', 'true'}]).
-define(LARGE_HEAP_SIZE_WORDS, 500_000).

-define(HEARTBEAT, 10 * ?MILLISECONDS_IN_SECOND + rand:uniform(10 * ?MILLISECONDS_IN_SECOND)).
-define(EXPIRE_PERIOD, 1 * ?MILLISECONDS_IN_SECOND).
-define(UPDATE_PERIOD, 15 * ?MILLISECONDS_IN_SECOND).
-define(FUDGE_FACTOR, 1.5).

-define(MONITOR_NODES_OPTIONS, ['nodedown_reason', {'node_type', 'all'}]).

-record(state, {heartbeat_ref = 'undefined' :: reference() | 'undefined'
               ,node = node() :: atom()
               ,md5 :: kz_term:ne_binary()
               ,zone = 'local' :: atom()
               ,version :: kz_term:ne_binary()
               ,zones = [] :: kz_term:proplist()
               ,is_consuming = 'false' :: boolean()
               ,has_ets = 'false' :: boolean()
               ,waiting = [] :: [kz_term:pid_ref()]
               ,expires_ref = 'undefined' :: reference() | 'undefined'
               ,update_ref = 'undefined' :: reference() | 'undefined'
               ,payload = 'undefined' :: kz_term:api_object()
               }).
-type nodes_state() :: #state{}.

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server.
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_listener:start_link({'local', ?SERVER}
                           ,?MODULE
                           ,[{'bindings', ?BINDINGS}
                            ,{'responders', ?RESPONDERS}
                            ,{'queue_name', ?QUEUE_NAME}
                            ,{'queue_options', ?QUEUE_OPTIONS}
                            ,{'consume_options', ?CONSUME_OPTIONS}
                            ,{'kz_monitor', #{'large_heap' => ?LARGE_HEAP_SIZE_WORDS}}
                            ]
                           ,[]
                           ).

-spec flush() -> 'ok'.
flush() ->
    gen_listener:cast(?SERVER, 'flush').

-spec notify_new() -> 'ok'.
notify_new() ->
    kz_nodes_notify:notify_new().

-spec notify_expire() -> 'ok'.
notify_expire() ->
    kz_nodes_notify:notify_expire().

-spec notify_heartbeat() -> 'ok'.
notify_heartbeat() ->
    kz_nodes_notify:notify_heartbeat().

-spec handle_advertise(kz_json:object(), kz_term:proplist()) -> 'ok'.
handle_advertise(JObj, Props) ->
    erlang:put('kazoo_bindings_silent_apply', 'true'),
    'true' = kapi_nodes:advertise_v(JObj),
    State = props:get_value('state', Props),
    build_advertised_node(JObj, State).

-spec build_advertised_node(kz_json:object(), nodes_state()) ->'ok'.
build_advertised_node(JObj, State) ->
    try
        Node = from_json(JObj, State),
        gen_listener:cast(?MODULE, {'advertise', Node})
    catch
        _E:_R:_ST ->
            kz_log:log_stacktrace(_ST),
            lager:warning("error building advertised node : ~p", [{_E, _R}])
    end.

-spec update_advertised_node(kz_types:kz_node(), nodes_state()) -> pid() | 'true'.
update_advertised_node(_Node, #state{has_ets = 'false'}) -> 'true';
update_advertised_node(Node, #state{has_ets = 'true'}) ->
    case kz_nodes_ets:add_node(Node) of
        'new' ->
            kz_process:spawn(fun notify_new/1, [Node]);
        'update' ->
            kz_process:spawn(fun notify_heartbeat/1, [Node])
    end.

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server.
%% @end
%%------------------------------------------------------------------------------
-spec init([]) -> {'ok', nodes_state()}.
init([]) ->
    lager:debug("starting nodes watcher"),
    erlang:put('kazoo_bindings_silent_apply', 'true'),

    _ = net_kernel:monitor_nodes('true', ?MONITOR_NODES_OPTIONS),
    State = #state{zone = kz_nodes:local_zone()
                  ,md5 = kz_nodes:node_encoded()
                  ,version = version()
                  },
    {'ok', State}.

-type start_timer_fun() :: fun((nodes_state()) -> nodes_state()).
-type start_timer_fun_list() :: [start_timer_fun()].

-spec start_timers_list() -> start_timer_fun_list().
start_timers_list() ->
    [fun start_expire_nodes_timer/1
    ,fun start_update_me_timer/1
    ,fun start_heartbeat_timer/1
    ].

-spec start_timers(nodes_state()) -> nodes_state().
start_timers(State) ->
    lists:foldl(fun start_timer/2, State, start_timers_list()).

-spec start_timer(start_timer_fun(), nodes_state()) -> nodes_state().
start_timer(Fun, State) -> Fun(State).

start_expire_nodes_timer(State) ->
    State#state{expires_ref = erlang:start_timer(?EXPIRE_PERIOD, self(), 'expire_nodes')}.

start_update_me_timer(State) ->
    State#state{update_ref = erlang:start_timer(?UPDATE_PERIOD, self(), 'update_me')}.

start_heartbeat_timer(State) ->
    start_heartbeat_timer(State, ?HEARTBEAT).

start_heartbeat_timer(State, Period) ->
    State#state{heartbeat_ref = next_heartbeat(Period)}.

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), nodes_state()) -> kz_types:handle_call_ret_state(nodes_state()).
handle_call('is_ready', _From, #state{is_consuming='true', has_ets='true'}=State) ->
    {'reply', 'true', State};
handle_call('is_ready', _From, State) ->
    {'reply', 'false', State};
handle_call('zone', _From, #state{zone=Zone}=State) ->
    {'reply', Zone, State};
handle_call('refresh', From, #state{waiting = Waiting} = State) ->
    {'noreply', State#state{waiting = [From | Waiting]}};
handle_call(_Request, _From, State) ->
    {'reply', {'error', 'not_implemented'}, State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), nodes_state()) -> kz_types:handle_cast_ret_state(nodes_state()).
handle_cast({'advertise', Node}, State) ->
    _ = update_advertised_node(Node, State),
    {'noreply', maybe_add_zone(Node, State)};
handle_cast({'update_me', Node, Payload}, State) ->
    _ = kz_nodes_ets:add_node(Node),
    {'noreply', start_update_me_timer(State#state{payload = Payload})};
handle_cast({'gen_listener', {'created_queue', _Q}}, State) ->
    lager:info("nodes acquired queue name ~s, starting remote heartbeats", [_Q]),
    {'noreply', State};
handle_cast({'gen_listener', {'is_consuming', IsConsuming}}, State) ->
    lager:debug("heartbeat from remotes is ~p", [IsConsuming]),
    {'noreply', State#state{is_consuming=IsConsuming}};
handle_cast('flush', State) ->
    _ = kz_nodes_ets:flush(),
    {'noreply', State};
handle_cast(_Msg, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), nodes_state()) -> kz_types:handle_info_ret_state(nodes_state()).
handle_info({'timeout', Ref, 'expire_nodes'}, #state{expires_ref = Ref, node = ThisNode, has_ets = 'true'}=State) ->
    ExpiredNodes = kz_nodes_ets:expire_nodes(ThisNode),
    _ = kz_process:spawn(fun notify_expire/1, [ExpiredNodes]),
    {'noreply', start_expire_nodes_timer(State)};
handle_info({'timeout', Ref, 'expire_nodes'}, #state{expires_ref = Ref}=State) ->
    {'noreply', start_expire_nodes_timer(State)};
handle_info({'timeout', _Ref, 'expire_nodes'}, State) ->
    {'noreply', State};

handle_info({'timeout', TimerRef, 'update_me'}, #state{update_ref = TimerRef, zone=Zone, version=Version, md5=MD5} = State) ->
    _ = kz_process:spawn(fun create_node/4, [?UPDATE_PERIOD, Zone, Version, MD5]),
    {'noreply', State};

handle_info({'timeout', _TimerRef, 'update_me'}, State) ->
    {'noreply', State};

handle_info({'timeout', Ref, 'heartbeat'}, #state{heartbeat_ref = Ref, payload = 'undefined'} = State) ->
    {'noreply', start_heartbeat_timer(State)};

handle_info({'timeout', Ref, 'heartbeat'}, #state{heartbeat_ref = Ref, is_consuming = 'false'} = State) ->
    {'noreply', start_heartbeat_timer(State)};

handle_info({'timeout', Ref, 'heartbeat'}, #state{heartbeat_ref=Ref, waiting=Waiting, payload = Payload} = State) ->
    Hearbeat = ?HEARTBEAT,
    AMQPConsumer = kz_amqp_channel:consumer_pid(),
    AMQPChannel = kz_amqp_channel:consumer_channel(),
    _ = kz_process:spawn(fun advertise_node/3, [Payload, Hearbeat, {AMQPConsumer, AMQPChannel}]),
    _ = notify_waiting(Waiting),
    {'noreply', start_heartbeat_timer(State#state{waiting=[]}, Hearbeat)};

handle_info({'timeout', _Ref, 'heartbeat'}, State) ->
    lager:warning("received out of sync heartbeat timer ref => ~p", [_Ref]),
    {'noreply', State};

handle_info({'nodedown', Node, _InfoList}, State) ->
    lager:info("~s is no longer connected", [Node]),
    {'noreply', State};
handle_info({'nodedown', Node}, State) ->
    lager:info("~s is no longer connected", [Node]),
    {'noreply', State};
handle_info({'nodeup', Node, _InfoList}, State) ->
    lager:info("~s is now connected", [Node]),
    {'noreply', State};
handle_info({'nodeup', Node}, State) ->
    lager:info("VM ~s is now connected", [Node]),
    {'noreply', State};
handle_info({'ETS-TRANSFER', _TblId, _From, _Data}, State) ->
    lager:info("received ets transfer, start heartbeat"),
    {'noreply', start_timers(State#state{has_ets = 'true'})};
handle_info(_Info, State) ->
    lager:debug("unhandled message: ~p", [_Info]),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Allows listener to pass options to handlers.
%% @end
%%------------------------------------------------------------------------------
-spec handle_event(kz_json:object(), nodes_state()) -> gen_listener:handle_event_return().
handle_event(_JObj, #state{has_ets='false'}) ->
    'ignore';
handle_event(JObj, #state{node=Node}=State) ->
    case kz_api:node(JObj) =:= kz_term:to_binary(Node) of
        'true' -> 'ignore';
        'false' -> {'reply', [{'state', State}]}
    end.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_server' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_server' terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), nodes_state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:debug("listener terminating: ~p", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), nodes_state(), any()) -> {'ok', nodes_state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec advertise_payload(kz_types:kz_node()) -> kz_json:object().
advertise_payload(#kz_node{expires=Expires
                          ,kapps=Whapps
                          ,kapps_loaded=KappsLoaded
                          ,media_servers=MediaServers
                          ,used_memory=UsedMemory
                          ,processes=Processes
                          ,ports=Ports
                          ,version=Version
                          ,channels=Channels
                          ,conferences=Conferences
                          ,registrations=Registrations
                          ,zone=Zone
                          ,globals=Globals
                          ,md5=MD5
                          ,node=_N
                          }) ->
    kz_json:from_list(
      [{<<"md5">>, MD5}
      ,{<<"Expires">>, Expires}
      ,{<<"WhApps">>, kapps_to_json(Whapps) }
      ,{<<"Kapps-Loaded">>, kapp_versions_to_json(KappsLoaded)}
      ,{<<"Media-Servers">>, media_servers_to_json(MediaServers)}
      ,{<<"Used-Memory">>, UsedMemory}
      ,{<<"Processes">>, Processes}
      ,{<<"Ports">>, Ports}
      ,{<<"Version">>, Version}
      ,{<<"Channels">>, Channels}
      ,{<<"Conferences">>, Conferences}
      ,{<<"Registrations">>, Registrations}
      ,{<<"Zone">>, kz_term:to_binary(Zone)}
      ,{<<"Globals">>, kz_json:from_list(Globals)}
      ,{<<"Node-Info">>, kz_node:node_info()}
      | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
      ]).

-spec media_servers_to_json(kz_types:media_servers()) -> kz_json:object().
media_servers_to_json([]) -> 'undefined';
media_servers_to_json(Servers) ->
    kz_json:from_list(Servers).

-spec media_servers_from_json(kz_json:object()) -> kz_types:media_servers().
media_servers_from_json(Servers) ->
    [{Key, kz_json:get_value(Key, Servers)}
     || Key <- kz_json:get_keys(Servers)
    ].

-spec from_json(kz_json:object(), nodes_state()) -> kz_types:kz_node().
from_json(JObj, State) ->
    Node = kz_json:get_value(<<"Node">>, JObj),
    #kz_node{node=kz_term:to_atom(Node, 'true')
            ,md5=kz_json:get_value(<<"md5">>, JObj)
            ,expires=kz_term:to_integer(kz_json:get_integer_value(<<"Expires">>, JObj, 0) * ?FUDGE_FACTOR)
            ,kapps=kapps_from_json(kz_json:get_value(<<"WhApps">>, JObj, []))
            ,kapps_loaded=kapp_versions_from_json(kz_json:get_json_value(<<"Kapps-Loaded">>, JObj, kz_json:new()))
            ,media_servers=media_servers_from_json(kz_json:get_value(<<"Media-Servers">>, JObj, kz_json:new()))
            ,used_memory=kz_json:get_integer_value(<<"Used-Memory">>, JObj, 0)
            ,processes=kz_json:get_integer_value(<<"Processes">>, JObj, 0)
            ,ports=kz_json:get_integer_value(<<"Ports">>, JObj, 0)
            ,version=kz_json:get_first_defined([<<"Version">>, <<"App-Version">>], JObj, <<"unknown">>)
            ,channels=kz_json:get_integer_value(<<"Channels">>, JObj, 0)
            ,conferences=kz_json:get_integer_value(<<"Conferences">>, JObj, 0)
            ,registrations=kz_json:get_integer_value(<<"Registrations">>, JObj, 0)
            ,broker=get_amqp_broker(JObj)
            ,zone=get_zone(JObj, State)
            ,globals=kz_json:to_proplist(kz_json:get_value(<<"Globals">>, JObj, kz_json:new()))
            ,node_info=kz_json:get_json_value(<<"Node-Info">>, JObj)
            ,runtime=kz_json:get_json_value(<<"Runtime-Info">>, JObj)
            ,modules=kz_json:get_json_value(<<"Modules">>, JObj)
            ,roles=kz_json:to_proplist(kz_json:get_json_value(<<"Roles">>, JObj, kz_json:new()))
            }.

-spec kapps_from_json(kz_term:api_terms()) -> kz_types:kapps_info().
kapps_from_json(Whapps) when is_list(Whapps) ->
    [{Whapp, #whapp_info{}} || Whapp <- Whapps];
kapps_from_json(JObj) ->
    Keys = kz_json:get_keys(JObj),
    [whapp_from_json(Key, JObj) || Key <- Keys].

-spec whapp_from_json(binary(), kz_json:object()) -> {binary(), kz_types:whapp_info()}.
whapp_from_json(Key, JObj) ->
    {Key, whapp_info_from_json(Key, kz_json:get_value(Key, JObj))}.

-spec whapp_info_from_json(kz_term:ne_binary(), kz_json:object()) -> kz_types:whapp_info().
whapp_info_from_json(Key, JObj) ->
    whapp_info_from_json(Key, #whapp_info{}, kz_json:get_values(JObj)).

-spec whapp_info_from_json(kz_term:ne_binary(), kz_types:whapp_info(), {kz_json:json_terms(), kz_json:keys()}) -> kz_types:whapp_info().
whapp_info_from_json(_Key, Info, {[], []}) -> Info;
whapp_info_from_json(Key, Info, {[V | V1], [<<"Roles">> | K1]}) ->
    whapp_info_from_json(Key, Info#whapp_info{roles=V}, {V1, K1});
whapp_info_from_json(<<"kamailio">> = Key, Info, {[V | V1], [<<"Startup">> | K1]}) ->
    whapp_info_from_json(Key, Info#whapp_info{startup=kz_time:unix_seconds_to_gregorian_seconds(V)}, {V1, K1});
whapp_info_from_json(<<"freeswitch">> = Key, Info, {[V | V1], [<<"Startup">> | K1]}) ->
    whapp_info_from_json(Key, Info#whapp_info{startup=kz_time:unix_seconds_to_gregorian_seconds(V)}, {V1, K1});
whapp_info_from_json(Key, Info, {[V | V1], [<<"Startup">> | K1]}) ->
    whapp_info_from_json(Key, Info#whapp_info{startup=V}, {V1, K1});
whapp_info_from_json(Key, Info, {[_V | V1], [_K | K1]}) ->
    whapp_info_from_json(Key, Info, {V1, K1}).

-spec kapps_to_json(kz_types:kapps_info()) -> kz_json:object().
kapps_to_json(Whapps) ->
    List = [whapp_to_json(Whapp) || Whapp <- Whapps],
    kz_json:from_list(List).

-spec whapp_to_json({kz_term:ne_binary(), kz_types:whapp_info()}) -> {kz_term:ne_binary(), kz_json:object()}.
whapp_to_json({K, Info}) ->
    {K, whapp_info_to_json(Info)}.

-spec whapp_info_to_json(kz_types:whapp_info()) -> kz_json:object().
whapp_info_to_json(#whapp_info{startup=Start, roles=Roles}) ->
    kz_json:from_list(
      [{<<"Startup">>, Start}
      ,{<<"Roles">>, Roles}
      ]).

-spec kapp_versions_to_json([{kz_json:key(), kz_types:kapp_version()}]) -> kz_json:object().
kapp_versions_to_json([]) -> undefined;
kapp_versions_to_json(Kapps) ->
    List = [{Name, kapp_version_to_json(KappVersion)} || {Name, KappVersion} <- Kapps],
    kz_json:from_list(List).

-spec kapp_version_to_json(kz_types:kapp_version()) -> kz_json:object().
kapp_version_to_json(#kapp_version{name=Name, description=Desc, version=Version}) ->
    kz_json:from_list(
      [{<<"Name">>, Name}
      ,{<<"Description">>, Desc}
      ,{<<"Version">>, Version}
      ]).

-spec kapp_versions_from_json(kz_json:object()) -> [{kz_json:key(), kz_types:kapp_version()}].
kapp_versions_from_json(JObj) ->
    Keys = kz_json:get_keys(JObj),
    [kapp_version_tuple(Name, JObj) || Name <- Keys].

kapp_version_tuple(Name, JObj) ->
    VersionInfo = kz_json:get_value(Name, JObj),
    {Name, kapp_version_from_json(VersionInfo)}.

-spec kapp_version_from_json(kz_json:object()) -> kz_types:kapp_version().
kapp_version_from_json(JObj) ->
    #kapp_version{
       name = kz_json:get_ne_binary_value(<<"Name">>, JObj)
      ,description = kz_json:get_ne_binary_value(<<"Description">>, JObj)
      ,version = kz_json:get_ne_binary_value(<<"Version">>, JObj)
      }.

-spec get_zone(kz_json:object(), nodes_state()) -> atom().
get_zone(JObj, #state{zones=Zones, zone=LocalZone}) ->
    case kz_json:get_first_defined([<<"Zone">>, <<"AMQP-Broker-Zone">>], JObj) of
        'undefined' ->
            case kz_json:get_value(<<"AMQP-Broker">>, JObj) of
                'undefined' -> LocalZone;
                Broker ->
                    case props:get_value(Broker, Zones) of
                        'undefined' -> LocalZone;
                        Zone -> kz_term:to_atom(Zone, 'true')
                    end
            end;
        Zone -> kz_term:to_atom(Zone, 'true')
    end.

-spec get_amqp_broker(kz_term:api_ne_binary() | kz_json:object()) -> kz_term:api_ne_binary().
get_amqp_broker('undefined') ->
    kz_amqp_util:normalize_amqp_uri(kz_amqp_connections:primary_broker());
get_amqp_broker(Broker) when is_binary(Broker) ->
    kz_amqp_util:normalize_amqp_uri(Broker);
get_amqp_broker(JObj) ->
    get_amqp_broker(kz_json:get_ne_value(<<"AMQP-Broker">>, JObj)).

-spec notify_expire(kz_types:kz_nodes()) -> 'ok'.
notify_expire(Nodes) ->
    kz_nodes_notify:notify_expire(Nodes),
    lists:foreach(fun log_expired/1, Nodes).

-spec log_expired(kz_types:kz_node()) -> 'ok'.
log_expired(#kz_node{node=NodeName}) ->
    lager:info("lost heartbeat from node ~s", [NodeName]).

-spec notify_new(kz_types:kz_node()) -> 'ok'.
notify_new(#kz_node{node=NodeName}=Node) ->
    lager:info("received heartbeat from new node ~s", [NodeName]),
    kz_nodes_notify:notify_new(Node).

-spec notify_heartbeat(kz_types:kz_node()) -> 'ok'.
notify_heartbeat(#kz_node{}=Node) ->
    kz_nodes_notify:notify_heartbeat(Node).

-spec maybe_add_zone(kz_types:kz_node(), nodes_state()) -> nodes_state().
maybe_add_zone(#kz_node{zone='undefined'}, #state{}=State) -> State;
maybe_add_zone(#kz_node{zone=Zone, broker=B}, #state{zones=Zones}=State) ->
    Broker = kz_amqp_util:normalize_amqp_uri(B),
    case props:get_value(Broker, Zones) of
        'undefined' -> State#state{zones=[{Broker, Zone} | Zones]};
        _ -> State
    end.

-spec is_ready() -> boolean().
is_ready() ->
    try
        gen_listener:call(?MODULE, 'is_ready')
    catch
        _T:_E ->
            lager:info("nodes is_ready returned ~p : ~p", [_T,_E]),
            'false'
    end.

-spec find_me() -> kz_term:api_pid().
find_me() ->
    whereis(?SERVER).

-spec wait_for_refresh() -> 'ok'.
wait_for_refresh() ->
    gen_listener:call(?MODULE, 'refresh', 'infinity').

-spec advertise_node(kz_json:object(), pos_integer(), {pid(), pid()}) -> 'ok'.
advertise_node(Payload, Expires, {AMQPConsumer, AMQPChannel}) ->
    _ = kz_amqp_channel:consumer_channel(AMQPChannel),
    _ = kz_amqp_channel:consumer_pid(AMQPConsumer),
    FudgeExpires = kz_term:to_integer(Expires * ?FUDGE_FACTOR),
    Advertise = kz_json:set_value(<<"Expires">>, FudgeExpires, Payload),

    kapi_nodes:publish_advertise(Advertise).

-spec version() -> kz_term:ne_binary().
version() ->
    kz_application:application_version_with_otp_release(?APP).

next_heartbeat(Heartbeat) ->
    erlang:start_timer(Heartbeat, self(), 'heartbeat').

create_node(Heartbeat, Zone, Version, MD5) ->
    erlang:put('kazoo_bindings_silent_apply', 'true'),
    try
        Node = #kz_node{} = kz_node:create(Heartbeat, Zone, Version, MD5),
        Payload = advertise_payload(Node),
        gen_listener:cast(?MODULE, {'update_me', Node, Payload})
    catch
        _E:_N:ST ->
            lager:error("error creating node ~p : ~p", [_E, _N]),
            kz_log:log_stacktrace(ST)
    end.

-spec notify_waiting([pid()]) -> pid() | 'ok'.
notify_waiting([]) -> 'ok';
notify_waiting(Waiting) ->
    kz_process:spawn(fun() -> [gen_server:reply(Pid, 'ok') || Pid <- Waiting] end).
