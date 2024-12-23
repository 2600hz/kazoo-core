%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_callflows).

-export([new/0]).
-export([featurecode/1, featurecode/2, set_featurecode/2]).
-export([featurecode_name/1, featurecode_name/2, set_featurecode_name/2]).
-export([featurecode_number/1, featurecode_number/2, set_featurecode_number/2]).
-export([flags/1, flags/2, set_flags/2]).
-export([flow/1, flow/2, set_flow/2]).
-export([metaflow/1, metaflow/2, set_metaflow/2]).
-export([name/1, name/2, set_name/2]).
-export([numbers/1, numbers/2, set_numbers/2]).
-export([owner_id/1, owner_id/2, set_owner_id/2]).
-export([patterns/1, patterns/2, set_patterns/2]).
-export([ringback/1, ringback/2, set_ringback/2]).
-export([ringback_early/1, ringback_early/2, set_ringback_early/2]).
-export([ringback_transfer/1, ringback_transfer/2, set_ringback_transfer/2]).
-export([ignore_progress/1, ignore_progress/2, set_ignore_progress/2]).

-export([type/0
        ,is_feature_code/1
        ,validate/1
        ,validate_flow/1
        ,prepend_preflow/2
        ,fetch/2
        ,validate/3

         %% Dynamically added per-call
        ,capture_group/1, capture_group/2, set_capture_group/2
        ,capture_groups/1, capture_groups/2, set_capture_groups/2
        ]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-type docs() :: [doc()].
-export_type([doc/0
             ,docs/0
             ]).

-define(KEY_NUMBERS, [<<"numbers">>]).
-define(KEY_PATTERNS, [<<"patterns">>]).

-define(SCHEMA, <<"callflows">>).

-define(PVT_TYPE, <<"callflow">>).

-define(LIST_BY_NUMBER, <<"callflows/listing_by_number">>).
-define(LIST_BY_PATTERN, <<"callflows/listing_by_pattern">>).

-spec new() -> doc().
new() ->
    kz_doc:update_pvt_parameters(kz_json_schema:default_object(?SCHEMA)
                                ,'undefined'
                                ,[{'type', type()}
                                 ,{'now', kz_time:now_s()}
                                 ]
                                ).

-spec type() -> kz_term:ne_binary().
type() -> ?PVT_TYPE.

-spec featurecode(doc()) -> kz_term:api_object().
featurecode(Doc) ->
    featurecode(Doc, 'undefined').

-spec featurecode(doc(), Default) -> kz_json:object() | Default.
featurecode(Doc, Default) ->
    kz_json:get_json_value([<<"featurecode">>], Doc, Default).

-spec set_featurecode(doc(), kz_json:object()) -> doc().
set_featurecode(Doc, Featurecode) ->
    kz_json:set_value([<<"featurecode">>], Featurecode, Doc).

-spec featurecode_name(doc()) -> kz_term:api_ne_binary().
featurecode_name(Doc) ->
    featurecode_name(Doc, 'undefined').

-spec featurecode_name(doc(), Default) -> kz_term:ne_binary() | Default.
featurecode_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"featurecode">>, <<"name">>], Doc, Default).

-spec set_featurecode_name(doc(), kz_term:ne_binary()) -> doc().
set_featurecode_name(Doc, FeaturecodeName) ->
    kz_json:set_value([<<"featurecode">>, <<"name">>], FeaturecodeName, Doc).

-spec featurecode_number(doc()) -> kz_term:api_ne_binary().
featurecode_number(Doc) ->
    featurecode_number(Doc, 'undefined').

-spec featurecode_number(doc(), Default) -> kz_term:ne_binary() | Default.
featurecode_number(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"featurecode">>, <<"number">>], Doc, Default).

-spec set_featurecode_number(doc(), kz_term:ne_binary()) -> doc().
set_featurecode_number(Doc, FeaturecodeNumber) ->
    kz_json:set_value([<<"featurecode">>, <<"number">>], FeaturecodeNumber, Doc).

-spec flags(doc()) -> kz_term:api_ne_binaries().
flags(Doc) ->
    flags(Doc, 'undefined').

-spec flags(doc(), Default) -> kz_term:ne_binaries() | Default.
flags(Doc, Default) ->
    kz_json:get_list_value([<<"flags">>], Doc, Default).

