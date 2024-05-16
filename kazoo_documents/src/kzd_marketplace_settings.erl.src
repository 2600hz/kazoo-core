%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `marketplace_settings' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_marketplace_settings).

-export([new/0]).
-export([access_code/1, access_code/2, set_access_code/2]).
-export([settings/1, settings/2, set_settings/2]).
-export([settings_api_url/1, settings_api_url/2, set_settings_api_url/2]).
-export([settings_is_aio_cluster/1, settings_is_aio_cluster/2, set_settings_is_aio_cluster/2]).
-export([settings_name/1, settings_name/2, set_settings_name/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"marketplace_settings">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec access_code(doc()) -> kz_term:api_binary().
access_code(Doc) ->
    access_code(Doc, 'undefined').

-spec access_code(doc(), Default) -> binary() | Default.
access_code(Doc, Default) ->
    kz_json:get_binary_value([<<"access_code">>], Doc, Default).

-spec set_access_code(doc(), binary()) -> doc().
set_access_code(Doc, AccessCode) ->
    kz_json:set_value([<<"access_code">>], AccessCode, Doc).

-spec settings(doc()) -> kz_term:api_object().
settings(Doc) ->
    settings(Doc, 'undefined').

-spec settings(doc(), Default) -> kz_json:object() | Default.
settings(Doc, Default) ->
    kz_json:get_json_value([<<"settings">>], Doc, Default).

-spec set_settings(doc(), kz_json:object()) -> doc().
set_settings(Doc, Settings) ->
    kz_json:set_value([<<"settings">>], Settings, Doc).

-spec settings_api_url(doc()) -> kz_term:api_binary().
settings_api_url(Doc) ->
    settings_api_url(Doc, 'undefined').

-spec settings_api_url(doc(), Default) -> binary() | Default.
settings_api_url(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"api_url">>], Doc, Default).

-spec set_settings_api_url(doc(), binary()) -> doc().
set_settings_api_url(Doc, SettingsAPIUrl) ->
    kz_json:set_value([<<"settings">>, <<"api_url">>], SettingsAPIUrl, Doc).

-spec settings_is_aio_cluster(doc()) -> kz_term:api_boolean().
settings_is_aio_cluster(Doc) ->
    settings_is_aio_cluster(Doc, 'undefined').

-spec settings_is_aio_cluster(doc(), Default) -> boolean() | Default.
settings_is_aio_cluster(Doc, Default) ->
    kz_json:get_boolean_value([<<"settings">>, <<"is_aio_cluster">>], Doc, Default).

-spec set_settings_is_aio_cluster(doc(), boolean()) -> doc().
set_settings_is_aio_cluster(Doc, SettingsIsAioCluster) ->
    kz_json:set_value([<<"settings">>, <<"is_aio_cluster">>], SettingsIsAioCluster, Doc).

-spec settings_name(doc()) -> kz_term:api_binary().
settings_name(Doc) ->
    settings_name(Doc, 'undefined').

-spec settings_name(doc(), Default) -> binary() | Default.
settings_name(Doc, Default) ->
    kz_json:get_binary_value([<<"settings">>, <<"name">>], Doc, Default).

-spec set_settings_name(doc(), binary()) -> doc().
set_settings_name(Doc, SettingsName) ->
    kz_json:set_value([<<"settings">>, <<"name">>], SettingsName, Doc).
