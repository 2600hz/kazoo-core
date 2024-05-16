%%------------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_versions).

-export([nodes_running/2]).

-export([list/0
        ,filter/2
        ]).

-export([groups_by/2
        ,groups_by/3
        ,map_get/3
        ,map_groups/2
        ,fold_groups/3
        ,filter_groups/2
        ,map_to_table/1
        ]).

-export([counts_by/2
        ,count_stats_by/2
        ,count_pairs_by/2
        ,desc_count_pairs_by/2
        ,asc_count_pairs_by/2
        ,sorted_count_pairs_by/3
        ]).

-export([get_node/1
        ,get_host/1
        ,get_name/1
        ,get_description/1
        ,get_version/1
        ,get_startup/1
        ,get_running/1
        ]).

-export([report_groups/1
        ,report_node_app_version/1
        ,report_node_app_versions/1
        ,report_node_app_versions/2
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-elvis([{elvis_style, no_debug_call, disable}]).

%%%=============================================================================
%%% Types
%%%=============================================================================

-define(INDENT_SPACES, 4).

-record(node_app_version, {node :: atom()
                          ,name :: kz_term:ne_binary()
                          ,description :: kz_term:ne_binary()
                          ,version :: kz_term:ne_binary()
                          ,startup :: kz_term:api_integer()
                          }).

-type node_app_version() :: #node_app_version{}.
-type node_app_versions() :: [node_app_version()].

-type versionish() :: node_app_version() | string() | binary().

-type group_map() :: map().

-type predicate_function() :: fun((ListItem :: any()) -> boolean())
                            | fun((ListItem :: any(), Arg :: any()) -> boolean()).

-type predicate_function_specifier() :: atom()
                                      | {atom(), any()}
                                      | predicate_function().

-type predicate_list() :: list(predicate_function_specifier()).

-type key_function() :: fun((ListItem :: any()) -> any()).

-type key_function_specifier() :: atom()
                                | key_function().

-type key_functions() :: list(key_function_specifier()).

-type stats_tuple() :: { integer(), any() }.

-type stats_list() :: list(stats_tuple()).

-type stats_map() :: #{'majority' := stats_tuple(),
                       'minority' := [ stats_tuple() ]
                      }.

%%%=============================================================================
%%% Handy Queries
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Returns the list of nodes from `NAVs' where all `Apps' are running.
%% @end
%%------------------------------------------------------------------------------
-spec nodes_running(kz_term:ne_binary() | kz_term:ne_binaries(), node_app_versions()) -> [atom()].
nodes_running(Apps, NAVs) when is_list(Apps) ->
    Filtered = filter([{'names', Apps}], NAVs),
    AppCount = erlang:length(Apps),
    G1 = groups_by(['node'], Filtered, [{'count', AppCount}]),
    maps:keys(G1);

nodes_running(App, NAVs) ->
    nodes_running([App], NAVs).

%%%=============================================================================
%%% List Functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Returns a list of `#node_app_version{}` records for all Kazoo
%% applications on all nodes for which a heartbeat notification has
%% been received.  (@see kz_nodes:nodes/0).
%%
%% The list is derived from the list of `#kz_node{}' supplied by
%% `kz_nodes:nodes/0':
%%
%%  * All running Kazoo applications report their start time in the
%%  `kapps' field.
%%
%%  * Recent versions of the `kazoo_nodes' application report the
%%  versions of all loaded Kazoo applications in the `kapps_loaded'
%%  field.
%%
%%  * Kamailio reports its startup time in the `kapps' field.
%%
%%  * FreeSWITCH does not report its startup time or its version, but,
%%  if running, will have an entry in the `kapps' field where
%%  `startup' is `'undefined''.
%%@end
%%------------------------------------------------------------------------------
-spec list() -> node_app_versions().

list() ->
    Nodes = kz_nodes:nodes(),
    lists:foldl(fun node_kapp_versions/2, [], Nodes).

node_kapp_versions(#kz_node{node=Node, kapps_loaded=[], kapps=Running}, Acc0) ->
    lists:foldl(fun(Whapp, Acc) ->
                        node_whapp_to_kapp_version(Node, Whapp, Acc)
                end
               ,Acc0
               ,Running
               );
node_kapp_versions(#kz_node{node=Node, kapps_loaded=Loaded, kapps=Running}, Acc0) ->
    lists:foldl(fun({_Name, KappVersion}, Acc) ->
                        node_kapp_version(Node, KappVersion, Running, Acc)
                end
               ,Acc0
               ,Loaded
               ).

node_whapp_to_kapp_version(Node, {Name, #whapp_info{startup=Startup}}, Acc) ->
    [#node_app_version{node = Node
                      ,name = Name
                      ,description = <<"unknown">>
                      ,version = <<"unknown">>
                      ,startup = Startup
                      }
    | Acc
    ].

node_kapp_version(Node
                 ,#kapp_version{name=Name, description=Description, version=Version}
                 ,Running
                 ,Acc
                 ) ->
    Startup = add_startup(Name, Running),
    [#node_app_version{node=Node
                      ,name=Name
                      ,description=Description
                      ,version=Version
                      ,startup=Startup
                      }
    | Acc
    ].

add_startup(Name, RunningApps) ->
    case lists:keyfind(Name, 1, RunningApps) of
        'false' ->
            'undefined';
        {_Name, #whapp_info{startup=Startup}} ->
            Startup
    end.

%%------------------------------------------------------------------------------
%% @doc `List2' contains all of the elements from `List1' for which
%% all of the predicates in `Predicates' returned `true'.

%% Note that `Predicates' can be a list of boolean functions or terms
%% referring to convenience functions supplied by this module.  For
%% example:

%%
%% <code>
%%   % returns the list of running applications
%%   filter(['running'], list()).
%%
%%   % returns all instances of webhooks
%%   filter([{'name', <<"webhooks">>}], list()).
%%
%%   % returns all instances of webhooks that have been loaded but not started
%%   filter([{'name', <<"webhooks">>}], 'not_running'], list()).
%%
%%   % returns the list of running applications for which `CustomPred1' returns'true'%%   filter([CustomPred1, 'running'], list()).
%% </code>
%%
%% Predicate functions can be arity 1 or 2.  Arity 1 functions can be
%% passed directly, like this:
%%
%% <code>
%%    filter([CustomPred1], list()).
%% </code>
%%
%% Or indirectly, by specifying an atom, provided `get_predicate/1`
%% has been extended to return the appropriate function.
%%
%% Arity 2 functions must be added to `get_grouping_fun/1'. They are
%% passed as tuples, for example `{'my_predicate_name', <<"some_arg">>}' and
%% called as `my_predicate_fun(ListItem, <<"some_arg">>)'.
%%
%% @end
%%------------------------------------------------------------------------------
-spec filter(Predicates :: predicate_list(), List1 :: list()) -> List2 :: list().

filter(Predicates, List) ->
    lists:filter(
      fun(ListItem) ->
              test_predicates(Predicates, ListItem)
      end,
      List
     ).

test_predicates(Predicates, ListItem) ->
    lists:all(
      fun(Predicate) ->
              test_predicate(Predicate, ListItem)
      end,
      Predicates
     ).

test_predicate({PredicateName, Args}, ListItem) when is_atom(PredicateName) ->
    PredicateFun = get_predicate(PredicateName),
    test_predicate({PredicateFun, Args}, ListItem);

test_predicate(PredicateName, ListItem) when is_atom(PredicateName) ->
    PredicateFun = get_predicate(PredicateName),
    test_predicate(PredicateFun, ListItem);

test_predicate({PredicateFun, Args}, ListItem) when is_function(PredicateFun, 2) ->
    apply(PredicateFun, [ListItem, Args]);

test_predicate(PredicateFun, ListItem) when is_function(PredicateFun, 1) ->
    apply(PredicateFun, [ListItem]).

get_predicate('all') -> fun all_predicate/2;
get_predicate('any') -> fun any_predicate/2;
get_predicate('count') -> fun count_predicate/2;
get_predicate('and') -> fun and_predicates/2;
get_predicate('or') -> fun or_predicates/2;
get_predicate('not') -> fun not_predicates/2;
get_predicate('name') -> fun name/2;
get_predicate('names') -> fun names/2;
get_predicate('node') -> fun node/2;
get_predicate('node_match') -> fun node_match/2;
get_predicate('host') -> fun host/2;
get_predicate('running') -> fun running/1;
get_predicate('not_running') -> fun not_running/1;
get_predicate('running_since') -> fun running_since/2;
get_predicate('running_since_localtime') -> fun running_since_localtime/2;
get_predicate('version') -> fun version_eq/2;
get_predicate('version_eq') -> fun version_eq/2;
get_predicate('version_gt') -> fun version_gt/2;
get_predicate('version_gte') -> fun version_gte/2;
get_predicate('version_lt') -> fun version_lt/2;
get_predicate('version_lte') -> fun version_lte/2.

%%
%% Version Predicates
%%
%% These functions compare version numbers like this:
%%
%% 1.  Convert the arguments to strings.
%% 2.  Split the strings into parts on "."
%% 3.  Convert each part to an integer if possible.
%% 4.  Compare the results.
%%
%% For example:
%%
%% <code>
%%   version_gt(#node_app_version{version=<<"5.0.1">>}, "5.0.2").
%% </code>
%%
%% Will be evaluated as:
%%
%% <code>
%%     [5, 0, 1] > [5, 0, 2]
%% </code>
%%
%% If the version contains something other than numbers and dots,
%% those strings will be compared based on the numeric values of their
%% bytes.  For example, "5.0.3-foo" becomes `[5,0,3,45,102,111,111]'.
%%

-spec version_gt(versionish(), versionish()) -> boolean().
version_gt(#node_app_version{version=A}, #node_app_version{version=B}) ->
    version_gt(A, B);

version_gt(A, B) ->
    AParts = version_to_list(A),
    BParts = version_to_list(B),
    AParts > BParts.

-spec version_gte(versionish(), versionish()) -> boolean().
version_gte(A, B) ->
    AParts = version_to_list(A),
    BParts = version_to_list(B),
    AParts >= BParts.

-spec version_lt(versionish(), versionish()) -> boolean().
version_lt(A, B) ->
    not version_gte(A, B).

-spec version_lte(versionish(), versionish()) -> boolean().
version_lte(A, B) ->
    not version_gt(A, B).

-spec version_eq(versionish(), versionish()) -> boolean().
version_eq(A, B) ->
    %% The conversion here ensures we're comparing like things and
    %% not, for example, a binary to a record.
    Alist = version_to_list(A),
    Blist = version_to_list(B),
    Alist =:= Blist.

-spec version_to_list(versionish()) -> list().
version_to_list(<<"unknown">>) -> 0;

version_to_list(#node_app_version{version=V}) ->
    version_to_list(V);

version_to_list(B) when is_binary(B) ->
    version_to_list(binary_to_list(B));

version_to_list(V) ->
    Parts = string:split(V, ".", 'all'),
    lists:flatten(
      lists:map(fun version_parts_to_int/1, Parts)
     ).

version_parts_to_int(Part) ->
    case string:to_integer(Part) of
        {Int, []} -> Int;
        {'error', 'no_integer'} -> Part;
        {Int, Rest} -> [Int, Rest]
    end.

%%
%% Uptime Predicates
%%
%% These functions evaluate the `startup' field of a
%% `#node_app_version{}'.
%%
%% `startup' is the UTC date and time at which an application was
%% started, converted to Gregorian seconds, or `'undefined'`.
%%
%% Note that this field does NOT contain timezone information.  It is
%% assumed to be UTC as the recommended practice is to set the
%% timezone to UTC on all hosts running Kazoo applications.
%%
%% The `running_since_localtime/2' predicate is provided for
%% convenience: It assumes the application's startup time is UTC and
%% the argument for comparison is a `datetime()' in the user's
%% preferred timezone.

running(#node_app_version{startup = 'undefined'}) ->'false';
running(#node_app_version{startup=_I}) when is_integer(_I) -> 'true'.

not_running(NAV) ->
    not running(NAV).

running_since(NAV, {Date, Time}) ->
    Since = calendar:datetime_to_gregorian_seconds({Date, Time}),
    running_since(NAV, Since);

running_since(NAV, {Year, Month, Day}) ->
    Since = calendar:datetime_to_gregorian_seconds({{Year, Month, Day}, {0, 0, 0}}),
    running_since(NAV, Since);

running_since(#node_app_version{startup='undefined'}, _) ->
    'false';
running_since(#node_app_version{startup=Startup}, Since) ->
    running_since(Startup, Since);

running_since(Startup, Since) when is_integer(Startup), is_integer(Since) ->
    Since =< Startup;

running_since(_, _) -> 'false'.

running_since_localtime(#node_app_version{startup='undefined'}, _) ->
    'false';

running_since_localtime(#node_app_version{startup=Startup}, Since) ->
    StartupUniversalDT = calendar:gregorian_seconds_to_datetime(Startup),
    StartupLocalDT = calendar:universal_time_to_local_time(StartupUniversalDT),
    StartupLocalSeconds = calendar:datetime_to_gregorian_seconds(StartupLocalDT),
    running_since(StartupLocalSeconds, Since).

%%
%% List Predicates
%%

%%------------------------------------------------------------------------------
%% @doc Returns `true' if `Pred' returns `true' for all `Items'.
%% @end
%%------------------------------------------------------------------------------
-spec all_predicate(Items :: list(), Pred :: predicate_function_specifier()) -> boolean().
all_predicate(Items, Predicate) ->
    lists:all(
      fun(Item) ->
              test_predicates(Predicate, Item)
      end
     ,Items
     ).

%%------------------------------------------------------------------------------
%% @doc Returns `true' if `Pred' returns `true' for any `Items'.
%% @end
%%------------------------------------------------------------------------------
-spec any_predicate(Items :: list(), Pred :: predicate_function_specifier()) -> boolean().
any_predicate(Items, Predicate) ->
    lists:any(
      fun(Item) ->
              test_predicates(Predicate, Item)
      end
     ,Items
     ).

%%------------------------------------------------------------------------------
%% @doc Returns `true' if the number of items in `Items' is equal to `Count'.
%% @end
%%------------------------------------------------------------------------------
-spec count_predicate(Items :: list(), Count :: non_neg_integer()) -> boolean().
count_predicate(Items, Count) ->
    erlang:length(Items) =:= Count.
%%
%% Composite Predicates
%%

%%------------------------------------------------------------------------------
%% @doc Returns `true' if all `Predicates' return `true' for `Item'.
%% @end
%%------------------------------------------------------------------------------
-spec and_predicates(Item :: any(), Predicates :: predicate_list()) -> boolean().

and_predicates(ListItem, Predicates) ->
    test_predicates(Predicates, ListItem).

%%------------------------------------------------------------------------------
%% @doc Returns `true' if any of `Predicates' returns `true' for
%% `Item'.
%% @end
%%------------------------------------------------------------------------------
-spec or_predicates(any(), predicate_list()) -> boolean().
or_predicates(ListItem, Predicates) ->
    lists:any(
      fun(Predicate) ->
              test_predicate(Predicate, ListItem)
      end
     ,Predicates
     ).

%%------------------------------------------------------------------------------
%% @doc Returns `true' if all `Predicates' return `false' for `Item'.
%% @end
%%------------------------------------------------------------------------------
-spec not_predicates(any(), predicate_list()) -> boolean().
not_predicates(ListItem, Predicates) ->
    not test_predicates(Predicates, ListItem).

%%
%% Node Predicates
%%
%% These functions evaluate the `node' on which an application is running.

%%------------------------------------------------------------------------------
%% @doc Returns `true' if `Node1' and `Node2' are the same.
%% @end
%%------------------------------------------------------------------------------
-spec node(Node1 :: node_app_version() | atom() | binary(), Node2 :: binary()) -> boolean().

node(#node_app_version{node=NodeAtom}, Node) when is_atom(NodeAtom), is_binary(Node) ->
    node(atom_to_binary(NodeAtom), Node);

node(Node, Node) -> 'true';
node(_, _) -> 'false'.

%%------------------------------------------------------------------------------
%% @doc Returns `true' if the host component of the first argument is
%% equal to the second argument.
%% @end
%%------------------------------------------------------------------------------

-spec host(node_app_version() | atom() | binary(), Host :: binary()) -> boolean().

host(NAV=#node_app_version{}, Host) ->
    host(get_host(NAV), Host);

host(Host, Host) when is_binary(Host) -> 'true';
host(_, _) -> 'false'.

%%------------------------------------------------------------------------------
%% @doc Returns `true' if `Node1', converted to a binary, matches any
%% of `Patterns' according to `binary:match/2'.
%% @end
%%------------------------------------------------------------------------------
-spec node_match(Node1 :: node_app_version() | atom() | binary(), list()) -> boolean().

node_match(#node_app_version{node=Node}, Patterns) ->
    node_match(Node, Patterns);

node_match(Node, Patterns) when is_atom(Node) ->
    node_match(atom_to_binary(Node), Patterns);

node_match(Node, Patterns) when is_list(Patterns), is_binary(Node) ->
    try binary:match(Node, Patterns) of
        'nomatch' ->
            'false';
        _Any ->
            'true'
    catch
        _:_:_ ->
            'false'
    end.

%%
%% Application Name Predicates
%%

%%------------------------------------------------------------------------------
%% @doc Returns 'true' if the application name of the first argument is
%% equal to `Name2'.
%% @end
%% ------------------------------------------------------------------------------
-spec name(Name1 :: node_app_version() | binary(), Name2 :: binary()) -> boolean().

name(#node_app_version{name=Name}, Name) -> 'true';
name(Name, Name) when is_binary(Name) -> 'true';
name(_, _) -> 'false'.

%%------------------------------------------------------------------------------
%% @doc Returns `true' if the application name in the first argument
%% is equal to any of the binaries in `Names'.
%% @end
%%------------------------------------------------------------------------------
-spec names(Name1 :: node_app_version() | binary(), Names :: kz_term:ne_binaries()) -> boolean().
names(#node_app_version{name=Name}, Names) ->
    names(Name, Names);
names(Name, Names) ->
    lists:any(
      fun(N) ->
              N =:= Name
      end
     ,Names
     ).

%%%
%%% GROUPING FUNCTIONS
%%%

%%------------------------------------------------------------------------------
%% @doc Returns the elements of `List' organized into a hierarchy of
%% nested categories.  Each level, N, of the hierarchy corresponds to
%% the Nth element in `Groupers'.
%%
%% Example:
%%
%% ```
%%    > NAV1 = #node_app_version{node = 'kazoo_apps@host1.mydomain.com', version = <<"5.0.1">>, name = <<"webhooks">>}.
%%
%%    > NAV2 = #node_app_version{node = 'kazoo_apps@host2.mydomain.com', version = <<"5.0.1">>, name = <<"webhooks">>}.
%%
%%    > NAV3 = #node_app_version{node = 'kazoo_apps@host2.mydomain.com', version = <<"5.2.0">>, name = <<"webhooks">>}.
%%
%%    > kapps_versions:groups_by([fun kapps_versions:get_name/1, fun kapps_versions:get_version/1], [NAV1, NAV2, NAV3]).
%%    #{<<"webhooks">> =>
%%          #{<<"5.0.1">> =>
%%                [#node_app_version{node = 'kazoo_apps@host2.mydomain.com',
%%                                   name = <<"webhooks">>,description = 'undefined',
%%                                   version = <<"5.0.1">>,startup = 'undefined'},
%%                 #node_app_version{node = 'kazoo_apps@host1.mydomain.com',
%%                                   name = <<"webhooks">>,description = 'undefined',
%%                                   version = <<"5.0.1">>,startup = 'undefined'}],
%%            <<"5.2.0">> =>
%%                [#node_app_version{node = 'kazoo_apps@host2.mydomain.com',
%%                                   name = <<"webhooks">>,description = 'undefined',
%%                                   version = <<"5.2.0">>,startup = 'undefined'}]}}
%% '''
%%
%% For convenience, this module provides a number of ready-made
%% grouping functions that can be specified as atoms in `Groupers'
%% (@see get_grouping_fun/1). The example above can also be written:
%%
%% <code>
%%    kapps_versions:groups_by(['name', 'version'], [NAV1, NAV2, NAV3]).
%% </code>
%% @end
%%------------------------------------------------------------------------------
-spec groups_by(Groupers :: key_functions(), List :: list()) -> GroupMap :: group_map().

groups_by(Groupers, List) when is_list(Groupers) ->
    lists:foldl(
      fun(Row, Acc) ->
              group_append(Groupers, Row, Acc)
      end
     ,#{}
     ,List
     ).

-spec groups_by(Groupers :: key_functions(), List :: list(), Having :: predicate_list()) -> GroupMap :: group_map().
%%------------------------------------------------------------------------------
%% @doc Generates the same group map as `groups_by/2' and then filters
%% the result with the predicate list `Having'.
%% @end
%%------------------------------------------------------------------------------
groups_by(Groupers, List, Having) ->
    G1 = groups_by(Groupers, List),
    filter_groups(Having, G1).

group_append([Grouper], Value, Map) ->
    GrouperFun = get_grouping_fun(Grouper),
    Key = GrouperFun(Value),
    CurrentValue = maps:get(Key, Map, []),
    maps:put(Key, [Value | CurrentValue], Map);

group_append([Grouper|Rest], Value, Map) ->
    GrouperFun = get_grouping_fun(Grouper),
    Key = GrouperFun(Value),
    SubMap = maps:get(Key, Map, #{}),
    maps:put(Key, group_append(Rest, Value, SubMap), Map).

get_grouping_fun('node') -> fun get_node/1;
get_grouping_fun('host') -> fun get_host/1;
get_grouping_fun('name') -> fun get_name/1;
get_grouping_fun('description') -> fun get_description/1;
get_grouping_fun('version') -> fun get_version/1;
get_grouping_fun('startup') -> fun get_startup/1;
get_grouping_fun('running') -> fun get_running/1;
get_grouping_fun(Fun) when is_function(Fun, 1) -> Fun.

%%------------------------------------------------------------------------------
%% @doc Returns a `group_map()' where the innermost value is an
%% integer indicating the number of elements in that category.
%%
%% For example, given `NAV1', `NAV2', and `NAV3' as defined above:
%%
%% ```
%%   > kapps_versions:counts_by(['version'], [NAV1, NAV2, NAV3]).
%%   #{<<"5.0.1">> => 2,<<"5.2.0">> => 1}
%%
%%   > kapps_versions:counts_by(['name', 'version'], [NAV1, NAV2, NAV3]).
%%   #{<<"webhooks">> => #{<<"5.0.1">> => 2,<<"5.2.0">> => 1}}
%% '''
%% @end
%%------------------------------------------------------------------------------
-spec counts_by(Groupers :: key_functions(), list()) -> group_map().

counts_by(Groupers, List) ->
    Grouped = groups_by(Groupers, List),
    map_groups(fun erlang:length/1, Grouped).

%%------------------------------------------------------------------------------
%% @doc Returns a `group_map()' where the innermost value is a list of
%% `{Count, Key}` where `Key' is a key from the innermost category and
%% `Count' is the number of items having that key.
%%
%% For example, given `NAV1', `NAV2', and `NAV3' as defined above:
%%
%% ```
%%   > kapps_versions:count_pairs_by(['name', 'version'], [NAV1, NAV2, NAV3]).
%%   #{<<"webhooks">> => [{1,<<"5.2.0">>},{2,<<"5.0.1">>}]}
%% '''
%% @end
%%------------------------------------------------------------------------------
-spec count_pairs_by(Groupers :: key_functions(), list()) -> map() | list().

count_pairs_by([Grouper], List) ->
    Counted = counts_by([Grouper], List),
    maps:fold(
      fun(Key, Value, Acc) ->
              [{Value, Key} | Acc]
      end
     ,[]
     ,Counted
     );

count_pairs_by(Groupers, List) ->
    Counted = counts_by(Groupers, List),
    fold_groups(
      fun(Path, Value, Acc) ->
              RevPath = lists:reverse(Path),
              Key = hd(RevPath),
              ParentPath = tl(RevPath),
              CurrentValue = map_get(ParentPath, Acc, []),
              map_put(ParentPath, [{Value, Key} | CurrentValue], Acc)

      end
     ,#{}
     ,Counted
     ).

%%------------------------------------------------------------------------------
%% @doc Same as `count_pairs_by/2' but the innermost lists are sorted
%% according `SortFun'.
%% @end
%%------------------------------------------------------------------------------
-spec sorted_count_pairs_by(SortFun :: function(), Groupers :: key_functions(), List :: list()) -> list() | map().

sorted_count_pairs_by(SortFun, [Grouper], List) ->
    PairList = count_pairs_by([Grouper], List),
    lists:sort(SortFun, PairList);

sorted_count_pairs_by(SortFun, Groupers, List) ->
    Paired = count_pairs_by(Groupers, List),
    map_groups(
      fun(SubList) ->
              lists:sort(SortFun, SubList)
      end
     ,Paired
     ).

%%------------------------------------------------------------------------------
%% @doc Same as `count_pairs_by/2' but the innermost lists are sorted
%% in descending order.
%% @end
%%------------------------------------------------------------------------------
-spec desc_count_pairs_by(Groupers :: key_functions(), list()) -> list() | map().

desc_count_pairs_by(Groupers, List) ->
    SortDescFun = fun({Count1, _}, {Count2, _}) ->
                          Count1 > Count2
                  end,
    sorted_count_pairs_by(SortDescFun, Groupers, List).

-spec asc_count_pairs_by(Groupers :: key_functions(), list()) -> map().
%%------------------------------------------------------------------------------
%% @doc Same as `count_pairs_by/2' but the innermost lists are sorted
%% in ascending order.
%% @end
asc_count_pairs_by(Groupers, List) ->
    SortAscFun = fun({Count1, _}, {Count2, _}) ->
                         Count1 < Count2
                 end,
    sorted_count_pairs_by(SortAscFun, Groupers, List).

%%------------------------------------------------------------------------------
%% @doc Returns a `group_map()' where the innermost value is a
%% `stats_map()' describing the frequencies of elements in that
%% category.
%% @end
%%------------------------------------------------------------------------------
-spec count_stats_by(Groupers :: key_functions(), list()) -> map().

count_stats_by([Grouper], List) ->
    Counts = desc_count_pairs_by([Grouper], List),
    count_stats(Counts);

count_stats_by(Groupers, List) ->
    Counts = desc_count_pairs_by(Groupers, List),
    map_groups(fun count_stats/1, Counts).

%%------------------------------------------------------------------------------
%% @doc Given a sorted (descending) list of tuples in the form
%% `[{Count, Item}, ...]', returns a `stats_map()' where `'majority''
%% is the tuple with the highest count and `'minority'' is the list of
%% tuples with counts less than the majority.
%% @end
%%------------------------------------------------------------------------------
-spec count_stats(stats_list()) -> stats_map().

count_stats(List) ->
    {Majority, Minority} = count_majority(List),
    #{
      'majority' => Majority,
      'minority' => Minority
     }.

%%------------------------------------------------------------------------------
%% @doc Assuming `List' is stats_list() in descending order, returns a
%% tuple of `{Majority, Minority}' where `Majority' is the tuple with
%% the highest count and `Minority' is the list of tuples with counts
%% less than `Majority'.
%% @end
%%------------------------------------------------------------------------------
-spec count_majority(List :: stats_list()) -> {stats_tuple(), stats_list()}.

count_majority([]) ->
    %% If the list is empty, there is no majority.
    {'none', []};
count_majority([Value]) ->
    %% If the list has one item, there is a majority.
    {Value, []};
count_majority([{Value, _}, {Value, _} | _]=All) ->
    %% If the top two elements have the same count, there is no majority.
    {'none', All};
count_majority([{Value1, _}=A, {Value2, _}=B | Rest]) when Value1 > Value2 ->
    %% A is the majority, B and everything after is the minority.
    {A, [B | Rest]}.

%%------------------------------------------------------------------------------
%% @doc `Groups2' is a group map containing all of the groups from
%% `Group1' for which all the `Predicates' returned `true'.
%% @end
%% ------------------------------------------------------------------------------
-spec filter_groups(Predicates :: predicate_list(), Groups1 :: group_map()) -> Groups2 :: group_map().

filter_groups(Fun, Map) ->
    filter_groups([], Fun, #{}, Map).

filter_groups(KeyPath, FunSpec, Init, Map) ->
    maps:fold(
      fun(Key, SubMap, Acc) when is_map(SubMap) ->
              filter_groups([Key | KeyPath], FunSpec, Acc, SubMap);

         (Key, List, Acc) when is_list(List) ->
              Path = lists:reverse([Key | KeyPath]),
              %% We should probably pass Path to test_predicates somehow.
              case test_predicates(FunSpec, List) of
                  'true' ->
                      map_put(Path, List, Acc);
                  'false' ->
                      Acc
              end
      end
     ,Init
     ,Map
     ).

%%------------------------------------------------------------------------------
%% @doc Inserts `Value' into a nested map at the path described by
%% `Path'.  New submaps are created as needed.  If a value already
%% exists at the given path, it is replaced.
%%
%% Note that `Path' is a list of terms, NOT a list of key generating
%% functions as with `groups_by/2'.
%% @end
%%------------------------------------------------------------------------------
-spec map_put(Path :: list(), Value :: any(), GroupMap :: group_map()) -> map().

map_put([Key], Value, Map) ->
    maps:put(Key, Value, Map);

map_put([Key|Rest], Value, Map) ->
    SubMap = maps:get(Key, Map, #{}),
    maps:put(Key, map_put(Rest, Value, SubMap), Map).

%%------------------------------------------------------------------------------
%% @doc Traverses `GroupMap' along the keys described by `Path' and
%% returns the value found there or `Default' if any key along the
%% path does not exist.
%% @end
%%------------------------------------------------------------------------------
-spec map_get(Path :: list(), GroupMap :: group_map(), Default :: any()) -> any().

map_get([Key], Map, Default) ->
    maps:get(Key, Map, Default);

map_get([Key|Rest], Map, Default) ->
    case maps:get(Key, Map, 'undefined') of
        'undefined' ->
            Default;
        SubMap when is_map(SubMap) ->
            map_get(Rest, SubMap, Default)
    end.

%%------------------------------------------------------------------------------
%% @doc Calls `Fun(Path, Elem, AccN)` on each of the innermost values
%% of `GroupMap`, starting with `AccN == Acc0'.  `Fun/3' must return
%% a new accumulator which is passed to the next call.  Returns the
%% final value of the accumulator.
%% @end
%%------------------------------------------------------------------------------
-spec fold_groups(Fun :: function(), Acc0 :: any(), GroupMap :: group_map()) -> any().

fold_groups(Fun, Acc0, Map) ->
    fold_groups([], Fun, Acc0, Map).

fold_groups(KeyPath, Fun, Acc0, Map) ->
    maps:fold(
      fun(Key, SubMap, AccN) when is_map(SubMap) ->
              fold_groups([Key | KeyPath], Fun, AccN, SubMap);
         (Key, Value, AccN) ->
              Path = lists:reverse([Key | KeyPath]),
              Fun(Path, Value, AccN)
      end
     ,Acc0
     ,Map
     ).

%%------------------------------------------------------------------------------
%% @doc Calls `Fun(Value)' or `Fun(Key, Value)' on each of the
%% innermost key/value pairs of `GroupMap1', replacing `Value' with
%% the result.
%% @end
%%------------------------------------------------------------------------------
-spec map_groups(Fun :: function(), GroupMap1 :: map()) -> GroupMap2 :: map().

map_groups(Fun, Map) when is_function(Fun) ->
    maps:map(
      fun(_Key, Value) when is_map(Value) ->
              map_groups(Fun, Value);
         (_Key, Value) when is_function(Fun, 1) ->
              Fun(Value);
         (Key, Value) when is_function(Fun, 2) ->
              Fun(Key, Value)
      end
     ,Map
     ).

%%------------------------------------------------------------------------------
%% @doc Returns a 2-dimensional list generated from `GroupMap'.
%% @end
%%------------------------------------------------------------------------------
-spec map_to_table(GroupMap :: group_map()) -> list().

map_to_table(Map) ->
    map_to_table([], Map).

map_to_table(Prefix, Map) ->
    maps:fold(
      fun(Key, SubMap, Acc) when is_map(SubMap) ->
              Rows = map_to_table([Key | Prefix], SubMap),
              Rows ++ Acc;
         (Key, List, Acc) when is_list(List) ->
              Rows = list_to_table([Key | Prefix], List),
              Rows ++ Acc;
         (Key, Value, Acc) ->
              Row = lists:reverse(
                      lists:flatten(
                        [Value, Key, Prefix]
                       )
                     ),
              [Row | Acc]
      end
     ,[]
     ,Map
     ).

list_to_table(Prefix, List) ->
    lists:map(
      fun(Value) ->
              lists:reverse(
                lists:flatten(
                  [Value, Prefix]
                 )
               )
      end
     ,List
     ).

%%
%% Getters and Mappers
%%

%% These functions convert one thing to another and are suitable for
%% use as key functions ("groupers").
%%
%% When adding a new function here, it may be appropriate to add a
%% corresponding clause to `get_grouping_fun/1' as well.

-spec get_node(node_app_version()) -> atom().
get_node(#node_app_version{node=Node}) -> Node.

-spec get_host(node_app_version()) -> kz_term:ne_binary().
get_host(#node_app_version{node=Node}) ->
    NodeBin = atom_to_binary(Node),
    [_, Host] = binary:split(NodeBin, <<"@">>),
    Host.

-spec get_name(node_app_version()) -> kz_term:ne_binary().
get_name(#node_app_version{name=Name}) -> Name.

-spec get_description(node_app_version()) -> kz_term:ne_binary().
get_description(#node_app_version{description=Description}) -> Description.

-spec get_version(node_app_version()) -> kz_term:ne_binary().
get_version(#node_app_version{version=Version}) -> Version.

-spec get_startup(node_app_version()) -> kz_term:api_integer().
get_startup(#node_app_version{startup=Startup}) -> Startup.

-spec get_running(node_app_version()) -> boolean().
get_running(NAV) ->
    is_integer(get_startup(NAV)).

%%%
%%% REPORTING FUNCTIONS
%%%

%% These functions are for printing information on the screen with
%% indentation.  Where supported, indentation is specified by an
%% integer argument that will be used as multiplier.  For example an
%% argument of 2 will cause `2 * ?INDENT_SPACES` spaces to be printed
%% on the screen.  The default indentation is 0.

%%------------------------------------------------------------------------------
%% @doc Print a `#node_app_version{}' on the screen indented at 0.
%% @end
%%------------------------------------------------------------------------------
-spec report_node_app_version(node_app_version()) -> 'ok'.

report_node_app_version(NAV) ->
    report_node_app_version(0, NAV).

%%------------------------------------------------------------------------------
%% @doc Print a `#node_app_version{}' on the screen indented at
%% 'Indent'.
%% @end.
%%------------------------------------------------------------------------------
-spec report_node_app_version(Indent :: integer(), NAV :: node_app_version()) -> 'ok'.

report_node_app_version(Indent, #node_app_version{node=Node, name=Name, version=Version, startup=Startup}) ->
    AvailableOrRunning = available_or_running(Startup),
    report_indented(Indent, "node ~s ~s version ~s ~s~n", [Node, Name, Version, AvailableOrRunning]).

%%------------------------------------------------------------------------------
%% @doc Print a list of `#node_app_version{}' to the screen with
%% indentation starting at 0.  Each record is printed on a separate
%% line.
%% @end
%%------------------------------------------------------------------------------
-spec report_node_app_versions(list()) -> 'ok'.

report_node_app_versions(Nodes) ->
    lists:foreach(fun report_node_app_version/1, Nodes).

%%------------------------------------------------------------------------------
%% @doc Print a list of `#node_app_version{}' to the screen with
%% indentation starting at `Indent'.  Each record is printed on a
%% separate line.
%% @end
%%------------------------------------------------------------------------------
-spec report_node_app_versions(Indent :: integer(), NAVs :: list()) -> 'ok'.

report_node_app_versions(Indent, NAVs) ->
    _ = lists:foreach(
          fun(NAV) ->
                  report_node_app_version(Indent, NAV)
          end,
          NAVs
         ),
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Prints `GroupMap' to the screen with indentation starting at
%% 0. Keys and values are printed on separate lines.
%% @end
%%------------------------------------------------------------------------------
-spec report_groups(group_map()) -> 'ok'.

report_groups(Map) ->
    report_groups(0, Map).

%%------------------------------------------------------------------------------
%% @doc Prints `GroupMap' to the screen with indentation starting at
%% `Indent'. Keys and values are printed on separate lines.
%% @end
%%------------------------------------------------------------------------------
-spec report_groups(Indent :: integer(), GroupMap :: group_map()) -> 'ok'.

report_groups(Indent, Map) ->
    _ = maps:map(
          fun(Key, SubMap) when is_map(SubMap) ->
                  report_indented(Indent, "~s:~n", [Key]),
                  report_groups(Indent+1, SubMap);

             (Key, Value) ->
                  report_indented(Indent, "~s:~n", [Key]),
                  report_value(Indent+1, Value)
          end,
          Map
         ),
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Prints `Value' on the screen with indentation.  If `Value' is
%% a list, each element of the list is printed on a separate line.
%% @end
%%------------------------------------------------------------------------------
-spec report_value(Indent :: integer(), Value :: any()) -> 'ok'.

report_value(Indent, Value) when is_list(Value) ->
    lists:foreach(
      fun(Row) ->
              report_value(Indent, Row)
      end,
      Value
     ),
    'ok';

report_value(Indent, NAV=#node_app_version{}) ->
    report_node_app_version(Indent, NAV);

report_value(Indent, Value) ->
    report_indented(Indent, "~p~n", [Value]).

%%------------------------------------------------------------------------------
%% @doc Equivalent to `io:format(Format, Data)' prefixed with
%% `Indent * ?INDENT_SPACES' space characters.
%%
%% @end
%%------------------------------------------------------------------------------
-spec report_indented(Indent :: integer(), Format :: io:format(), Data :: list()) -> 'ok'.

report_indented(Indent, Format, Data) ->
    IndentFmt = io_lib:format("~~~Bs", [?INDENT_SPACES * Indent]),
    io:format(IndentFmt, [" "]),
    io:format(Format, Data).

available_or_running(_I) when is_integer(_I) -> 'running';
available_or_running('undefined') -> 'available'.
