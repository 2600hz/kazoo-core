%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc call detail record amqp definitions.
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_interaction).

-export([id/1
        ,key/1
        ,timestamp/1
        ,is_root/1
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-spec id(kz_json:object()) -> kz_term:api_ne_binary().
id(JObj) ->
    kz_json:get_ne_binary_value([<<?CALL_INTERACTION>>, <<"Id">>], JObj).

-spec key(kz_json:object()) -> kz_term:api_ne_binary().
key(JObj) ->
    kz_json:get_ne_binary_value([<<?CALL_INTERACTION>>, <<"Key">>], JObj).

-spec timestamp(kz_json:object()) -> kz_time:gregorian_seconds().
timestamp(JObj) ->
    kz_json:get_integer_value([<<?CALL_INTERACTION>>, <<"Timestamp">>], JObj).

-spec is_root(kz_json:object()) -> boolean().
is_root(JObj) ->
    kz_json:get_boolean_value([<<?CALL_INTERACTION>>, <<"Is-Root">>], JObj).
