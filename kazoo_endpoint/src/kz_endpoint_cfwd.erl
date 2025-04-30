%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoint_cfwd).

-export([selective/2
        ,allowed_call_fields/0
        ,call_fields/1
        ]).

-ifdef(TEST).
-export([does_rule_match/3]).

-include_lib("eunit/include/eunit.hrl").
-endif.

-include("kazoo_endpoint.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").

%% @doc takes merged selective call forwarding and checks rules
%% against the call for a match
-spec selective(kzd_endpoint:endpoint(), kapps_call:call()) ->
          kzd_call_forward:doc() | 'undefined'.
selective(Endpoint, Call) ->
    Selective = selective_call_forward(Endpoint),
    Rules = kzd_call_forward:rules(Selective, []),
    do_rules_match(Selective, call_fields(Call), Rules).

-spec selective_call_forward(kzd_call_forward:doc()) -> kzd_call_forward:doc().
selective_call_forward(Endpoint) ->
    kzd_call_forward:merged(kzd_endpoint:call_forward(Endpoint, kz_json:new())
                           ,fun kzd_call_forward:selective/1
                           ,kz_json:new()
                           ).

-spec do_rules_match(kzd_call_forward:doc(), kz_term:proplist(), kz_json:objects()) ->
          kzd_call_forward:doc().
do_rules_match(_Selective, _CallFields, []) -> 'undefined';
do_rules_match(Selective, CallFields, [Rule | Rules]) ->
    case does_rule_match(CallFields, Rule) of
        'undefined' -> do_rules_match(Selective, CallFields, Rules);
        Matched ->
            kz_json:merge(fun kz_json:merge_right/2, Selective, Matched) % prefer Matched's settings
    end.

does_rule_match(CallFields, Rule) ->
    MatchListId = kz_json:get_ne_binary_value(<<"match_list_id">>, Rule),
    Result = kz_datamgr:open_cache_doc(props:get_value(<<"account_id">>, CallFields), MatchListId),
    does_rule_match(CallFields, Rule, Result).

does_rule_match(_CallFields, _Rule, {'error', _E}) -> 'undefined';
does_rule_match(CallFields, Rule, {'ok', MatchList}) ->
    does_rule_match(CallFields, Rule, kzd_match_lists:rules(MatchList, []));

does_rule_match(_CallFields, _Rule, []) -> 'undefined';
does_rule_match(CallFields, Rule, [MatchRule | MatchRules]) ->
    case match_list_rule_matches(MatchRule, CallFields) of
        'true' -> Rule;
        'false' -> does_rule_match(CallFields, Rule, MatchRules)
    end.

match_list_rule_matches(MatchRule, CallFields) ->
    match_list_rule_matches(MatchRule, CallFields, kzd_match_list_rule:type(MatchRule)).

match_list_rule_matches(MatchRule, CallFields, <<"regex">>) ->
    ?LOG_INFO("regex match rule: ~p", [MatchRule]),
    regex_matches(CallFields, kzd_match_list_rule:regex(MatchRule), kzd_match_list_rule:target(MatchRule));
match_list_rule_matches(MatchRule, CallFields, <<"temporal_route">>) ->
    temporal_route_matches(MatchRule, CallFields, kzd_match_lists_rule:temporal_route_id(MatchRule));
match_list_rule_matches(MatchRule, CallFields, <<"temporal_rule">>) ->
    temporal_route_matches(MatchRule, CallFields, kzd_match_lists_rule:temporal_route_id(MatchRule));
match_list_rule_matches(MatchRule, CallFields, <<"temporal_rules_set">>) ->
    temporal_rules_set_matches(CallFields, kzd_match_lists_rule:temporal_rules_set_id(MatchRule));
match_list_rule_matches(AndMatchRule, CallFields, <<"and">>) ->
    does_and_rule_match(kzd_match_lists:rules(AndMatchRule), CallFields);
match_list_rule_matches(NotMatchRule, CallFields, <<"not">>) ->
    does_not_rule_match(kzd_match_lists:rules(NotMatchRule), CallFields).

-spec does_and_rule_match(kz_json:objects(), kz_term:proplist()) -> boolean().
does_and_rule_match([], _CallFields) -> 'true';
does_and_rule_match([AndRule|AndRules], CallFields) ->
    case does_rule_match(CallFields, AndRule, [AndRule]) of
        'undefined' -> 'false';
        _Matched -> does_and_rule_match(AndRules, CallFields)
    end.

does_not_rule_match([], _CallFields) -> 'false';
does_not_rule_match([NotRule], CallFields) ->
    'undefined' =:= does_rule_match(CallFields, NotRule, [NotRule]).

regex_matches(CallFields, Regex, Target) ->
    regex_matches(CallFields, Regex, Target, props:get_value(Target, CallFields, 'undefined')).

regex_matches(_CallFields, _Regex, _Target, 'undefined') -> 'false';
regex_matches(_CallFields, Regex, _Target, Value) ->
    case re:run(Value, Regex) of
        'nomatch' ->
            ?LOG_INFO("key ~s value ~p does not match regex ~s", [_Target, Value, Regex]),
            'false';
        {'match', _} ->
            ?LOG_INFO("key ~s value ~p matches regex ~s", [_Target, Value, Regex]),
            'true'
    end.

temporal_route_matches(MatchRule, CallFields, 'undefined') ->
    ?LOG_DEBUG("no temporal route id, checking for temporal rule data in match rule"),
    temporal_route_matches(MatchRule, CallFields
                          ,{'ok', kzd_match_lists_rule:temporal_route(MatchRule, 'undefined')}
                          );
