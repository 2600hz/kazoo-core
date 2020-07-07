%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2016-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_scope_map_user).

-export([map/2]).

-include("kz_auth_scope.hrl").

%%------------------------------------------------------------------------------
%% @doc map auth properties to claims
%% @end
%%------------------------------------------------------------------------------
-spec map(kz_term:api_binaries(), kz_term:proplist()) -> kz_term:api_proplist().
map(Map, Props) ->
    OwnerId = props:get_value(<<"owner_id">>, Props),
    AccountId = props:get_value(<<"account_id">>, Props),
    case kz_datamgr:open_cache_doc(AccountId, OwnerId) of
        {'ok', Doc} -> map_user_to_props(Map, Doc);
        {'error', _}=_Error -> map_user_to_props(Map, 'undefined')
    end.

%%------------------------------------------------------------------------------
%% @doc map claims to user fields
%% @end
%%------------------------------------------------------------------------------
-spec map_user_to_props(kz_term:ne_binaries(), kz_doc:doc()) -> kz_term:proplist().
map_user_to_props(Map, User) ->
    Fun = fun(Key, Acc) ->
                  Claim = map_user_to_claim(Key, User),
                  [Claim | Acc]
          end,
    Claims = lists:foldl(Fun, [], Map),
    props:filter_undefined(Claims).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec map_user_to_claim( kz_term:ne_binaries() | kz_term:ne_binary(), kz_doc:doc()) -> {kz_term:ne_binary(), any()}.
map_user_to_claim([Key, Map], User) ->
    {Key, kz_json:get_value(Map, User, 'undefined')};
map_user_to_claim(Key, User) ->
    {Key, kz_json:get_value(Key, User, 'undefined')}.
