%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2026, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_amqp_connections).
-behaviour(gen_server).

-export([new/1
        ,new/2
        ]).
-export([add/1
        ,add/2
        ,add/3
        ]).
-export([remove/1]).
-export([broker_connections/1
        ,connections/0, connections/1, managers/1
        ]).
-export([broker_available_connections/1]).
-export([primary_broker/0]).
-export([arbitrator_broker/0]).
-export([federated_brokers/0]).
-export([broker_zone/1]).
-export([available/1]).
-export([unavailable/1]).
-export([is_available/0]).
-export([wait_for_available/0, wait_for_available/1]).
-export([wait_for_available_tag/1]).

-export([brokers_for_zone/1, brokers_for_zone/2, broker_for_zone/1]).
-export([brokers_with_tag/1, brokers_with_tag/2, broker_with_tag/1]).
-export([is_zone_available/1, is_tag_available/1, is_hidden_broker/1]).
-export([uris/0]).

-export([configured_brokers/0]).

-export([start_link/0]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-include("kz_amqp_util.hrl").

-define(SERVER, ?MODULE).

-define(TAB, ?MODULE).

-record(state, {watchers = sets:new() :: sets:set(pid())}).
-type state() :: #state{}.

-type broker_config() :: {'name', atom()} |
                         {'zone', atom()} |
                         {'uri', list()} |
                         {'amqp_uri', list()}.
-type configured_broker() :: {atom(), [broker_config()]}.
-type configured_brokers() :: [configured_broker()].

-export_type([kz_amqp_connections/0
             ,configured_brokers/0
             ]).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server.
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?SERVER}, ?MODULE, [], []).

%% @doc create a new local-zone connection to an AMQP URI
-spec new(kz_amqp_connection() | kz_term:text()) ->
          kz_amqp_connection() |
          {'error', any()}.
new(Broker) -> new(Broker, 'local').

%% @doc create a new connection (if not existing) to an AMQP URI,
%% assigned to a zone
-spec new(kz_amqp_connection() | kz_term:text(), kz_term:text()) ->
          kz_amqp_connection() |
          {'error', any()}.
new(<<Broker/binary>>, Zone) ->
    case broker_connections(Broker) =:= 0 of
        'false' -> {'error', 'exists'};
        'true' -> add(Broker, Zone)
    end;
new(Broker, Zone) ->
    new(kz_term:to_binary(Broker), Zone).

-spec add(kz_amqp_connection() | kz_term:text()) ->
          kz_amqp_connection() |
          {'error', any()}.
add(Broker) -> add(Broker, 'local').

-spec add(kz_amqp_connection() | kz_term:text(), kz_term:text()) ->
          kz_amqp_connection() |
          {'error', any()}.
add(#kz_amqp_connection{broker=Broker, tags=Tags}=Connection, Zone) ->
    case kz_amqp_connection_sup:add(Connection) of
        {'ok', Pid} ->
            lager:info("new connection proc ~p for ~s", [Pid, Broker]),
            gen_server:cast(?SERVER, {'new_connection', Pid, Broker, Zone, Tags}),
            Connection;
        {'error', Reason} = Error ->
            lager:warning("unable to start amqp connection to '~s': ~p"
                         ,[Broker, Reason]
                         ),
            Error
    end;
add(Broker, Zone) when not is_binary(Broker) ->
    add(kz_term:to_binary(Broker), Zone);
add(Broker, Zone) when not is_atom(Zone) ->
    add(Broker, kz_term:to_atom(Zone, 'true'));
add(Broker, Zone) ->
    add(Broker, Zone, []).

-spec add(kz_amqp_connection() | kz_term:text(), kz_term:text(), list()) ->
          kz_amqp_connection() |
          {'error', any()}.
add(Broker, Zone, Tags) ->
    try amqp_uri:parse(kz_term:to_list(Broker)) of
        {'error', {Info, _}} ->
            lager:error("failed to parse AMQP URI '~s': ~p", [Broker, Info]),
            {'error', 'invalid_uri'};
        {'ok', #amqp_params_network{}=Params} ->
            add(#kz_amqp_connection{broker=Broker
                                   ,params=Params#amqp_params_network{connection_timeout=500}
                                   ,tags=Tags
                                   ,hidden=is_hidden_broker(Tags)
                                   ,prechannels=prechannels_from_zone_config(zone_config_name(Zone))
                                   }
               ,Zone
               );
        {'ok', Params} ->
            lager:info("broker ~s params ~p", [Broker, Params]),
            add(#kz_amqp_connection{broker=Broker
                                   ,params=Params
                                   ,tags=Tags
                                   ,hidden=is_hidden_broker(Tags)
                                   }
               ,Zone
               )
    catch
        _E:_R ->
            lager:error("failed to parse AMQP URI '~s': ~s ~p", [Broker, _E, _R]),
            {'error', 'invalid_uri'}
    end.

