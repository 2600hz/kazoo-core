%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
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
-export([merge/1]).

-export([endpoints_to_aliases/1, endpoint_to_aliases/1]).

-type endpoint() :: kz_json:object().
-type endpoints() :: [endpoint()].
-type presence_aliases() :: kz_json:object() | kz_term:ne_binaries().
-type api_presence_aliases() :: presence_aliases() | undefined.

-export_type([endpoint/0, endpoints/0, presence_aliases/0, api_presence_aliases/0]).

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

-spec merge(endpoints()) -> api_presence_aliases().
merge(Endpoints) ->
    case endpoints_to_aliases(Endpoints) of
        [] -> undefined;
        [One] -> One;
        Aliases -> merge_aliases(Aliases)
    end.

merge_aliases([First | Aliases]) ->
    lists:foldl(fun merge_aliases/2, First, Aliases).

merge_aliases(Aliases, Acc0) ->
    Acc = merge_aliases_value(<<"monitoring">>, Aliases, Acc0),
    merge_aliases_value(<<"publishing">>, Aliases, Acc).

merge_aliases_value(Key, Aliases, Acc) ->
    V1 = aliases_value(Key, Aliases, []),
    V2 = aliases_value(Key, Acc, []),
    kz_json:set_value(Key, lists:umerge(V1, V2), Acc).

-spec endpoints_to_aliases(endpoints()) -> api_presence_aliases().
endpoints_to_aliases(Endpoints) ->
    lists:filter(fun kz_term:is_not_empty/1, [endpoint_to_aliases(Endpoint) || Endpoint <- Endpoints]).

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
