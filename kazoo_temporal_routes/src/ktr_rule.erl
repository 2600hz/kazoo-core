%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc Rule record for use in ktr_routes for processing
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(ktr_rule).

-export([new/4
        ,should_build_rule/3, should_build_rule/4
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include("ktr.hrl").

-export_type([rule/0]).

%% @doc
%% Id is the return value if the rule matches the time/date
%% RulesDoc is the temporal rules doc from the database
%% StartDate is the start time of the rule (or the current local time), timezone-adjusted
%% EndDate is the end time of the rule, if present, timezone-adjusted
-spec new(any(), kzd_temporal_rules:doc(), kz_time:date(), end_date()) -> rule().
new(Id, RulesDoc, StartDate, EndDate) ->
    #rule{cycle = kzd_temporal_rules:cycle(RulesDoc, ?RULE_DEFAULT_CYCLE)
         ,days = days_in_rule(RulesDoc)
         ,enabled = kzd_temporal_rules:enabled(RulesDoc, 'undefined')
         ,id = Id
         ,interval = kzd_temporal_rules:interval(RulesDoc, ?RULE_DEFAULT_INTERVAL)
         ,month = kzd_temporal_rules:month(RulesDoc, ?RULE_DEFAULT_MONTH)
         ,name = kzd_temporal_rules:name(RulesDoc, ?RULE_DEFAULT_NAME)
         ,ordinal = kzd_temporal_rules:ordinal(RulesDoc, ?RULE_DEFAULT_ORDINAL)
         ,start_date = StartDate
         ,end_date = EndDate
         ,wdays = sort_wdays(kzd_temporal_rules:wdays(RulesDoc, ?RULE_DEFAULT_WDAYS))
         ,wtime_start = kzd_temporal_rules:time_window_start(RulesDoc, ?RULE_DEFAULT_WTIME_START)
         ,wtime_stop = kzd_temporal_rules:time_window_stop(RulesDoc, ?RULE_DEFAULT_WTIME_STOP)
         }.

-spec days_in_rule(kzd_temporal_rules:doc()) -> kz_term:integers().
days_in_rule(RulesDoc) ->
    lists:foldr(fun add_day/2, [], kzd_temporal_rules:days(RulesDoc, ?RULE_DEFAULT_DAYS)).

-spec sort_wdays([wday()]) -> [wday()].
sort_wdays([]) -> [kz_date:dow_to_wday(D) || D <- lists:seq(1, 7)];
sort_wdays(WDays0) ->
    {_, WDays1} = lists:unzip(
                    lists:keysort(1, [{kz_date:wday_to_dow(Day), Day} || Day <- WDays0])
                   ),
    WDays1.

-spec add_day(kz_term:ne_binary() | integer(), kz_term:integers()) -> kz_term:integers().
add_day(Day, Acc) -> [kz_term:to_integer(Day)|Acc].

-spec should_build_rule(kz_time:datetime(), kz_time:datetime(), kz_time:datetime() | {'undefined', kz_time:time()}) -> boolean().
should_build_rule(NowDateTime, StartDateTime, EndDateTime) ->
    should_build_rule(NowDateTime, StartDateTime, EndDateTime, []).

%% @doc check current datetime against rule's start/end times
%% All datetimes should be in the account-specific timezone
-spec should_build_rule(kz_time:datetime(), kz_time:datetime(), kz_time:datetime() | {'undefined', kz_time:time()}, kz_term:ne_binaries()) -> boolean().
should_build_rule(NowDateTime, StartDateTime, {'undefined', _}, []) ->
    %% StartDateTime < NowDatetime
    'past' =:= kz_date:relative_difference(NowDateTime, StartDateTime);
should_build_rule(NowDateTime, StartDateTime, EndDateTime, []) ->
    %% StartDateTime < NowDatetime < EndDateTime
    'past' =:= kz_date:relative_difference(NowDateTime, StartDateTime)
        andalso 'future' =:= kz_date:relative_difference(NowDateTime, EndDateTime);
should_build_rule({Today, _} = NowDateTime, StartDateTime, EndDateTime, Exclude) ->
    case lists:member(kz_date:to_iso8601(Today), Exclude) of
        'false' ->
            should_build_rule(NowDateTime, StartDateTime, EndDateTime, []);
        'true' ->
            lager:debug("rule configured to be excluded today, discarding"),
            'false'
    end.
