%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `storage_attachment_azure' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_storage_attachment_azure).

-export([new/0]).
-export([handler/1, handler/2, set_handler/2]).
-export([settings/1, settings/2, set_settings/2]).
-export([settings_account/1, settings_account/2, set_settings_account/2]).
-export([settings_container/1, settings_container/2, set_settings_container/2]).
-export([settings_key/1, settings_key/2, set_settings_key/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"storage.attachment.azure">>).

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

-spec settings_account(doc()) -> kz_term:api_binary().
settings_account(Doc) ->
    settings_account(Doc, 'undefined').

-spec settings_account(doc(), Default) -> binary() | Default.
settings_account(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"account">>], Doc, Default).

-spec set_settings_account(doc(), binary()) -> doc().
set_settings_account(Doc, SettingsAccount) ->
    kz_json:set_value([<<"settings">>, <<"account">>], SettingsAccount, Doc).

-spec settings_container(doc()) -> kz_term:api_binary().
settings_container(Doc) ->
    settings_container(Doc, 'undefined').

-spec settings_container(doc(), Default) -> binary() | Default.
settings_container(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"container">>], Doc, Default).

-spec set_settings_container(doc(), binary()) -> doc().
set_settings_container(Doc, SettingsContainer) ->
    kz_json:set_value([<<"settings">>, <<"container">>], SettingsContainer, Doc).

-spec settings_key(doc()) -> kz_term:api_binary().
settings_key(Doc) ->
    settings_key(Doc, 'undefined').

-spec settings_key(doc(), Default) -> binary() | Default.
settings_key(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"key">>], Doc, Default).

-spec set_settings_key(doc(), binary()) -> doc().
set_settings_key(Doc, SettingsKey) ->
    kz_json:set_value([<<"settings">>, <<"key">>], SettingsKey, Doc).
