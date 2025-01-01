%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `call_forward' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_call_forward).

-export([new/0]).
-export([direct_calls_only/1, direct_calls_only/2, set_direct_calls_only/2]).
-export([enabled/1, enabled/2, set_enabled/2]).
-export([ignore_early_media/1, ignore_early_media/2, set_ignore_early_media/2]).
-export([keep_caller_id/1, keep_caller_id/2, set_keep_caller_id/2]).
-export([number/1, number/2, set_number/2]).
-export([require_keypress/1, require_keypress/2, set_require_keypress/2]).
-export([substitute/1, substitute/2, set_substitute/2]).
-export([busy/1, busy/2, set_busy/2]).
-export([busy_direct_calls_only/1, busy_direct_calls_only/2, set_busy_direct_calls_only/2]).
-export([busy_enabled/1, busy_enabled/2, set_busy_enabled/2]).
-export([busy_ignore_early_media/1, busy_ignore_early_media/2, set_busy_ignore_early_media/2]).
-export([busy_keep_caller_id/1, busy_keep_caller_id/2, set_busy_keep_caller_id/2]).
-export([busy_number/1, busy_number/2, set_busy_number/2]).
-export([busy_require_keypress/1, busy_require_keypress/2, set_busy_require_keypress/2]).
-export([no_answer/1, no_answer/2, set_no_answer/2]).
-export([no_answer_direct_calls_only/1, no_answer_direct_calls_only/2, set_no_answer_direct_calls_only/2]).
-export([no_answer_enabled/1, no_answer_enabled/2, set_no_answer_enabled/2]).
-export([no_answer_ignore_early_media/1, no_answer_ignore_early_media/2, set_no_answer_ignore_early_media/2]).
-export([no_answer_keep_caller_id/1, no_answer_keep_caller_id/2, set_no_answer_keep_caller_id/2]).
-export([no_answer_number/1, no_answer_number/2, set_no_answer_number/2]).
-export([no_answer_require_keypress/1, no_answer_require_keypress/2, set_no_answer_require_keypress/2]).
-export([selective/1, selective/2, set_selective/2]).
-export([selective_direct_calls_only/1, selective_direct_calls_only/2, set_selective_direct_calls_only/2]).
-export([selective_enabled/1, selective_enabled/2, set_selective_enabled/2]).
-export([selective_ignore_early_media/1, selective_ignore_early_media/2, set_selective_ignore_early_media/2]).
-export([selective_keep_caller_id/1, selective_keep_caller_id/2, set_selective_keep_caller_id/2]).
-export([selective_number/1, selective_number/2, set_selective_number/2]).
-export([selective_require_keypress/1, selective_require_keypress/2, set_selective_require_keypress/2]).
-export([selective_rules/1, selective_rules/2, set_selective_rules/2]).
-export([unconditional/1, unconditional/2, set_unconditional/2]).
-export([unconditional_direct_calls_only/1, unconditional_direct_calls_only/2, set_unconditional_direct_calls_only/2]).
-export([unconditional_enabled/1, unconditional_enabled/2, set_unconditional_enabled/2]).
-export([unconditional_ignore_early_media/1, unconditional_ignore_early_media/2, set_unconditional_ignore_early_media/2]).
-export([unconditional_keep_caller_id/1, unconditional_keep_caller_id/2, set_unconditional_keep_caller_id/2]).
-export([unconditional_number/1, unconditional_number/2, set_unconditional_number/2]).
-export([unconditional_require_keypress/1, unconditional_require_keypress/2, set_unconditional_require_keypress/2]).

-export([validate/1]).
-export([is_legacy/1]).
-export([merged/2, merged/3]).
-export([rules/1, rules/2]).

-include("kz_documents.hrl").

-elvis([{elvis_style, god_modules, disable}]).

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"call_forward">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec direct_calls_only(doc()) -> boolean().
direct_calls_only(Doc) ->
    direct_calls_only(Doc, 'false').

-spec direct_calls_only(doc(), Default) -> boolean() | Default.
direct_calls_only(Doc, Default) ->
    kz_json:get_boolean_value([<<"direct_calls_only">>], Doc, Default).

-spec set_direct_calls_only(doc(), boolean()) -> doc().
set_direct_calls_only(Doc, DirectCallsOnly) ->
    kz_json:set_value([<<"direct_calls_only">>], DirectCallsOnly, Doc).

-spec enabled(doc()) -> boolean().
enabled(Doc) ->
    enabled(Doc, 'false').

%% @doc global is-cfwd-enabled flag, 'false' means all cfwd is off
-spec enabled(doc(), Default) -> boolean() | Default.
enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"enabled">>], Doc, Default).

-spec set_enabled(doc(), boolean()) -> doc().
set_enabled(Doc, Enabled) ->
    kz_json:set_value([<<"enabled">>], Enabled, Doc).

-spec ignore_early_media(doc()) -> boolean().
ignore_early_media(Doc) ->
    ignore_early_media(Doc, 'true').

-spec ignore_early_media(doc(), Default) -> boolean() | Default.
ignore_early_media(Doc, Default) ->
    kz_json:get_boolean_value([<<"ignore_early_media">>], Doc, Default).

-spec set_ignore_early_media(doc(), boolean()) -> doc().
set_ignore_early_media(Doc, IgnoreEarlyMedia) ->
    kz_json:set_value([<<"ignore_early_media">>], IgnoreEarlyMedia, Doc).

-spec keep_caller_id(doc()) -> boolean().
keep_caller_id(Doc) ->
    keep_caller_id(Doc, 'true').

-spec keep_caller_id(doc(), Default) -> boolean() | Default.
keep_caller_id(Doc, Default) ->
    kz_json:get_boolean_value([<<"keep_caller_id">>], Doc, Default).

-spec set_keep_caller_id(doc(), boolean()) -> doc().
set_keep_caller_id(Doc, KeepCallerId) ->
    kz_json:set_value([<<"keep_caller_id">>], KeepCallerId, Doc).

-spec number(doc()) -> kz_term:api_binary().
number(Doc) ->
    number(Doc, 'undefined').

-spec number(doc(), Default) -> binary() | Default.
number(Doc, Default) ->
    kz_json:get_binary_value([<<"number">>], Doc, Default).

-spec set_number(doc(), binary()) -> doc().
set_number(Doc, Number) ->
    kz_json:set_value([<<"number">>], Number, Doc).

-spec require_keypress(doc()) -> boolean().
require_keypress(Doc) ->
    require_keypress(Doc, 'true').

-spec require_keypress(doc(), Default) -> boolean() | Default.
require_keypress(Doc, Default) ->
    kz_json:get_boolean_value([<<"require_keypress">>], Doc, Default).

-spec set_require_keypress(doc(), boolean()) -> doc().
set_require_keypress(Doc, RequireKeypress) ->
    kz_json:set_value([<<"require_keypress">>], RequireKeypress, Doc).

-spec substitute(doc()) -> boolean().
substitute(Doc) ->
    substitute(Doc, 'true').

-spec substitute(doc(), Default) -> boolean() | Default.
substitute(Doc, Default) ->
    kz_json:get_boolean_value([<<"substitute">>], Doc, Default).

-spec set_substitute(doc(), boolean()) -> doc().
set_substitute(Doc, Substitute) ->
    kz_json:set_value([<<"substitute">>], Substitute, Doc).

-spec busy(doc()) -> kz_term:api_object().
busy(Doc) ->
    busy(Doc, 'undefined').

-spec busy(doc(), Default) -> kz_json:object() | Default.
busy(Doc, Default) ->
    kz_json:get_json_value([<<"busy">>], Doc, Default).

-spec set_busy(doc(), kz_json:object()) -> doc().
set_busy(Doc, Busy) ->
    kz_json:set_value([<<"busy">>], Busy, Doc).

-spec busy_direct_calls_only(doc()) -> boolean().
busy_direct_calls_only(Doc) ->
    busy_direct_calls_only(Doc, 'false').

-spec busy_direct_calls_only(doc(), Default) -> boolean() | Default.
busy_direct_calls_only(Doc, Default) ->
    kz_json:get_boolean_value([<<"busy">>, <<"direct_calls_only">>], Doc, Default).

-spec set_busy_direct_calls_only(doc(), boolean()) -> doc().
set_busy_direct_calls_only(Doc, BusyDirectCallsOnly) ->
    kz_json:set_value([<<"busy">>, <<"direct_calls_only">>], BusyDirectCallsOnly, Doc).

-spec busy_enabled(doc()) -> boolean().
busy_enabled(Doc) ->
    busy_enabled(Doc, 'false').

-spec busy_enabled(doc(), Default) -> boolean() | Default.
busy_enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"busy">>, <<"enabled">>], Doc, Default).

-spec set_busy_enabled(doc(), boolean()) -> doc().
set_busy_enabled(Doc, BusyEnabled) ->
    kz_json:set_value([<<"busy">>, <<"enabled">>], BusyEnabled, Doc).

-spec busy_ignore_early_media(doc()) -> boolean().
busy_ignore_early_media(Doc) ->
    busy_ignore_early_media(Doc, 'true').

-spec busy_ignore_early_media(doc(), Default) -> boolean() | Default.
busy_ignore_early_media(Doc, Default) ->
    kz_json:get_boolean_value([<<"busy">>, <<"ignore_early_media">>], Doc, Default).

-spec set_busy_ignore_early_media(doc(), boolean()) -> doc().
set_busy_ignore_early_media(Doc, BusyIgnoreEarlyMedia) ->
    kz_json:set_value([<<"busy">>, <<"ignore_early_media">>], BusyIgnoreEarlyMedia, Doc).

-spec busy_keep_caller_id(doc()) -> boolean().
busy_keep_caller_id(Doc) ->
    busy_keep_caller_id(Doc, 'true').

-spec busy_keep_caller_id(doc(), Default) -> boolean() | Default.
busy_keep_caller_id(Doc, Default) ->
    kz_json:get_boolean_value([<<"busy">>, <<"keep_caller_id">>], Doc, Default).

-spec set_busy_keep_caller_id(doc(), boolean()) -> doc().
set_busy_keep_caller_id(Doc, BusyKeepCallerId) ->
    kz_json:set_value([<<"busy">>, <<"keep_caller_id">>], BusyKeepCallerId, Doc).

-spec busy_number(doc()) -> kz_term:api_binary().
busy_number(Doc) ->
    busy_number(Doc, 'undefined').

-spec busy_number(doc(), Default) -> binary() | Default.
busy_number(Doc, Default) ->
    kz_json:get_binary_value([<<"busy">>, <<"number">>], Doc, Default).

-spec set_busy_number(doc(), binary()) -> doc().
set_busy_number(Doc, BusyNumber) ->
    kz_json:set_value([<<"busy">>, <<"number">>], BusyNumber, Doc).

-spec busy_require_keypress(doc()) -> boolean().
busy_require_keypress(Doc) ->
    busy_require_keypress(Doc, 'true').

-spec busy_require_keypress(doc(), Default) -> boolean() | Default.
busy_require_keypress(Doc, Default) ->
    kz_json:get_boolean_value([<<"busy">>, <<"require_keypress">>], Doc, Default).

-spec set_busy_require_keypress(doc(), boolean()) -> doc().
set_busy_require_keypress(Doc, BusyRequireKeypress) ->
    kz_json:set_value([<<"busy">>, <<"require_keypress">>], BusyRequireKeypress, Doc).

-spec no_answer(doc()) -> kz_term:api_object().
no_answer(Doc) ->
    no_answer(Doc, 'undefined').

-spec no_answer(doc(), Default) -> kz_json:object() | Default.
no_answer(Doc, Default) ->
    kz_json:get_json_value([<<"no_answer">>], Doc, Default).

-spec set_no_answer(doc(), kz_json:object()) -> doc().
set_no_answer(Doc, NoAnswer) ->
    kz_json:set_value([<<"no_answer">>], NoAnswer, Doc).

-spec no_answer_direct_calls_only(doc()) -> boolean().
no_answer_direct_calls_only(Doc) ->
    no_answer_direct_calls_only(Doc, 'false').

-spec no_answer_direct_calls_only(doc(), Default) -> boolean() | Default.
no_answer_direct_calls_only(Doc, Default) ->
    kz_json:get_boolean_value([<<"no_answer">>, <<"direct_calls_only">>], Doc, Default).

-spec set_no_answer_direct_calls_only(doc(), boolean()) -> doc().
set_no_answer_direct_calls_only(Doc, NoAnswerDirectCallsOnly) ->
    kz_json:set_value([<<"no_answer">>, <<"direct_calls_only">>], NoAnswerDirectCallsOnly, Doc).

-spec no_answer_enabled(doc()) -> boolean().
no_answer_enabled(Doc) ->
    no_answer_enabled(Doc, 'false').

-spec no_answer_enabled(doc(), Default) -> boolean() | Default.
no_answer_enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"no_answer">>, <<"enabled">>], Doc, Default).

-spec set_no_answer_enabled(doc(), boolean()) -> doc().
set_no_answer_enabled(Doc, NoAnswerEnabled) ->
    kz_json:set_value([<<"no_answer">>, <<"enabled">>], NoAnswerEnabled, Doc).

-spec no_answer_ignore_early_media(doc()) -> boolean().
no_answer_ignore_early_media(Doc) ->
    no_answer_ignore_early_media(Doc, 'true').

-spec no_answer_ignore_early_media(doc(), Default) -> boolean() | Default.
no_answer_ignore_early_media(Doc, Default) ->
    kz_json:get_boolean_value([<<"no_answer">>, <<"ignore_early_media">>], Doc, Default).

-spec set_no_answer_ignore_early_media(doc(), boolean()) -> doc().
set_no_answer_ignore_early_media(Doc, NoAnswerIgnoreEarlyMedia) ->
    kz_json:set_value([<<"no_answer">>, <<"ignore_early_media">>], NoAnswerIgnoreEarlyMedia, Doc).

-spec no_answer_keep_caller_id(doc()) -> boolean().
no_answer_keep_caller_id(Doc) ->
    no_answer_keep_caller_id(Doc, 'true').

-spec no_answer_keep_caller_id(doc(), Default) -> boolean() | Default.
no_answer_keep_caller_id(Doc, Default) ->
    kz_json:get_boolean_value([<<"no_answer">>, <<"keep_caller_id">>], Doc, Default).

-spec set_no_answer_keep_caller_id(doc(), boolean()) -> doc().
set_no_answer_keep_caller_id(Doc, NoAnswerKeepCallerId) ->
    kz_json:set_value([<<"no_answer">>, <<"keep_caller_id">>], NoAnswerKeepCallerId, Doc).

-spec no_answer_number(doc()) -> kz_term:api_binary().
no_answer_number(Doc) ->
    no_answer_number(Doc, 'undefined').

-spec no_answer_number(doc(), Default) -> binary() | Default.
no_answer_number(Doc, Default) ->
    kz_json:get_binary_value([<<"no_answer">>, <<"number">>], Doc, Default).

-spec set_no_answer_number(doc(), binary()) -> doc().
set_no_answer_number(Doc, NoAnswerNumber) ->
    kz_json:set_value([<<"no_answer">>, <<"number">>], NoAnswerNumber, Doc).

-spec no_answer_require_keypress(doc()) -> boolean().
no_answer_require_keypress(Doc) ->
    no_answer_require_keypress(Doc, 'true').

-spec no_answer_require_keypress(doc(), Default) -> boolean() | Default.
no_answer_require_keypress(Doc, Default) ->
    kz_json:get_boolean_value([<<"no_answer">>, <<"require_keypress">>], Doc, Default).

-spec set_no_answer_require_keypress(doc(), boolean()) -> doc().
set_no_answer_require_keypress(Doc, NoAnswerRequireKeypress) ->
    kz_json:set_value([<<"no_answer">>, <<"require_keypress">>], NoAnswerRequireKeypress, Doc).

-spec selective(doc()) -> kz_term:api_object().
selective(Doc) ->
    selective(Doc, 'undefined').

-spec selective(doc(), Default) -> kz_json:object() | Default.
selective(Doc, Default) ->
    kz_json:get_json_value([<<"selective">>], Doc, Default).

-spec set_selective(doc(), kz_json:object()) -> doc().
set_selective(Doc, Selective) ->
    kz_json:set_value([<<"selective">>], Selective, Doc).

-spec selective_direct_calls_only(doc()) -> boolean().
selective_direct_calls_only(Doc) ->
    selective_direct_calls_only(Doc, 'false').

-spec selective_direct_calls_only(doc(), Default) -> boolean() | Default.
selective_direct_calls_only(Doc, Default) ->
    kz_json:get_boolean_value([<<"selective">>, <<"direct_calls_only">>], Doc, Default).

-spec set_selective_direct_calls_only(doc(), boolean()) -> doc().
set_selective_direct_calls_only(Doc, SelectiveDirectCallsOnly) ->
    kz_json:set_value([<<"selective">>, <<"direct_calls_only">>], SelectiveDirectCallsOnly, Doc).

-spec selective_enabled(doc()) -> boolean().
selective_enabled(Doc) ->
    selective_enabled(Doc, 'false').

-spec selective_enabled(doc(), Default) -> boolean() | Default.
selective_enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"selective">>, <<"enabled">>], Doc, Default).

-spec set_selective_enabled(doc(), boolean()) -> doc().
set_selective_enabled(Doc, SelectiveEnabled) ->
    kz_json:set_value([<<"selective">>, <<"enabled">>], SelectiveEnabled, Doc).

-spec selective_ignore_early_media(doc()) -> boolean().
selective_ignore_early_media(Doc) ->
    selective_ignore_early_media(Doc, 'true').

-spec selective_ignore_early_media(doc(), Default) -> boolean() | Default.
selective_ignore_early_media(Doc, Default) ->
    kz_json:get_boolean_value([<<"selective">>, <<"ignore_early_media">>], Doc, Default).

-spec set_selective_ignore_early_media(doc(), boolean()) -> doc().
set_selective_ignore_early_media(Doc, SelectiveIgnoreEarlyMedia) ->
    kz_json:set_value([<<"selective">>, <<"ignore_early_media">>], SelectiveIgnoreEarlyMedia, Doc).

-spec selective_keep_caller_id(doc()) -> boolean().
selective_keep_caller_id(Doc) ->
    selective_keep_caller_id(Doc, 'true').

-spec selective_keep_caller_id(doc(), Default) -> boolean() | Default.
selective_keep_caller_id(Doc, Default) ->
    kz_json:get_boolean_value([<<"selective">>, <<"keep_caller_id">>], Doc, Default).

-spec set_selective_keep_caller_id(doc(), boolean()) -> doc().
set_selective_keep_caller_id(Doc, SelectiveKeepCallerId) ->
    kz_json:set_value([<<"selective">>, <<"keep_caller_id">>], SelectiveKeepCallerId, Doc).

-spec selective_number(doc()) -> kz_term:api_binary().
selective_number(Doc) ->
    selective_number(Doc, 'undefined').

-spec selective_number(doc(), Default) -> binary() | Default.
selective_number(Doc, Default) ->
    kz_json:get_binary_value([<<"selective">>, <<"number">>], Doc, Default).

-spec set_selective_number(doc(), binary()) -> doc().
set_selective_number(Doc, SelectiveNumber) ->
    kz_json:set_value([<<"selective">>, <<"number">>], SelectiveNumber, Doc).

-spec selective_require_keypress(doc()) -> boolean().
selective_require_keypress(Doc) ->
    selective_require_keypress(Doc, 'true').

-spec selective_require_keypress(doc(), Default) -> boolean() | Default.
selective_require_keypress(Doc, Default) ->
    kz_json:get_boolean_value([<<"selective">>, <<"require_keypress">>], Doc, Default).

-spec set_selective_require_keypress(doc(), boolean()) -> doc().
set_selective_require_keypress(Doc, SelectiveRequireKeypress) ->
    kz_json:set_value([<<"selective">>, <<"require_keypress">>], SelectiveRequireKeypress, Doc).

-spec selective_rules(doc()) -> kz_term:api_objects().
selective_rules(Doc) ->
    selective_rules(Doc, 'undefined').

-spec selective_rules(doc(), Default) -> kz_json:objects() | Default.
selective_rules(Doc, Default) ->
    kz_json:get_list_value([<<"selective">>, <<"rules">>], Doc, Default).

-spec set_selective_rules(doc(), kz_json:objects()) -> doc().
set_selective_rules(Doc, SelectiveRules) ->
    kz_json:set_value([<<"selective">>, <<"rules">>], SelectiveRules, Doc).

-spec rules(doc()) -> kz_json:objects().
rules(Doc) ->
    rules(Doc, []).

-spec rules(doc(), Default) -> kz_json:objects() | Default.
rules(Doc, Default) ->
    kz_json:get_list_value([<<"rules">>], Doc, Default).

%% for internal merge of selective onto top-level settings
-spec set_rules(doc(), kz_json:objects()) -> doc().
set_rules(Doc, SelectiveRules) ->
    kz_json:set_value([<<"rules">>], SelectiveRules, Doc).

-spec unconditional(doc()) -> kz_term:api_object().
unconditional(Doc) ->
    unconditional(Doc, 'undefined').

-spec unconditional(doc(), Default) -> kz_json:object() | Default.
unconditional(Doc, Default) ->
    kz_json:get_json_value([<<"unconditional">>], Doc, Default).

-spec set_unconditional(doc(), kz_json:object()) -> doc().
set_unconditional(Doc, Unconditional) ->
    kz_json:set_value([<<"unconditional">>], Unconditional, Doc).

-spec unconditional_direct_calls_only(doc()) -> boolean().
unconditional_direct_calls_only(Doc) ->
    unconditional_direct_calls_only(Doc, 'false').

-spec unconditional_direct_calls_only(doc(), Default) -> boolean() | Default.
unconditional_direct_calls_only(Doc, Default) ->
    kz_json:get_boolean_value([<<"unconditional">>, <<"direct_calls_only">>], Doc, Default).

-spec set_unconditional_direct_calls_only(doc(), boolean()) -> doc().
set_unconditional_direct_calls_only(Doc, UnconditionalDirectCallsOnly) ->
    kz_json:set_value([<<"unconditional">>, <<"direct_calls_only">>], UnconditionalDirectCallsOnly, Doc).

-spec unconditional_enabled(doc()) -> boolean().
unconditional_enabled(Doc) ->
    unconditional_enabled(Doc, 'false').

-spec unconditional_enabled(doc(), Default) -> boolean() | Default.
unconditional_enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"unconditional">>, <<"enabled">>], Doc, Default).

-spec set_unconditional_enabled(doc(), boolean()) -> doc().
set_unconditional_enabled(Doc, UnconditionalEnabled) ->
    kz_json:set_value([<<"unconditional">>, <<"enabled">>], UnconditionalEnabled, Doc).

-spec unconditional_ignore_early_media(doc()) -> boolean().
unconditional_ignore_early_media(Doc) ->
    unconditional_ignore_early_media(Doc, 'true').

-spec unconditional_ignore_early_media(doc(), Default) -> boolean() | Default.
unconditional_ignore_early_media(Doc, Default) ->
    kz_json:get_boolean_value([<<"unconditional">>, <<"ignore_early_media">>], Doc, Default).

-spec set_unconditional_ignore_early_media(doc(), boolean()) -> doc().
set_unconditional_ignore_early_media(Doc, UnconditionalIgnoreEarlyMedia) ->
    kz_json:set_value([<<"unconditional">>, <<"ignore_early_media">>], UnconditionalIgnoreEarlyMedia, Doc).

-spec unconditional_keep_caller_id(doc()) -> boolean().
unconditional_keep_caller_id(Doc) ->
    unconditional_keep_caller_id(Doc, 'true').

-spec unconditional_keep_caller_id(doc(), Default) -> boolean() | Default.
unconditional_keep_caller_id(Doc, Default) ->
    kz_json:get_boolean_value([<<"unconditional">>, <<"keep_caller_id">>], Doc, Default).

-spec set_unconditional_keep_caller_id(doc(), boolean()) -> doc().
set_unconditional_keep_caller_id(Doc, UnconditionalKeepCallerId) ->
    kz_json:set_value([<<"unconditional">>, <<"keep_caller_id">>], UnconditionalKeepCallerId, Doc).

-spec unconditional_number(doc()) -> kz_term:api_binary().
unconditional_number(Doc) ->
    unconditional_number(Doc, 'undefined').

-spec unconditional_number(doc(), Default) -> binary() | Default.
unconditional_number(Doc, Default) ->
    kz_json:get_binary_value([<<"unconditional">>, <<"number">>], Doc, Default).

-spec set_unconditional_number(doc(), binary()) -> doc().
set_unconditional_number(Doc, UnconditionalNumber) ->
    kz_json:set_value([<<"unconditional">>, <<"number">>], UnconditionalNumber, Doc).

-spec unconditional_require_keypress(doc()) -> boolean().
unconditional_require_keypress(Doc) ->
    unconditional_require_keypress(Doc, 'true').

-spec unconditional_require_keypress(doc(), Default) -> boolean() | Default.
unconditional_require_keypress(Doc, Default) ->
    kz_json:get_boolean_value([<<"unconditional">>, <<"require_keypress">>], Doc, Default).

-spec set_unconditional_require_keypress(doc(), boolean()) -> doc().
set_unconditional_require_keypress(Doc, UnconditionalRequireKeypress) ->
    kz_json:set_value([<<"unconditional">>, <<"require_keypress">>], UnconditionalRequireKeypress, Doc).

%% @doc validate an endpoint (account/user/device) doc's call forwarding settings
-spec validate(doc()) -> 'ok' | kazoo_documents:doc_validation_errors().
validate(CallForward) ->
    Types = [{<<"unconditional">>, fun unconditional/1}
            ,{<<"no_answer">>, fun no_answer/1}
            ,{<<"busy">>, fun busy/1}
            ,{<<"selective">>, fun selective/1, <<"rules">>, fun selective_rules/1}
            ],
    validate(CallForward, Types).

validate(CallForward, Types) ->
    validate_return(lists:foldl(validate_fun(CallForward), [], Types)).

validate_return([]) -> 'ok';
validate_return(Errors) -> Errors.

validate_fun(CallForward) ->
    fun({Name, Fun}, Acc) when is_function(Fun)->
            case merged_call_forward_settings(CallForward, Fun(CallForward)) of
                'undefined' -> Acc;
                JObj -> validate_call_forward(Name, JObj, Acc)
            end;
       ({Name, ItemObj}, Acc) ->
            case merged_call_forward_settings(CallForward, ItemObj) of
                'undefined' -> Acc;
                JObj -> validate_call_forward(Name, JObj, Acc)
            end;
       ({Name, Fun, ItemName, ArrayFun}, Acc) ->
            case merged_call_forward_settings(CallForward, Fun(CallForward)) of
                'undefined' -> Acc;
                JObj ->
                    case ArrayFun(JObj) of
                        'undefined' -> Acc;
                        Items -> validate_array(JObj, Name, ItemName, Items, Acc)
                    end
            end
    end.

validate_array(JObj, Name, ItemName, Array, Acc) ->
    {_, Items} = lists:foldl(validate_array_fun(Name, ItemName), {0, []}, Array),
    lists:foldr(validate_fun(JObj), Acc, Items).

validate_array_fun(Name, ItemName) ->
    fun(Item, {N, Acc}) ->
            {N+1, [{array_index_name(Name, ItemName, N), Item} | Acc]}
    end.

array_index_name(Name, ItemName, N) ->
    list_to_binary([Name, ".", ItemName, "[", kz_term:to_binary(N) ,"]"]).

validate_call_forward(Type, CallForward, Errors) ->
    CallForwardNumber = number(CallForward, <<>>),
    Enabled = enabled(CallForward),
    validate_enabled_setting(Enabled, CallForwardNumber, Type, Errors).

validate_enabled_setting('true', <<>>, Type, Errors) ->
    [{[<<"call_forward.", Type/binary, ".number">>]
     ,<<"required">>
     ,kz_json:from_list(
        [{<<"message">>, <<"Call forward number cannot be empty when call forward is enabled">>}
        ,{<<"value">>, <<>>}
        ])
     }
    ,{[<<"call_forward.", Type/binary, ".number">>]
     ,<<"minLength">>
     ,kz_json:from_list(
        [{<<"message">>, <<"Call forward number cannot be empty when call forward is enabled">>}
        ,{<<"cause">>, <<>>}
        ,{<<"value">>, <<>>}
        ,{<<"target">>, 3}
        ])
     }
    | Errors
    ];
validate_enabled_setting(_Enabled, _Number, _Index, Errors) -> Errors.

-spec merged_call_forward_settings(doc(), kz_term:api_object()) -> kz_term:api_object().
merged_call_forward_settings(_Top, 'undefined') -> 'undefined';
merged_call_forward_settings(Top, CfwdType) ->
    Properties = [{fun direct_calls_only/2, fun set_direct_calls_only/2}
                 ,{fun enabled/2, fun set_enabled/2}
                 ,{fun ignore_early_media/2, fun set_ignore_early_media/2}
                 ,{fun keep_caller_id/2, fun set_keep_caller_id/2}
                 ,{fun number/2, fun set_number/2}
                 ,{fun require_keypress/2, fun set_require_keypress/2}
                 ,{fun always_true/2, fun set_substitute/2}
                 ,{fun selective_rules/2, fun set_rules/2}
                 ],
    Merged = lists:foldl(merge_call_forward_setting_fun(CfwdType), Top, Properties),
    lists:foldl(merge_call_forward_setting_fun(Merged), kz_json:new(), Properties).

always_true(_, _) -> 'true'.

merge_call_forward_setting_fun(Override) ->
    fun({Getter, Setter}, MergedCfwd) ->
            case Getter(Override, 'undefined') of
                'undefined' -> MergedCfwd;
                Value -> Setter(MergedCfwd, Value)
            end
    end.

-spec is_legacy(kz_json:object()) -> boolean().
is_legacy(CallForward) ->
    Types = [fun unconditional/1
            ,fun no_answer/1
            ,fun busy/1
            ,fun selective/1
            ],
    not lists:any(fun(TypeFun) -> TypeFun(CallForward) =/= 'undefined' end, Types).

-type merged_getter() :: fun((kz_json:object()) -> kz_term:api_object()).

-spec merged(kz_json:object(), merged_getter()) -> kz_term:api_object().
merged(CallForward, Fun) ->
    merged(CallForward, Fun, 'undefined').

-spec merged(kz_json:object(), merged_getter(), Default) -> kz_json:object() | Default.
merged(CallForward, Fun, Default) ->
    case merged_call_forward_settings(CallForward, Fun(CallForward)) of
        'undefined' -> Default;
        JObj -> JObj
    end.
