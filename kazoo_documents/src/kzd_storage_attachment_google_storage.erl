%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `storage_attachment_google_storage' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_storage_attachment_google_storage).

-export([new/0]).
-export([handler/1, handler/2, set_handler/2]).
-export([settings/1, settings/2, set_settings/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"storage.attachment.google_storage">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec handler(doc()) -> kz_term:api_binary().
handler(Doc) ->
    handler(Doc, 'undefined').

-spec handler(doc(), Default) -> binary() | Default.
handler(Doc, Default) ->
    kz_json:get_binary_value([<<"handler">>], Doc, Default).

-spec set_handler(doc(), binary()) -> doc().
set_handler(Doc, Handler) ->
    kz_json:set_value([<<"handler">>], Handler, Doc).

-spec settings(doc()) -> kz_term:api_object().
settings(Doc) ->
    settings(Doc, 'undefined').

-spec settings(doc(), Default) -> kz_json:object() | Default.
settings(Doc, Default) ->
    kz_json:get_json_value([<<"settings">>], Doc, Default).

-spec set_settings(doc(), kz_json:object()) -> doc().
set_settings(Doc, Settings) ->
    kz_json:set_value([<<"settings">>], Settings, Doc).
