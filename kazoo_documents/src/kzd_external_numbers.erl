%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_external_numbers).

-export([new/0
        ,type/0
        ]).

%% Private field accessors
-export([pvt_verified/1, pvt_verified/2, set_pvt_verified/2, pvt_verified_path/0]).
-export([pvt_code/1, pvt_code/2, set_pvt_code/2, pvt_code_path/0]).
-export([pvt_adopted/1, pvt_adopted/2, set_pvt_adopted/2, pvt_adopted_path/0]).

%% Public field accessors
-export([number/1, number/2, set_number/2, number_path/0]).
-export([attestation/1, attestation/2, set_attestation/2, attestation_path/0]).
-export([attestation_date/1, attestation_date/2, set_attestation_date/2, attestation_date_path/0]).
-export([attestation_token_method/1, attestation_token_method/2, set_attestation_token_method/2, attestation_token_method_path/0]).
-export([attestation_token_source/1, attestation_token_source/2, set_attestation_token_source/2, attestation_token_source_path/0]).
-export([attestation_account_id/1, attestation_account_id/2, set_attestation_account_id/2, attestation_account_id_path/0]).
-export([attestation_account_name/1, attestation_account_name/2, set_attestation_account_name/2, attestation_account_name_path/0]).
-export([attestation_user_id/1, attestation_user_id/2, set_attestation_user_id/2, attestation_user_id_path/0]).
-export([attestation_user_name/1, attestation_user_name/2, set_attestation_user_name/2, attestation_user_name_path/0]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"external_numbers">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec type() -> kz_term:ne_binary().
type() -> <<"external_number">>.


%%%=============================================================================
%%% Private field accessor functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_verified(doc()) -> boolean().
pvt_verified(Doc) ->
    pvt_verified(Doc, 'false').

-spec pvt_verified(doc(), Default) -> boolean() | Default.
pvt_verified(Doc, Default) ->
    kz_json:is_true(pvt_verified_path(), Doc, Default).

-spec set_pvt_verified(doc(), boolean()) -> doc().
set_pvt_verified(Doc, Value) ->
    kz_json:set_value(pvt_verified_path(), Value, Doc).

-spec pvt_verified_path() -> kz_json:path().
pvt_verified_path() -> [<<"pvt_verified">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_code(doc()) -> kz_term:api_ne_binary().
pvt_code(Doc) ->
    pvt_code(Doc, 'undefined').

-spec pvt_code(doc(), Default) -> kz_term:ne_binary() | Default.
pvt_code(Doc, Default) ->
    kz_json:get_ne_binary_value(pvt_code_path(), Doc, Default).

-spec set_pvt_code(doc(), kz_term:api_ne_binary()) -> doc().
set_pvt_code(Doc, Value) ->
    kz_json:set_value(pvt_code_path(), Value, Doc).

-spec pvt_code_path() -> kz_json:path().
pvt_code_path() -> [<<"pvt_code">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_adopted(doc()) -> boolean().
pvt_adopted(Doc) ->
    pvt_adopted(Doc, 'false').

-spec pvt_adopted(doc(), Default) -> boolean() | Default.
pvt_adopted(Doc, Default) ->
    kz_json:is_true(pvt_adopted_path(), Doc, Default).

-spec set_pvt_adopted(doc(), boolean()) -> doc().
set_pvt_adopted(Doc, Value) ->
    kz_json:set_value(pvt_adopted_path(), Value, Doc).

-spec pvt_adopted_path() -> kz_json:path().
pvt_adopted_path() -> [<<"pvt_adopted">>].

%%%=============================================================================
%%% Public field accessor
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec number(doc()) -> kz_term:api_ne_binary().
number(Doc) ->
    number(Doc, 'undefined').

-spec number(doc(), Default) -> kz_term:ne_binary() | Default.
number(Doc, Default) ->
    kz_json:get_ne_binary_value(number_path(), Doc, Default).

-spec set_number(doc(), kz_term:ne_binary()) -> doc().
set_number(Doc, Number) ->
    kz_json:set_value(number_path(), Number, Doc).

-spec number_path() -> kz_json:path().
number_path() ->
    [<<"number">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation(doc()) -> kz_term:api_object().
attestation(Doc) ->
    attestation(Doc, 'undefined').

-spec attestation(doc(), Default) -> kz_json:object() | Default.
attestation(Doc, Default) ->
    kz_json:get_json_value(attestation_path(), Doc, Default).

-spec set_attestation(doc(), kz_json:object()) -> doc().
set_attestation(Doc, Attestation) ->
    kz_json:set_value(attestation_path(), Attestation, Doc).

-spec attestation_path() -> kz_json:path().
attestation_path() ->
    [<<"attestation">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation_date(doc()) -> kz_term:api_object().
attestation_date(Doc) ->
    attestation_date(Doc, 'undefined').

-spec attestation_date(doc(), Default) -> kz_term:ne_binary() | Default.
attestation_date(Doc, Default) ->
    kz_json:get_ne_binary_value(attestation_date_path(), Doc, Default).

-spec set_attestation_date(doc(), kz_term:ne_binary()) -> doc().
set_attestation_date(Doc, Date) ->
    kz_json:set_value(attestation_date_path(), Date, Doc).

-spec attestation_date_path() -> kz_json:path().
attestation_date_path() ->
    [<<"attestation">>, <<"date">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation_token_method(doc()) -> kz_term:api_object().
attestation_token_method(Doc) ->
    attestation_token_method(Doc, 'undefined').

-spec attestation_token_method(doc(), Default) -> kz_term:ne_binary() | Default.
attestation_token_method(Doc, Default) ->
    kz_json:get_ne_binary_value(attestation_token_method_path(), Doc, Default).

-spec set_attestation_token_method(doc(), kz_term:ne_binary()) -> doc().
set_attestation_token_method(Doc, TokenMethod) ->
    kz_json:set_value(attestation_token_method_path(), TokenMethod, Doc).

-spec attestation_token_method_path() -> kz_json:path().
attestation_token_method_path() ->
    [<<"attestation">>, <<"token">>, <<"method">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation_token_source(doc()) -> kz_term:api_object().
attestation_token_source(Doc) ->
    attestation_token_source(Doc, 'undefined').

-spec attestation_token_source(doc(), Default) -> kz_term:ne_binary() | Default.
attestation_token_source(Doc, Default) ->
    kz_json:get_ne_binary_value(attestation_token_source_path(), Doc, Default).

-spec set_attestation_token_source(doc(), kz_term:ne_binary()) -> doc().
set_attestation_token_source(Doc, TokenSource) ->
    kz_json:set_value(attestation_token_source_path(), TokenSource, Doc).

-spec attestation_token_source_path() -> kz_json:path().
attestation_token_source_path() ->
    [<<"attestation">>, <<"token">>, <<"source">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation_account_id(doc()) -> kz_term:api_object().
attestation_account_id(Doc) ->
    attestation_account_id(Doc, 'undefined').

-spec attestation_account_id(doc(), Default) -> kz_term:ne_binary() | Default.
attestation_account_id(Doc, Default) ->
    kz_json:get_ne_binary_value(attestation_account_id_path(), Doc, Default).

-spec set_attestation_account_id(doc(), kz_term:ne_binary()) -> doc().
set_attestation_account_id(Doc, AccountId) ->
    kz_json:set_value(attestation_account_id_path(), AccountId, Doc).

-spec attestation_account_id_path() -> kz_json:path().
attestation_account_id_path() ->
    [<<"attestation">>, <<"account">>, <<"id">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation_account_name(doc()) -> kz_term:api_object().
attestation_account_name(Doc) ->
    attestation_account_name(Doc, 'undefined').

-spec attestation_account_name(doc(), Default) -> kz_term:ne_binary() | Default.
attestation_account_name(Doc, Default) ->
    kz_json:get_ne_binary_value(attestation_account_name_path(), Doc, Default).

-spec set_attestation_account_name(doc(), kz_term:ne_binary()) -> doc().
set_attestation_account_name(Doc, AccountName) ->
    kz_json:set_value(attestation_account_name_path(), AccountName, Doc).

-spec attestation_account_name_path() -> kz_json:path().
attestation_account_name_path() ->
    [<<"attestation">>, <<"account">>, <<"name">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation_user_id(doc()) -> kz_term:api_object().
attestation_user_id(Doc) ->
    attestation_user_id(Doc, 'undefined').

-spec attestation_user_id(doc(), Default) -> kz_term:ne_binary() | Default.
attestation_user_id(Doc, Default) ->
    kz_json:get_ne_binary_value(attestation_user_id_path(), Doc, Default).

-spec set_attestation_user_id(doc(), kz_term:ne_binary()) -> doc().
set_attestation_user_id(Doc, UserId) ->
    kz_json:set_value(attestation_user_id_path(), UserId, Doc).

-spec attestation_user_id_path() -> kz_json:path().
attestation_user_id_path() ->
    [<<"attestation">>, <<"user">>, <<"id">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec attestation_user_name(doc()) -> kz_term:api_object().
attestation_user_name(Doc) ->
    attestation_user_name(Doc, 'undefined').

-spec attestation_user_name(doc(), Default) -> kz_term:ne_binary() | Default.
attestation_user_name(Doc, Default) ->
    kz_json:get_ne_binary_value(attestation_user_name_path(), Doc, Default).

-spec set_attestation_user_name(doc(), kz_term:ne_binary()) -> doc().
set_attestation_user_name(Doc, UserName) ->
    kz_json:set_value(attestation_user_name_path(), UserName, Doc).

-spec attestation_user_name_path() -> kz_json:path().
attestation_user_name_path() ->
    [<<"attestation">>, <<"user">>, <<"name">>].
