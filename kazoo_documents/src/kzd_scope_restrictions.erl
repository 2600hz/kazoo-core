%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `scope_restrictions' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_scope_restrictions).

-export([new/0]).
-export([id/1, id/2, set_id/2]).
-export([scopes/1, scopes/2, set_scopes/2]).
-export([token_restriction/2, token_restriction/3, set_token_restriction/3]).
-export([token_restrictions/1, token_restrictions/2, set_token_restrictions/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"scope_restrictions">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec id(doc()) -> kz_term:api_binary().
id(Doc) ->
    id(Doc, 'undefined').

-spec id(doc(), Default) -> binary() | Default.
id(Doc, Default) ->
    kz_json:get_binary_value([<<"id">>], Doc, Default).

-spec set_id(doc(), binary()) -> doc().
set_id(Doc, Id) ->
    kz_json:set_value([<<"id">>], Id, Doc).

-spec scopes(doc()) -> kz_term:ne_binaries().
scopes(Doc) ->
    scopes(Doc, []).

-spec scopes(doc(), Default) -> kz_term:ne_binaries() | Default.
scopes(Doc, Default) ->
    kz_json:get_list_value([<<"scopes">>], Doc, Default).

-spec set_scopes(doc(), kz_term:ne_binaries()) -> doc().
set_scopes(Doc, Scopes) ->
    kz_json:set_value([<<"scopes">>], Scopes, Doc).

-spec token_restriction(doc(), kz_json:key()) -> kz_term:api_objects().
token_restriction(Doc, TokenRestriction) ->
    token_restriction(Doc, TokenRestriction, 'undefined').

-spec token_restriction(doc(), kz_json:key(), Default) -> kz_json:objects() | Default.
token_restriction(Doc, TokenRestriction, Default) ->
    kz_json:get_list_value([<<"token_restrictions">>, TokenRestriction], Doc, Default).

-spec set_token_restriction(doc(), kz_json:key(), kz_json:objects()) -> doc().
set_token_restriction(Doc, TokenRestriction, Value) ->
    kz_json:set_value([<<"token_restrictions">>, TokenRestriction], Value, Doc).

-spec token_restrictions(doc()) -> kz_term:api_object().
token_restrictions(Doc) ->
    token_restrictions(Doc, 'undefined').

-spec token_restrictions(doc(), Default) -> kz_json:object() | Default.
token_restrictions(Doc, Default) ->
    kz_json:get_json_value([<<"token_restrictions">>], Doc, Default).

-spec set_token_restrictions(doc(), kz_json:object()) -> doc().
set_token_restrictions(Doc, TokenRestrictions) ->
    kz_json:set_value([<<"token_restrictions">>], TokenRestrictions, Doc).
