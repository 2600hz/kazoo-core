%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `auth_app' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_auth_app).

-export([new/0]).
-export([client_id/1, client_id/2, set_client_id/2]).
-export([email/1, email/2, set_email/2]).
-export([provider/1, provider/2, set_provider/2]).
-export([secret/1, secret/2, set_secret/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"auth.app">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec client_id(doc()) -> kz_term:api_binary().
client_id(Doc) ->
    client_id(Doc, 'undefined').

-spec client_id(doc(), Default) -> binary() | Default.
client_id(Doc, Default) ->
    kz_json:get_binary_value([<<"client_id">>], Doc, Default).

-spec set_client_id(doc(), binary()) -> doc().
set_client_id(Doc, ClientId) ->
    kz_json:set_value([<<"client_id">>], ClientId, Doc).

-spec email(doc()) -> kz_term:api_binary().
email(Doc) ->
    email(Doc, 'undefined').

-spec email(doc(), Default) -> binary() | Default.
email(Doc, Default) ->
    kz_json:get_binary_value([<<"email">>], Doc, Default).

-spec set_email(doc(), binary()) -> doc().
set_email(Doc, Email) ->
    kz_json:set_value([<<"email">>], Email, Doc).

-spec provider(doc()) -> kz_term:api_binary().
provider(Doc) ->
    provider(Doc, 'undefined').

-spec provider(doc(), Default) -> binary() | Default.
provider(Doc, Default) ->
    kz_json:get_binary_value([<<"provider">>], Doc, Default).

-spec set_provider(doc(), binary()) -> doc().
set_provider(Doc, Provider) ->
    kz_json:set_value([<<"provider">>], Provider, Doc).

-spec secret(doc()) -> kz_term:api_binary().
secret(Doc) ->
    secret(Doc, 'undefined').

-spec secret(doc(), Default) -> binary() | Default.
secret(Doc, Default) ->
    kz_json:get_binary_value([<<"secret">>], Doc, Default).

-spec set_secret(doc(), binary()) -> doc().
set_secret(Doc, Secret) ->
    kz_json:set_value([<<"secret">>], Secret, Doc).
