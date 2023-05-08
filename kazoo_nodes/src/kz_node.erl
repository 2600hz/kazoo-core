%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2023, 2600Hz
%%% @doc Wrapper around #kz_node{} record
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_node).

-export([create/4]).

-export([print_node_status/2
        ,to_json/1
        ,node_info/0
        ,pool_states/0
        ]).

-include("kazoo_nodes.hrl").

-define(MEDIA_SERVERS_HEADER, "Media Servers : ").
-define(MEDIA_SERVERS_LINE, "                ").
-define(MEDIA_SERVERS_DETAIL, "~s (~s)").

-define(HEADER_COL, "~-14s").
-define(SIMPLE_ROW_STR, ?HEADER_COL ": ~s~n").
-define(SIMPLE_ROW_NUM, ?HEADER_COL ": ~B~n").

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec create('undefined' | 5000..15000, atom(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          kz_types:kz_node().
create(Heartbeat, Zone, Version, MD5) ->
    add_kapps_data(#kz_node{expires=Heartbeat
                           ,kapps_loaded=loaded_apps()
                           ,broker=kz_amqp_util:normalize_amqp_uri(kz_amqp_connections:primary_broker())
                           ,used_memory=erlang:memory('total')
                           ,processes=erlang:system_info('process_count')
                           ,ports=length(erlang:ports())
                           ,version=Version
                           ,zone=Zone
                           ,md5=MD5
                           ,globals=globals()
                           ,node_info=node_info()
                           }).

-spec add_kapps_data(kz_types:kz_node()) -> kz_types:kz_node().
add_kapps_data(Node) ->
    lists:foldl(fun kapp_data/2, Node, apps()).


-spec kapp_data(atom(), kz_types:kz_node()) -> kz_types:kz_node().
kapp_data(App, Node) ->
    kapp_data(App, Node, kz_nodes_bindings:request(App)).

kapp_data(App
         ,#kz_node{kapps=Kapps
                  ,media_servers=Servers
                  ,channels=Channels
                  ,conferences=Conferences
                  ,registrations=Registrations
                  }=Node
         ,RequestAcc
         ) ->
    Node#kz_node{kapps=maybe_add_info(App, props:get_value('info', RequestAcc), Kapps)
                ,media_servers=props:get_value('media_servers', RequestAcc, []) ++ Servers
                ,channels=props:get_integer_value('channels', RequestAcc, 0) + Channels
                ,conferences=props:get_integer_value('conferences', RequestAcc, 0) + Conferences
                ,registrations=props:get_integer_value('registrations', RequestAcc, 0) + Registrations
                }.

-spec maybe_add_info(atom(), 'undefined' | kz_types:whapp_info(), kz_types:kapps_info()) -> kz_types:kapps_info().
maybe_add_info(_App, 'undefined', Kapps) -> Kapps;
maybe_add_info(App, AppInfo, Kapps) ->
    [{kz_term:to_binary(App), AppInfo} | Kapps].

globals() ->
    kazoo_bindings:map(<<"kz_nodes.globals">>, []).


-spec apps() -> kz_term:atoms().
apps() ->
    [App || {App, _, _} <- kz_application:running_apps()].

