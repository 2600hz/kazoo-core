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

-export([selective/2]).

-include("kazoo_endpoint.hrl").

%% @doc takes merged selective call forwarding and checks rules
%% against the call for a match
-spec selective(kzd_endpoint:endpoint(), kapps_call:call()) ->
          kzd_call_forward:doc() | 'undefined'.
selective(Endpoint, Call) ->
    Selective = selective_call_forward(Endpoint),
    Rules = kzd_call_forward:rules(Selective, []),
    do_rules_match(Selective, Call, Rules).

selective_call_forward(Endpoint) ->
    kzd_call_forward:merged(kzd_endpoint:call_forward(Endpoint, kz_json:new())
                           ,fun kzd_call_forward:selective/1
                           ,kz_json:new()
                           ).

do_rules_match(_Selective, _Call, []) -> 'undefined';
do_rules_match(Selective, Call, [Rule | Rules]) ->
    case does_rule_match(Call, Rule) of
        'undefined' -> do_rules_match(Selective, Call, Rules);
        Matched ->
            kz_json:merge(fun kz_json:merge_right/2, Selective, Matched) % prefer Matched's settings
    end.

does_rule_match(Call, Rule) ->
    MatchListId = kz_json:get_ne_binary_value(<<"match_list_id">>, Rule),
    does_rule_match(Call, Rule, kz_datamgr:open_cache_doc(kapps_call:account_id(Call), MatchListId)).

does_rule_match(_Call, _Rule, {'error', _E}) -> 'undefined';
does_rule_match(Call, Rule, {'ok', MatchList}) ->
    does_rule_match(Call, Rule, kzd_match_lists:rules(MatchList, []));

does_rule_match(_Call, _Rule, []) -> 'undefined';
does_rule_match(Call, Rule, [MatchRule | MatchRules]) ->
    case match_list_rule_matches(MatchRule, Call) of
        'true' -> Rule;
        'false' -> does_rule_match(Call, Rule, MatchRules)
    end.

match_list_rule_matches(MatchRule, Call) ->
    match_list_rule_matches(MatchRule, Call, kzd_match_list_rule:type(MatchRule)).

match_list_rule_matches(MatchRule, Call, <<"regex">>) ->
    lager:info("regex match rule: ~p", [MatchRule]),
    regex_matches(Call, kzd_match_list_rule:regex(MatchRule), kzd_match_list_rule:target(MatchRule));
match_list_rule_matches(MatchRule, Call, <<"temporal_route">>) ->
    temporal_route_matches(Call, kzd_match_list_rule:temporal_route_id(MatchRule)).

regex_matches(Call, Regex, Target) ->
    case kz_module:is_exported('kapps_call', Target, 1) of
        'false' ->
            lager:info("no exported fun for target ~s", [Target]),
            'false';
        'true' ->
            Function = kz_term:to_atom(Target),
            Value = kapps_call:Function(Call),
            case re:run(Regex, Value) of
                'nomatch' ->
                    lager:info("key ~s value ~p does not match regex ~s", [Target, Value, Regex]),
                    'false';
                {'match', _} ->
                    lager:info("key ~s value ~p matches regex ~s", [Target, Value, Regex]),
                    'true'
            end
    end.

temporal_route_matches(Call, <<TemporalRouteId/binary>>) ->
    temporal_route_matches(Call, kz_datamgr:open_cache_doc(kapps_call:account_id(Call), TemporalRouteId));
temporal_route_matches(_Call, {'error', _E}) ->
    lager:info("failed to load temporal route: ~p", [_E]),
    'false';
temporal_route_matches(Call, {'ok', TemporalRouteDoc}) ->
    TZ = kzd_accounts:timezone(kapps_call:account_id(Call)),

    {LocalDate, _} = LocalDatetime = kz_time:adjust_utc_datetime(calendar:universal_time(), TZ),
    LocalSeconds = calendar:datetime_to_gregorian_seconds(LocalDatetime),

    StartDate = kz_date:from_gregorian_seconds(kzd_temporal_rules:start_date(TemporalRouteDoc, LocalSeconds), TZ),
    EndDate = maybe_date_from_gregorian_seconds(kzd_temporal_rules:end_date(TemporalRouteDoc), TZ),

    StartDatetime = {StartDate, {0,0,0}},
    EndDatetime = {EndDate, {23,59,59}},

    Exclusions = kzd_temporal_rules:exclude(TemporalRouteDoc, []),

    case ktr_rule:should_build_rule(LocalDatetime, StartDatetime, EndDatetime, Exclusions) of
        'false' -> 'false';
        'true' ->
            Rule = ktr_rule:new('true', TemporalRouteDoc, StartDate, EndDate),
            process_rule(LocalSeconds, LocalDate, Rule)
    end.

-spec maybe_date_from_gregorian_seconds(kz_time:date() | 'undefined', kz_term:ne_binary()) ->
          kz_time:gregorian_seconds() | 'undefined'.
maybe_date_from_gregorian_seconds('undefined', _TZ) -> 'undefined';
maybe_date_from_gregorian_seconds(EndDate, TZ) -> kz_date:from_gregorian_seconds(EndDate, TZ).

-spec process_rule(kz_time:gregorian_seconds(), kz_time:date(), ktr_rule:rule()) -> boolean().
process_rule(LocalSeconds, LocalDate, Rule) ->
    'true' =:= ktr_routes:process(LocalSeconds, LocalDate, [Rule]).
