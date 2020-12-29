%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2020, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_nodes_ets).

-compile({'no_auto_import', [nodes/0]}).

-export([is_up/1]).
-export([whapp_count/1, whapp_count/2
        ,whapp_role_count/2, whapp_role_count/3
        ,node_role_count/1, node_role_count/2
        ,whapp_oldest_node/1
        ,whapp_oldest_node/2

        ,expire_nodes/1
        ]).
-export([status/0]).
-export([status_to_json/0
        ,request/1
        ,nodes/0
        ]).
-export([local_zone/0]).
-export([whapp_zones/1, whapp_zone_count/1]).
-export([globals_scope/0]).

-export([with_role/1, with_role/2]).

%% ETS Management
-export([table_id/0
        ,table_options/0
        ,gift_data/0
        ]).

-export([add_node/1
        ,get_node/1
        ,get_nodes_info/0
        ]).

-type request_info() :: {'app', atom()} |
                        {'media_servers', [{kz_term:ne_binary(), kz_json:object()}]} |
                        {'channels', non_neg_integer()} |
                        {'conferences', non_neg_integer()} |
                        {'registrations', non_neg_integer()} |
                        {'info', kz_types:whapp_info()}.
-type request_acc() :: [request_info()].

-export_type([request_acc/0]).

-include("kazoo_nodes.hrl").

-define(TAB_NAME, ?MODULE).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server.
%% @end
%%------------------------------------------------------------------------------

-spec is_up(node()) -> boolean().
is_up(Node) ->
    case ets:match(?MODULE, #kz_node{node = Node
                                    ,expires = '$2'
                                    ,_ = '_'
                                    })
    of
        [] -> 'false';
        [_] -> 'true'
    end.

-spec globals_scope() -> integer().
globals_scope() ->
    MatchSpec = [{#kz_node{globals='$1'
                          ,node='$2'
                          ,_ = '_'
                          }
                 ,[{'andalso'
                   ,{'=/=', '$1', []}
                   ,{'=/=', '$2', {'const', node()}}
                   }]
                 ,['$1']
                 }],
    length(ets:select(?MODULE, MatchSpec)).

-spec whapp_count(kz_term:text()) -> integer().
whapp_count(Whapp) ->
    whapp_count(Whapp, 'false').

-spec whapp_count(kz_term:text(), kz_term:text() | boolean() | 'remote') -> integer().
whapp_count(Whapp, Arg) when not is_atom(Arg) ->
    whapp_count(Whapp, kz_term:to_atom(Arg, 'true'));
whapp_count(Whapp, 'false') ->
    MatchSpec = [{#kz_node{kapps='$1'
                          ,zone = local_zone()
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,['$1']
                 }],
    determine_whapp_count(kz_term:to_binary(Whapp), MatchSpec);
whapp_count(Whapp, 'true') ->
    MatchSpec = [{#kz_node{kapps='$1'
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,['$1']
                 }],
    determine_whapp_count(kz_term:to_binary(Whapp), MatchSpec);
whapp_count(Whapp, 'remote') ->
    Zone = local_zone(),
    MatchSpec = [{#kz_node{kapps='$1'
                          ,zone='$2'
                          ,_ = '_'
                          }
                 ,[{'andalso'
                   ,{'=/=', '$1', []}
                   ,{'=/=', '$2', {'const', Zone}}
                   }]
                 ,['$1']
                 }],
    determine_whapp_count(kz_term:to_binary(Whapp), MatchSpec);
whapp_count(Whapp, Unhandled) ->
    lager:debug("invalid parameters ~p ~p", [Whapp, Unhandled]),
    0.

-spec determine_whapp_count(kz_term:ne_binary(), ets:match_spec()) -> non_neg_integer().
determine_whapp_count(Whapp, MatchSpec) ->
    lists:foldl(fun(Whapps, Acc) when is_list(Whapps) ->
                        determine_whapp_count_fold(Whapps, Acc, Whapp)
                end
               ,0
               ,ets:select(?MODULE, MatchSpec)
               ).

-spec determine_whapp_count_fold(kz_types:kapps_info(), non_neg_integer(), kz_term:ne_binary()) -> non_neg_integer().
determine_whapp_count_fold(Whapps, Acc, Whapp) ->
    case props:is_defined(Whapp, Whapps) of
        'true' -> Acc + 1;
        'false' -> Acc
    end.

