%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc
%%% @author Peter Defebvre
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_converters).

-include("knm.hrl").

-export([normalize/1, normalize/2, normalize/3
        ,is_normalized/1
        ,is_npan/1, to_npan/1
        ,is_1npan/1, to_1npan/1
        ,is_strip_plus/1, to_strip_plus/1
        ,to_db/1
        ,is_reconcilable/1, is_reconcilable/2, are_reconcilable/1
        ,classify/1, available_classifiers/0, migrate_classifiers/0
        ,available_converters/0
        ,default_converter/0
        ]).

-ifdef(TEST).
-export([available_classifiers/1, migrate_classifiers/1]).
-endif.

-define(DEFAULT_CONVERTER_B, <<"regex">>).
-define(DEFAULT_CONVERTERS, [?DEFAULT_CONVERTER_B]).

-define(DEFAULT_RECONCILE_REGEX, <<"^(\\+?1)?\\d{10}$|^\\+[2-9]\\d{7,}$|^011\\d*$|^00\\d*$">>).
-define(KEY_RECONCILE_REGEX, <<"reconcile_regex">>).

-define(CLASSIFIER_TOLLFREE_US,
        kz_json:from_list([{<<"regex">>, <<"^\\+1((?:800|88\\d|877|866|855|844|833|822)\\d{7})\$">>}
                          ,{<<"friendly_name">>, <<"US TollFree">>}
                          ,{<<"pretty_print">>, ?PRETTY_PRINT_FORMAT_NANP}
                          ,{<<"name">>, <<"tollfree_us">>}
                          ])).

-define(CLASSIFIER_TOLL_US,
        kz_json:from_list([{<<"regex">>, <<"^\\+1(900\\d{7})\$">>}
                          ,{<<"friendly_name">>, <<"US Toll">>}
                          ,{<<"pretty_print">>, ?PRETTY_PRINT_FORMAT_NANP}
                          ,{<<"name">>, <<"toll_us">>}
                          ])).

-define(CLASSIFIER_EMERGENCY,
        kz_json:from_list([{<<"regex">>, <<"^(911|922|933|988|833|811|711|999)\$">>}
                          ,{<<"emergency">>, 'true'}
                          ,{<<"friendly_name">>, <<"Emergency Dispatcher">>}
                          ,{<<"name">>, <<"emergency">>}
                          ])).

-define(CLASSIFIER_CARIBBEAN,
        kz_json:from_list([{<<"regex">>, <<"^\\+?1((?:684|264|268|242|246|441|284|345|767|809|829|849|473|671|876|664|670|787|939|869|758|784|721|868|649|340)\\d{7})\$">>}
                          ,{<<"friendly_name">>, <<"Caribbean">>}
                          ,{<<"pretty_print">>, ?PRETTY_PRINT_FORMAT_NANP}
                          ,{<<"name">>, <<"caribbean">>}
                          ])).

-define(CLASSIFIER_DID_US,
        kz_json:from_list([{<<"regex">>, <<"^(\\+?1)?([2-9][0-9]{2}[2-9][0-9]{6})\$">>}
                          ,{<<"friendly_name">>, <<"US DID">>}
                          ,{<<"pretty_print">>, ?PRETTY_PRINT_FORMAT_NANP}
                          ,{<<"name">>, <<"did_us">>}
                          ])).

-define(CLASSIFIER_INTERNATIONAL,
        kz_json:from_list([{<<"regex">>, <<"^\\+([2-9]\\d{7,})\$">>}
                          ,{<<"friendly_name">>, <<"International">>}
                          ,{<<"name">>, <<"international">>}
                          ])).

-define(CLASSIFIER_UNKNOWN,
        kz_json:from_list([{<<"regex">>, <<"^(.*)\$">>}
                          ,{<<"friendly_name">>, <<"Unknown">>}
                          ,{<<"name">>, <<"unknown">>}
                          ])).

-define(DEFAULT_CLASSIFIERS,
        [?CLASSIFIER_TOLLFREE_US
        ,?CLASSIFIER_TOLL_US
        ,?CLASSIFIER_EMERGENCY
        ,?CLASSIFIER_CARIBBEAN
        ,?CLASSIFIER_DID_US
        ,?CLASSIFIER_INTERNATIONAL
        ,?CLASSIFIER_UNKNOWN
        ]).

-define(DEFAULT_CONVERTER
       ,kapps_config:get_ne_binary(?KNM_CONFIG_CAT, <<"converter">>, ?DEFAULT_CONVERTER_B)
       ).
-define(RECONCILE_REGEX
       ,kapps_config:get_ne_binary(?KNM_CONFIG_CAT, ?KEY_RECONCILE_REGEX, ?DEFAULT_RECONCILE_REGEX)
       ).

