%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2026, 2600Hz
%%% @doc Accessors for `enrollment' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_enrollment).

-export([new/0]).
-export([capability_id/1, capability_id/2, set_capability_id/2]).
-export([enabled/1, enabled/2, set_enabled/2]).
-export([enrolled/1, enrolled/2, set_enrolled/2]).

-export([type/0, schema/0]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"enrollment">>).
-define(TYPE, <<"enrollment">>).

-spec schema() -> kz_term:ne_binary().
schema() -> ?SCHEMA.

-spec type() -> kz_term:ne_binary().
type() -> ?TYPE.

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec capability_id(doc()) -> kz_term:api_binary().
capability_id(Doc) ->
    capability_id(Doc, 'undefined').

-spec capability_id(doc(), Default) -> binary() | Default.
capability_id(Doc, Default) ->
    kz_json:get_binary_value([<<"capability_id">>], Doc, Default).

-spec set_capability_id(doc(), binary()) -> doc().
set_capability_id(Doc, CapabilityId) ->
    kz_json:set_value([<<"capability_id">>], CapabilityId, Doc).

-spec enabled(doc()) -> kz_term:api_boolean().
enabled(Doc) ->
    enabled(Doc, 'undefined').

-spec enabled(doc(), Default) -> boolean() | Default.
enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"enabled">>], Doc, Default).

-spec set_enabled(doc(), boolean()) -> doc().
set_enabled(Doc, Enabled) ->
    kz_json:set_value([<<"enabled">>], Enabled, Doc).

-spec enrolled(doc()) -> kz_term:api_integer().
enrolled(Doc) ->
    enrolled(Doc, 'undefined').

-spec enrolled(doc(), Default) -> integer() | Default.
enrolled(Doc, Default) ->
    kz_json:get_integer_value([<<"enrolled">>], Doc, Default).

-spec set_enrolled(doc(), integer()) -> doc().
set_enrolled(Doc, Enrolled) ->
    kz_json:set_value([<<"enrolled">>], Enrolled, Doc).
