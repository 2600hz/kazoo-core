%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @author Navoda Ginige
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_contacts).

-export([new/0]).
-export([type/0]).
-export([schema/0]).
-export([capture_group/1, capture_group/2, set_capture_group/2]).
-export([capture_group_key/1, capture_group_key/2, set_capture_group_key/2]).
-export([capture_group_length/1, capture_group_length/2, set_capture_group_length/2]).
-export([contacts/1, contacts/2, set_contacts/2]).
-export([favorite/1, favorite/2, set_favorite/2]).
-export([first_name/1, first_name/2, set_first_name/2]).
-export([history/1, history/2, set_history/2]).
-export([last_name/1, last_name/2, set_last_name/2]).
-export([organization/1, organization/2, set_organization/2]).
-export([organization_name/1, organization_name/2, set_organization_name/2]).
-export([owner_id/1, owner_id/2, set_owner_id/2]).
-export([pattern/1, pattern/2, set_pattern/2]).
-export([tags/1, tags/2, set_tags/2]).

-export([is_primary_contact/1]).
-export([get_type_contact/1]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().

-export_type([doc/0
             ]).

-define(TYPE, <<"contact">>).
-define(SCHEMA, <<"contacts">>).

-spec new() -> doc().
new() ->
    kz_doc:set_type(kz_json_schema:default_object(?SCHEMA), type()).

-spec type() -> kz_term:ne_binary().
type() -> ?TYPE.

-spec schema() -> kz_term:ne_binary().
schema() -> ?SCHEMA.

-spec capture_group(doc()) -> kz_json:object().
capture_group(Doc) ->
    capture_group(Doc, kz_json:new()).

-spec capture_group(doc(), Default) -> kz_json:object() | Default.
capture_group(Doc, Default) ->
    kz_json:get_json_value([<<"capture_group">>], Doc, Default).

-spec set_capture_group(doc(), kz_json:object()) -> doc().
set_capture_group(Doc, CaptureGroup) ->
    kz_json:set_value([<<"capture_group">>], CaptureGroup, Doc).

-spec capture_group_key(doc()) -> kz_term:api_binary().
capture_group_key(Doc) ->
    capture_group_key(Doc, 'undefined').

-spec capture_group_key(doc(), Default) -> binary() | Default.
capture_group_key(Doc, Default) ->
    kz_json:get_binary_value([<<"capture_group">>, <<"key">>], Doc, Default).

-spec set_capture_group_key(doc(), binary()) -> doc().
set_capture_group_key(Doc, CaptureGroupKey) ->
    kz_json:set_value([<<"capture_group">>, <<"key">>], CaptureGroupKey, Doc).

-spec capture_group_length(doc()) -> kz_term:api_integer().
capture_group_length(Doc) ->
    capture_group_length(Doc, 'undefined').

-spec capture_group_length(doc(), Default) -> integer() | Default.
capture_group_length(Doc, Default) ->
    kz_json:get_integer_value([<<"capture_group">>, <<"length">>], Doc, Default).

-spec set_capture_group_length(doc(), integer()) -> doc().
set_capture_group_length(Doc, CaptureGroupLength) ->
    kz_json:set_value([<<"capture_group">>, <<"length">>], CaptureGroupLength, Doc).

-spec contacts(doc()) -> kz_json:objects().
contacts(Doc) ->
    contacts(Doc, []).

-spec contacts(doc(), Default) -> kz_json:objects() | Default.
contacts(Doc, Default) ->
    kz_json:get_list_value([<<"contacts">>], Doc, Default).

-spec set_contacts(doc(), kz_json:objects()) -> doc().
set_contacts(Doc, Contacts) ->
    kz_json:set_value([<<"contacts">>], Contacts, Doc).

-spec favorite(doc()) -> boolean().
favorite(Doc) ->
    favorite(Doc, 'false').

-spec favorite(doc(), Default) -> boolean() | Default.
favorite(Doc, Default) ->
    kz_json:get_boolean_value([<<"favorite">>], Doc, Default).

-spec set_favorite(doc(), boolean()) -> doc().
set_favorite(Doc, Favorite) ->
    kz_json:set_value([<<"favorite">>], Favorite, Doc).

-spec first_name(doc()) -> kz_term:api_binary().
first_name(Doc) ->
    first_name(Doc, 'undefined').

-spec first_name(doc(), Default) -> binary() | Default.
first_name(Doc, Default) ->
    kz_json:get_binary_value([<<"first_name">>], Doc, Default).

-spec set_first_name(doc(), binary()) -> doc().
set_first_name(Doc, FirstName) ->
    kz_json:set_value([<<"first_name">>], FirstName, Doc).

-spec history(doc()) -> kz_json:objects().
history(Doc) ->
    history(Doc, []).

-spec history(doc(), Default) -> kz_json:objects() | Default.
history(Doc, Default) ->
    kz_json:get_list_value([<<"history">>], Doc, Default).

-spec set_history(doc(), kz_json:objects()) -> doc().
set_history(Doc, History) ->
    kz_json:set_value([<<"history">>], History, Doc).

-spec last_name(doc()) -> kz_term:api_binary().
last_name(Doc) ->
    last_name(Doc, 'undefined').

-spec last_name(doc(), Default) -> binary() | Default.
last_name(Doc, Default) ->
    kz_json:get_binary_value([<<"last_name">>], Doc, Default).

-spec set_last_name(doc(), binary()) -> doc().
set_last_name(Doc, LastName) ->
    kz_json:set_value([<<"last_name">>], LastName, Doc).

-spec organization(doc()) -> kz_json:object().
organization(Doc) ->
    organization(Doc, kz_json:new()).

-spec organization(doc(), Default) -> kz_json:object() | Default.
organization(Doc, Default) ->
    kz_json:get_json_value([<<"organization">>], Doc, Default).

-spec set_organization(doc(), kz_json:object()) -> doc().
set_organization(Doc, Organization) ->
    kz_json:set_value([<<"organization">>], Organization, Doc).

-spec organization_name(doc()) -> kz_term:api_binary().
organization_name(Doc) ->
    organization_name(Doc, 'undefined').

-spec organization_name(doc(), Default) -> binary() | Default.
organization_name(Doc, Default) ->
    kz_json:get_binary_value([<<"organization">>, <<"name">>], Doc, Default).

-spec set_organization_name(doc(), binary()) -> doc().
set_organization_name(Doc, OrganizationName) ->
    kz_json:set_value([<<"organization">>, <<"name">>], OrganizationName, Doc).

-spec owner_id(doc()) -> binary().
owner_id(Doc) ->
    owner_id(Doc, 'undefined').

-spec owner_id(doc(), Default) -> binary() | Default.
owner_id(Doc, Default) ->
    kz_json:get_binary_value([<<"pvt_owner_id">>], Doc, Default).

-spec set_owner_id(doc(), binary()) -> doc().
set_owner_id(Doc, OrganizationName) ->
    kz_json:set_value([<<"pvt_owner_id">>], OrganizationName, Doc).

-spec pattern(doc()) -> kz_term:api_binary().
pattern(Doc) ->
    pattern(Doc, 'undefined').

-spec pattern(doc(), Default) -> binary() | Default.
pattern(Doc, Default) ->
    kz_json:get_binary_value([<<"pattern">>], Doc, Default).

-spec set_pattern(doc(), binary()) -> doc().
set_pattern(Doc, Pattern) ->
    kz_json:set_value([<<"pattern">>], Pattern, Doc).

-spec tags(doc()) -> kz_term:api_ne_binaries().
tags(Doc) ->
    tags(Doc, 'undefined').

-spec tags(doc(), Default) -> kz_term:ne_binaries() | Default.
tags(Doc, Default) ->
    kz_json:get_list_value([<<"tags">>], Doc, Default).

-spec set_tags(doc(), kz_term:ne_binaries()) -> doc().
set_tags(Doc, Tags) ->
    kz_json:set_value([<<"tags">>], Tags, Doc).

-spec is_primary_contact(kz_json:object()) -> boolean().
is_primary_contact(Contact) ->
    kz_json:get_boolean_value(<<"primary">>, Contact).

-spec get_type_contact(kz_json:object()) -> kz_term:ne_binary().
get_type_contact(Contact) ->
    kz_json:get_value(<<"type">>, Contact).
