%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_endpoint_aliases).

-export([aliases/1, aliases/2, set_aliases/2]).
-export([monitoring/1, monitoring/2, set_monitoring/2]).
-export([publishing/1, publishing/2, set_publishing/2]).
-export([merge/1, merge/2]).

-type endpoint() :: kz_json:object().
-type endpoints() :: [endpoint()].
-type presence_aliases() :: kz_json:object() | kz_term:ne_binaries().
-type api_presence_aliases() :: presence_aliases() | undefined.
-type api_presence_aliases_list() :: [api_presence_aliases()].

-type aliases_collector_fun_return() :: api_presence_aliases() | api_presence_aliases_list().
-type aliases_collector_fun() :: fun((endpoints()) -> aliases_collector_fun_return()).
-type aliases_collector_funs() :: [aliases_collector_fun()].

-type options() :: #{aliases_collector_funs => aliases_collector_funs()
                    ,endpoints_only => boolean()
                    }.

-export_type([endpoint/0
             ,endpoints/0
             ,presence_aliases/0
             ,api_presence_aliases/0
             ,options/0
             ]).

-spec aliases(endpoint()) -> api_presence_aliases().
aliases(Endpoint) ->
    aliases(Endpoint, 'undefined').

-spec aliases(endpoint(), Default) -> presence_aliases() | Default.
aliases(Endpoint, Default) ->
    case kz_json:get_json_value([<<"presence_aliases">>], Endpoint, not_found_or_not_json) of
        not_found_or_not_json -> kz_json:get_ne_binaries([<<"presence_aliases">>], Endpoint, Default);
        Value -> Value
    end.

-spec set_aliases(endpoint(), presence_aliases()) -> endpoint().
set_aliases(Endpoint, []) ->
    kz_json:set_value([<<"presence_aliases">>], 'null', Endpoint);
set_aliases(Endpoint, Aliases)
  when is_list(Aliases) ->
    case kz_term:is_ne_binaries(Aliases) of
        true -> kz_json:set_value([<<"presence_aliases">>], Aliases, Endpoint);
        false -> throw(badarg)
    end;
set_aliases(Endpoint, Aliases) ->
    case kz_json:is_json_object(Aliases) of
        true -> kz_json:set_value([<<"presence_aliases">>], Aliases, Endpoint);
        false -> throw(badarg)
    end.

-spec monitoring(endpoint()) -> kz_term:api_ne_binaries().
monitoring(Endpoint) ->
    monitoring(Endpoint, 'undefined').

-spec monitoring(endpoint(), Default) -> kz_term:ne_binaries() | Default.
monitoring(Endpoint, Default) ->
    aliases_value(<<"monitoring">>, aliases(Endpoint), Default).

-spec set_monitoring(endpoint(), kz_term:ne_binaries()) -> endpoint().
set_monitoring(Endpoint, Aliases) ->
    kz_json:set_value([<<"presence_aliases">>, <<"monitoring">>], Aliases, Endpoint).

-spec publishing(endpoint()) -> kz_term:api_ne_binaries().
publishing(Endpoint) ->
    publishing(Endpoint, 'undefined').

-spec publishing(endpoint(), Default) -> kz_term:ne_binaries() | Default.
publishing(Endpoint, Default) ->
    aliases_value(<<"publishing">>, aliases(Endpoint), Default).

-spec set_publishing(endpoint(), kz_term:ne_binaries()) -> endpoint().
set_publishing(Endpoint, Aliases) ->
    kz_json:set_value([<<"presence_aliases">>, <<"publishing">>], Aliases, Endpoint).

-spec aliases_value(kz_term:ne_binary(), api_presence_aliases(), Default) -> kz_term:ne_binaries() | Default.
aliases_value(_Key, undefined, Default) ->
    Default;
aliases_value(_Key, Aliases, _Default)
  when is_list(Aliases) ->
    Aliases;
aliases_value(Key, Aliases, Default) ->
    case kz_json:is_json_object(Aliases) of
        true -> kz_json:get_ne_binaries([Key], Aliases, Default);
        false -> throw(badarg)
    end.

-spec default_merge_options() -> options().
default_merge_options() ->
    #{aliases_collector_funs => default_aliases_collectors()}.

-spec merge(endpoints()) -> api_presence_aliases().
merge(Endpoints) ->
    merge(Endpoints, default_merge_options()).

-spec merge(endpoints(), options()) -> api_presence_aliases().
merge(Endpoints, Options) ->
    case endpoints_to_aliases(Endpoints, Options) of
        [] -> undefined;
        [One] -> One;
        Aliases -> merge_aliases(Aliases, Options)
    end.