temporal_route_matches(MatchRule, CallFields, <<TemporalRouteId/binary>>) ->
    Result = kz_datamgr:open_cache_doc(props:get_value(<<"account_id">>, CallFields), TemporalRouteId),
    temporal_route_matches(MatchRule, CallFields, Result);
temporal_route_matches(_MatchRule, _CallFields, {'error', _E}) ->
    ?LOG_INFO("failed to load temporal route: ~p", [_E]),
    'false';
temporal_route_matches(_MatchRule, _CallFields, {'ok', 'undefined'}) ->
    ?LOG_INFO("bad temporal route config in match rule"),
    'false';
temporal_route_matches(_MatchRule, CallFields, {'ok', TemporalRouteDoc}) ->
    TZ = kzd_accounts:timezone(props:get_value(<<"account_id">>, CallFields)
                              ,props:get_value(<<"timezone">>, CallFields)
                              ), % defaults to Los Angeles

    {LocalDate, _} = LocalDatetime = kz_time:adjust_utc_datetime(calendar:universal_time(), TZ),
    ?LOG_DEBUG("local time in ~s: ~p", [TZ, LocalDatetime]),

    LocalSeconds = calendar:datetime_to_gregorian_seconds(LocalDatetime),

    StartDate = kz_date:from_gregorian_seconds(kzd_temporal_rules:start_date(TemporalRouteDoc, LocalSeconds), TZ),
    EndDate = maybe_date_from_gregorian_seconds(kzd_temporal_rules:end_date(TemporalRouteDoc), TZ),

    StartDatetime = {StartDate, {0,0,0}},
    EndDatetime = {EndDate, {23,59,59}},

    Exclusions = kzd_temporal_rules:exclude(TemporalRouteDoc, []),

    case ktr_rule:should_build_rule(LocalDatetime, StartDatetime, EndDatetime, Exclusions) of
        'false' ->
            ?LOG_INFO("temporal rule did not build", []),
            'false';
        'true' ->
            Rule = ktr_rule:new('true', TemporalRouteDoc, StartDate, EndDate),
            process_rule(LocalSeconds, LocalDate, [Rule])
    end.

temporal_rules_set_matches(CallFields, <<TemporalRulesSetId/binary>>) ->
    Result = kz_datamgr:open_cache_doc(props:get_value(<<"account_id">>, CallFields)
                                      ,TemporalRulesSetId
                                      ),
    temporal_rules_set_matches(CallFields, Result);
temporal_rules_set_matches(_CallFiels, {'error', _E}) ->
    ?LOG_INFO("failed to load temporal route set: ~p", [_E]),
    'false';
temporal_rules_set_matches(CallFields, {'ok', TemporalRuleSet}) ->
    lists:any(fun(TemporalRuleId) ->
                      temporal_route_matches(kz_json:new(), CallFields, TemporalRuleId)
              end
             ,kzd_temporal_rules_sets:temporal_rules(TemporalRuleSet)
             ).

-spec maybe_date_from_gregorian_seconds(kz_time:date() | 'undefined', kz_term:ne_binary()) ->
          kz_time:gregorian_seconds() | 'undefined'.
maybe_date_from_gregorian_seconds('undefined', _TZ) -> 'undefined';
maybe_date_from_gregorian_seconds(EndDate, TZ) -> kz_date:from_gregorian_seconds(EndDate, TZ).

-spec process_rule(kz_time:gregorian_seconds(), kz_time:date(), [ktr_rule:rule()]) -> boolean().
process_rule(LocalSeconds, LocalDate, Rules) ->
    'true' =:= ktr_routes:process(LocalSeconds, LocalDate, Rules).

-spec allowed_call_fields() -> kz_term:ne_binaries().
allowed_call_fields() ->
    Keys = props:get_keys(kapps_call:to_proplist(kapps_call:new())),
    [Normalized
     || Key <- Keys,
        Normalized <- [normalize_call_field(Key)],
        'undefined' =/= Normalized
    ].

normalize_call_field(Key) ->
    maybe_restrict_call_field(kz_json:normalize_key(Key)).

maybe_restrict_call_field(<<"control_queue">>) -> 'undefined';
maybe_restrict_call_field(<<"controller_queue">>) -> 'undefined';
maybe_restrict_call_field(<<"custom_application_vars">>) -> 'undefined';
maybe_restrict_call_field(<<"custom_channel_vars">>) -> 'undefined';
maybe_restrict_call_field(<<"custom_sip_headers">>) -> 'undefined';
maybe_restrict_call_field(<<"custom_auth_headers">>) -> 'undefined';
maybe_restrict_call_field(<<"key_value_store">>) -> 'undefined';
maybe_restrict_call_field(<<"switch_hostname">>) -> 'undefined';
maybe_restrict_call_field(<<"switch_nodename">>) -> 'undefined';
maybe_restrict_call_field(<<"switch_uri">>) -> 'undefined';
maybe_restrict_call_field(<<"switch_url">>) -> 'undefined';
maybe_restrict_call_field(<<"sip_diversions">>) -> 'undefined';
maybe_restrict_call_field(<<"authorizing_token">>) -> 'undefined';
maybe_restrict_call_field(<<"endpoint_token">>) -> 'undefined';

maybe_restrict_call_field(<<"call_direction">>) -> <<"direction">>;
maybe_restrict_call_field(Key) -> Key.

-spec call_fields(kapps_call:call()) -> kz_term:proplist().
call_fields(Call) ->
    [{Field, kz_term:to_binary(Value)}
     || Field <- allowed_call_fields(),
        Value <- [apply('kapps_call', kz_term:to_atom(Field), [Call])],
        'undefined' =/= Value,
        <<>> =/= Value
    ].