zone_config_name('local') -> kz_config:zone();
zone_config_name(Zone) -> Zone.

prechannels_from_zone_config(Zone) ->
    DefaultPrechannels = kz_app_config:get_integer('amqp', <<"number_of_prechannels">>, 10),
    Brokers = configured_brokers(),
    lists:foldl(fun(Item, Acc) -> prechannels_from_zone_config(Item, Acc, Zone) end, DefaultPrechannels, Brokers).

prechannels_from_zone_config({_, Props}, Acc, Zone) ->
    case props:get_value(<<"zone">>, Props, 'local') of
        Zone -> props:get_integer_value(<<"prechannels">>, Props, Acc);
        _OtherZone -> Acc
    end.

-spec remove(kz_term:pids() | pid() | kz_term:text()) -> 'ok'.
remove([]) -> 'ok';
remove([Connection|Connections]) when is_pid(Connection) ->
    remove(Connection),
    remove(Connections);
remove(Connection) when is_pid(Connection) ->
    _R = kz_amqp_connection_sup:remove(Connection),
    gen_server:cast(?SERVER, {'connection_removed', Connection});
remove(Broker) when not is_binary(Broker) ->
    remove(kz_term:to_binary(Broker));
remove(Broker=?NE_BINARY) ->
    Pattern = #kz_amqp_connections{broker=Broker
                                  ,connection='$1'
                                  ,_='_'
                                  },
    remove([Connection || [Connection] <- ets:match(?TAB, Pattern)]).

%% @doc Change a connection's availability to 'true'
-spec available(pid()) -> 'ok'.
available(Connection) when is_pid(Connection) ->
    gen_server:cast(?SERVER, {'connection_available', Connection}).

%% @doc Change a connection's availability to 'false'
-spec unavailable(pid()) -> 'ok'.
unavailable(Connection) when is_pid(Connection) ->
    gen_server:cast(?SERVER, {'connection_unavailable', Connection}).

%% @doc Selects the first available, non-hidden broker as the
%% arbitrator broker.
-spec arbitrator_broker() -> kz_term:api_binary().
arbitrator_broker() ->
    MatchSpec = [{#kz_amqp_connections{broker='$1'
                                      ,available='true'
                                      ,hidden='false'
                                      ,_='_'
                                      },
                  [],
                  ['$1']}
                ],
    case lists:sort(ets:select(?TAB, MatchSpec)) of
        [] -> 'undefined';
        [Arbitrator|_] -> Arbitrator
    end.

%% @doc counts how many connections to Broker (AMQP URI) exist
-spec broker_connections(kz_term:ne_binary()) -> non_neg_integer().
broker_connections(Broker) ->
    gen_server:call(?SERVER, {'broker_connections', Broker}).

%% @doc returns all kz_amqp_connections() records
-spec connections() -> [kz_amqp_connections()].
connections() ->
    MatchSpec = [{#kz_amqp_connections{connection='$1'
                                      ,_='_'
                                      },
                  [],
                  ['$_']}
                ],
    ets:select(?TAB, MatchSpec).

