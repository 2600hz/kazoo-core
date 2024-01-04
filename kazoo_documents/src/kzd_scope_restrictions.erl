%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `scope_restrictions' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_scope_restrictions).

-export([new/0]).
-export([id/1, id/2, set_id/2]).
-export([scopes/1, scopes/2, set_scopes/2]).


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
