%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoint_cfwd_tests).

-include_lib("eunit/include/eunit.hrl").

selective_regex_test_() ->
    CallJObj = kz_json:from_list([{<<"Caller-ID-Number">>, <<"+14158867900">>}]),
    Call = kapps_call:from_json(CallJObj),

    WrongCallJObj = kz_json:from_list([{<<"Caller-ID-Number">>, <<"+15558675309">>}]),
    WrongCall = kapps_call:from_json(WrongCallJObj),

    MatchCIDRule = match_list_cid_regex_rule(),

    CFwd = kz_endpoint_cfwd:does_rule_match(kz_endpoint_cfwd:call_fields(Call), MatchCIDRule, [MatchCIDRule]),

    WrongCFwd = kz_endpoint_cfwd:does_rule_match(kz_endpoint_cfwd:call_fields(WrongCall), MatchCIDRule, [MatchCIDRule]),

    [{"Caller ID Number matches, got settings", ?_assert(kz_json:is_json_object(CFwd))}
    ,{"Caller ID Number matches", ?_assert(kzd_call_forward:enabled(CFwd, 'true'))}
    ,{"Caller ID Number matches", ?_assertEqual('undefined', WrongCFwd)}
    ].

selective_and_test_() ->
    CallJObj = kz_json:from_list([{<<"Caller-ID-Number">>, <<"+14158867900">>}
                                 ,{<<"Callee-ID-Number">>, <<"+14158867999">>}
                                 ]),
    Call = kapps_call:from_json(CallJObj),

    WrongCallJObj = kz_json:from_list([{<<"Caller-ID-Number">>, <<"+14158867900">>}
                                      ,{<<"Callee-ID-Number">>, <<"+15558867999">>}
                                      ]),
    WrongCall = kapps_call:from_json(WrongCallJObj),

    MatchCIDRule = match_list_cid_regex_rule(),
    MatchCalleeRule = match_list_callee_regex_rule(),
    AndRule = match_list_and_rule([MatchCIDRule, MatchCalleeRule]),

    CFwd = kz_endpoint_cfwd:does_rule_match(kz_endpoint_cfwd:call_fields(Call), AndRule, [AndRule]),
    WrongCFwd = kz_endpoint_cfwd:does_rule_match(kz_endpoint_cfwd:call_fields(WrongCall), AndRule, [AndRule]),

    [{"Caller and Callee match, got settings", ?_assert(kz_json:is_json_object(CFwd))}
    ,{"Caller and Callee match", ?_assert(kzd_call_forward:enabled(CFwd, 'true'))}
    ,{"Caller and Callee don't match", ?_assertEqual('undefined', WrongCFwd)}
    ].

selective_not_test_() ->
    CallJObj = kz_json:from_list([{<<"Caller-ID-Number">>, <<"+14158867900">>}]),
    Call = kapps_call:from_json(CallJObj),

    WrongCallJObj = kz_json:from_list([{<<"Caller-ID-Number">>, <<"+15558675309">>}]),
    WrongCall = kapps_call:from_json(WrongCallJObj),

    MatchCIDRule = match_list_cid_regex_rule(),
    NotRule = match_list_not_rule([MatchCIDRule]),

    NotCFwd = kz_endpoint_cfwd:does_rule_match(kz_endpoint_cfwd:call_fields(Call), NotRule, [NotRule]),
    CFwd = kz_endpoint_cfwd:does_rule_match(kz_endpoint_cfwd:call_fields(WrongCall), NotRule, [NotRule]),

    [{"Caller ID doesn't match, 'not' it, got settings", ?_assert(kz_json:is_json_object(CFwd))}
    ,{"Caller ID doesn't match, 'not' it to get enabled cfwd", ?_assert(kzd_call_forward:enabled(CFwd, 'true'))}
    ,{"Caller ID matches but 'not' it so no cfwd", ?_assertEqual('undefined', NotCFwd)}
    ].

