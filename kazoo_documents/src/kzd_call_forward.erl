%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `call_forward' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_call_forward).

-export([new/0]).
-export([direct_calls_only/1, direct_calls_only/2, set_direct_calls_only/2]).
-export([enabled/1, enabled/2, set_enabled/2]).
-export([ignore_early_media/1, ignore_early_media/2, set_ignore_early_media/2]).
-export([keep_caller_id/1, keep_caller_id/2, set_keep_caller_id/2]).
-export([match_list/1, match_list/2, set_match_list/2]).
-export([match_list_enabled/1, match_list_enabled/2, set_match_list_enabled/2]).
-export([match_list_id/1, match_list_id/2, set_match_list_id/2]).
-export([number/1, number/2, set_number/2]).
-export([require_keypress/1, require_keypress/2, set_require_keypress/2]).
-export([substitute/1, substitute/2, set_substitute/2]).

-export([validate/1]).

-include("kz_documents.hrl").

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

-spec match_list(doc()) -> kz_term:api_object().
match_list(Doc) ->
    match_list(Doc, 'undefined').

-spec match_list(doc(), Default) -> kz_json:object() | Default.
match_list(Doc, Default) ->
    kz_json:get_json_value([<<"match_list">>], Doc, Default).

-spec set_match_list(doc(), kz_json:object()) -> doc().
set_match_list(Doc, MatchList) ->
    kz_json:set_value([<<"match_list">>], MatchList, Doc).

-spec match_list_enabled(doc()) -> kz_term:api_boolean().
match_list_enabled(Doc) ->
    match_list_enabled(Doc, 'undefined').

-spec match_list_enabled(doc(), Default) -> boolean() | Default.
match_list_enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"match_list">>, <<"enabled">>], Doc, Default).

-spec set_match_list_enabled(doc(), boolean()) -> doc().
set_match_list_enabled(Doc, MatchListEnabled) ->
    kz_json:set_value([<<"match_list">>, <<"enabled">>], MatchListEnabled, Doc).

-spec match_list_id(doc()) -> kz_term:api_binary().
match_list_id(Doc) ->
    match_list_id(Doc, 'undefined').

-spec match_list_id(doc(), Default) -> binary() | Default.
match_list_id(Doc, Default) ->
    kz_json:get_binary_value([<<"match_list">>, <<"id">>], Doc, Default).

-spec set_match_list_id(doc(), binary()) -> doc().
set_match_list_id(Doc, MatchListId) ->
    kz_json:set_value([<<"match_list">>, <<"id">>], MatchListId, Doc).

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

%% @doc validate an endpoint (account/user/device) doc's call forwarding settings
-spec validate(kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
validate({EndpointDoc, Errors}) ->
    validate_call_forward_settings(kzd_endpoint:call_forward(EndpointDoc, [])
                                  ,1
                                  ,{EndpointDoc, Errors}
                                  ).

validate_call_forward_settings([], _Index, Acc) -> Acc;
validate_call_forward_settings([CallForward | CallForwards], Index, {Doc, Errors}) ->
    CallForwardNumber = number(CallForward, <<>>),
    Enabled = kz_term:is_true(match_list_enabled(CallForward)),
    UpdatedErrors = validate_enabled_setting(Enabled, CallForwardNumber, Index, Errors),
    validate_call_forward_settings(CallForwards, Index+1, {Doc, UpdatedErrors}).

validate_enabled_setting('true', <<>>, Index, Errors) ->
    [{[<<"call_forward.", (kz_term:to_binary(Index))/binary, ".number">>]
     ,<<"required">>
     ,kz_json:from_list(
        [{<<"message">>, <<"Call forward number cannot be empty when call forward is enabled">>}
        ,{<<"value">>, <<>>}
        ])
     }
    ,{[<<"call_forward.", (kz_term:to_binary(Index))/binary, ".number">>]
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