-spec whapp_zones(kz_term:text()) -> kz_term:atoms().
whapp_zones(Whapp) ->
    MatchSpec = [{#kz_node{kapps='$1'
                          ,zone='$2'
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,[{{'$2', '$1'}}]
                 }],
    determine_whapp_zones(kz_term:to_binary(Whapp), MatchSpec).

-spec determine_whapp_zones(kz_term:ne_binary(), ets:match_spec()) -> kz_term:atoms().
determine_whapp_zones(Whapp, MatchSpec) ->
    {Whapp, Zones, _} =
        lists:foldl(fun determine_whapp_zones_fold/2
                   ,{Whapp, [], 0}
                   ,ets:select(?MODULE, MatchSpec)
                   ),
    Zones.

-spec whapp_zone_count(kz_term:text()) -> integer().
whapp_zone_count(Whapp) ->
    length(whapp_zones(Whapp)).

-type fold_zones_acc() :: {atom(), kz_term:atoms(), non_neg_integer()}.

-spec determine_whapp_zones_fold({atom(), kz_types:kapps_info()}, fold_zones_acc()) -> fold_zones_acc().
determine_whapp_zones_fold({Zone, Whapps}, {Whapp, Zones, C}=Acc) ->
    case props:is_defined(Whapp, Whapps)
        andalso not lists:member(Zone, Zones)
    of
        'true' -> {Whapp, [Zone | Zones], C+ 1};
        'false' -> Acc
    end.

-spec status_to_json() -> kz_json:object().
status_to_json() ->
    try
        Nodes = lists:sort(fun compare_nodes/2, ets:tab2list(?MODULE)),
        lists:foldl(fun node_status_to_json/2, kz_json:new(), Nodes)
    catch
        'error':'badarg' ->
            kz_json:set_value(<<"error">>
                             ,<<"status unknown until node is fully initialized, try again in a moment\n">>
                             ,kz_json:new()
                             )
    end.

-spec node_status_to_json(kz_types:kz_node(), kz_json:object()) -> kz_json:object().
node_status_to_json(#kz_node{zone=NodeZone
                            ,node=N
                            ,md5=MD5
                            ,version=Version
                            ,processes=Processes
                            ,ports=Ports
                            ,used_memory=UsedMemory
                            ,broker=Broker
                            ,kapps=Kapps
                            ,globals=Globals
                            ,node_info=NodeInfo
                            ,roles=Roles
                            ,media_servers=MediaServers
                            ,registrations=Regs
                            ,channels=Channels
                            ,conferences=Conferences
                            }=_Node
                   ,Acc
                   ) ->
    StatusProps = props:filter_empty(
                    [{<<"node">>, kz_term:to_binary(N)}
                    ,{<<"md5">>, MD5}
                    ,{<<"version">>, Version}
                    ,{<<"used_memory">>, kz_term:to_binary(kz_network_utils:pretty_print_bytes(UsedMemory))}
                    ,{<<"processes">>, Processes}
                    ,{<<"ports">>, Ports}
                    ,{<<"zone">>, kz_term:to_binary(NodeZone)}
                    ,{<<"broker">>, Broker}
                    ,{<<"kapps">>, [K || {K, _} <- Kapps]}
                    ,{<<"globals">>, kz_json:from_list(Globals)}
                    ,{<<"node_info">>, NodeInfo}
                    ,{<<"roles">>, kz_json:from_list(Roles)}
                    ,{<<"media_servers">>, [K || {K, _} <- MediaServers]}
                    ,{<<"channels">>, Channels}
                    ,{<<"conferences">>, Conferences}
                    ,{<<"registrations">>, Regs}
                    ]),
    [NodeType,_] = binary:split(kz_term:to_binary(N), <<"@">>),
    kz_json:set_value([kz_term:to_binary(NodeZone), NodeType, kz_term:to_binary(N)]
                     ,kz_json:from_list(StatusProps)
                     ,Acc
                     ).

-spec status() -> 'ok'.
status() ->
    Nodes = nodes(),
    print_status(Nodes, kz_nodes_listener:local_zone()),
    check_node_versions(Nodes).

-spec nodes() -> kz_types:kz_nodes().
nodes() ->
    lists:sort(fun compare_nodes/2, ets:tab2list(?MODULE)).

-spec check_node_versions(kz_types:kz_nodes()) -> 'ok'.
check_node_versions([]) -> 'ok';
check_node_versions([_Node]) -> 'ok';
check_node_versions([#kz_node{version=Version
                             ,node=Node
                             }
                    | Nodes
                    ]) ->
    [Name, _Host] = binary:split(kz_term:to_binary(Node), <<"@">>),
    check_node_versions(Nodes, {Name, Node, Version}).