-spec set_flags(doc(), kz_term:ne_binaries()) -> doc().
set_flags(Doc, Flags) ->
    kz_json:set_value([<<"flags">>], Flags, Doc).

-spec flow(doc()) -> kz_term:api_object().
flow(Doc) ->
    flow(Doc, 'undefined').

-spec flow(doc(), Default) -> kz_json:object() | Default.
flow(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>], Doc, Default).

-spec set_flow(doc(), kz_json:object()) -> doc().
set_flow(Doc, Flow) ->
    kz_json:set_value([<<"flow">>], Flow, Doc).

-spec metaflow(doc()) -> kz_term:api_object().
metaflow(Doc) ->
    metaflow(Doc, 'undefined').

-spec metaflow(doc(), Default) -> kz_json:object() | Default.
metaflow(Doc, Default) ->
    kz_json:get_json_value([<<"metaflow">>], Doc, Default).

-spec set_metaflow(doc(), kz_json:object()) -> doc().
set_metaflow(Doc, Metaflow) ->
    kz_json:set_value([<<"metaflow">>], Metaflow, Doc).

-spec name(doc()) -> kz_term:api_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> binary() | Default.
name(Doc, Default) ->
    kz_json:get_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

-spec numbers(doc()) -> kz_term:ne_binaries().
numbers(Doc) ->
    numbers(Doc, []).

-spec numbers(doc(), Default) -> kz_term:ne_binaries() | Default.
numbers(Doc, Default) ->
    kz_json:get_list_value(?KEY_NUMBERS, Doc, Default).

-spec set_numbers(doc(), kz_term:ne_binaries()) -> doc().
set_numbers(Doc, Numbers) ->
    kz_json:set_value(?KEY_NUMBERS, Numbers, Doc).

-spec owner_id(doc()) -> kz_term:api_binary().
owner_id(Doc) ->
    owner_id(Doc, 'undefined').

-spec owner_id(doc(), Default) -> binary() | Default.
owner_id(Doc, Default) ->
    kz_json:get_binary_value([<<"owner_id">>], Doc, Default).

-spec set_owner_id(doc(), binary()) -> doc().
set_owner_id(Doc, OwnerId) ->
    kz_json:set_value([<<"owner_id">>], OwnerId, Doc).

-spec patterns(doc()) -> kz_term:ne_binaries().
patterns(Doc) ->
    patterns(Doc, []).

-spec patterns(doc(), Default) -> kz_term:ne_binaries() | Default.
patterns(Doc, Default) ->
    kz_json:get_list_value(?KEY_PATTERNS, Doc, Default).

-spec set_patterns(doc(), kz_term:ne_binaries()) -> doc().
set_patterns(Doc, Patterns) ->
    kz_json:set_value(?KEY_PATTERNS, Patterns, Doc).

-spec is_feature_code(doc()) -> boolean().
is_feature_code(Doc) ->
    featurecode(Doc, 'false') =/= 'false'.

-spec validate(doc()) ->
          {'ok', doc()} |
          {'error', kz_json_schema:validation_errors()}.
validate(Doc) ->
    case kz_json_schema:validate(<<"callflows">>, Doc) of
        {'ok', _}= OK -> OK;
        {'error', Errors} -> {'error', kz_json_schema:errors_to_jobj(Errors)}
    end.

-ifdef(TEST).
-spec validate_flow(doc()) -> {'ok', doc()} | {'error', list()}.
validate_flow(Doc) ->
    case kz_json_schema:validate(<<"callflows.action">>
                                ,flow(Doc)
                                ,[{'schema_loader_fun', fun schema_test_load/1}
                                 ,{'allowed_errors', 'infinity'}
                                 ])
    of
        {'ok', JObj} -> {'ok', set_flow(Doc, JObj)};
        {'error', Errors} -> {'error', Errors}
    end.

schema_test_load(Schema) when not is_binary(Schema) ->
    schema_test_load(kz_term:to_binary(Schema));
schema_test_load(<<"file://", Schema/binary>>) -> schema_test_load(Schema);
schema_test_load(<<"callflows.test">> = Schema) ->
    {'ok', kz_json:insert_value(<<"id">>, Schema, ?SCHEMA_JOBJ)};
schema_test_load(Schema) ->
    kz_json_schema:fload(Schema).
-else.
-spec validate_flow(doc()) ->
          {'ok', doc()} |
          {'error', kz_json_schema:validation_errors()}.
