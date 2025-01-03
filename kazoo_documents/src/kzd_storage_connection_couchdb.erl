%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `storage_connection_couchdb' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_storage_connection_couchdb).

-export([new/0]).
-export([driver/1, driver/2, set_driver/2]).
-export([name/1, name/2, set_name/2]).
-export([settings/1, settings/2, set_settings/2]).
-export([settings_connect_options/1, settings_connect_options/2, set_settings_connect_options/2]).
-export([settings_connect_options_keepalive/1, settings_connect_options_keepalive/2, set_settings_connect_options_keepalive/2]).
-export([settings_connect_timeout/1, settings_connect_timeout/2, set_settings_connect_timeout/2]).
-export([settings_credentials/1, settings_credentials/2, set_settings_credentials/2]).
-export([settings_credentials_password/1, settings_credentials_password/2, set_settings_credentials_password/2]).
-export([settings_credentials_username/1, settings_credentials_username/2, set_settings_credentials_username/2]).
-export([settings_ip/1, settings_ip/2, set_settings_ip/2]).
-export([settings_max_pipeline_size/1, settings_max_pipeline_size/2, set_settings_max_pipeline_size/2]).
-export([settings_max_sessions/1, settings_max_sessions/2, set_settings_max_sessions/2]).
-export([settings_pool/1, settings_pool/2, set_settings_pool/2]).
-export([settings_pool_name/1, settings_pool_name/2, set_settings_pool_name/2]).
-export([settings_pool_size/1, settings_pool_size/2, set_settings_pool_size/2]).
-export([settings_port/1, settings_port/2, set_settings_port/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"storage.connection.couchdb">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec driver(doc()) -> any().
driver(Doc) ->
    driver(Doc, 'undefined').

-spec driver(doc(), Default) -> any() | Default.
driver(Doc, Default) ->
    kz_json:get_value([<<"driver">>], Doc, Default).

-spec set_driver(doc(), any()) -> doc().
set_driver(Doc, Driver) ->
    kz_json:set_value([<<"driver">>], Driver, Doc).

-spec name(doc()) -> kz_term:api_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> binary() | Default.
name(Doc, Default) ->
    kz_json:get_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

-spec settings(doc()) -> kz_term:api_object().
settings(Doc) ->
    settings(Doc, 'undefined').

-spec settings(doc(), Default) -> kz_json:object() | Default.
settings(Doc, Default) ->
    kz_json:get_json_value([<<"settings">>], Doc, Default).

-spec set_settings(doc(), kz_json:object()) -> doc().
set_settings(Doc, Settings) ->
    kz_json:set_value([<<"settings">>], Settings, Doc).

-spec settings_connect_options(doc()) -> kz_term:api_object().
settings_connect_options(Doc) ->
    settings_connect_options(Doc, 'undefined').

-spec settings_connect_options(doc(), Default) -> kz_json:object() | Default.
settings_connect_options(Doc, Default) ->
    kz_json:get_json_value([<<"settings">>, <<"connect_options">>], Doc, Default).

-spec set_settings_connect_options(doc(), kz_json:object()) -> doc().
set_settings_connect_options(Doc, SettingsConnectOptions) ->
    kz_json:set_value([<<"settings">>, <<"connect_options">>], SettingsConnectOptions, Doc).

-spec settings_connect_options_keepalive(doc()) -> kz_term:api_boolean().
settings_connect_options_keepalive(Doc) ->
    settings_connect_options_keepalive(Doc, 'undefined').

-spec settings_connect_options_keepalive(doc(), Default) -> boolean() | Default.
settings_connect_options_keepalive(Doc, Default) ->
    kz_json:get_boolean_value([<<"settings">>, <<"connect_options">>, <<"keepalive">>], Doc, Default).

-spec set_settings_connect_options_keepalive(doc(), boolean()) -> doc().
set_settings_connect_options_keepalive(Doc, SettingsConnectOptionsKeepalive) ->
    kz_json:set_value([<<"settings">>, <<"connect_options">>, <<"keepalive">>], SettingsConnectOptionsKeepalive, Doc).

-spec settings_connect_timeout(doc()) -> kz_term:api_integer().
settings_connect_timeout(Doc) ->
    settings_connect_timeout(Doc, 'undefined').

-spec settings_connect_timeout(doc(), Default) -> integer() | Default.
settings_connect_timeout(Doc, Default) ->
    kz_json:get_integer_value([<<"settings">>, <<"connect_timeout">>], Doc, Default).

-spec set_settings_connect_timeout(doc(), integer()) -> doc().
set_settings_connect_timeout(Doc, SettingsConnectTimeout) ->
    kz_json:set_value([<<"settings">>, <<"connect_timeout">>], SettingsConnectTimeout, Doc).

-spec settings_credentials(doc()) -> kz_term:api_object().
settings_credentials(Doc) ->
    settings_credentials(Doc, 'undefined').

-spec settings_credentials(doc(), Default) -> kz_json:object() | Default.
settings_credentials(Doc, Default) ->
    kz_json:get_json_value([<<"settings">>, <<"credentials">>], Doc, Default).

-spec set_settings_credentials(doc(), kz_json:object()) -> doc().
set_settings_credentials(Doc, SettingsCredentials) ->
    kz_json:set_value([<<"settings">>, <<"credentials">>], SettingsCredentials, Doc).

-spec settings_credentials_password(doc()) -> kz_term:api_integer().
settings_credentials_password(Doc) ->
    settings_credentials_password(Doc, 'undefined').

-spec settings_credentials_password(doc(), Default) -> integer() | Default.
settings_credentials_password(Doc, Default) ->
    kz_json:get_integer_value([<<"settings">>, <<"credentials">>, <<"password">>], Doc, Default).

-spec set_settings_credentials_password(doc(), integer()) -> doc().
set_settings_credentials_password(Doc, SettingsCredentialsPassword) ->
    kz_json:set_value([<<"settings">>, <<"credentials">>, <<"password">>], SettingsCredentialsPassword, Doc).

-spec settings_credentials_username(doc()) -> kz_term:api_binary().
settings_credentials_username(Doc) ->
    settings_credentials_username(Doc, 'undefined').

-spec settings_credentials_username(doc(), Default) -> binary() | Default.
settings_credentials_username(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"credentials">>, <<"username">>], Doc, Default).

-spec set_settings_credentials_username(doc(), binary()) -> doc().
set_settings_credentials_username(Doc, SettingsCredentialsUsername) ->
    kz_json:set_value([<<"settings">>, <<"credentials">>, <<"username">>], SettingsCredentialsUsername, Doc).

-spec settings_ip(doc()) -> kz_term:api_binary().
settings_ip(Doc) ->
    settings_ip(Doc, 'undefined').

-spec settings_ip(doc(), Default) -> binary() | Default.
settings_ip(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"ip">>], Doc, Default).

-spec set_settings_ip(doc(), binary()) -> doc().
set_settings_ip(Doc, SettingsIP) ->
    kz_json:set_value([<<"settings">>, <<"ip">>], SettingsIP, Doc).

-spec settings_max_pipeline_size(doc()) -> kz_term:api_integer().
settings_max_pipeline_size(Doc) ->
    settings_max_pipeline_size(Doc, 'undefined').

-spec settings_max_pipeline_size(doc(), Default) -> integer() | Default.
settings_max_pipeline_size(Doc, Default) ->
    kz_json:get_integer_value([<<"settings">>, <<"max_pipeline_size">>], Doc, Default).

-spec set_settings_max_pipeline_size(doc(), integer()) -> doc().
set_settings_max_pipeline_size(Doc, SettingsMaxPipelineSize) ->
    kz_json:set_value([<<"settings">>, <<"max_pipeline_size">>], SettingsMaxPipelineSize, Doc).

-spec settings_max_sessions(doc()) -> kz_term:api_integer().
settings_max_sessions(Doc) ->
    settings_max_sessions(Doc, 'undefined').

-spec settings_max_sessions(doc(), Default) -> integer() | Default.
settings_max_sessions(Doc, Default) ->
    kz_json:get_integer_value([<<"settings">>, <<"max_sessions">>], Doc, Default).

-spec set_settings_max_sessions(doc(), integer()) -> doc().
set_settings_max_sessions(Doc, SettingsMaxSessions) ->
    kz_json:set_value([<<"settings">>, <<"max_sessions">>], SettingsMaxSessions, Doc).

-spec settings_pool(doc()) -> kz_term:api_object().
settings_pool(Doc) ->
    settings_pool(Doc, 'undefined').

-spec settings_pool(doc(), Default) -> kz_json:object() | Default.
settings_pool(Doc, Default) ->
    kz_json:get_json_value([<<"settings">>, <<"pool">>], Doc, Default).

-spec set_settings_pool(doc(), kz_json:object()) -> doc().
set_settings_pool(Doc, SettingsPool) ->
    kz_json:set_value([<<"settings">>, <<"pool">>], SettingsPool, Doc).

-spec settings_pool_name(doc()) -> kz_term:api_binary().
settings_pool_name(Doc) ->
    settings_pool_name(Doc, 'undefined').

-spec settings_pool_name(doc(), Default) -> binary() | Default.
settings_pool_name(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"pool">>, <<"name">>], Doc, Default).

-spec set_settings_pool_name(doc(), binary()) -> doc().
set_settings_pool_name(Doc, SettingsPoolName) ->
    kz_json:set_value([<<"settings">>, <<"pool">>, <<"name">>], SettingsPoolName, Doc).

-spec settings_pool_size(doc()) -> kz_term:api_integer().
settings_pool_size(Doc) ->
    settings_pool_size(Doc, 'undefined').

-spec settings_pool_size(doc(), Default) -> integer() | Default.
settings_pool_size(Doc, Default) ->
    kz_json:get_integer_value([<<"settings">>, <<"pool">>, <<"size">>], Doc, Default).

-spec set_settings_pool_size(doc(), integer()) -> doc().
set_settings_pool_size(Doc, SettingsPoolSize) ->
    kz_json:set_value([<<"settings">>, <<"pool">>, <<"size">>], SettingsPoolSize, Doc).

-spec settings_port(doc()) -> kz_term:api_integer().
settings_port(Doc) ->
    settings_port(Doc, 'undefined').

-spec settings_port(doc(), Default) -> integer() | Default.
settings_port(Doc, Default) ->
    kz_json:get_integer_value([<<"settings">>, <<"port">>], Doc, Default).

-spec set_settings_port(doc(), integer()) -> doc().
set_settings_port(Doc, SettingsPort) ->
    kz_json:set_value([<<"settings">>, <<"port">>], SettingsPort, Doc).
