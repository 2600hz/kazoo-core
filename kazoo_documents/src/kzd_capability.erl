%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2026, 2600Hz
%%% @doc Accessors for `capability' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_capability).

-export([new/0]).
-export([description/1, description/2, set_description/2]).
-export([enabled/1, enabled/2, set_enabled/2]).
-export([name/1, name/2, set_name/2]).
-export([provided_by/1, provided_by/2, set_provided_by/2]).

-export([type/0, schema/0]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"capability">>).
-define(TYPE, <<"capability">>).

-spec type() -> kz_term:ne_binary().
type() -> ?TYPE.

-spec schema() -> kz_term:ne_binary().
schema() -> ?SCHEMA.

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec description(doc()) -> kz_term:api_binary().
description(Doc) ->
    description(Doc, 'undefined').

-spec description(doc(), Default) -> binary() | Default.
description(Doc, Default) ->
    kz_json:get_binary_value([<<"description">>], Doc, Default).

-spec set_description(doc(), binary()) -> doc().
set_description(Doc, Description) ->
    kz_json:set_value([<<"description">>], Description, Doc).

-spec enabled(doc()) -> kz_term:api_boolean().
enabled(Doc) ->
    enabled(Doc, 'undefined').

-spec enabled(doc(), Default) -> boolean() | Default.
enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"enabled">>], Doc, Default).

-spec set_enabled(doc(), boolean()) -> doc().
set_enabled(Doc, Enabled) ->
    kz_json:set_value([<<"enabled">>], Enabled, Doc).

-spec name(doc()) -> kz_term:api_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> binary() | Default.
name(Doc, Default) ->
    kz_json:get_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

-spec provided_by(doc()) -> kz_term:api_binary().
provided_by(Doc) ->
    provided_by(Doc, 'undefined').

-spec provided_by(doc(), Default) -> binary() | Default.
provided_by(Doc, Default) ->
    kz_json:get_binary_value([<<"provided_by">>], Doc, Default).

-spec set_provided_by(doc(), binary()) -> doc().
set_provided_by(Doc, ProvidedBy) ->
    kz_json:set_value([<<"provided_by">>], ProvidedBy, Doc).
