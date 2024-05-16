%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `storage_attachment_http' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_storage_attachment_http).

-export([new/0]).
-export([handler/1, handler/2, set_handler/2]).
-export([settings/1, settings/2, set_settings/2]).
-export([settings_base64_encode_data/1, settings_base64_encode_data/2, set_settings_base64_encode_data/2]).
-export([settings_send_multipart/1, settings_send_multipart/2, set_settings_send_multipart/2]).
-export([settings_url/1, settings_url/2, set_settings_url/2]).
-export([settings_verb/1, settings_verb/2, set_settings_verb/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"storage.attachment.http">>).

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

-spec settings_base64_encode_data(doc()) -> boolean().
settings_base64_encode_data(Doc) ->
    settings_base64_encode_data(Doc, 'false').

-spec settings_base64_encode_data(doc(), Default) -> boolean() | Default.
settings_base64_encode_data(Doc, Default) ->
    kz_json:get_boolean_value([<<"settings">>, <<"base64_encode_data">>], Doc, Default).

-spec set_settings_base64_encode_data(doc(), boolean()) -> doc().
set_settings_base64_encode_data(Doc, SettingsBase64EncodeData) ->
    kz_json:set_value([<<"settings">>, <<"base64_encode_data">>], SettingsBase64EncodeData, Doc).

-spec settings_send_multipart(doc()) -> kz_term:api_boolean().
settings_send_multipart(Doc) ->
    settings_send_multipart(Doc, 'undefined').

-spec settings_send_multipart(doc(), Default) -> boolean() | Default.
settings_send_multipart(Doc, Default) ->
    kz_json:get_boolean_value([<<"settings">>, <<"send_multipart">>], Doc, Default).

-spec set_settings_send_multipart(doc(), boolean()) -> doc().
set_settings_send_multipart(Doc, SettingsSendMultipart) ->
    kz_json:set_value([<<"settings">>, <<"send_multipart">>], SettingsSendMultipart, Doc).

-spec settings_url(doc()) -> kz_term:api_ne_binary().
settings_url(Doc) ->
    settings_url(Doc, 'undefined').

-spec settings_url(doc(), Default) -> kz_term:ne_binary() | Default.
settings_url(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"settings">>, <<"url">>], Doc, Default).

-spec set_settings_url(doc(), kz_term:ne_binary()) -> doc().
set_settings_url(Doc, SettingsUrl) ->
    kz_json:set_value([<<"settings">>, <<"url">>], SettingsUrl, Doc).

-spec settings_verb(doc()) -> binary().
settings_verb(Doc) ->
    settings_verb(Doc, <<"put">>).

-spec settings_verb(doc(), Default) -> binary() | Default.
settings_verb(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"verb">>], Doc, Default).

-spec set_settings_verb(doc(), binary()) -> doc().
set_settings_verb(Doc, SettingsVerb) ->
    kz_json:set_value([<<"settings">>, <<"verb">>], SettingsVerb, Doc).
