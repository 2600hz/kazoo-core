%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `storage_attachment_aws' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_storage_attachment_aws).

-export([new/0]).
-export([handler/1, handler/2, set_handler/2]).
-export([settings/1, settings/2, set_settings/2]).
-export([settings_bucket/1, settings_bucket/2, set_settings_bucket/2]).
-export([settings_bucket_access_method/1, settings_bucket_access_method/2, set_settings_bucket_access_method/2]).
-export([settings_bucket_after_host/1, settings_bucket_after_host/2, set_settings_bucket_after_host/2]).
-export([settings_host/1, settings_host/2, set_settings_host/2]).
-export([settings_key/1, settings_key/2, set_settings_key/2]).
-export([settings_port/1, settings_port/2, set_settings_port/2]).
-export([settings_region/1, settings_region/2, set_settings_region/2]).
-export([settings_scheme/1, settings_scheme/2, set_settings_scheme/2]).
-export([settings_secret/1, settings_secret/2, set_settings_secret/2]).
-export([settings_tags_key_path/1, settings_tags_key_path/2, set_settings_tags_key_path/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"storage.attachment.aws">>).

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

-spec settings_bucket(doc()) -> kz_term:api_ne_binary().
settings_bucket(Doc) ->
    settings_bucket(Doc, 'undefined').

-spec settings_bucket(doc(), Default) -> kz_term:ne_binary() | Default.
settings_bucket(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"settings">>, <<"bucket">>], Doc, Default).

-spec set_settings_bucket(doc(), kz_term:ne_binary()) -> doc().
set_settings_bucket(Doc, SettingsBucket) ->
    kz_json:set_value([<<"settings">>, <<"bucket">>], SettingsBucket, Doc).

-spec settings_bucket_access_method(doc()) -> kz_term:api_binary().
settings_bucket_access_method(Doc) ->
    settings_bucket_access_method(Doc, 'undefined').

-spec settings_bucket_access_method(doc(), Default) -> binary() | Default.
settings_bucket_access_method(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"bucket_access_method">>], Doc, Default).

-spec set_settings_bucket_access_method(doc(), binary()) -> doc().
set_settings_bucket_access_method(Doc, SettingsBucketAccessMethod) ->
    kz_json:set_value([<<"settings">>, <<"bucket_access_method">>], SettingsBucketAccessMethod, Doc).

-spec settings_bucket_after_host(doc()) -> kz_term:api_boolean().
settings_bucket_after_host(Doc) ->
    settings_bucket_after_host(Doc, 'undefined').

-spec settings_bucket_after_host(doc(), Default) -> boolean() | Default.
settings_bucket_after_host(Doc, Default) ->
    kz_json:get_boolean_value([<<"settings">>, <<"bucket_after_host">>], Doc, Default).

-spec set_settings_bucket_after_host(doc(), boolean()) -> doc().
set_settings_bucket_after_host(Doc, SettingsBucketAfterHost) ->
    kz_json:set_value([<<"settings">>, <<"bucket_after_host">>], SettingsBucketAfterHost, Doc).

-spec settings_host(doc()) -> kz_term:api_ne_binary().
settings_host(Doc) ->
    settings_host(Doc, 'undefined').

-spec settings_host(doc(), Default) -> kz_term:ne_binary() | Default.
settings_host(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"settings">>, <<"host">>], Doc, Default).

-spec set_settings_host(doc(), kz_term:ne_binary()) -> doc().
set_settings_host(Doc, SettingsHost) ->
    kz_json:set_value([<<"settings">>, <<"host">>], SettingsHost, Doc).

-spec settings_key(doc()) -> kz_term:api_ne_binary().
settings_key(Doc) ->
    settings_key(Doc, 'undefined').

-spec settings_key(doc(), Default) -> kz_term:ne_binary() | Default.
settings_key(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"settings">>, <<"key">>], Doc, Default).

-spec set_settings_key(doc(), kz_term:ne_binary()) -> doc().
set_settings_key(Doc, SettingsKey) ->
    kz_json:set_value([<<"settings">>, <<"key">>], SettingsKey, Doc).

-spec settings_port(doc()) -> kz_term:api_integer().
settings_port(Doc) ->
    settings_port(Doc, 'undefined').

-spec settings_port(doc(), Default) -> integer() | Default.
settings_port(Doc, Default) ->
    kz_json:get_integer_value([<<"settings">>, <<"port">>], Doc, Default).

-spec set_settings_port(doc(), integer()) -> doc().
set_settings_port(Doc, SettingsPort) ->
    kz_json:set_value([<<"settings">>, <<"port">>], SettingsPort, Doc).

-spec settings_region(doc()) -> kz_term:api_ne_binary().
settings_region(Doc) ->
    settings_region(Doc, 'undefined').

-spec settings_region(doc(), Default) -> kz_term:ne_binary() | Default.
settings_region(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"settings">>, <<"region">>], Doc, Default).

-spec set_settings_region(doc(), kz_term:ne_binary()) -> doc().
set_settings_region(Doc, SettingsRegion) ->
    kz_json:set_value([<<"settings">>, <<"region">>], SettingsRegion, Doc).

-spec settings_scheme(doc()) -> kz_term:api_binary().
settings_scheme(Doc) ->
    settings_scheme(Doc, 'undefined').

-spec settings_scheme(doc(), Default) -> binary() | Default.
settings_scheme(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"scheme">>], Doc, Default).

-spec set_settings_scheme(doc(), binary()) -> doc().
set_settings_scheme(Doc, SettingsScheme) ->
    kz_json:set_value([<<"settings">>, <<"scheme">>], SettingsScheme, Doc).

-spec settings_secret(doc()) -> kz_term:api_ne_binary().
settings_secret(Doc) ->
    settings_secret(Doc, 'undefined').

-spec settings_secret(doc(), Default) -> kz_term:ne_binary() | Default.
settings_secret(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"settings">>, <<"secret">>], Doc, Default).

-spec set_settings_secret(doc(), kz_term:ne_binary()) -> doc().
set_settings_secret(Doc, SettingsSecret) ->
    kz_json:set_value([<<"settings">>, <<"secret">>], SettingsSecret, Doc).

-spec settings_tags_key_path(doc()) -> kz_term:api_ne_binaries().
settings_tags_key_path(Doc) ->
    settings_tags_key_path(Doc, 'undefined').

-spec settings_tags_key_path(doc(), Default) -> kz_term:ne_binaries() | Default.
settings_tags_key_path(Doc, Default) ->
    kz_json:get_list_value([<<"settings">>, <<"tags_key_path">>], Doc, Default).

-spec set_settings_tags_key_path(doc(), kz_term:ne_binaries()) -> doc().
set_settings_tags_key_path(Doc, SettingsTagsKeyPath) ->
    kz_json:set_value([<<"settings">>, <<"tags_key_path">>], SettingsTagsKeyPath, Doc).