validate_flow(Doc) ->
    case kz_json_schema:validate(<<"callflows.action">>, flow(Doc)) of
        {'ok', JObj} -> {'ok', set_flow(Doc, JObj)};
        {'error', Errors} -> {'error', kz_json_schema:errors_to_jobj(Errors)}
    end.
-endif.

-spec prepend_preflow(doc(), kz_term:ne_binary()) -> doc().
prepend_preflow(Callflow, PreflowId) ->
    AmendedFlow =
        kz_json:from_list([{<<"module">>, <<"callflow">>}
                          ,{<<"data">>, kz_json:from_list([{<<"id">>, PreflowId}])}
                          ,{<<"children">>, kz_json:from_list([{<<"_">>, flow(Callflow)}])}
                          ]),
    set_flow(Callflow, AmendedFlow).

-spec ringback(doc()) -> kz_term:api_object().
ringback(Doc) ->
    ringback(Doc, 'undefined').

-spec ringback(doc(), Default) -> kz_json:object() | Default.
ringback(Doc, Default) ->
    kz_json:get_json_value([<<"ringback">>], Doc, Default).

-spec set_ringback(doc(), kz_json:object()) -> doc().
set_ringback(Doc, Ringback) ->
    kz_json:set_value([<<"ringback">>], Ringback, Doc).

-spec ringback_early(doc()) -> kz_term:api_binary().
ringback_early(Doc) ->
    ringback_early(Doc, 'undefined').

-spec ringback_early(doc(), Default) -> binary() | Default.
ringback_early(Doc, Default) ->
    kz_json:get_binary_value([<<"ringback">>, <<"early">>], Doc, Default).

-spec set_ringback_early(doc(), binary()) -> doc().
set_ringback_early(Doc, RingbackEarly) ->
    kz_json:set_value([<<"ringback">>, <<"early">>], RingbackEarly, Doc).

-spec ringback_transfer(doc()) -> kz_term:api_binary().
ringback_transfer(Doc) ->
    ringback_transfer(Doc, 'undefined').

-spec ringback_transfer(doc(), Default) -> binary() | Default.
ringback_transfer(Doc, Default) ->
    kz_json:get_binary_value([<<"ringback">>, <<"transfer">>], Doc, Default).

-spec set_ringback_transfer(doc(), binary()) -> doc().
set_ringback_transfer(Doc, RingbackTransfer) ->
    kz_json:set_value([<<"ringback">>, <<"transfer">>], RingbackTransfer, Doc).

-spec capture_group(doc()) -> kz_term:api_ne_binary().
capture_group(Doc) ->
    capture_group(Doc, 'undefined').

-spec capture_group(doc(), Default) -> kz_term:ne_binary() | Default.
capture_group(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"capture_group">>], Doc, Default).

-spec set_capture_group(doc(), kz_term:ne_binary()) -> doc().
set_capture_group(Doc, CaptureGroup) ->
    kz_json:set_value([<<"capture_group">>], CaptureGroup, Doc).

-spec capture_groups(doc()) -> kz_term:api_object().
capture_groups(Doc) ->
    capture_groups(Doc, 'undefined').

-spec capture_groups(doc(), Default) -> kz_json:object() | Default.
capture_groups(Doc, Default) ->
    kz_json:get_json_value([<<"capture_groups">>], Doc, Default).

-spec set_capture_groups(doc(), kz_json:object()) -> doc().
set_capture_groups(Doc, CaptureGroups) ->
    kz_json:set_value([<<"capture_groups">>], CaptureGroups, Doc).

-spec ignore_progress(doc()) -> kz_term:api_boolean().
ignore_progress(Doc) ->
    ignore_progress(Doc, 'undefined').

-spec ignore_progress(doc(), Default) -> boolean() | Default.
ignore_progress(Doc, Default) ->
    kz_json:get_boolean_value([<<"ignore_progress">>], Doc, Default).

-spec set_ignore_progress(doc(), kz_term:api_boolean()) -> doc().
set_ignore_progress(Doc, IgnoreProgress) ->
    kz_json:set_value([<<"ignore_progress">>], IgnoreProgress, Doc).

%%------------------------------------------------------------------------------
%% @doc Fetch a callflow from cache.
%% @end
%%------------------------------------------------------------------------------
-spec fetch(kz_term:api_ne_binary(), kz_term:api_ne_binary()) ->
          {'ok', doc()} |
          kz_datamgr:data_error().
