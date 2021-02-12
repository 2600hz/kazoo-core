%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_qubicle_user).

-export([new/0]).
-export([first_name/1, first_name/2, set_first_name/2]).
-export([last_name/1, last_name/2, set_last_name/2]).
-export([presence_id/1, presence_id/2, set_presence_id/2]).
-export([email/1, email/2, set_email/2]).
-export([username/1, username/2, set_username/2]).
-export([qubicle_enabled/1, qubicle_enabled/2, set_qubicle_enabled/2]).
-export([recipient_offering/1, recipient_offering/2, set_recipient_offering/2]).
-export([track_registrations/1, track_registrations/2, set_track_registrations/2]).
-export([disable_sync/1, disable_sync/2, set_disable_sync/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-type docs() :: [doc()].
-export_type([doc/0, docs/0]).

-define(SCHEMA, <<"users">>).

-spec new() -> doc().
new() ->
    kz_doc:set_type(kz_json_schema:default_object(?SCHEMA), type()).

-spec first_name(doc()) -> kz_term:api_ne_binary().
first_name(Doc) ->
    first_name(Doc, 'undefined').

-spec first_name(doc(), Default) -> kz_term:ne_binary() | Default.
first_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"first_name">>], Doc, Default).

-spec set_first_name(doc(), kz_term:ne_binary()) -> doc().
set_first_name(Doc, FirstName) ->
    kz_json:set_value([<<"first_name">>], FirstName, Doc).

-spec last_name(doc()) -> kz_term:api_ne_binary().
last_name(Doc) ->
    last_name(Doc, 'undefined').

-spec last_name(doc(), Default) -> kz_term:ne_binary() | Default.
last_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"last_name">>], Doc, Default).

-spec set_last_name(doc(), kz_term:ne_binary()) -> doc().
set_last_name(Doc, LastName) ->
    kz_json:set_value([<<"last_name">>], LastName, Doc).

-spec presence_id(doc()) -> kz_term:api_binary().
presence_id(Doc) ->
    presence_id(Doc, 'undefined').

-spec presence_id(doc(), Default) -> binary() | Default.
presence_id(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"presence_id">>], Doc, Default).

-spec set_presence_id(doc(), binary()) -> doc().
set_presence_id(Doc, PresenceId) ->
    kz_json:set_value([<<"presence_id">>], PresenceId, Doc).

-spec email(doc()) -> kz_term:api_ne_binary().
email(Doc) ->
    email(Doc, 'undefined').

-spec email(doc(), Default) -> kz_term:ne_binary() | Default.
email(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"email">>], Doc, Default).

-spec set_email(doc(), kz_term:ne_binary()) -> doc().
set_email(Doc, Email) ->
    kz_json:set_value([<<"email">>], Email, Doc).

-spec type() -> kz_term:ne_binary().
type() -> <<"user">>.

-spec username(doc()) -> kz_term:api_ne_binary().
username(Doc) ->
    username(Doc, 'undefined').

-spec username(doc(), Default) -> kz_term:ne_binary() | Default.
username(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"username">>], Doc, Default).

-spec set_username(doc(), kz_term:ne_binary()) -> doc().
set_username(Doc, Username) ->
    kz_json:set_value([<<"username">>], Username, Doc).

-spec qubicle_enabled(doc()) -> kz_term:api_object().
qubicle_enabled(Doc) ->
    qubicle_enabled(Doc, 'undefined').

-spec qubicle_enabled(doc(), Default) -> kz_json:object() | Default.
qubicle_enabled(Doc, Default) ->
    kz_json:get_json_value([<<"qubicle">>, <<"enabled">>], Doc, Default).

-spec set_qubicle_enabled(doc(), kz_json:object()) -> doc().
set_qubicle_enabled(Doc, Enabled) ->
    kz_json:set_value([<<"qubicle">>, <<"enabled">>], Enabled, Doc).

-spec recipient_offering(doc()) -> kz_term:api_object().
recipient_offering(Doc) ->
    recipient_offering(Doc, 'undefined').

-spec recipient_offering(doc(), Default) -> kz_json:object() | Default.
recipient_offering(Doc, Default) ->
    kz_json:get_json_value([<<"qubicle">>, <<"recipient">>, <<"offering">>], Doc, Default).

-spec set_recipient_offering(doc(), kz_json:object()) -> doc().
set_recipient_offering(Doc, Enabled) ->
    kz_json:set_value([<<"qubicle">>, <<"recipient">>, <<"offering">>], Enabled, Doc).

-spec track_registrations(doc()) -> kz_term:api_object().
track_registrations(Doc) ->
    track_registrations(Doc, 'undefined').

-spec track_registrations(doc(), Default) -> kz_json:object() | Default.
track_registrations(Doc, Default) ->
    kz_json:track_registrations([<<"qubicle">>, <<"recipient">>, <<"track_registrations">>], Doc, Default).

-spec set_track_registrations(doc(), kz_json:object()) -> doc().
set_track_registrations(Doc, Enabled) ->
    kz_json:set_value([<<"qubicle">>, <<"recipient">>, <<"track_registrations">>], Enabled, Doc).

-spec disable_sync(doc()) -> kz_term:api_object().
disable_sync(Doc) ->
    disable_sync(Doc, 'undefined').

-spec disable_sync(doc(), Default) -> kz_json:object() | Default.
disable_sync(Doc, Default) ->
    kz_json:set_value([<<"qubicle">>, <<"recipient">>, <<"disable_sync">>], Doc, Default).

-spec set_disable_sync(doc(), kz_json:object()) -> doc().
set_disable_sync(Doc, Enabled) ->
    kz_json:set_value([<<"qubicle">>, <<"recipient">>, <<"disable_sync">>], Enabled, Doc).