-ifdef(TEST).
%% Orders of classifiers matters, but unfortunately schema file system_config.number_manager.json
%% is being sorted on Kazoo compile so we need to access the macro directly here for testing purposes.
-define(CLASSIFIERS, ?DEFAULT_CLASSIFIERS).
-else.
-define(CLASSIFIERS
       ,kapps_config:get(?KNM_CONFIG_CAT, <<"classifiers">>, ?DEFAULT_CLASSIFIERS)
       ).
-endif.

-define(RECONCILE_REGEX(AccountId)
       ,kapps_account_config:get_global(AccountId, ?KNM_CONFIG_CAT, ?KEY_RECONCILE_REGEX, ?DEFAULT_RECONCILE_REGEX)
       ).

-define(CONVERTER_MOD, kz_term:to_atom(<<"knm_converter_", (?DEFAULT_CONVERTER)/binary>>, 'true')).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec normalize(binary()) -> binary();
               (kz_term:binaries()) -> kz_term:binaries().
normalize(<<>>) -> <<>>;
normalize(Num=?NE_BINARY) ->
    (?CONVERTER_MOD):normalize(Num);
normalize(Nums)
  when is_list(Nums) ->
    [normalize(Num) || Num <- Nums].

-spec normalize(kz_term:ne_binary(), kz_term:api_ne_binary()) -> kz_term:ne_binary();
               (kz_term:ne_binaries(), kz_term:api_ne_binary()) -> kz_term:ne_binaries().
normalize(Num=?NE_BINARY, 'undefined') ->
    normalize(Num);
normalize(Num=?NE_BINARY, AccountId) ->
    (?CONVERTER_MOD):normalize(Num, AccountId);
normalize(Nums, 'undefined')
  when is_list(Nums) ->
    normalize(Nums);
normalize(Nums, AccountId)
  when is_list(Nums) ->
    [normalize(Num, AccountId) || Num <- Nums].

-spec normalize(kz_term:ne_binary() | kz_term:ne_binaries()
               ,kz_term:ne_binary()
               ,kz_term:api_ne_binary() | kz_json:object()
               ) ->
          kz_term:ne_binary() |
          kz_term:ne_binaries().
normalize(Num=?NE_BINARY, ?MATCH_ACCOUNT_RAW(AccountId), DialPlan) ->
    (?CONVERTER_MOD):normalize(Num, AccountId, DialPlan);
normalize(Nums, ?MATCH_ACCOUNT_RAW(AccountId), DialPlan)
  when is_list(Nums) ->
    [normalize(Num, AccountId, DialPlan) || Num <- Nums].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec is_normalized(kz_term:ne_binary()) -> boolean().
is_normalized(Num) ->
    normalize(Num) =:= Num.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec is_npan(kz_term:ne_binary()) -> boolean().
is_npan(Num) ->
    to_npan(Num) =:= Num.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec to_npan(kz_term:ne_binary()) -> kz_term:ne_binary().
to_npan(Num) ->
    (?CONVERTER_MOD):to_npan(Num).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec is_1npan(kz_term:ne_binary()) -> boolean().
is_1npan(Num) ->
    to_1npan(Num) =:= Num.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec to_1npan(kz_term:ne_binary()) -> kz_term:ne_binary().
to_1npan(Num) ->
    (?CONVERTER_MOD):to_1npan(Num).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec is_strip_plus(kz_term:ne_binary()) -> boolean().
is_strip_plus(Num) ->
    to_strip_plus(Num) =:= Num.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec to_strip_plus(kz_term:ne_binary()) -> kz_term:ne_binary().
to_strip_plus(Num) ->
    (?CONVERTER_MOD):to_strip_plus(Num).

%%------------------------------------------------------------------------------
%% @doc Given a number determine the database name it belongs to..
%% @end
%%------------------------------------------------------------------------------
-spec to_db(<<_:40,_:_*8>>) -> kz_term:api_binary().
to_db(<<NumPrefix:5/binary, _/binary>>) ->
    kz_http_util:urlencode(<<?KNM_DB_PREFIX, NumPrefix/binary>>);
to_db(_) -> 'undefined'.

