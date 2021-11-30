%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc Accessors for `presence' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_presence).

-export([new/0]).
-export([action/1, action/2, set_action/2]).
-export([reset/1, reset/2, set_reset/2]).
-export([state/1, state/2, set_state/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"presence">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec action(doc()) -> kz_term:api_object().
action(Doc) ->
    action(Doc, 'undefined').

-spec action(doc(), Default) -> kz_json:object() | Default.
action(Doc, Default) ->
    kz_json:get_json_value([<<"action">>], Doc, Default).

-spec set_action(doc(), kz_json:object()) -> doc().
set_action(Doc, Action) ->
    kz_json:set_value([<<"action">>], Action, Doc).

-spec reset(doc()) -> kz_term:api_boolean().
reset(Doc) ->
    reset(Doc, 'undefined').

-spec reset(doc(), Default) -> boolean() | Default.
reset(Doc, Default) ->
    kz_json:get_boolean_value([<<"reset">>], Doc, Default).

-spec set_reset(doc(), boolean()) -> doc().
set_reset(Doc, Reset) ->
    kz_json:set_value([<<"reset">>], Reset, Doc).

-spec state(doc()) -> kz_term:api_object().
state(Doc) ->
    state(Doc, 'undefined').

-spec state(doc(), Default) -> kz_json:object() | Default.
state(Doc, Default) ->
    kz_json:get_json_value([<<"state">>], Doc, Default).

-spec set_state(doc(), kz_json:object()) -> doc().
set_state(Doc, State) ->
    kz_json:set_value([<<"state">>], State, Doc).
