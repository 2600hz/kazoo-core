%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `storage_plan' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_storage_plan).

-export([new/0]).
-export([account/1, account/2, set_account/2]).
-export([aggregate/1, aggregate/2, set_aggregate/2]).
-export([modb/1, modb/2, set_modb/2]).
-export([system/1, system/2, set_system/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"storage.plan">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec account(doc()) -> kz_term:api_object().
account(Doc) ->
    account(Doc, 'undefined').

-spec account(doc(), Default) -> kz_json:object() | Default.
account(Doc, Default) ->
    kz_json:get_json_value([<<"account">>], Doc, Default).

-spec set_account(doc(), kz_json:object()) -> doc().
set_account(Doc, Account) ->
    kz_json:set_value([<<"account">>], Account, Doc).

-spec aggregate(doc()) -> kz_term:api_object().
aggregate(Doc) ->
    aggregate(Doc, 'undefined').

-spec aggregate(doc(), Default) -> kz_json:object() | Default.
aggregate(Doc, Default) ->
    kz_json:get_json_value([<<"aggregate">>], Doc, Default).

-spec set_aggregate(doc(), kz_json:object()) -> doc().
set_aggregate(Doc, Aggregate) ->
    kz_json:set_value([<<"aggregate">>], Aggregate, Doc).

-spec modb(doc()) -> kz_term:api_object().
modb(Doc) ->
    modb(Doc, 'undefined').

-spec modb(doc(), Default) -> kz_json:object() | Default.
modb(Doc, Default) ->
    kz_json:get_json_value([<<"modb">>], Doc, Default).

-spec set_modb(doc(), kz_json:object()) -> doc().
set_modb(Doc, Modb) ->
    kz_json:set_value([<<"modb">>], Modb, Doc).

-spec system(doc()) -> kz_term:api_object().
system(Doc) ->
    system(Doc, 'undefined').

-spec system(doc(), Default) -> kz_json:object() | Default.
system(Doc, Default) ->
    kz_json:get_json_value([<<"system">>], Doc, Default).

-spec set_system(doc(), kz_json:object()) -> doc().
set_system(Doc, System) ->
    kz_json:set_value([<<"system">>], System, Doc).
