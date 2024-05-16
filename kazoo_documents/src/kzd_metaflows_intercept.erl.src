%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `metaflows_intercept' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_intercept).

-export([new/0]).
-export([auto_answer/1, auto_answer/2, set_auto_answer/2]).
-export([can_call_self/1, can_call_self/2, set_can_call_self/2]).
-export([target_id/1, target_id/2, set_target_id/2]).
-export([target_type/1, target_type/2, set_target_type/2]).
-export([unbridged_only/1, unbridged_only/2, set_unbridged_only/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.intercept">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec auto_answer(doc()) -> boolean().
auto_answer(Doc) ->
    auto_answer(Doc, 'false').

-spec auto_answer(doc(), Default) -> boolean() | Default.
auto_answer(Doc, Default) ->
    kz_json:get_boolean_value([<<"auto_answer">>], Doc, Default).

-spec set_auto_answer(doc(), boolean()) -> doc().
set_auto_answer(Doc, AutoAnswer) ->
    kz_json:set_value([<<"auto_answer">>], AutoAnswer, Doc).

-spec can_call_self(doc()) -> boolean().
can_call_self(Doc) ->
    can_call_self(Doc, 'true').

-spec can_call_self(doc(), Default) -> boolean() | Default.
can_call_self(Doc, Default) ->
    kz_json:get_boolean_value([<<"can_call_self">>], Doc, Default).

-spec set_can_call_self(doc(), boolean()) -> doc().
set_can_call_self(Doc, CanCallSelf) ->
    kz_json:set_value([<<"can_call_self">>], CanCallSelf, Doc).

-spec target_id(doc()) -> kz_term:api_binary().
target_id(Doc) ->
    target_id(Doc, 'undefined').

-spec target_id(doc(), Default) -> binary() | Default.
target_id(Doc, Default) ->
    kz_json:get_binary_value([<<"target_id">>], Doc, Default).

-spec set_target_id(doc(), binary()) -> doc().
set_target_id(Doc, TargetId) ->
    kz_json:set_value([<<"target_id">>], TargetId, Doc).

-spec target_type(doc()) -> kz_term:api_binary().
target_type(Doc) ->
    target_type(Doc, 'undefined').

-spec target_type(doc(), Default) -> binary() | Default.
target_type(Doc, Default) ->
    kz_json:get_binary_value([<<"target_type">>], Doc, Default).

-spec set_target_type(doc(), binary()) -> doc().
set_target_type(Doc, TargetType) ->
    kz_json:set_value([<<"target_type">>], TargetType, Doc).

-spec unbridged_only(doc()) -> boolean().
unbridged_only(Doc) ->
    unbridged_only(Doc, 'true').

-spec unbridged_only(doc(), Default) -> boolean() | Default.
unbridged_only(Doc, Default) ->
    kz_json:get_boolean_value([<<"unbridged_only">>], Doc, Default).

-spec set_unbridged_only(doc(), boolean()) -> doc().
set_unbridged_only(Doc, UnbridgedOnly) ->
    kz_json:set_value([<<"unbridged_only">>], UnbridgedOnly, Doc).