-spec merge_aliases(presence_aliases(), options()) -> presence_aliases().
merge_aliases([First | Aliases], Options) ->
    Merged = lists:foldl(fun merge_aliases_fold/2, First, Aliases),
    merge_aliases_result(Merged, Options).

merge_aliases_result(Result, _Options) ->
    %% TODO
    %% return list (if possible) or object by looking at options
    Result.

merge_aliases_fold(Aliases, Acc0) ->
    Acc = merge_aliases_value(<<"monitoring">>, Aliases, Acc0),
    merge_aliases_value(<<"publishing">>, Aliases, Acc).

merge_aliases_value(Key, Aliases, Acc) ->
    V1 = aliases_value(Key, Aliases, []),
    V2 = aliases_value(Key, Acc, []),
    kz_json:set_value(Key, lists:umerge(V1, V2), Acc).

-spec default_aliases_collectors() -> aliases_collector_funs().
default_aliases_collectors() ->
    [fun from_endpoints/1
    ,fun from_groups/1
    ].

-spec aliases_collectors(options()) -> aliases_collector_funs().
aliases_collectors(#{aliases_collector_funs := Funs}) ->
    Funs;
aliases_collectors(#{endpoints_only := true}) ->
    [fun from_endpoints/1];
aliases_collectors(_Options) ->
    default_aliases_collectors().

-spec endpoints_to_aliases(endpoints(), options()) -> api_presence_aliases().
endpoints_to_aliases(Endpoints, Options) ->
    Funs = aliases_collectors(Options),
    Aliases = lists:map(fun(Fun) -> Fun(Endpoints) end, Funs),
    lists:filter(fun kz_term:is_not_empty/1, lists:flatten(Aliases)).

-spec from_endpoints(endpoints()) -> api_presence_aliases_list().
from_endpoints(Endpoints) ->
    lists:map(fun endpoint_to_aliases/1, Endpoints).

-spec endpoint_to_aliases(endpoint() | presence_aliases()) -> presence_aliases().
endpoint_to_aliases(Aliases)
  when is_list(Aliases) ->
    Props = [{<<"monitoring">>, Aliases}
            ,{<<"publishing">>, Aliases}
            ],
    kz_json:from_list(Props);
endpoint_to_aliases(Endpoint) ->
    case aliases(Endpoint) of
        Aliases when is_list(Aliases) -> endpoint_to_aliases(Aliases);
        Other -> Other
    end.

-define(GROUP_ENDPOINT_QUERY, <<"groups/listing_by_endpoint">>).

-spec group_account_id(endpoints()) -> kz_term:api_ne_binary().
group_account_id(Endpoints) ->
    AccountIdList = lists:map(fun kzd_endpoint:account_id/1, Endpoints),
    case lists:filter(fun kz_term:is_not_empty/1, AccountIdList) of
        [] -> undefined;
        List -> lists:last(List)
    end.

-spec from_groups(endpoints()) -> api_presence_aliases().
from_groups(Endpoints) ->
    case group_account_id(Endpoints) of
        AccountId when is_binary(AccountId) ->
            from_groups_query(AccountId, Endpoints);
        Else -> Else
    end.

from_groups_query(AccountId, Endpoints) ->
    QueryOptions = group_query_options(Endpoints),
    QueryResult = kz_datamgr:get_results(AccountId, ?GROUP_ENDPOINT_QUERY, QueryOptions),
    group_query_results(QueryResult).

group_query_keys(Endpoints) ->
    lists:usort(lists:filter(fun kz_term:is_not_empty/1, lists:map(fun kz_doc:id/1, Endpoints))).

group_query_options(Endpoints) ->
    [{'keys', group_query_keys(Endpoints)}].

group_query_results({error, _}) -> undefined;
group_query_results({ok, []}) -> undefined;
group_query_results({ok, Results}) ->
    case lists:filtermap(fun group_query_result/1, Results) of
        [] -> undefined;
        List -> kz_json:from_list([{<<"monitoring">>, lists:usort(List)}])
    end.

group_query_result_features(Result) ->
    kz_json:get_ne_binaries([<<"value">>, <<"features">>], Result, []).

group_query_result_has_sca(Result) ->
    lists:member(<<"sca">>, group_query_result_features(Result)).

group_query_result_name(Result) ->
    kz_json:get_ne_binary_value([<<"value">>, <<"name">>], Result, []).

group_query_result_alias(Result) ->
    list_to_binary(["sca.group.", group_query_result_name(Result)]).

group_query_result(Result) ->
    case group_query_result_has_sca(Result) of
        true -> {true, group_query_result_alias(Result)};
        false -> false
    end.
