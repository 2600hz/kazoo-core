%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2024-2024, 2600Hz
%%% @doc Call Event JSON Object
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_metaflows).

-export([patterns/1, patterns/2
        ,numbers/1, numbers/2
        ,listen_on/1, listen_on/2
        ,endpoint_id/1, endpoint_id/2
        ,binding_digit/1, binding_digit/2
        ,is_empty/1
        ]).

-type payload() :: kz_json:object().
-export_type([payload/0]).

-spec patterns(payload()) -> kz_term:api_ne_binary().
patterns(JObj) ->
    patterns(JObj, 'undefined').

-spec patterns(payload(), Default) -> kz_term:ne_binaries() | Default.
patterns(JObj, Default) ->
    kz_json:get_list_value(<<"Patterns">>, JObj, Default).

-spec numbers(payload()) -> kz_term:api_ne_binary().
numbers(JObj) ->
    numbers(JObj, 'undefined').

-spec numbers(payload(), Default) -> kz_term:ne_binaries() | Default.
numbers(JObj, Default) ->
    kz_json:get_list_value(<<"Numbers">>, JObj, Default).

-spec listen_on(payload()) -> kz_term:api_ne_binary().
listen_on(JObj) ->
    listen_on(JObj, 'undefined').

-spec listen_on(payload(), Default) -> kz_term:ne_binary() | Default.
listen_on(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Listen-On">>, JObj, Default).

-spec endpoint_id(payload()) -> kz_term:api_ne_binary().
endpoint_id(JObj) ->
    endpoint_id(JObj, 'undefined').

-spec endpoint_id(payload(), Default) -> kz_term:ne_binary() | Default.
endpoint_id(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Endpoint-ID">>, JObj, Default).

-spec binding_digit(payload()) -> kz_term:api_ne_binary().
binding_digit(JObj) ->
    binding_digit(JObj, 'undefined').

-spec binding_digit(payload(), Default) -> kz_term:ne_binary() | Default.
binding_digit(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Binding-Digit">>, JObj, Default).

-spec is_empty(payload()) -> boolean().
is_empty(Doc) ->
    (numbers(Doc, []) ++ patterns(Doc, [])) =:= [].