%% @doc returns all kz_amqp_connection() records for Broker
-spec connections(kz_term:ne_binary()) -> [kz_amqp_connection()].
connections(Broker) ->
    MatchSpec = [{#kz_amqp_connections{broker=Broker
                                      ,connection='$1'
                                      ,_='_'
                                      },
                  [],
                  ['$$']}
                ],
    ets:select(?TAB, MatchSpec).

%% @doc selects all amqp_client connection PIDs for Broker (or primary
%% broker if undefined)
-spec managers(kz_term:api_ne_binary()) -> [pid()].
managers('undefined') ->
    managers(primary_broker());
managers(Broker) ->
    MatchSpec = [{#kz_amqp_connections{available='true'
                                      ,broker=Broker
                                      ,connection='$1'
                                      ,_='_'
                                      },
                  [],
                  ['$1']}
                ],
    ets:select(?TAB, MatchSpec).

-spec broker_available_connections(kz_term:ne_binary()) -> non_neg_integer().
broker_available_connections(Broker) ->
    gen_server:call(?SERVER, {'broker_available_connections', Broker}).

%% @doc returns the first Broker URI from the sorted list of
%% available, non-hidden brokers in the 'local' zone
-spec primary_broker() -> kz_term:api_ne_binary().
primary_broker() ->
    Pattern = #kz_amqp_connections{available='true'
                                  ,zone='local'
                                  ,hidden='false'
                                  ,broker='$1'
                                  ,_='_'
                                  },
    case lists:sort([Broker
                     || [Broker] <- ets:match(?TAB, Pattern)
                    ])
    of
        [] -> 'undefined';
        [Broker|_] -> Broker
    end.

%% @doc returns list of unique broker URIs that are not in the 'local'
%% zone and are not hidden.
-spec federated_brokers() -> kz_term:ne_binaries().
federated_brokers() ->
    MatchSpec = [{#kz_amqp_connections{zone='$1'
                                      ,broker='$2'
                                      ,hidden='$3'
                                      ,_='_'
                                      },
                  [{'andalso',
                    {'=/=', '$1', 'local'},
                    {'=:=', '$3', 'false'}}
                  ],
                  ['$2']
                 }
                ],
    sets:to_list(
      sets:from_list(
        ets:select(?TAB, MatchSpec)
       )
     ).

%% @doc returns what zone a Broker URI is assigned (or 'unknown' if none found)
-spec broker_zone(kz_term:ne_binary()) -> atom().
broker_zone(Broker) ->
    Pattern = #kz_amqp_connections{broker=Broker
                                  ,zone='$1'
                                  ,_='_'
                                  },
    case ets:match(?TAB, Pattern) of
        [[Zone]|_] -> Zone;
        _Else -> 'unknown'
    end.

-spec is_available() -> boolean().
is_available() -> primary_broker() =/= 'undefined'.

%% @doc wait until the primary broker is available
-spec wait_for_available() -> 'ok'.
wait_for_available() ->
    wait_for_available('infinity').

-spec wait_for_available(timeout()) -> 'ok'.
wait_for_available(Timeout) ->
    wait_for_available(fun is_available/0, Timeout).

%% @doc wait until a broker with Tag is available
-spec wait_for_available_tag(binary()) -> 'ok'.
wait_for_available_tag(Tag) -> wait_for_available(fun() -> is_tag_available(Tag) end, 'infinity').

