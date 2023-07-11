%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_list_entries).

-export([new/0]).
-export([contacts/1, contacts/2, set_contacts/2]).
-export([description/1, description/2, set_description/2]).
-export([history/1, history/2, set_history/2]).
-export([list_id/1, list_id/2, set_list_id/2]).
-export([name/1, name/2, set_name/2]).
-export([organization/1, organization/2, set_organization/2]).
-export([organization_name/1, organization_name/2, set_organization_name/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"list_entries">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec contacts(doc()) -> kz_json:objects().
contacts(Doc) ->
    contacts(Doc, []).

-spec contacts(doc(), Default) -> kz_json:objects() | Default.
contacts(Doc, Default) ->
    kz_json:get_list_value([<<"contacts">>], Doc, Default).

-spec set_contacts(doc(), kz_json:objects()) -> doc().
set_contacts(Doc, Contacts) ->
    kz_json:set_value([<<"contacts">>], Contacts, Doc).

-spec description(doc()) -> kz_term:api_binary().
description(Doc) ->
    description(Doc, 'undefined').

-spec description(doc(), Default) -> binary() | Default.
description(Doc, Default) ->
    kz_json:get_binary_value([<<"description">>], Doc, Default).

-spec set_description(doc(), binary()) -> doc().
set_description(Doc, Description) ->
    kz_json:set_value([<<"description">>], Description, Doc).

-spec history(doc()) -> kz_json:objects() | [].
history(Doc) ->
    history(Doc, []).

-spec history(doc(), Default) -> kz_json:objects() | Default.
history(Doc, Default) ->
    kz_json:get_list_value([<<"history">>], Doc, Default).

-spec set_history(doc(), kz_json:objects()) -> doc().
set_history(Doc, History) ->
    kz_json:set_value([<<"history">>], History, Doc).

-spec list_id(doc()) -> kz_term:api_binary().
list_id(Doc) ->
    list_id(Doc, 'undefined').

-spec list_id(doc(), Default) -> binary() | Default.
list_id(Doc, Default) ->
    kz_json:get_binary_value([<<"list_id">>], Doc, Default).

-spec set_list_id(doc(), binary()) -> doc().
set_list_id(Doc, ListId) ->
    kz_json:set_value([<<"list_id">>], ListId, Doc).

-spec name(doc()) -> kz_term:api_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> binary() | Default.
name(Doc, Default) ->
    kz_json:get_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

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
