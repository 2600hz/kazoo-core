%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `conference_auth' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_conference_auth).

-export([new/0]).
-export([account_name/1, account_name/2, set_account_name/2]).
-export([conference_name/1, conference_name/2, set_conference_name/2]).
-export([conference_pin/1, conference_pin/2, set_conference_pin/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"conference_auth">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec account_name(doc()) -> kz_term:api_ne_binary().
account_name(Doc) ->
    account_name(Doc, 'undefined').

-spec account_name(doc(), Default) -> kz_term:ne_binary() | Default.
account_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"account_name">>], Doc, Default).

-spec set_account_name(doc(), kz_term:ne_binary()) -> doc().
set_account_name(Doc, AccountName) ->
    kz_json:set_value([<<"account_name">>], AccountName, Doc).

-spec conference_name(doc()) -> kz_term:api_ne_binary().
conference_name(Doc) ->
    conference_name(Doc, 'undefined').

-spec conference_name(doc(), Default) -> kz_term:ne_binary() | Default.
conference_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"conference_name">>], Doc, Default).

-spec set_conference_name(doc(), kz_term:ne_binary()) -> doc().
set_conference_name(Doc, ConferenceName) ->
    kz_json:set_value([<<"conference_name">>], ConferenceName, Doc).

-spec conference_pin(doc()) -> kz_term:api_binary().
conference_pin(Doc) ->
    conference_pin(Doc, 'undefined').

-spec conference_pin(doc(), Default) -> binary() | Default.
conference_pin(Doc, Default) ->
    kz_json:get_binary_value([<<"conference_pin">>], Doc, Default).

-spec set_conference_pin(doc(), binary()) -> doc().
set_conference_pin(Doc, ConferencePin) ->
    kz_json:set_value([<<"conference_pin">>], ConferencePin, Doc).