-spec wait_for_available(fun(() -> boolean()), timeout()) -> 'ok' | {'error', 'timeout'}.
wait_for_available(IsAvailableFun, Timeout) ->
    case IsAvailableFun() of
        'true' -> 'ok';
        'false' ->
            gen_server:cast(?SERVER, {'add_watcher', IsAvailableFun, self()}),
            wait_for_notification(Timeout)
    end.

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server.
%% @end
%%------------------------------------------------------------------------------
-spec init([]) -> {'ok', state()}.
init([]) ->
    kz_log:put_callid(?DEFAULT_LOG_SYSTEM_ID),
    _ = ets:new(?TAB, ['named_table'
                      ,{'keypos', #kz_amqp_connections.connection}
                      ,'protected'
                      ,{'read_concurrency', 'true'}
                      ]),
    {'ok', #state{}}.

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call({'broker_connections', Broker}, _From, State) ->
    MatchSpec = [{#kz_amqp_connections{broker=Broker
                                      ,_='_'
                                      },
                  [],
                  ['true']}
                ],
    {'reply', ets:select_count(?TAB, MatchSpec), State};
handle_call({'broker_available_connections', Broker}, _From, State) ->
    MatchSpec = [{#kz_amqp_connections{broker=Broker
                                      ,available='true'
                                      ,_='_'
                                      },
                  [],
                  ['true']}
                ],
    {'reply', ets:select_count(?TAB, MatchSpec), State};
handle_call(_Msg, _From, State) ->
    lager:error("unhandled call from ~p => ~p", [_From, _Msg]),
    {'reply', {'error', 'not_implemented'}, State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'new_connection', KZConnection, Broker, Zone, Tags}, State) ->
    Ref = erlang:monitor('process', KZConnection),
    _ = ets:insert(?TAB, #kz_amqp_connections{connection=KZConnection
                                             ,connection_ref=Ref
                                             ,broker=Broker
                                             ,zone=Zone
                                             ,tags=Tags
                                             ,hidden=is_hidden_broker(Tags)
                                             }),
    {'noreply', State, 'hibernate'};
