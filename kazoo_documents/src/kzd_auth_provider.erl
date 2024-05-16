%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `auth_provider' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_auth_provider).

-export([new/0]).
-export([id/1, id/2, set_id/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"auth.provider">>).

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