%%------------------------------------------------------------------------------
%% @doc Returns `{Reconcilables, NotReconcilables}'.
%% @end
%%------------------------------------------------------------------------------
-spec are_reconcilable(kz_term:ne_binaries()) -> {kz_term:ne_binaries(), kz_term:ne_binaries()}.
are_reconcilable(Nums) ->
    lists:partition(fun is_reconcilable/1, Nums).

%%------------------------------------------------------------------------------
%% @doc Is the number recognized as "global" number or a "local" extension
%% @end
%%------------------------------------------------------------------------------
-spec is_reconcilable(kz_term:ne_binary()) -> boolean().
is_reconcilable(Number) ->
    is_reconcilable_by_regex(Number, ?RECONCILE_REGEX).

-spec is_reconcilable(kz_term:ne_binary(), kz_term:ne_binary()) -> boolean().
is_reconcilable(Number, AccountId) ->
    is_reconcilable_by_regex(Number, ?RECONCILE_REGEX(AccountId)).

is_reconcilable_by_regex(Num, Regex) ->
    case re:run(Num, Regex) of
        'nomatch' -> 'false';
        _ -> 'true'
    end.


%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec classify(kz_term:ne_binary()) -> kz_term:api_binary().
classify(Number) ->
    Num = normalize(Number),
    classify_number(Num, available_classifiers()).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec available_classifiers() -> kz_json:objects().
available_classifiers() ->
    available_classifiers(?CLASSIFIERS).

-spec available_classifiers(kz_json:objects()) -> kz_json:objects().
available_classifiers(Cs) when is_list(Cs) -> Cs;
available_classifiers(Cs) ->
    Updated = kz_json:foldl(fun correct_depreciated_classifiers/3, kz_json:new(), Cs),
    {Classifiers, _Names} = kz_json:get_values(Updated),
    Classifiers.

-spec migrate_classifiers() -> boolean().
migrate_classifiers() ->
    migrate_classifiers(?CLASSIFIERS).

migrate_classifiers(Cs) when is_list(Cs) ->
    ensure_classifiers_format(Cs);
migrate_classifiers(Cs) ->
    lager:info("migrating classifiers to list of objects"),
    Migrated = available_classifiers(Cs),
    ensure_classifiers_format(Migrated).

ensure_classifiers_format(Cs) ->
    case lists:all(fun ensure_classifier_format/1, Cs) of
        'false' ->
            lager:warning("migration of classifiers failed"),
            'false';
        'true' ->
            {'ok', _} = kapps_config:set_default(?KNM_CONFIG_CAT, <<"classifiers">>, Cs),
            lager:info("classifiers migrated successfully"),
            'true'
    end.

ensure_classifier_format(Classifier) ->
    case 'undefined' =/= kz_json:get_ne_binary_value(<<"name">>, Classifier)
        andalso 'undefined' =/= kz_json:get_ne_binary_value(<<"regex">>, Classifier)
    of
        'true' -> 'true';
        'false' ->
            lager:warning("classifier is not in expected format: ~p", [Classifier]),
            'false'
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec available_converters() -> kz_term:ne_binaries().
available_converters() ->
    kapps_config:get_ne_binaries(?KNM_CONFIG_CAT, <<"converters">>, ?DEFAULT_CONVERTERS).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec default_converter() -> atom().
default_converter() -> ?CONVERTER_MOD.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec classify_number(kz_term:ne_binary(), kz_json:objects()) -> kz_term:api_binary().
classify_number(Num, []) ->
    lager:debug("unable to classify number ~s", [Num]),
    'undefined';
classify_number(Num, [Classifier|Classifiers]) ->
    Regex = get_classifier_regex(Classifier),
    case re:run(Num, Regex) of
        'nomatch' ->
            classify_number(Num, Classifiers);
        _ ->
            Classification = kz_json:get_ne_binary_value(<<"name">>, Classifier),
            lager:debug("number '~s' is classified as ~s(~s)", [Num, Classification, Regex]),
            kz_term:to_binary(Classification)
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec get_classifier_regex(kz_json:object()) -> kz_term:ne_binary().
get_classifier_regex(JObj) ->
    kz_json:get_ne_binary_value(<<"regex">>, JObj, <<"^$">>).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec correct_depreciated_classifiers(kz_json:key(), kz_json:json_term(), kz_json:object()) ->
          kz_json:object().
correct_depreciated_classifiers(ClassifierName, <<Regex/binary>>, CorrectedClassifiers) ->
    ClassifierSettings = kz_json:from_list([{<<"regex">>, Regex}
                                           ,{<<"friendly_name">>, ClassifierName}
                                           ,{<<"name">>, ClassifierName}
                                           ]),
    kz_json:set_value(ClassifierName, ClassifierSettings, CorrectedClassifiers);
correct_depreciated_classifiers(ClassifierName, ClassifierSettings, CorrectedClassifiers) ->
    case kz_json:get_value(<<"friendly_name">>, ClassifierSettings) of
        'undefined' ->
            UpdatedSettings = kz_json:set_values([{<<"friendly_name">>, ClassifierName}
                                                 ,{<<"name">>, ClassifierName}
                                                 ]
                                                ,ClassifierSettings
                                                ),
            kz_json:set_value(ClassifierName, UpdatedSettings, CorrectedClassifiers);
        _Else ->
            kz_json:set_value(ClassifierName
                             ,kz_json:set_value(<<"name">>, ClassifierName, ClassifierSettings)
                             ,CorrectedClassifiers
                             )
    end.