-spec check_node_versions(kz_types:kz_nodes(), {kz_term:ne_binary(), node(), kz_term:ne_binary()}) -> 'ok'.
check_node_versions([], _) -> 'ok';
check_node_versions([#kz_node{version=Vsn
                             ,node=N
                             }
                    | Nodes
                    ]
                   ,{Name, Node, Version}=Current
                   ) ->
    CheckAgainst =
        case binary:split(kz_term:to_binary(N), <<"@">>) of
            [Name, _Host] when Vsn =:= Version -> Current;
            [Name, _Host] when Vsn > Version ->
                lager:warning("node ~s is running a newer version (~s) than ~s (~s)"
                             ,[N, Vsn, Node, Version]
                             ),
                Current;
            [Name, _Host] ->
                lager:warning("node ~s is running an older version (~s) than ~s (~s)"
                             ,[N, Vsn, Node, Version]
                             ),
                Current;
            [NewName, _Host] ->
                {NewName, N, Vsn}
        end,
    check_node_versions(Nodes, CheckAgainst).

-spec compare_nodes(kz_types:kz_node(), kz_types:kz_node()) -> boolean().
compare_nodes(#kz_node{node = N1}, #kz_node{node = N2}) -> N1 > N2.

-spec print_status(kz_types:kz_nodes(), atom()) -> 'ok'.
print_status(Nodes, Zone) ->
    F = fun(Node) -> kz_node:print_node_status(Node, Zone) end,
    lists:foreach(F, Nodes).

-spec add_node(kz_types:kz_node()) -> 'new' | 'update'.
add_node(Node) ->
    case ets:insert_new(?TAB_NAME, Node) of
        'true' -> 'new';
        'false' ->
            _ = ets:insert(?TAB_NAME, Node),
            'update'
    end.

-spec get_node(atom()) -> kz_types:kz_node() | 'undefined'.
get_node(NodeName) when is_atom(NodeName) ->
    case ets:lookup(?MODULE, NodeName) of
        [] -> 'undefined';
        [Node] -> Node
    end.

-spec get_nodes_info() -> [{node(), kz_term:api_object()}].
get_nodes_info() ->
    MatchSpec = [{#kz_node{node='$1'
                          ,node_info='$2'
                          ,_ = '_'
                          }
                 ,[]
                 ,[{{'$1','$2'}}]
                 }],
    ets:select(?TAB_NAME, MatchSpec).

%%%=============================================================================
%%% Internal functions
%%%=============================================================================
%% @doc default callback module:function/1 for kz_nodes_bindings:bind/1 calls
-spec request(request_acc()) -> request_acc().
request(Acc) ->
    App = props:get_value('app', Acc),
    [{'info', get_whapp_info(App)} | Acc].

-spec get_whapp_info(atom() | pid() | kz_term:proplist() | 'undefined') -> kz_types:whapp_info().
get_whapp_info('undefined') -> #whapp_info{};
get_whapp_info(Whapp) when is_atom(Whapp) ->
    try
        get_whapp_info(application_controller:get_master(Whapp))
    catch
        _E:_R -> #whapp_info{}
    end;
get_whapp_info(Master) when is_pid(Master) ->
    try
        get_whapp_info(application_master:get_child(Master))
    catch
        _E:_R -> #whapp_info{}
    end;
get_whapp_info({Pid, _Module}) when is_pid(Pid) ->
    try
        get_whapp_process_info(erlang:process_info(Pid))
    catch
        _E:_R -> #whapp_info{}
    end;
get_whapp_info(_Arg) ->
    lager:debug("can't get info for ~p", [_Arg]),
    #whapp_info{}.

-spec get_whapp_process_info(kz_term:proplist() | 'undefined') -> kz_types:whapp_info().
get_whapp_process_info('undefined') -> #whapp_info{};
get_whapp_process_info([]) -> #whapp_info{};
get_whapp_process_info(PInfo) ->
    Startup = props:get_value('$startup', props:get_value('dictionary', PInfo, [])),
    #whapp_info{startup=Startup}.

-spec local_zone() -> atom().
local_zone() -> kz_config:zone().

-spec whapp_oldest_node(kz_term:text()) -> kz_term:api_integer().
whapp_oldest_node(Whapp) ->
    whapp_oldest_node(Whapp, 'false').