fetch('undefined', _CallflowId) ->
    {'error', 'invalid_db_name'};
fetch(_Account, 'undefined') ->
    {'error', 'not_found'};
fetch(Account, <<CallflowId/binary>>) ->
    AccountDb = kzs_util:format_account_db(Account),
    kz_datamgr:open_cache_doc(AccountDb, CallflowId).

%%------------------------------------------------------------------------------
%% @doc Validate a requested callflow can be created
%%
%% Returns the updated callflow doc (with relevant defaults)
%% or returns the validation error {Path, ErrorType, ErrorMessage}
%% @end
%%------------------------------------------------------------------------------
-spec validate(kz_term:ne_binary(), kz_term:api_ne_binary(), doc()) ->
          kazoo_documents:doc_validation_return().
validate(<<AccountId/binary>>, CallflowId, ReqJObj) ->
    ValidateFuns = [fun validate_either_numbers_or_patterns_is_set/3
                   ,fun maybe_validate_numbers/3
                   ,fun maybe_validate_patterns/3
                   ,fun validate_schema/3
                   ],
    try do_validation(AccountId, CallflowId, ReqJObj, ValidateFuns) of
        {CallflowDoc, []} -> {'true', CallflowDoc};
        {_CallflowDoc, ValidationErrors} ->
            {'validation_errors', ValidationErrors}
    catch
        'throw':SystemError -> SystemError
    end.

-spec do_validation(kz_term:ne_binary(), kz_term:api_ne_binary(), doc(), [kazoo_documents:doc_validation_fun()]) ->
          kazoo_documents:doc_validation_acc().
do_validation(AccountId, CallflowId, ReqJObj, ValidateFuns) ->
    lists:foldl(fun(F, Acc) -> F(AccountId, CallflowId, Acc) end
               ,{ReqJObj, []}
               ,ValidateFuns
               ).

