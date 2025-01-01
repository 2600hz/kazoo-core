%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `call_forward_types' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_call_forward_types).

-export([new/0]).
-export([busy/1, busy/2, set_busy/2]).
-export([no_answer/1, no_answer/2, set_no_answer/2]).
-export([selective/1, selective/2, set_selective/2]).
-export([selective_rules/1, selective_rules/2, set_selective_rules/2]).
-export([unconditional/1, unconditional/2, set_unconditional/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"call_forward_types">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec busy(doc()) -> kz_term:api_object().
busy(Doc) ->
    busy(Doc, 'undefined').

-spec busy(doc(), Default) -> kz_json:object() | Default.
busy(Doc, Default) ->
    kz_json:get_json_value([<<"busy">>], Doc, Default).

-spec set_busy(doc(), kz_json:object()) -> doc().
set_busy(Doc, Busy) ->
    kz_json:set_value([<<"busy">>], Busy, Doc).

-spec no_answer(doc()) -> kz_term:api_object().
no_answer(Doc) ->
    no_answer(Doc, 'undefined').

-spec no_answer(doc(), Default) -> kz_json:object() | Default.
no_answer(Doc, Default) ->
    kz_json:get_json_value([<<"no_answer">>], Doc, Default).

-spec set_no_answer(doc(), kz_json:object()) -> doc().
set_no_answer(Doc, NoAnswer) ->
    kz_json:set_value([<<"no_answer">>], NoAnswer, Doc).

-spec selective(doc()) -> kz_term:api_object().
selective(Doc) ->
    selective(Doc, 'undefined').

-spec selective(doc(), Default) -> kz_json:object() | Default.
selective(Doc, Default) ->
    kz_json:get_json_value([<<"selective">>], Doc, Default).

-spec set_selective(doc(), kz_json:object()) -> doc().
set_selective(Doc, Selective) ->
    kz_json:set_value([<<"selective">>], Selective, Doc).

-spec selective_rules(doc()) -> kz_term:api_objects().
selective_rules(Doc) ->
    selective_rules(Doc, 'undefined').

-spec selective_rules(doc(), Default) -> kz_json:objects() | Default.
selective_rules(Doc, Default) ->
    kz_json:get_list_value([<<"selective">>, <<"rules">>], Doc, Default).

-spec set_selective_rules(doc(), kz_json:objects()) -> doc().
set_selective_rules(Doc, SelectiveRules) ->
    kz_json:set_value([<<"selective">>, <<"rules">>], SelectiveRules, Doc).

-spec unconditional(doc()) -> kz_term:api_object().
unconditional(Doc) ->
    unconditional(Doc, 'undefined').

-spec unconditional(doc(), Default) -> kz_json:object() | Default.
unconditional(Doc, Default) ->
    kz_json:get_json_value([<<"unconditional">>], Doc, Default).

-spec set_unconditional(doc(), kz_json:object()) -> doc().
set_unconditional(Doc, Unconditional) ->
    kz_json:set_value([<<"unconditional">>], Unconditional, Doc).
