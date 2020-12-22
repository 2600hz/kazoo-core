%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2020-2020, 2600Hz
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
        ,call_id/1, call_id/2
        ,node/1, node/2
        ,msg_id/1, msg_id/2
        ,event_name/1, event_name/2
        ,event_category/1, event_category/2
        ,app_version/1, app_version/2
        ,app_name/1, app_name/2
        ]).

-type payload() :: kz_json:object().
-export_type([payload/0]).

-spec patterns(payload()) -> kz_term:api_ne_binary().
patterns(JObj) ->
    patterns(JObj, 'undefined').

-spec patterns(payload(), Default) -> kz_term:ne_binaries() | Default.
patterns(JObj, Default) ->
    kz_json:get_value(<<"Patterns">>, JObj, Default).

-spec numbers(payload()) -> kz_term:api_ne_binary().
numbers(JObj) ->
    numbers(JObj, 'undefined').

-spec numbers(payload(), Default) -> kz_term:ne_binaries() | Default.
numbers(JObj, Default) ->
    kz_json:get_value(<<"Numbers">>, JObj, Default).

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

-spec call_id(payload()) -> kz_term:api_ne_binary().
call_id(JObj) ->
    call_id(JObj, 'undefined').

-spec call_id(payload(), Default) -> kz_term:ne_binary() | Default.
call_id(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Call-ID">>, JObj, Default).

-spec node(payload()) -> kz_term:api_ne_binary().
node(JObj) ->
    node(JObj, 'undefined').

-spec node(payload(), Default) -> kz_term:ne_binary() | Default.
node(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Node">>, JObj, Default).

-spec msg_id(payload()) -> kz_term:api_ne_binary().
msg_id(JObj) ->
    msg_id(JObj, 'undefined').

-spec msg_id(payload(), Default) -> kz_term:ne_binary() | Default.
msg_id(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Msg-ID">>, JObj, Default).

-spec event_name(payload()) -> kz_term:api_ne_binary().
event_name(JObj) ->
    event_name(JObj, 'undefined').

-spec event_name(payload(), Default) -> kz_term:ne_binary() | Default.
event_name(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Event-Name">>, JObj, Default).

-spec event_category(payload()) -> kz_term:api_ne_binary().
event_category(JObj) ->
    event_category(JObj, 'undefined').

-spec event_category(payload(), Default) -> kz_term:ne_binary() | Default.
event_category(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Event-Category">>, JObj, Default).

-spec app_version(payload()) -> kz_term:api_ne_binary().
app_version(JObj) ->
    app_version(JObj, 'undefined').

-spec app_version(payload(), Default) -> kz_term:ne_binary() | Default.
app_version(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"App-Version">>, JObj, Default).

-spec app_name(payload()) -> kz_term:api_ne_binary().
app_name(JObj) ->
    app_name(JObj, 'undefined').

-spec app_name(payload(), Default) -> kz_term:ne_binary() | Default.
app_name(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"App-Name">>, JObj, Default).