%%------------------------------------------------------------------------------
%% @doc Validate that either of the callflow's `numbers' or `patterns' attribute
%% is set and has at least one list element.
%% @end
%%------------------------------------------------------------------------------
-spec validate_either_numbers_or_patterns_is_set(kz_term:ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
validate_either_numbers_or_patterns_is_set(_AccountId, _CallflowId, {Doc, Errors}=ValidateAcc) ->
    case {numbers(Doc, []), patterns(Doc, [])} of
        {[], []} ->
            lager:warning("callflows must be assigned at least one number or pattern"),
            Msg = kz_json:from_list(
                    [{<<"message">>, <<"Callflows must be assigned at least one number or pattern">>}]
                   ),
            {Doc, [{?KEY_NUMBERS, <<"required">>, Msg} | Errors]};
        {_Numbers, _Patterns} ->
            ValidateAcc
    end.

%%------------------------------------------------------------------------------
%% @doc If set, run all validation functions on the field `numbers'.
%% First verify the `numbers' value is a non empty list, If it is then do
%% further validation on the numbers list, if it is not then skip all further
%% number validation steps.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_validate_numbers(kz_term:ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
maybe_validate_numbers(AccountId, CallflowId, {Doc, _Errors}=ValidateAcc) ->
    case kz_json:get_value(?KEY_NUMBERS, Doc, 'undefined') of
        'undefined' ->
            lager:debug("callflow's ~p is not defined, skipping further number validation", [?KEY_NUMBERS]),
            ValidateAcc;
        [] ->
            lager:debug("callflow's ~p is an empty list, skipping further number validation", [?KEY_NUMBERS]),
            ValidateAcc;
        Numbers when is_list(Numbers) ->
            lager:debug("callflow's ~p is a non empty list, running further number validation", [?KEY_NUMBERS]),
            do_further_number_validation(AccountId, CallflowId, ValidateAcc);
        Numbers ->
            %% No need to add error as this will be added by schema check
            lager:warning("validation error, callflow's ~p is not of type list, value: ~p, skipping further number validation"
                         ,[?KEY_NUMBERS, Numbers]
                         ),
            ValidateAcc
    end.

%%------------------------------------------------------------------------------
%% @doc Run all number validation functions on the list field `numbers'.
%% @end
%%------------------------------------------------------------------------------
-spec do_further_number_validation(kz_term:ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
do_further_number_validation(AccountId, CallflowId, {_Doc, _Errors}=ValidateAcc) ->
    NumValidateFuns = [fun normalize_numbers/3
                      ,fun(AID, CID, Acc) ->
                               maybe_validate_attribute_list_is_unique_within_account_callflows(?KEY_NUMBERS, AID, CID, Acc)
                       end
                      ,fun validate_number_ownership/3
                      ],
    lists:foldl(fun(F, Acc) -> F(AccountId, CallflowId, Acc) end
               ,ValidateAcc
               ,NumValidateFuns
               ).

%%------------------------------------------------------------------------------
%% @doc Normalize the numbers in the `numbers' list.
%% @end
%%------------------------------------------------------------------------------
-spec normalize_numbers(kz_term:ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
normalize_numbers(AccountId, _CallflowId, {Doc, Errors}) ->
    lager:debug("normalizing callflow's numbers"),
    Normalized = knm_converters:normalize(numbers(Doc, []), AccountId),
    {set_numbers(Doc, Normalized), Errors}.

%%------------------------------------------------------------------------------
%% @doc Validate that all numbers set are owned by the account.
%% @end
%%------------------------------------------------------------------------------
-spec validate_number_ownership(kz_term:ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
validate_number_ownership(AccountId, _CallflowId, {Doc, _Errors}=ValidateAcc) ->
    Numbers = numbers(Doc, []),
    lager:debug("validating number ownership for numbers ~p", [Numbers]),
    case knm_numbers:validate_ownership(AccountId, Numbers) of
        'true' -> ValidateAcc;
        {'false', Unauthorized} ->
            lager:error("numbers ~p are not owned by the account ~p", [Unauthorized, AccountId]),
            Prefix = <<"unauthorized to use ">>,
            NumbersStr = kz_binary:join(Unauthorized, <<", ">>),
            Message = <<Prefix/binary, NumbersStr/binary>>,
            throw({'system_error', {'forbidden', Message}})
    end.

%%------------------------------------------------------------------------------
%% @doc If set, run all validation functions on the field `patterns'.
%% First verify the `patterns' value is a non empty list, If it is then do
%% further validation on the patterns list, if it is not then skip all further
%% pattern validation steps.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_validate_patterns(kz_term:ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
maybe_validate_patterns(AccountId, CallflowId, {Doc, _Errors}=ValidateAcc) ->
    case kz_json:get_value(?KEY_PATTERNS, Doc, 'undefined') of
        'undefined' ->
            lager:debug("callflow's ~p is not defined, skipping further pattern validation", [?KEY_PATTERNS]),
            ValidateAcc;
        [] ->
            lager:debug("callflow's ~p is an empty list, skipping further pattern validation", [?KEY_PATTERNS]),
            ValidateAcc;
        Patterns when is_list(Patterns) ->
            lager:debug("callflow's ~p is a non empty list, running further pattern validation", [?KEY_PATTERNS]),
            do_further_pattern_validation(AccountId, CallflowId, ValidateAcc);
        Patterns ->
            %% No need to add error as this will be added by schema check
            lager:warning("validation error, callflow's ~p is not of type list, value: ~p, skipping further pattern validation"
                         ,[?KEY_PATTERNS, Patterns]
                         ),
            ValidateAcc
    end.

%%------------------------------------------------------------------------------
%% @doc Run all pattern validation functions on the list field `patterns'.
%% @end
%%------------------------------------------------------------------------------
-spec do_further_pattern_validation(kz_term:ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
do_further_pattern_validation(AccountId, CallflowId, {_Doc, _Errors}=ValidateAcc) ->
    ValidateFuns = [fun(AID, CID, Acc) ->
                            maybe_validate_attribute_list_is_unique_within_account_callflows(?KEY_PATTERNS, AID, CID, Acc)
                    end
                   ],
    lists:foldl(fun(F, Acc) -> F(AccountId, CallflowId, Acc) end
               ,ValidateAcc
               ,ValidateFuns
               ).

%%------------------------------------------------------------------------------
%% @doc Validate each of the callflow's `patterns' or `numbers' is unique within
%% the account's callflows.
%% First check if the patterns / numbers have changed from the current callflow
%% doc.
%% If they have not changed then skip any further checks,
%% If they have changed or its a new callflow then verify each of the patterns /
%% numbers is not used in any of the other callflows within the account.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_validate_attribute_list_is_unique_within_account_callflows(
        kz_json:get_key()
       ,kz_term:ne_binary()
       ,kz_term:api_ne_binary()
       ,kazoo_documents:doc_validation_acc()
       ) ->
          kazoo_documents:doc_validation_acc().
maybe_validate_attribute_list_is_unique_within_account_callflows(Key, AccountId, CallflowId, {Doc, _Errors}=ValidateAcc) ->
    NewValue = kz_json:get_list_value(Key, Doc, 'undefined'),
    CurrentValue = case fetch(AccountId, CallflowId) of
                       {'ok', CurrentDoc} -> kz_json:get_list_value(Key, CurrentDoc, []);
                       {'error', _R} -> 'undefined'
                   end,
    case not kz_term:is_empty(CurrentValue)
        andalso (length(NewValue) =:= length(CurrentValue))
        andalso ((NewValue -- CurrentValue) =:= [])
    of
        'true' when NewValue =:= 'undefined' ->
            lager:debug("~p is not set on callflow, skipping unique ~p checks", [Key, Key]),
            ValidateAcc;
        'true' ->
            lager:debug("~p '~p' (currently '~p') has not changed from the current callflow, skipping unique checks"
                       ,[Key, NewValue, CurrentValue]),
            ValidateAcc;
        'false' when CurrentValue =:= 'undefined' ->
            lager:debug("new callflow with ~p '~p', running unique checks", [Key, NewValue]),
            do_validate_attribute_list_is_unique_within_account_callflows(Key, AccountId, CallflowId, ValidateAcc);
        'false' ->
            lager:debug("~p '~p' (currently '~p') have changed from the current callflow, running unique checks"
                       ,[Key, NewValue, CurrentValue]),
            do_validate_attribute_list_is_unique_within_account_callflows(Key, AccountId, CallflowId, ValidateAcc)
    end.

%%------------------------------------------------------------------------------
%% @doc Check the callflow's `patterns' or `numbers' against the accounts
%% callflows in the db.
%% If any of the patterns / numbers are found in other callflows then add an
%% error to the `doc_validation_acc()' for each pattern conflict.
%% @end
%%------------------------------------------------------------------------------
-spec do_validate_attribute_list_is_unique_within_account_callflows(
        kz_json:get_key()
       ,kz_term:ne_binary()
       ,kz_term:api_ne_binary()
       ,kazoo_documents:doc_validation_acc()
       ) -> kazoo_documents:doc_validation_acc().
do_validate_attribute_list_is_unique_within_account_callflows(Key, AccountId, CallflowId, {Doc, _Errors}=ValidateAcc) ->
    AccountDb = kzs_util:format_account_db(AccountId),
    Options = [{'keys', kz_json:get_list_value(Key, Doc, [])}],
    View = get_view_by(Key),
    case kz_datamgr:get_results(AccountDb, View, Options) of
        {'ok', []} ->
            ValidateAcc;
        {'ok', CallflowViews} ->
            validate_attribute_conflicts(Key, CallflowViews, CallflowId, ValidateAcc);
        {'error', Error} ->
            lager:error("failed to load view ~s from account ~s, error: ~p", [View, AccountDb, Error]),
            throw({'system_error', Error})
    end.

%%------------------------------------------------------------------------------
%% @doc Get the DB view name for callflows listed by `numbers' or `patterns'.
%% @end
%%------------------------------------------------------------------------------
-spec get_view_by(kz_json:get_key()) -> kz_term:ne_binary().
get_view_by(?KEY_NUMBERS) -> ?LIST_BY_NUMBER;
get_view_by(?KEY_PATTERNS) -> ?LIST_BY_PATTERN.

%%------------------------------------------------------------------------------
%% @doc Validate the `numbers' or `patterns' conflicts are not part of its own
%% callflow.
%% If the conflict is part of its own callflow then ignore, else add the
%% conflict errors to the `doc_validation_acc()'
%% @end
%%------------------------------------------------------------------------------
-spec validate_attribute_conflicts(kz_json:get_key(), kz_json:objects(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
validate_attribute_conflicts(Key, CallflowViews, 'undefined', ValidateAcc) ->
    add_attribute_conflict_errors(Key, CallflowViews, ValidateAcc);
validate_attribute_conflicts(Key, CallflowViews, CallflowId, ValidateAcc) ->
    ConflictingViewObj = filter_callflow_list(CallflowId, CallflowViews),
    add_attribute_conflict_errors(Key, ConflictingViewObj, ValidateAcc).

%%------------------------------------------------------------------------------
%% @doc Remove any callflows from a list of callflows where the callflow's id
%% value equals the supplied `CallflowId'.
%% @end
%%------------------------------------------------------------------------------
-spec filter_callflow_list(kz_term:ne_binary(), kz_json:objects()) -> kz_json:objects().
filter_callflow_list(CallflowId, Callflows) ->
    [Callflow
     || Callflow <- Callflows,
        kz_doc:id(Callflow) =/= CallflowId
    ].

%%------------------------------------------------------------------------------
%% @doc Add only limited no of `numbers' or `patterns' conflict errors to the
%% `doc_validation_acc()'.
%% @end
%%------------------------------------------------------------------------------
-spec add_attribute_conflict_errors(kz_json:get_key(), docs(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
add_attribute_conflict_errors(_Key, [], ValidateAcc) -> ValidateAcc;
add_attribute_conflict_errors(Key, [CallflowView | CallflowViews], ValidateAcc)
  when length(ValidateAcc) < 50 ->
    UpdatedValidateAcc = add_attribute_conflict_error(Key, CallflowView, ValidateAcc),
    add_attribute_conflict_errors(Key, CallflowViews, UpdatedValidateAcc);
add_attribute_conflict_errors(_Key, _CallflowViews, ValidateAcc) ->
    ValidateAcc.

%%------------------------------------------------------------------------------
%% @doc Add a `numbers' or `patterns' conflict error to the
%% `doc_validation_acc()'.
%% @end
%%------------------------------------------------------------------------------
-spec add_attribute_conflict_error(kz_json:get_key(), doc(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
add_attribute_conflict_error(Key, CallflowView, {Doc, Errors}) ->
    Id = kz_doc:id(CallflowView),
    Name = kz_json:get_ne_binary_value([<<"value">>, <<"name">>], CallflowView, <<>>),
    Number = kz_json:get_value(<<"key">>, CallflowView),
    lager:warning("validation error, ~p ~p exists in callflow ~s (~s)", [Key, Number, Id, Name]),
    Msg = kz_json:from_list(
            [{<<"message">>, <<Number/binary, " exists in callflow ", Id/binary, " (", Name/binary, ")">>}
            ,{<<"cause">>, Number}
            ]),
    {Doc, [{Key, <<"unique">>, Msg} | Errors]}.

%%------------------------------------------------------------------------------
%% @doc Verify the doc against the callflow doc schema.
%% On Success merge the private fields from the current user doc into Doc.
%% @end
%%------------------------------------------------------------------------------
-spec validate_schema(kz_term:api_ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
validate_schema(AccountId, CallflowId, {_Doc, _Errors}=ValidateAcc) ->
    lager:debug("checking callflow doc against schema"),
    OnSuccess = fun(ValAcc) -> on_successful_schema_validation(AccountId, CallflowId, ValAcc) end,
    kzd_module_utils:validate_schema(<<"callflows">>, ValidateAcc, OnSuccess).

%%------------------------------------------------------------------------------
%% @doc Executed after `validate_schema/3' if it passes schema validation.
%% If the callflow Id is defined then merge the current callflow doc's private
%% fields into `Doc'.
%% @end
%%------------------------------------------------------------------------------
-spec on_successful_schema_validation(kz_term:api_ne_binary(), kz_term:api_ne_binary(), kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
on_successful_schema_validation(_AccountId, 'undefined', {Doc, Errors}) ->
    lager:debug("new callflow doc passed schema validation"),
    {kz_doc:set_type(Doc, type()), Errors};
on_successful_schema_validation(AccountId, UserId, {Doc, Errors}) ->
    lager:debug("updated callflow doc passed schema validation"),
    UpdatedDoc = maybe_merge_current_private_fields(AccountId, UserId, Doc),
    {UpdatedDoc, Errors}.

%%------------------------------------------------------------------------------
%% @doc Merge the current (cached) doc's private fields into Doc. If the current
%% doc can not be found by Account Id and User Id, then return the unaltered
%% Doc.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_merge_current_private_fields(kz_term:ne_binary(), kz_term:ne_binary(), doc()) -> doc().
maybe_merge_current_private_fields(AccountId, CallflowId, Doc) ->
    case fetch(AccountId, CallflowId) of
        {'ok', CurrentDoc} ->
            kz_json:merge_jobjs(kz_doc:private_fields(CurrentDoc), Doc);
        {'error', _R} -> Doc
    end.