%% test missing call field in regex target
selective_invalid_field_test_() ->
    CallJObj = kz_json:from_list([{<<"Caller-ID-Number">>, <<"+14158867900">>}]),
    Call = kapps_call:from_json(CallJObj),

    Rule = match_list_missing_target_rule(),
    NotCFwd = kz_endpoint_cfwd:does_rule_match(kz_endpoint_cfwd:call_fields(Call), Rule, [Rule]),
    [{"Match rule for undefined target key in call", ?_assertEqual('undefined', NotCFwd)}].

selective_temporal_rule_test_() ->
    Call = kapps_call:new(),
    CallFields = [{<<"timezone">>, <<"UTC">>} | kz_endpoint_cfwd:call_fields(Call)],

    {Y, M, D} = erlang:date(),
    TodayTemporalRule = match_list_temporal_route({Y, M, D}),
    TomorrowTemporalRule = match_list_temporal_route(kz_date:normalize({Y, M, D+1})),

    CFwd = kz_endpoint_cfwd:does_rule_match(CallFields, TodayTemporalRule, [TodayTemporalRule]),
    NotCFwd = kz_endpoint_cfwd:does_rule_match(CallFields, TomorrowTemporalRule, [TomorrowTemporalRule]),

    [{"Time of day matches, got settings", ?_assert(kz_json:is_json_object(CFwd))}
    ,{"Time of day matches today, forward call", ?_assert(kzd_call_forward:enabled(CFwd, 'true'))}
    ,{"Time of day does not match tomorrow, don't forward call", ?_assertEqual('undefined', NotCFwd)}
    ].

match_list_and_rule(Rules) ->
    kz_json:from_list([{<<"name">>, <<"Match Caller and Callee">>}
                      ,{<<"type">>, <<"and">>}
                      ,{<<"rules">>, Rules}
                      ]).

match_list_not_rule(Rules) ->
    kz_json:from_list([{<<"name">>, <<"Not Matching the Caller ID">>}
                      ,{<<"type">>, <<"not">>}
                      ,{<<"rules">>, Rules}
                      ]).


match_list_cid_regex_rule() ->
    kz_json:from_list([{<<"name">>, <<"Match CID">>}
                      ,{<<"regex">>, <<"\\+?1?41588679\\d{2}">>}
                      ,{<<"target">>, <<"caller_id_number">>}
                      ,{<<"type">>, <<"regex">>}
                      ]).

match_list_callee_regex_rule() ->
    kz_json:from_list([{<<"name">>, <<"Match Callee">>}
                      ,{<<"regex">>, <<"\\+?1?41588679\\d{2}">>}
                      ,{<<"target">>, <<"callee_id_number">>}
                      ,{<<"type">>, <<"regex">>}
                      ]).

match_list_missing_target_rule() ->
    kz_json:from_list([{<<"name">>, <<"Match CID">>}
                      ,{<<"regex">>, <<"\\+?1?41588679\\d{2}">>}
                      ,{<<"target">>, <<"switch_hostname">>}
                      ,{<<"type">>, <<"regex">>}
                      ]).


match_list_temporal_route({Y, M, D}) ->
    kz_json:from_list([{<<"name">>, <<"Match Date">>}
                      ,{<<"type">>, <<"temporal_rule">>}
                      ,{<<"temporal_route">>, temporal_route({Y, M, D})}
                      ]).

temporal_route({Y, M, D}) ->
    StartDate = {kz_date:normalize({Y, M, D}), {0, 0, 0}},

    kz_json:exec_first([{fun kzd_temporal_rules:set_name/2, kz_binary:rand_hex(4)}
                       ,{fun kzd_temporal_rules:set_start_date/2, calendar:datetime_to_gregorian_seconds(StartDate)}
                       ,{fun kzd_temporal_rules:set_cycle/2, <<"date">>}
                       ]
                      ,kzd_temporal_rules:new()
                      ).
