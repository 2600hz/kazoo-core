%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc Accessors for `scopes' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_scopes).

-export([new/0]).
-export([claims/1, claims/2, set_claims/2]).
-export([module/1, module/2, set_module/2]).
-export([privileges/1, privileges/2, set_privileges/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"scopes">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec claims(doc()) -> list().
claims(Doc) ->
    claims(Doc, []).

-spec claims(doc(), Default) -> list() | Default.
claims(Doc, Default) ->
    kz_json:get_list_value([<<"claims">>], Doc, Default).

-spec set_claims(doc(), list()) -> doc().
set_claims(Doc, Claims) ->
    kz_json:set_value([<<"claims">>], Claims, Doc).

-spec module(doc()) -> kz_term:api_binary().
module(Doc) ->
    module(Doc, 'undefined').

-spec module(doc(), Default) -> binary() | Default.
module(Doc, Default) ->
    kz_json:get_binary_value([<<"module">>], Doc, Default).

-spec set_module(doc(), binary()) -> doc().
set_module(Doc, Module) ->
    kz_json:set_value([<<"module">>], Module, Doc).

-spec privileges(doc()) -> list().
privileges(Doc) ->
    privileges(Doc, []).

-spec privileges(doc(), Default) -> list() | Default.
privileges(Doc, Default) ->
    kz_json:get_list_value([<<"privileges">>], Doc, Default).

-spec set_privileges(doc(), list()) -> doc().
set_privileges(Doc, Privileges) ->
    kz_json:set_value([<<"privileges">>], Privileges, Doc).