-spec whapp_oldest_node(kz_term:text(), kz_term:text() | boolean() | atom()) -> kz_term:api_integer().
whapp_oldest_node(Whapp, Federated)
  when is_binary(Federated) ->
    whapp_oldest_node(Whapp, kz_term:is_true(Federated));
whapp_oldest_node(Whapp, 'true') ->
    MatchSpec = [{#kz_node{kapps='$1'
                          ,node='$2'
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,[{{'$1','$2'}}]
                 }],
    determine_whapp_oldest_node(kz_term:to_binary(Whapp), MatchSpec);
whapp_oldest_node(Whapp, 'false') ->
    whapp_oldest_node(Whapp, kz_nodes_listener:local_zone());
whapp_oldest_node(Whapp, Zone)
  when is_atom(Zone) ->
    MatchSpec = [{#kz_node{kapps='$1'
                          ,node='$2'
                          ,zone = Zone
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,[{{'$1', '$2'}}]
                 }],
    determine_whapp_oldest_node(kz_term:to_binary(Whapp), MatchSpec).

-spec determine_whapp_oldest_node(kz_term:ne_binary(), ets:match_spec()) ->
          'undefined' | node().
determine_whapp_oldest_node(Whapp, MatchSpec) ->
    case oldest_whapp_node(Whapp, MatchSpec) of
        {Node, _Start} -> Node;
        'undefined' -> 'undefined'
    end.

-type oldest_whapp_node() :: 'undefined' |
                             {node(), kz_time:gregorian_seconds()}.

-spec oldest_whapp_node(kz_term:ne_binary(), ets:match_spec()) ->
          oldest_whapp_node().
oldest_whapp_node(Whapp, MatchSpec) ->
    lists:foldl(fun({Whapps, _Node}=Info, Acc) when is_list(Whapps) ->
                        determine_whapp_oldest_node_fold(Info, Acc, Whapp)
                end
               ,'undefined'
               ,ets:select(?MODULE, MatchSpec)
               ).

-spec determine_whapp_oldest_node_fold({kz_types:kapps_info(), node()}, oldest_whapp_node(), kz_term:ne_binary()) ->
          oldest_whapp_node().
determine_whapp_oldest_node_fold({Whapps, Node}, 'undefined', Whapp) ->
    case props:get_value(Whapp, Whapps) of
        'undefined' -> 'undefined';
        #whapp_info{startup=Start} -> {Node, Start}
    end;
determine_whapp_oldest_node_fold({Whapps, Node}, {_, Startup}=Acc, Whapp) ->
    case props:get_value(Whapp, Whapps) of
        'undefined' -> Acc;
        #whapp_info{startup='undefined'} -> Acc;
        #whapp_info{startup=Start}
          when Start =< Startup -> {Node, Start};
        _ -> Acc
    end.

-spec whapp_role_count(kz_term:text(), kz_term:text()) -> integer().
whapp_role_count(Whapp, Role) ->
    whapp_role_count(Whapp, Role, 'false').

-spec whapp_role_count(kz_term:text(), kz_term:text(), kz_term:text() | boolean() | 'remote') -> integer().
whapp_role_count(Whapp, Role, Arg) when not is_atom(Arg) ->
    whapp_role_count(Whapp, Role, kz_term:to_atom(Arg, 'true'));
whapp_role_count(Whapp, Role, 'false') ->
    MatchSpec = [{#kz_node{kapps='$1'
                          ,zone = local_zone()
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,['$1']
                 }],
    determine_whapp_role_count(kz_term:to_binary(Whapp), kz_term:to_binary(Role), MatchSpec);
whapp_role_count(Whapp, Role, 'true') ->
    MatchSpec = [{#kz_node{kapps='$1'
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,['$1']
                 }],
    determine_whapp_role_count(kz_term:to_binary(Whapp), kz_term:to_binary(Role), MatchSpec);
whapp_role_count(Whapp, Role, 'remote') ->
    Zone = local_zone(),
    MatchSpec = [{#kz_node{kapps='$1'
                          ,zone='$2'
                          ,_ = '_'
                          }
                 ,[{'andalso'
                   ,{'=/=', '$1', []}
                   ,{'=/=', '$2', {'const', Zone}}
                   }]
                 ,['$1']
                 }],
    determine_whapp_role_count(kz_term:to_binary(Whapp), kz_term:to_binary(Role), MatchSpec);
whapp_role_count(Whapp, Role, Unhandled) ->
    lager:debug("invalid parameters ~p , ~p , ~p", [Whapp, Role, Unhandled]),
    0.

