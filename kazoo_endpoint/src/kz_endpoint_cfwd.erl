%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
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
    regex_matches(Call, kzd_match_list_rule:regex(MatchRule), kzd_match_list_rule:target(MatchRule)).

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
