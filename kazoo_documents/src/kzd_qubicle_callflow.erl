%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_qubicle_callflow).

-export([new/0]).
-export([module_user/1, module_user/2, set_module_user/2]).
-export([user_id/1, user_id/2, set_user_id/2]).
-export([flow_timeout/1, flow_timeout/2, set_flow_timeout/2]).
-export([can_call_self/1, can_call_self/2, set_can_call_self/2]).
-export([flow_delay/1, flow_delay/2, set_flow_delay/2]).
-export([flow_strategy/1, flow_strategy/2, set_flow_strategy/2]).
-export([flow_numbers/1, flow_numbers/2, set_flow_numbers/2]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-type docs() :: [doc()].
-export_type([doc/0
    ,docs/0
]).

-define(KEY_NUMBERS, [<<"numbers">>]).
-define(KEY_PATTERNS, [<<"patterns">>]).

-define(SCHEMA, <<"callflows">>).

-define(PVT_TYPE, <<"callflow">>).


-spec new() -> doc().
new() ->
    kz_doc:update_pvt_parameters(kz_json_schema:default_object(?SCHEMA)
        ,'undefined'
        ,[{'type', type()}
            ,{'now', kz_time:now_s()}
        ]
    ).

-spec type() -> kz_term:ne_binary().
type() -> ?PVT_TYPE.

-spec module_user(doc()) -> kz_term:api_object().
module_user(Doc) ->
    module_user(Doc, 'undefined').

-spec module_user(doc(), Default) -> kz_json:object() | Default.
module_user(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"module">>], Doc, Default).

-spec set_module_user(doc(), kz_json:object()) -> doc().
set_module_user(Doc, Enabled) ->
    kz_json:set_value([<<"flow">>, <<"module">>], Enabled, Doc).

-spec user_id(doc()) -> kz_term:api_object().
user_id(Doc) ->
    user_id(Doc, 'undefined').

-spec user_id(doc(), Default) -> kz_json:object() | Default.
user_id(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"data">>, <<"id">>], Doc, Default).

-spec set_user_id(doc(), kz_json:object()) -> doc().
set_user_id(Doc, Enabled) ->
    kz_json:set_value([<<"flow">>, <<"data">>, <<"id">>], Enabled, Doc).

-spec flow_timeout(doc()) -> kz_term:api_object().
flow_timeout(Doc) ->
    flow_timeout(Doc, 'undefined').

-spec flow_timeout(doc(), Default) -> kz_json:object() | Default.
flow_timeout(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"data">>, <<"timeout">>], Doc, Default).

-spec set_flow_timeout(doc(), kz_json:object()) -> doc().
set_flow_timeout(Doc, Enabled) ->
    kz_json:set_value([<<"flow">>, <<"data">>, <<"timeout">>], Enabled, Doc).

-spec can_call_self(doc()) -> kz_term:api_object().
can_call_self(Doc) ->
    can_call_self(Doc, 'undefined').

-spec can_call_self(doc(), Default) -> kz_json:object() | Default.
can_call_self(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"data">>, <<"can_call_self">>], Doc, Default).

-spec set_can_call_self(doc(), kz_json:object()) -> doc().
set_can_call_self(Doc, Enabled) ->
    kz_json:set_value([<<"flow">>, <<"data">>, <<"can_call_self">>], Enabled, Doc).

-spec flow_delay(doc()) -> kz_term:api_object().
flow_delay(Doc) ->
    flow_delay(Doc, 'undefined').

-spec flow_delay(doc(), Default) -> kz_json:object() | Default.
flow_delay(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"data">>, <<"delay">>], Doc, Default).

-spec set_flow_delay(doc(), kz_json:object()) -> doc().
set_flow_delay(Doc, Enabled) ->
    kz_json:set_value([<<"flow">>, <<"data">>, <<"delay">>], Enabled, Doc).

-spec flow_strategy(doc()) -> kz_term:api_object().
flow_strategy(Doc) ->
    flow_strategy(Doc, 'undefined').

-spec flow_strategy(doc(), Default) -> kz_json:object() | Default.
flow_strategy(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"data">>, <<"strategy">>], Doc, Default).

-spec set_flow_strategy(doc(), kz_json:object()) -> doc().
set_flow_strategy(Doc, Enabled) ->
    kz_json:set_value([<<"flow">>, <<"data">>, <<"strategy">>], Enabled, Doc).

-spec flow_numbers(doc()) -> kz_term:api_ne_binary().
flow_numbers(Doc) ->
    flow_numbers(Doc, 'undefined').

-spec flow_numbers(doc(), Default) -> kz_term:ne_binary() | Default.
flow_numbers(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"numbers">>], Doc, Default).

-spec set_flow_numbers(doc(), kz_term:ne_binary()) -> doc().
set_flow_numbers(Doc, LastName) ->
    kz_json:set_value([<<"numbers">>], LastName, Doc).