-spec loaded_apps() -> kz_types:kapps_version_info().
loaded_apps() ->
    [{KappVersion#kapp_version.name, KappVersion} || KappVersion <- kz_application:loaded_apps()].

-spec node_info() -> kz_json:object().
node_info() ->
    AMQP = [{<<"connections">>, amqp_status()}
           ,{<<"pools">>, kz_json:from_list(pool_states())}
           ],
    Info = kazoo_bindings:map(kz_nodes_bindings:binding_node_info(), []),
    NodeInfo = [{<<"amqp">>, kz_json:from_list(AMQP)}
               | [{Key, Value} ||
                     {Key, Value} <- Info,
                     'EXIT' =/= Key
                 ] % only use 2-tuples from Info
               ],
    kz_json:from_list(NodeInfo).

-spec amqp_status() -> kz_json:object().
amqp_status() ->
    Connections = kz_amqp_connections:connections(),
    lists:foldl(fun amqp_status_connection/2, kz_json:new(), Connections).

-spec amqp_status_connection(kz_amqp_connections:kz_amqp_connections(), kz_json:object()) ->
          kz_json:object().
amqp_status_connection(Connection, JObj) ->
    Count = kz_amqp_assignments:channel_count(Connection),
    Broker = kz_amqp_connection:broker(Connection),
    BrokerZone = kz_amqp_connection:zone(Connection),

    ConnStatus = kz_json:from_list([{<<"channel_count">>, Count}
                                   ,{<<"zone">>, BrokerZone}
                                   ]),

    Status = kz_json:get_list_value(Broker, JObj, []),

    kz_json:set_value(Broker, [ConnStatus | Status], JObj).

-spec pool_states() -> kz_term:proplist().
pool_states() ->
    AppPools = kazoo_bindings:map(kz_nodes_bindings:pool_state_binding(), []),
    lists:keysort(1, [pool_state(Pool)
                      || Pools <- AppPools,
                         {Pool, _Pid} <- Pools
                     ]).

-spec pool_state(atom()) -> {kz_term:ne_binary(), kz_term:ne_binary()}.
pool_state(Name) ->
    {PoolState, Workers, OverFlow, Monitors} = poolboy:status(Name),
    pool_state(Name, PoolState, Workers, OverFlow, Monitors).

-spec pool_state(atom(), atom(), integer(), integer(), integer()) -> {kz_term:ne_binary(), kz_term:ne_binary()}.
pool_state(Name, State, Workers, Overflow, Monitors) ->
    {kz_term:to_binary(Name)
    ,iolist_to_binary(
       io_lib:format("~p/~p/~p (~p)", [Workers, Monitors, Overflow, State])
      )
    }.

-spec print_node_status(kz_types:kz_node(), atom()) -> 'ok'.
print_node_status(#kz_node{zone=NodeZone
                          ,node=N
                          ,md5=MD5
                          ,version=Version
                          ,processes=Processes
                          ,ports=Ports
                          ,used_memory=UsedMemory
                          ,broker=Broker
                          ,kapps=Whapps
                          ,globals=Globals
                          ,node_info=NodeInfo
                          ,runtime=RuntimeInfo
                          ,modules=Modules
                          ,roles=Roles
                          }=Node
                 ,Zone
                 ) ->
    MemoryUsage = kz_network_utils:pretty_print_bytes(UsedMemory),
    print_simple_row_str([<<"Node">>, N]),
    _ = maybe_print_md5(MD5),
    print_simple_row_str([<<"Version">>, Version]),
    print_simple_row_str([<<"Memory Usage">>, MemoryUsage]),

    maybe_print_row(Processes > 0, [<<"Processes">>, Processes]),
    maybe_print_row(Ports > 0, [<<"Ports">>, Ports]),

    _ = maybe_print_zone(kz_term:to_binary(NodeZone)
                        ,kz_term:to_binary(Zone)
                        ),

    print_simple_row_str([<<"Broker">>, Broker]),

    _ = maybe_print_globals(Globals),
    _ = maybe_print_node_info(NodeInfo),
    _ = maybe_print_runtime_info(RuntimeInfo),

    _ = maybe_print_kapps(Whapps),
    _ = maybe_print_modules(Modules),
    _ = maybe_print_media_servers(Node),
    _ = maybe_print_roles(Roles),

    format("~n").

-spec maybe_print_row(boolean(), list()) -> 'ok'.
maybe_print_row('false', _Args) -> 'ok';
maybe_print_row('true', Args) ->
    print_simple_row(Args).

-spec print_simple_row(list()) -> 'ok'.
print_simple_row(Args) ->
    format(?SIMPLE_ROW_NUM, Args).

-spec print_simple_row_str(list()) -> 'ok'.
print_simple_row_str(Args) ->
    format(?SIMPLE_ROW_STR, Args).

-spec maybe_print_md5(kz_term:api_binary()) -> 'ok'.
maybe_print_md5('undefined') -> 'ok';
maybe_print_md5(MD5) ->
    print_simple_row_str([<<"md5">>, MD5]).

-spec maybe_print_zone(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
maybe_print_zone(Zone, Zone) when Zone =/= <<"local">> ->
    print_simple_row_str([<<"Zone">>, <<Zone/binary, " (local)">>]);
maybe_print_zone(NodeZone, _Zone) ->
    print_simple_row_str([<<"Zone">>, NodeZone]).

-spec maybe_print_globals(kz_term:proplist()) -> 'ok'.
maybe_print_globals([]) -> 'ok';
maybe_print_globals(Globals) ->
    format(?HEADER_COL ++ ":", [<<"Globals">>]),
    lists:foreach(fun print_global/1, Globals),
    format("~n").

-spec print_global({kz_json:key(), integer()}) -> 'ok'.
print_global({K,V}) -> format(" ~s (~B)",[K, V]).

-spec maybe_print_runtime_info(kz_term:api_object()) -> 'ok'.
maybe_print_runtime_info('undefined') -> 'ok';
maybe_print_runtime_info(_RuntimeInfo) ->
    format(?HEADER_COL ++ ": ", [<<"Runtime Info">>]),
    format("~n").

-spec maybe_print_modules(kz_term:api_object()) -> 'ok'.
maybe_print_modules('undefined') -> 'ok';
maybe_print_modules(Modules) ->
    format(?HEADER_COL ++ ": ", [<<"Modules">>]),
    L = kz_json:get_list_value(<<"loaded">>, Modules),
    Mods = lists:sort([N || <<"mod_", N/binary>> <- L]),
    simple_list(Mods, 7).

-spec maybe_print_kapps(kz_term:proplist()) -> 'ok'.
maybe_print_kapps(Whapps) ->
    case lists:sort(fun compare_apps/2, Whapps) of
        []-> 'ok';
        SortedWhapps ->
            format(?HEADER_COL ": ", [<<"WhApps">>]),
            status_list(SortedWhapps, 0)
    end.

-spec compare_apps({binary(), any()}, {binary(), any()}) -> boolean().
compare_apps({K1,_}, {K2,_}) -> K1 < K2.

-spec maybe_print_roles(kz_term:proplist()) -> 'ok'.
maybe_print_roles(Roles) ->
    case lists:sort(fun compare_apps/2, Roles) of
        []-> 'ok';
        SortedRoles ->
            format(?HEADER_COL ": ", [<<"Roles">>]),
            simple_list(props:get_keys(SortedRoles)),
            lists:foreach(fun print_role/1, SortedRoles)
    end.

-spec print_role({kz_term:ne_binary(), kz_json:object()}) -> 'ok'.
print_role({<<"Dispatcher">>, Data}) ->
    Groups = kz_json:get_json_value(<<"Groups">>, Data, kz_json:new()),
    Keys = lists:sort(kz_json:get_keys(Groups)),
    lists:foreach(fun(Group) ->
                          GData = kz_json:get_json_value(Group, Groups),
                          print_dispatcher({Group, GData})
                  end
                 ,Keys
                 );
print_role({<<"Presence">>, Data}) ->
    kz_json:foreach(fun print_presence/1, Data);
print_role({<<"Registrar">>, Data}) ->
    print_simple_row([<<"Registrations">>, kz_json:get_integer_value(<<"Registrations">>, Data, 0)]);
print_role({<<"Proxy">>, Data}) ->
    kz_json:foreach(fun print_proxy/1, Data);
print_role(_) -> 'ok'.

-spec print_proxy({kz_json:key(), kz_json:object()}) -> 'ok'.
print_proxy({<<"Listeners">>, Data}) ->
    Listeners = kz_json:foldl(fun collect_listeners/3, #{}, Data),

    case maps:to_list(Listeners) of
        [] -> 'ok';
        Addrs ->
            S = lists:max([byte_size(A) || {A, _} <- Addrs]),
            Fmt = print_address_format(S),
            [{Address, Info} | Addresses] = lists:keysort(1, Addrs),
            format(?HEADER_COL ++ ": ", [<<"Listening on">>]),
            print_address_info(Address, Info, Fmt),
            _ = lists:foreach(fun(A) -> print_address(A, Fmt) end, Addresses),
            'ok'
    end;
print_proxy({<<"proxy-default-uri">>, Data}) ->
    format(?HEADER_COL ++ ": ~s~n", [<<"Default Proxy">>, Data]);
print_proxy(_Ignore) -> 'ok'.

-spec print_address_format(pos_integer()) -> kz_term:ne_binary().
print_address_format(S) ->
    Size = 15 - (15 - S),
    list_to_binary(["~-",io_lib:format("~B", [Size]),"s "]).

-spec print_address({kz_term:ne_binary(), map()}, kz_term:ne_binary()) -> 'ok'.
print_address({Address, Info}, Fmt) ->
    format(?HEADER_COL ++ "  ", [""]),
    print_address_info(Address, Info, Fmt).

-spec print_address_info(kz_term:ne_binary(), map(), kz_term:ne_binary()) -> 'ok'.
print_address_info(Address, Info, Fmt) ->
    format(Fmt, [Address]),
    _ = lists:foreach(fun print_proto/1, lists:keysort(1, maps:to_list(Info))),
    format("~n").

-spec print_proto({kz_term:ne_binary(), kz_term:integers()}) -> 'ok'.
print_proto({Proto, Ports}) ->
    format("~s (~s) ", [Proto, kz_binary:join(lists:usort(Ports), <<" ">>)]).

-spec collect_listeners(kz_json:key(), kz_json:object(), map()) -> map().
collect_listeners(_FullAddress, Info, Acc) ->
    Address = kz_json:get_first_defined([<<"advertise">>, <<"address">>], Info),
    Proto = kz_json:get_ne_binary_value(<<"proto">>, Info),
    Port = kz_json:get_integer_value(<<"port">>, Info),

    AccAddress = maps:get(Address, Acc, #{}),
    AccProto = [Port | maps:get(Proto, AccAddress, [])],

    Acc#{Address => AccAddress#{Proto => AccProto}}.

-spec print_dispatcher({kz_term:ne_binary(), kz_json:object()}) -> 'ok'.
print_dispatcher({Group, Data})->
    format(?HEADER_COL ": ", [<<"Dispatcher ", Group/binary>>]),
    Sets = kz_json:get_keys(Data),
    M = lists:map(fun(S) ->
                          URI = kz_json:get_ne_binary_value([S, <<"destination">>], Data),
                          Flags = kz_json:get_ne_binary_value([S, <<"flags">>], Data),
                          <<URI/binary," (", Flags/binary, ")  ">>
                  end
                 ,Sets
                 ),
    simple_list(M).

-spec print_presence({kz_term:ne_binary(), kz_json:object()}) -> 'ok'.
print_presence({Group, Data}) ->
    format(?HEADER_COL ": ", [Group]),
    simple_list(format_presence_data(Data)).

-spec format_presence_data(kz_json:object()) -> kz_term:ne_binaries().
format_presence_data(Data) ->
    kz_json:foldl(fun format_presence_data/3, [], Data).

-spec format_presence_data(kz_term:ne_binary(), term(), kz_term:ne_binaries()) -> kz_term:ne_binaries().
format_presence_data(K, V, Acc) ->
    [<<K/binary, " (", (kz_term:to_binary(V))/binary, ") ">> | Acc].

-spec maybe_print_media_servers(kz_types:kz_node()) -> 'ok'.
maybe_print_media_servers(#kz_node{media_servers=MediaServers
                                  ,registrations=Registrations
                                  ,channels=Channels
                                  ,conferences=Conferences
                                  }) ->
    case lists:sort(MediaServers) of
        [] when Registrations =:= 0 -> 'ok';
        [] when Registrations > 0 ->
            print_simple_row([<<"Registrations">>, Registrations]);
        [Server|Servers] ->
            print_simple_row([<<"Channels">>, Channels]),
            print_simple_row([<<"Conferences">>, Conferences]),
            print_simple_row([<<"Registrations">>, Registrations]),
            print_media_server(Server, ?MEDIA_SERVERS_HEADER),
            lists:foreach(fun print_media_server/1, Servers)
    end.

-spec print_media_server(kz_types:media_server()) -> 'ok'.
print_media_server(Server) ->
    print_media_server(Server, ?MEDIA_SERVERS_LINE).

-spec print_media_server(kz_types:media_server(), string()) -> 'ok'.
print_media_server({Name, JObj}, Format) ->
    format(lists:flatten([Format, ?MEDIA_SERVERS_DETAIL, "~n"])
          ,[Name
           ,kz_time:pretty_print_elapsed_s(
              kz_time:elapsed_s(kz_json:get_integer_value(<<"Startup">>, JObj))
             )
           ]).

-spec maybe_print_node_info(kz_term:api_object() | kz_json:json_proplist()) -> 'ok'.
maybe_print_node_info('undefined') -> 'ok';
maybe_print_node_info([]) -> 'ok';
maybe_print_node_info([_|_] = NodeInfo) ->
    lists:foreach(fun print_node_info/1, NodeInfo);
maybe_print_node_info(NodeInfo) ->
    maybe_print_node_info(kz_json:to_proplist(NodeInfo)).

-spec print_node_info({kz_term:ne_binary(), term()}) -> 'ok'.
print_node_info({<<"telemetry">>, Info}) ->
    Leader = kz_json:get_ne_binary_value(<<"leader">>, Info),
    format(?HEADER_COL ++ ": Leader is ~s~n", [<<"Telemetry">>, Leader]);
print_node_info({<<"amqp">>, Info}) ->
    kz_json:foreach(fun print_node_info/1, Info);
print_node_info({<<"couch">>, Info}) ->
    AllNodes = kz_json:get_list_value(<<"all_nodes">>, Info, []),
    ClusterNodes = kz_json:get_list_value(<<"cluster_nodes">>, Info, []),

    case ClusterNodes -- AllNodes of
        [] -> 'ok';
        [MissingNode] ->
            format(?HEADER_COL ++ ": Missing COUCH Node: '~s'~n"
                  ,[<<"CouchDB">>, MissingNode]
                  );
        MissingNodes ->
            format(?HEADER_COL ++ ": Missing COUCH Nodes: '~s'~n"
                  ,[<<"CouchDB">>, kz_binary:join(lists:sort(MissingNodes), <<"' '">>)]
                  )
    end;
print_node_info({<<"connections">>, Info}) ->
    format(?HEADER_COL ++ ": ", [<<"AMQP Channels">>]),
    simple_list(kz_json:foldr(fun print_amqp_info/3, [], Info), 2);
print_node_info({<<"pools">>, Info}) ->
    format(?HEADER_COL ++ ": ", [<<"AMQP Pools">>]),
    simple_list(kz_json:foldr(fun print_pool_info/3, [], Info), 2);
print_node_info(_Info) ->
    format("~n").

-spec print_amqp_info(kz_term:ne_binary(), kz_json:objects(), iodata()) -> iodata().
print_amqp_info(Broker, Data, Acc) ->
    ChannelCounts = [kz_json:get_integer_value(<<"channel_count">>, Datum, 0)
                     || Datum <- Data
                    ],
    ChannelCountsBin = kz_binary:join(ChannelCounts, <<"/">>),
    [io_lib:format("~s (~s)", [format_broker(Broker), ChannelCountsBin]) | Acc].

-spec format_broker(kz_term:ne_binary()) -> string().
format_broker(Broker) ->
    amqp_uri:remove_credentials(Broker).

-spec print_pool_info(kz_term:ne_binary(), term(), iodata()) -> iodata().
print_pool_info(Pool, Info, Acc) ->
    [io_lib:format("~s : ~s", [Pool, Info]) | Acc].

-spec status_list(kz_types:kapps_info(), 0..4) -> 'ok'.
status_list([], _) -> format("~n", []);
status_list(Whapps, Column) when Column > 3 ->
    format("~n" ++ ?HEADER_COL ++ "  ", [""]),
    status_list(Whapps, 0);
status_list([{Whapp, #whapp_info{startup='undefined'}}|Whapps], Column) ->
    format("~-25s", [Whapp]),
    status_list(Whapps, Column + 1);
status_list([{Whapp, #whapp_info{startup=Started,roles=[]}}|Whapps], Column) ->
    Elapsed = kz_time:elapsed_s(Started),
    Print = <<(kz_term:to_binary(Whapp))/binary, "(", (kz_time:pretty_print_elapsed_s(Elapsed))/binary, ")">>,
    format("~-25s", [Print]),
    status_list(Whapps, Column + 1);
status_list([{Whapp, #whapp_info{startup=Started,roles=Roles}}|Whapps], _Column) ->
    Elapsed = kz_time:elapsed_s(Started),
    Print = <<(kz_term:to_binary(Whapp))/binary, "(", (kz_time:pretty_print_elapsed_s(Elapsed))/binary, ")">>,
    format("~-25s", [Print]),
    format("~s", [kz_binary:join(Roles, <<" , ">>)]),
    status_list(Whapps, 4).

-spec simple_list(kz_term:ne_binaries()) -> 'ok'.
simple_list(List) -> simple_list(List, 4).

-spec simple_list(kz_term:ne_binaries(), integer()) -> 'ok'.
simple_list(List, Size) -> simple_list(List, Size, 0).

-spec simple_list(kz_term:ne_binaries(), Size :: integer(), integer()) -> 'ok'.
simple_list([], _, _) -> format("~n", []);
simple_list(List, Size, Column) when Column >= Size ->
    format("~n" ++ ?HEADER_COL ++ "  ", [""]),
    simple_list(List, Size, 0);
simple_list([Item|Items], Size, Column) ->
    format("~s ", [Item]),
    simple_list(Items, Size, Column + 1).

format_output() ->
    case erlang:get('io_output') of
        'undefined' -> group_leader();
        Pid -> Pid
    end.

format(A) ->
    io:format(format_output(), A, []).

format(A, B) ->
    io:format(format_output(), A, B).

-spec to_json(kz_term:text() | kz_types:kz_node()) -> kz_json:object().
to_json(#kz_node{node=NodeName
                ,zone=Zone
                ,kapps=Kapps
                ,media_servers=MediaServers
                ,version=Version
                ,channels=Channels
                ,conferences=Conferences
                ,registrations=Regs
                }) ->
    kz_json:from_list([{<<"node">>, kz_term:to_binary(NodeName)}
                      ,{<<"zone">>, kz_term:to_binary(Zone)}
                      ,{<<"kapps">>, [K || {K, _} <- Kapps]}
                      ,{<<"media_servers">>, [K || {K, _} <- MediaServers]}
                      ,{<<"version">>, Version}
                      ,{<<"channels">>, Channels}
                      ,{<<"conferences">>, Conferences}
                      ,{<<"registrations">>, Regs}
                      ]);
to_json(Node) ->
    to_json(kz_nodes_ets:get_node(kz_term:to_atom(Node))).
