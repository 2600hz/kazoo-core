%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2022, 2600Hz
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

-define(HEARTBEAT, 5 * ?MILLISECONDS_IN_SECOND + rand:uniform(10 * ?MILLISECONDS_IN_SECOND)).
-define(EXPIRE_PERIOD, 1 * ?MILLISECONDS_IN_SECOND).
-define(FUDGE_FACTOR, 1.25).

-record(state, {heartbeat_ref = erlang:make_ref() :: reference()
               ,node = node() :: atom()
               ,md5 :: kz_term:ne_binary()
               ,zone = 'local' :: atom()
               ,version :: kz_term:ne_binary()
               ,zones = [] :: kz_term:proplist()
               ,me = 'undefined' :: kz_types:kz_node() | 'undefined'
               ,is_consuming = false :: boolean()
               ,has_ets = false :: boolean()
               ,waiting = [] :: [kz_term:pid_ref()]
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
    'true' = kapi_nodes:advertise_v(JObj),

    Srv = props:get_value('server', Props),
    Node = props:get_value('node', Props),
    case kz_json:get_value(<<"Node">>, JObj, Node) =:= Node of
        'false' -> gen_listener:cast(Srv, {'advertise', JObj});
        'true' -> 'ok'
    end.

-spec build_advertised_node(kz_json:object(), nodes_state()) -> kz_types:kz_node() | 'ok'.
build_advertised_node(JObj, State) ->
    try
        from_json(JObj, State)
    catch
        _E:_R:_ST ->
            kz_log:log_stacktrace(_ST),
            lager:warning("error building advertised node : ~p", [{_E, _R}])
    end.

-spec update_advertised_node(kz_types:kz_node(), nodes_state()) -> pid() | 'true'.
update_advertised_node(_Node, #state{has_ets='false'}) -> 'true';
update_advertised_node(Node, #state{has_ets='true'}) ->
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
    kapi_nodes:declare_exchanges(),
    kapi_self:declare_exchanges(),
    State = #state{zone = kz_nodes:local_zone()
                  ,md5 = kz_nodes:node_encoded()
                  ,version = version()
                  },
    {'ok', State}.

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
handle_cast({'advertise', JObj}, State) ->
    case build_advertised_node(JObj, State) of
        #kz_node{}=Node ->
            _ = update_advertised_node(Node, State),
            {'noreply', maybe_add_zone(Node, State)};
        'ok' -> {'noreply', State}
    end;
handle_cast({'gen_listener', {'created_queue', _Q}}, State) ->
    lager:info("nodes acquired queue name ~s, starting remote heartbeats", [_Q]),
    {'noreply', State};
handle_cast({'gen_listener', {'is_consuming', IsConsuming}}, State) ->
    lager:debug("heartbeat from remotes is ~p", [IsConsuming]),
    gen_listener:cast(self(), 'check_is_ready'),
    {'noreply', State#state{is_consuming=IsConsuming}};
handle_cast('flush', State) ->
    ets:delete_all_objects(?MODULE),
    {'noreply', State};
handle_cast('check_is_ready', #state{has_ets='true', is_consuming='true'}=State) ->
    self() ! {'heartbeat', State#state.heartbeat_ref},
    _ = erlang:send_after(?EXPIRE_PERIOD, self(), 'expire_nodes'),
    _ = net_kernel:monitor_nodes('true', ['nodedown_reason'
                                         ,{'node_type', 'all'}
                                         ]),
    {'noreply', State};
handle_cast('check_is_ready', State) ->
    {'noreply', State};
handle_cast(_Msg, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), nodes_state()) -> kz_types:handle_info_ret_state(nodes_state()).
handle_info('expire_nodes', #state{node=ThisNode, has_ets='true'}=State) ->
    ExpiredNodes = kz_nodes_ets:expire_nodes(ThisNode),
    _ = kz_process:spawn(fun notify_expire/1, [ExpiredNodes]),
    _ = erlang:send_after(?EXPIRE_PERIOD, self(), 'expire_nodes'),
    {'noreply', State};

handle_info({'heartbeat', Ref}
           ,#state{heartbeat_ref=Ref
                  ,me=Me
                  ,waiting=Waiting
                  ,zone=Zone
                  ,version=Version
                  ,md5=MD5
                  }=State
           ) ->
    Heartbeat = ?HEARTBEAT,
    Reference = erlang:make_ref(),
    _ = erlang:send_after(Heartbeat, self(), {'heartbeat', Reference}),

    try
        Node = #kz_node{} =
            kz_node:create(Heartbeat, Zone, Version, MD5),
        _ = kz_nodes_ets:add_node(Node),

        maybe_advertise_node(Node),
        _ = [gen_server:reply(Pid, 'ok') || Pid <- Waiting],
        {'noreply', State#state{heartbeat_ref=Reference, me=Node, waiting=[]}}
    catch
        _:{'noproc',_}:_ST ->
            {'noreply', State#state{heartbeat_ref=Reference}, 'hibernate'};
        'exit' : {'timeout' , _}:_ST when Me =/= 'undefined' ->
            NewMe = Me#kz_node{expires=Heartbeat},
            _ = kz_nodes_ets:add_node(NewMe),
            lager:notice("timeout creating node sending old data"),
            {'noreply', State#state{heartbeat_ref=Reference, me=NewMe}};
        'exit' : {'timeout' , _}:_ST ->
            lager:warning("timeout creating node, no data to send"),
            {'noreply', State#state{heartbeat_ref=Reference}};
        _E:_N:ST ->
            lager:error("error creating node ~p : ~p", [_E, _N]),
            kz_log:log_stacktrace(ST),
            {'noreply', State#state{heartbeat_ref=Reference}, 'hibernate'}
    end;

handle_info({'nodedown', Node, _InfoList}, State) ->
    lager:info("~s is no longer connected:", [Node]),
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
    lager:info("received ets transfer"),
    gen_listener:cast(self(), 'check_is_ready'),
    {'noreply', State#state{has_ets=true}};
handle_info(_Info, State) ->
    lager:debug("unhandled message: ~p", [_Info]),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Allows listener to pass options to handlers.
%% @end
%%------------------------------------------------------------------------------
-spec handle_event(kz_json:object(), nodes_state()) -> gen_listener:handle_event_return().
handle_event(_JObj, #state{has_ets=false}) ->
    'ignore';
handle_event(_JObj, #state{node=Node}) ->
    {'reply', [{'node', kz_term:to_binary(Node)}]}.

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
-spec advertise_payload(kz_types:kz_node()) -> kz_term:proplist().
advertise_payload(#kz_node{expires=Expires
                          ,kapps=Whapps
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
    props:filter_undefined(
      [{<<"md5">>, MD5}
      ,{<<"Expires">>, Expires}
      ,{<<"WhApps">>, kapps_to_json(Whapps) }
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
    kz_nodes_notify:notify_expire(Nodes).

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

-spec maybe_advertise_node(kz_types:kz_node()) -> 'ok'.
maybe_advertise_node(#kz_node{broker = <<"disconnected">>}) -> 'ok';
maybe_advertise_node(Node) ->
    kapi_nodes:publish_advertise(advertise_payload(Node)).

-spec version() -> kz_term:ne_binary().
version() ->
    Version = kapps_util:kazoo_version(),
    OTPRelease = kapps_util:otp_release(),
    list_to_binary([Version, " - ", OTPRelease]).
