%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `users_delete' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_users_delete).

-export([new/0]).
-export([object_types/1, object_types/2, set_object_types/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"users_delete">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec object_types(doc()) -> kz_term:api_ne_binary_or_binaries().
object_types(Doc) ->
    object_types(Doc, 'undefined').

-spec object_types(doc(), Default) -> kz_term:ne_binary_or_binaries() | Default.
object_types(Doc, Default) ->
    kz_json:get_ne_binary_or_binaries([<<"object_types">>], Doc, Default).

-spec set_object_types(doc(), kz_term:ne_binary_or_binaries()) -> doc().
set_object_types(Doc, ObjectTypes) ->
    kz_json:set_value([<<"object_types">>], ObjectTypes, Doc).