-spec determine_whapp_role_count(kz_term:ne_binary(), kz_term:ne_binary(), ets:match_spec()) -> non_neg_integer().
determine_whapp_role_count(Whapp, Role, MatchSpec) ->
    lists:foldl(fun(Whapps, Acc) when is_list(Whapps) ->
                        determine_whapp_role_count_fold(Whapps, Role, Acc, Whapp)
                end
               ,0
               ,ets:select(?MODULE, MatchSpec)
               ).

-spec determine_whapp_role_count_fold(kz_types:kapps_info(), kz_term:ne_binary(), non_neg_integer(), kz_term:ne_binary()) -> non_neg_integer().
determine_whapp_role_count_fold(Whapps, Role, Acc, Whapp) ->
    case props:is_defined(Whapp, Whapps)
        andalso lists:member(Role, (props:get_value(Whapp, Whapps))#whapp_info.roles)
    of
        'true' -> Acc + 1;
        'false' -> Acc
    end.

-spec node_role_count(kz_term:text()) -> integer().
node_role_count(Role) ->
    length(with_role(Role)).

-spec node_role_count(kz_term:text(), kz_term:text() | boolean() | 'remote') -> integer().
node_role_count(Role, Arg) ->
    length(with_role(Role, Arg)).

-spec with_role(kz_term:text()) -> kz_types:kz_nodes().
with_role(Role) ->
    with_role(Role, 'false').

-spec with_role(kz_term:text(), kz_term:text() | boolean() | 'remote') -> kz_types:kz_nodes().
with_role(Role, Arg) when not is_atom(Arg) ->
    with_role(Role, kz_term:to_atom(Arg, 'true'));
with_role(Role, 'false') ->
    MatchSpec = [{#kz_node{roles='$1'
                          ,zone = local_zone()
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,['$_']
                 }],
    with_role_filter(kz_term:to_binary(Role), MatchSpec);
with_role(Role, 'true') ->
    MatchSpec = [{#kz_node{roles='$1'
                          ,_ = '_'
                          }
                 ,[{'=/=', '$1', []}]
                 ,['$_']
                 }],
    with_role_filter(kz_term:to_binary(Role), MatchSpec);
with_role(Role, 'remote') ->
    Zone = local_zone(),
    MatchSpec = [{#kz_node{roles='$1'
                          ,zone='$2'
                          ,_ = '_'
                          }
                 ,[{'andalso'
                   ,{'=/=', '$1', []}
                   ,{'=/=', '$2', {'const', Zone}}
                   }]
                 ,['$_']
                 }],
    with_role_filter(kz_term:to_binary(Role), MatchSpec);
with_role(Role, Unhandled) ->
    lager:debug("invalid parameters ~p , ~p , ~p", [Role, Unhandled]),
    [].

-spec with_role_filter(kz_term:ne_binary(), ets:match_spec()) -> kz_types:kz_nodes().
with_role_filter(Role, MatchSpec) ->
    lists:foldl(fun(#kz_node{roles=Roles}=Node, Acc) when is_list(Roles) ->
                        case props:is_defined(Role, Roles) of
                            'true' -> [Node | Acc];
                            'false' -> Acc
                        end
                end
               ,[]
               ,ets:select(?MODULE, MatchSpec)
               ).

-spec table_id() -> ?TAB_NAME.
table_id() -> ?TAB_NAME.

-spec table_options() -> list().
table_options() -> ['set'
                   ,'protected'
                   ,'named_table'
                   ,{'keypos', #kz_node.node}
                   ,{'read_concurrency', 'true'}
                   ].

-spec gift_data() -> 'ok'.
gift_data() -> 'ok'.

-spec expire_nodes(atom()) -> kz_types:kz_nodes().
expire_nodes(ThisNode) ->
    Now = kz_time:now_ms(),
    FindSpec = [{#kz_node{node='$1'
                         ,expires='$2'
                         ,last_heartbeat='$3'
                         ,_ = '_'
                         }
                ,[{'andalso'
                  ,{'=/=','$2','undefined'}
                  ,{'andalso'
                   ,{'>',{'const',Now},{'+','$2','$3'}}
                   ,{'=/=','$1',{'const',ThisNode}}
                   }
                  }
                 ]
                ,['$_']
                }
               ],
    ExpiredNodes = ets:select(?TAB_NAME, FindSpec),
    _ = [ets:delete(?TAB_NAME, Node) || #kz_node{node=Node} <- ExpiredNodes],
    ExpiredNodes.