handle_cast({'connection_available', Connection}, State) ->
    lager:debug("connection ~p is now available", [Connection]),
    Props = [{#kz_amqp_connections.available, 'true'}],
    _ = ets:update_element(?TAB, Connection, Props),
    {'noreply', notify_watchers(State), 'hibernate'};
handle_cast({'connection_unavailable', Connection}, State) ->
    lager:warning("connection ~p is no longer available", [Connection]),
    Props = [{#kz_amqp_connections.available, 'false'}],
    _ = ets:update_element(?TAB, Connection, Props),
    {'noreply', State, 'hibernate'};
handle_cast({'connection_removed', Connection}, State) ->
    ets:delete(?TAB, Connection),
    lager:info("removed connection ~p", [Connection]),
    {'noreply', State, 'hibernate'};
handle_cast({'add_watcher', Fun, Watcher}, State) ->
    case Fun() of
        'false' -> {'noreply', add_watcher(Watcher, State), 'hibernate'};
        'true' ->
            notify_watcher(Watcher),
            {'noreply', State, 'hibernate'}
    end;
handle_cast(_Msg, State) ->
    {'noreply', State, 'hibernate'}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info({'DOWN', _Ref, 'process', _Connection, 'shutdown'}, State) ->
    {'noreply', State, 'hibernate'};
handle_info({'DOWN', Ref, 'process', Connection, _Reason}, State) ->
    lager:warning("connection ~p went down: ~p", [Connection, _Reason]),
    erlang:demonitor(Ref, ['flush']),
    _ = ets:delete(?TAB, Connection),
    {'noreply', State, 'hibernate'};
handle_info(_Info, State) ->
    lager:debug("unhandled message: ~p", [_Info]),
    {'noreply', State, 'hibernate'}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_server' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_server' terminates
%% with Reason. The return value is ignored.
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:debug("AMQP connections terminating: ~p", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec add_watcher(pid(), state()) -> state().
add_watcher(Watcher, #state{watchers=Watchers}=State) ->
    State#state{watchers=sets:add_element(Watcher, Watchers)}.

-spec notify_watchers(state()) -> state().
notify_watchers(#state{watchers = Watchers}=State) ->
    F = fun (Watcher, _) -> notify_watcher(Watcher) end,
    sets:fold(F, 'ok', Watchers),
    State#state{watchers = sets:new()}.

-spec notify_watcher(pid()) -> 'ok'.
notify_watcher(Watcher) ->
    Watcher ! {?MODULE, 'connection_available'},
    'ok'.

-spec wait_for_notification(timeout()) ->
          'ok' |
          {'error', 'timeout'}.
wait_for_notification(Timeout) ->
    receive
        {?MODULE, 'connection_available'} -> 'ok'
    after
        Timeout -> {'error', 'timeout'}
    end.

-spec brokers_with_tag(kz_term:ne_binary()) -> kz_amqp_connections_list().
brokers_with_tag(Tag) ->
    %% by default we want all the brokers
    brokers_with_tag(Tag, 'undefined').

-spec brokers_with_tag(kz_term:ne_binary(), kz_term:api_boolean()) -> kz_amqp_connections_list().
brokers_with_tag(Tag, Available) ->
    MatchSpec = [{#kz_amqp_connections{available='$1'
                                      ,_='_'
                                      },
                  [{'orelse',
                    {'=:=', '$1', {'const', Available}},
                    {'=:=', {'const', Available}, 'undefined'}
                   }
                  ]
                 ,['$_']
                 }
                ],
    [Connection
     || #kz_amqp_connections{tags=Tags}=Connection <- ets:select(?TAB, MatchSpec),
        lists:member(Tag, Tags)
    ].

-spec broker_with_tag(kz_term:ne_binary()) -> kz_term:api_binary().
broker_with_tag(Tag) ->
    case brokers_with_tag(Tag, 'true') of
        [] -> 'undefined';
        [#kz_amqp_connections{broker=Broker}|_] -> Broker
    end.

-spec brokers_for_zone(atom()) -> kz_amqp_connections_list().
brokers_for_zone(Zone) ->
    %% by default we want all the brokers
    brokers_for_zone(Zone, 'undefined').

-spec brokers_for_zone(atom(), kz_term:api_boolean()) -> kz_amqp_connections_list().
brokers_for_zone(Zone, Available) ->
    MatchSpec = [{#kz_amqp_connections{zone='$1'
                                      ,available='$2'
                                      ,_='_'
                                      },
                  [{'andalso',
                    {'=:=', '$1', {'const', Zone}},
                    {'orelse',
                     {'=:=', '$2', {'const', Available}},
                     {'=:=', {'const', Available}, 'undefined'}
                    }
                   }
                  ],
                  ['$_']
                 }
                ],
    ets:select(?TAB, MatchSpec).

-spec broker_for_zone(atom()) -> kz_term:api_binary().
broker_for_zone(Zone) ->
    case brokers_for_zone(Zone, 'true') of
        [] -> 'undefined';
        [#kz_amqp_connections{broker=Broker}|_] -> Broker
    end.

-spec is_zone_available(atom()) -> boolean().
is_zone_available(Zone) -> broker_for_zone(Zone) =/= 'undefined'.

-spec is_tag_available(kz_term:ne_binary()) -> boolean().
is_tag_available(Tag) -> broker_with_tag(Tag) =/= 'undefined'.

-spec is_hidden_broker(list()) -> boolean().
is_hidden_broker(Tags) -> lists:member(?AMQP_HIDDEN_TAG, Tags).

-spec uris() -> [{atom(), kz_term:ne_binary()}].
uris() ->
    lists:usort([{zone_config_name(Zone), Broker}
                 || #kz_amqp_connections{broker=Broker, zone = Zone, tags=Tags} <- ets:tab2list(?TAB),
                    not is_hidden_broker(Tags)
                ]
               ).

-spec configured_brokers() -> configured_brokers().
configured_brokers() ->
    case kz_config:get_section('zone') of
        [] -> kz_config:get_section(?CONFIG_SECTION);
        Zones -> Zones
    end.
