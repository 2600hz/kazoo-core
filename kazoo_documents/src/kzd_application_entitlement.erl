%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `application_entitlement' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_application_entitlement).

-export([new/0]).
-export([app_id/1, app_id/2, set_app_id/2]).
-export([app_type/1, app_type/2, set_app_type/2]).
-export([type/1, type/2, set_type/2]).
-export([users/1, users/2, set_users/2]).

-export([schema/0, pvt_type/0, db_id/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"application_entitlement">>).
-define(DB_SUFFIX, "_entitlement").

-spec schema() -> kz_term:ne_binary().
schema() -> ?SCHEMA.

-spec pvt_type() -> kz_term:ne_binary().
pvt_type() -> ?SCHEMA.

-spec db_id(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binary().
db_id(AppType, AppId) ->
    <<AppId/binary, "_", AppType/binary, ?DB_SUFFIX>>.

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec app_id(doc()) -> kz_term:api_ne_binary().
app_id(Doc) ->
    app_id(Doc, 'undefined').

-spec app_id(doc(), Default) -> kz_term:ne_binary() | Default.
app_id(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"app_id">>], Doc, Default).

-spec set_app_id(doc(), kz_term:ne_binary()) -> doc().
set_app_id(Doc, AppId) ->
    kz_json:set_value([<<"app_id">>], AppId, Doc).

-spec app_type(doc()) -> kz_term:api_ne_binary().
app_type(Doc) ->
    app_type(Doc, 'undefined').

-spec app_type(doc(), Default) -> kz_term:ne_binary() | Default.
app_type(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"app_type">>], Doc, Default).

-spec set_app_type(doc(), kz_term:ne_binary()) -> doc().
set_app_type(Doc, AppType) ->
    kz_json:set_value([<<"app_type">>], AppType, Doc).

-spec type(doc()) -> kz_term:api_ne_binary().
type(Doc) ->
    type(Doc, 'undefined').

-spec type(doc(), Default) -> kz_term:ne_binary() | Default.
type(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"type">>], Doc, Default).

-spec set_type(doc(), kz_term:ne_binary()) -> doc().
set_type(Doc, Type) ->
    kz_json:set_value([<<"type">>], Type, Doc).

-spec users(doc()) -> kz_term:api_ne_binaries().
users(Doc) ->
    users(Doc, 'undefined').

-spec users(doc(), Default) -> kz_term:ne_binaries() | Default.
users(Doc, Default) ->
    kz_json:get_ne_binaries([<<"users">>], Doc, Default).

-spec set_users(doc(), kz_term:ne_binary()) -> doc().
set_users(Doc, Users) ->
    kz_json:set_value([<<"users">>], Users, Doc).
