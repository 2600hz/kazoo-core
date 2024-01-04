%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2024, 2600Hz
%%% @doc Process temporal rules
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(ktr_routes).

-export([process/2, process/3]).

-ifdef(TEST).
-export([next_rule_date/2]).
-endif.

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include("ktr.hrl").

%%------------------------------------------------------------------------------
%% @doc Test all rules in reference to the current temporal routes, and
%% returns the first #rule.id that matches (or 'default' if
%% none). LocalSeconds is the gregorian seconds in the account's
%% timezone
%% @end
%%------------------------------------------------------------------------------
-spec process(kz_time:gregorian_seconds(), rule() | rules()) ->
          result().
process(LocalSeconds, #rule{}=Rule) ->
    process(LocalSeconds, [Rule]);
process(LocalSeconds, Rules) ->
    {LocalDate, _} = calendar:gregorian_seconds_to_datetime(LocalSeconds),
    process(LocalSeconds, LocalDate, Rules).

-spec process(kz_time:gregorian_seconds(), kz_time:date(), rule() | rules()) ->
          result().
process(LocalSeconds, LocalDate, #rule{}=Rule) ->
    process(LocalSeconds, LocalDate, [Rule]);
process(_LocalSeconds, _LocalDate, []) ->
    lager:info("no rules matched"),
    'undefined';
process(LocalSeconds
       ,LocalDate
       ,[#rule{enabled='false'
              ,id=Id
              ,name=Name
              }
        | Rules
        ]
       ) ->
    lager:info("time based rule ~p (~s) disabled", [Id, Name]),
    process(LocalSeconds, LocalDate, Rules);
process(_LocalSeconds
       ,_LocalDate
       ,[#rule{enabled='true'
              ,id=Id
              ,name=Name
              }
        | _Rules
        ]
       ) ->
    lager:info("time based rule ~p (~s) is forced active", [Id, Name]),
    Id;
process(LocalSeconds
       ,LocalDate
       ,[#rule{id=Id
              ,name=Name
              ,cycle = <<>>
              }
        | Rules
        ]
       ) ->
    lager:error("time based rule ~p (~s) is invalid, skipping", [Id, Name]),
    process(LocalSeconds, LocalDate, Rules);
process(LocalSeconds
       ,LocalDate
       ,[Rule | Rules]
       ) ->
    case process_rule(LocalSeconds, LocalDate, Rule) of
        'undefined' ->
            process(LocalSeconds, LocalDate, Rules);
        Id ->
            Id
    end.

process_rule(LocalSeconds
            ,LocalDate
            ,#rule{cycle=Cycle
                  ,id=Id
                  ,name=Name
                  ,wtime_start=TStart
                  ,wtime_stop=TStop
                  }=Rule
            ) ->
    lager:info("processing temporal rule ~s (~s)", [Id, Name]),

    SearchDate = search_date(Cycle, LocalDate),

    BaseDate = kz_date:normalize(
                 next_rule_date(Rule, SearchDate)
                ),
    BaseTime = calendar:datetime_to_gregorian_seconds({BaseDate, {0,0,0}}),

    case {BaseTime + TStart, BaseTime + TStop} of
        {Start, _} when LocalSeconds < Start ->
            lager:info("rule applies in the future ~w", [calendar:gregorian_seconds_to_datetime(Start)]),
            'undefined';
        {_, End} when LocalSeconds > End ->
            lager:info("rule was valid today but expired ~w", [calendar:gregorian_seconds_to_datetime(End)]),
            'undefined';
        {_, End} ->
            lager:info("rule is within active time window until ~w", [calendar:gregorian_seconds_to_datetime(End)]),
            Id
    end.

%% Weekly logic becomes convoluted when prev date is passed for SearchDate.
%% This creates lots of edge cases so pass today in weekly only.
search_date(<<"weekly">>, LocalDate) -> LocalDate;
search_date(_Cycle, {Y, M, D}) -> kz_date:normalize({Y, M, D - 1}).

%%------------------------------------------------------------------------------
%% @doc The big daddy
%% Calculates the date of the next event given the type, interval,
%% rule, start date, and current date.
%%
%% GOTCHA!
%% Weird predictions? Bet your weekdays or days are not in order....
%%   - monday, tuesday, wensday, thursday, friday, saturday, sunday
%%                      wednesday
%%   - 1,2,3..31
%% @end
%%------------------------------------------------------------------------------
-spec next_rule_date(rule(), kz_time:date()) -> kz_time:date().
next_rule_date(#rule{cycle = <<"date">>
                    ,start_date=Date0
                    }
              ,_Date
              ) ->
    Date0;
next_rule_date(#rule{cycle = <<"daily">>
                    ,interval=I0
                    ,start_date={Y0, M0, D0}
                    }
              ,{Y1, M1, D1}
              ) ->
    %% Calculate the distance in days as a function of
    %%   the interval and fix
    DS0 = calendar:date_to_gregorian_days({Y0, M0, D0}),
    DS1 = calendar:date_to_gregorian_days({Y1, M1, D1}),
    Offset = trunc( ( DS1 - DS0 ) / I0 ) * I0,
    kz_date:normalize({Y0, M0, D0 + Offset + I0});
next_rule_date(#rule{cycle = <<"weekly">>
                    ,interval=Interval
                    ,wdays=Weekdays
                    ,start_date={Y0, M0, D0}=StartDate
                    }=Rule
              ,{Y1, M1, D1}=Today
              ) ->
    DOW0 = calendar:day_of_the_week({Y1, M1, D1}),
    Distance = iso_week_difference({Y0, M0, D0}, {Y1, M1, D1}),
    Offset = trunc( Distance / Interval ) * Interval,
    Weekday = calendar:day_of_the_week(StartDate),

    %%TODO: remove these log lines when we are happy that this just works
    lager:debug("today is: ~p dow: ~p, startdate is: ~p, start dow is ~b, interval is: ~b, distance is: ~b, offset is: ~b, rule days found: ~p"
               ,[Today, DOW0, StartDate, Weekday, Interval, Distance, Offset, find_active_days(Weekdays, DOW0)]
               ),

    case find_active_days(Weekdays, DOW0) of
        %% When the start date is in the future but within the week,
        %% skip over the invalid rule dates by recursively calling
        %% self with Today as StartDate
        [_Day|_] when Today < StartDate
                      andalso Distance =:= Offset ->
            lager:debug("rule starts in the future jumping to search from ~p", [StartDate]),
            next_rule_date(Rule, StartDate);

        %% When today is the first rule day and also the start date return the start date
        [Day|_] when Today =:= StartDate
                     andalso Day =:= DOW0
                     andalso Distance =:= Offset ->
            lager:debug("rule starts today ~b", [Day]),
            StartDate;

        %% During an 'active' week that fails the previous guards, move to the next day this week
        [Day|_] when Distance =:= Offset ->
            lager:debug("next day in rule is ~w and day is ~w", [Day, DOW0]),
            kz_date:normalize({Y1, M1, D1 + Day - DOW0});

        %% Empty list:
        %% Non Empty List that failed the guard:
        %%   During an 'inactive' week
        _Val ->
            lager:debug("no rule found for this week"),
            {WY0, W0} = calendar:iso_week_number({Y0, M0, D0}),
            {Y2, M2, D2} = kz_date:from_iso_week({WY0, W0 + Offset + Interval}),
            kz_date:normalize({Y2, M2, ( D2 - 1 ) + kz_date:wday_to_dow( hd( Weekdays ) )})
    end;
next_rule_date(#rule{cycle = <<"monthly">>
                    ,interval=I0
                    ,days=[_|_]=Days
                    ,start_date={Y0, M0, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = ( Y1 - Y0 ) * 12 - M0 + M1,
    Offset = trunc( Distance / I0 ) * I0,
    case [D || D <- Days, D > D1] of
        %% The day hasn't happened on an 'active' month
        [Day|_] when Distance =:= Offset ->
            M01 = M0 + Offset,
            kz_date:normalize({Y0 + (M01 div 12), M01 rem 12, Day});
        %% Empty List:
        %%   All of the days in the list have already happened
        %% Non Empty List that failed the guard:
        %%   The day hasn't happened on an 'inactive' month
        _ ->
            M01 = M0 + Offset + I0,
            kz_date:normalize({Y0 + (M01 div 12), M01 rem 12, hd(Days)})
    end;

next_rule_date(#rule{cycle = <<"monthly">>
                    ,interval=I0
                    ,ordinal = <<"every">>
                    ,wdays=[Weekday]
                    ,start_date={Y0, M0, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = ( Y1 - Y0 ) * 12 - M0 + M1,
    Offset = trunc( Distance / I0 ) * I0,
    case Distance =:= Offset
        andalso kz_date:find_next_weekday({Y1, M1, D1}, Weekday)
    of
        %% If the next occurrence of the weekday is during an 'active' month
        %%   and does not span the current month/year then it is correct
        {Y1, M1, _}=Date ->
            Date;
        %% In the special case were the next weekday does span the current
        %%   month/year but it should be every month (I0 == 1) then the
        %%   date is also correct
        {_,_,_}=Date when I0 =:= 1 ->
            Date;
        %% During an 'inactive' month, or when it inappropriately spans
        %%   a month/year boundary calculate the next iteration
        _ ->
            find_ordinal_weekday(Y0, M0 + Offset + I0, Weekday, <<"first">>)
    end;

next_rule_date(#rule{cycle = <<"monthly">>
                    ,interval=I0
                    ,ordinal = <<"last">>
                    ,wdays=[Weekday]
                    ,start_date={Y0, M0, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = ( Y1 - Y0 ) * 12 - M0 + M1,
    Offset = trunc( Distance / I0 ) * I0,
    case Distance =:= Offset
        andalso find_last_weekday({Y1, M1, 1}, Weekday)
    of
        %% If today is before the occurrence day on an 'active' month since
        %%   the 'last' only happens once per month if we haven't passed it
        %%   then it must be this month
        {_, _, D2}=Date when D1 < D2 ->
            Date;
        %% In an 'inactive' month or when we have already passed
        %%   the last occurrence of the DOW
        _ ->
            find_last_weekday({Y0, M0 + Offset + I0, 1}, Weekday)
    end;

%% WARNING: There is a known bug when requesting the fifth occurrence
%%   of a weekday when I0 > 1 and the current month only has four instances
%%   of the given weekday, the calculation is incorrect.  I was told not
%%   to worry about that now...
next_rule_date(#rule{cycle = <<"monthly">>
                    ,interval=I0
                    ,ordinal=Ordinal
                    ,wdays=[Weekday]
                    ,start_date={Y0, M0, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = ( Y1 - Y0 ) * 12 - M0 + M1,
    Offset = trunc( Distance / I0 ) * I0,
    case Distance =:= Offset
        andalso {find_ordinal_weekday(Y1, M1, Weekday, Ordinal), I0}
    of
        %% If today is before the occurrence day on an 'active' month and
        %%   the occurrence does not cross month/year boundaries then the
        %%   calculated date is accurate
        {{_, M1, D2}=Date, _} when D1 < D2, I0 > 1 ->
            Date;
        %% If today is before the occurrence day on an 'active' month and
        %%   the interval =:= 1 then it happens every month so it doesn't
        %%   matter if it crosses month/year boundaries
        {{_, M2, D2}=Date, 1} when D1 < D2; M1 < M2 ->
            Date;
        %% false:
        %%   In an 'inactive' month
        %% {kz_time:date(), integer()}:
        %%   We have already passed the last occurrence of the DOW
        _ ->
            find_ordinal_weekday(Y0, M0 + Offset + I0, Weekday, Ordinal)
    end;

%% WARNING: This function does not ensure the provided day actually
%%   exists in the month provided.  For temporal routes that isn't
%%   an issue because we will 'pass' the invalid date and compute
%%   the next
next_rule_date(#rule{cycle = <<"yearly">>
                    ,interval=I0
                    ,month=Month
                    ,days=[_|_]=Days
                    ,start_date={Y0, _, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = Y1 - Y0,
    Offset = trunc( Distance / I0 ) * I0,
    case Distance =:= Offset of
        %% If this is not an 'active' year it will be the first specified
        %% day (of days) next interval year(s)
        'false' ->
            {Y0 + Offset + I0, Month, hd(Days)};
        %% If this an 'active' year but the month has not occurred yet
        %% it will be on the first day (of days) that month
        'true' when M1 < Month ->
            {Y1, Month, hd(Days)};
        %% If this an 'active' year but the month has not occurred yet
        %% it will be on the first day (of days) next interval year(s)
        'true' when M1 > Month ->
            {Y0 + Offset + I0, Month, hd(Days)};
        'true' ->
            case lists:dropwhile(fun(D) -> D1 >= D end, Days) of
                %% if this is the month but the all the days have passed
                %% it will be on the first day (of days) next interval year(s)
                [] -> {Y0 + Offset + I0, Month, hd(Days)};
                %% if not all the days have passed is is the next day after the
                %% ones that have passed
                [Day|_] ->
                    {Y1, Month, Day}
            end
    end;

next_rule_date(#rule{cycle = <<"yearly">>
                    ,interval=I0
                    ,ordinal = <<"every">>
                    ,month=Month
                    ,wdays=[Weekday]
                    ,start_date={Y0, _, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = Y1 - Y0,
    Offset = trunc( Distance / I0 ) * I0,
    case Distance =:= Offset
        andalso kz_date:find_next_weekday({Y1, Month, D1}, Weekday)
    of
        %% During an 'active' year before the target month the calculated
        %%   occurrence is accurate
        {Y1, Month, _}=Date when M1 < Month ->
            Date;
        %% During an 'active' year on the target month before the
        %%   calculated occurrence day it is accurate
        {Y1, Month, D2}=Date when M1 =:= Month, D1 < D2 ->
            Date;
        %% During an 'inactive' year, or after the target month
        %%   calculate the next iteration
        _ ->
            find_ordinal_weekday(Y0 + Offset + I0, Month, Weekday, <<"first">>)
    end;

next_rule_date(#rule{cycle = <<"yearly">>
                    ,interval=I0
                    ,ordinal = <<"last">>
                    ,month=Month
                    ,wdays=[Weekday]
                    ,start_date={Y0, _, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = Y1 - Y0,
    Offset = trunc( Distance / I0 ) * I0,
    case Distance =:= Offset
        andalso find_last_weekday({Y1, Month, 1}, Weekday)
    of
        %% During an 'active' year before the target month the calculated
        %%   occurrence is accurate
        {Y1, _, _}=Date when M1 < Month ->
            Date;
        %% During an 'active' year on the target month before the
        %%   calculated occurrence day it is accurate
        {Y1, _, D2}=Date when M1 =:= Month, D1 < D2 ->
            Date;
        %% During an 'inactive' year, or after the target month
        %%   calculate the next iteration
        _ ->
            find_last_weekday({Y0 + Offset + I0, Month, 1}, Weekday)
    end;

next_rule_date(#rule{cycle = <<"yearly">>
                    ,interval=I0
                    ,ordinal=Ordinal
                    ,month=Month
                    ,wdays=[Weekday]
                    ,start_date={Y0, _, _}
                    }
              ,{Y1, M1, D1}
              ) ->
    Distance = Y1 - Y0,
    Offset = trunc( Distance / I0 ) * I0,
    case Distance =:= Offset
        andalso find_ordinal_weekday(Y1, Month, Weekday, Ordinal)
    of
        %% During an 'active' year before the target month the calculated
        %%   occurrence is accurate
        {Y1, Month, _}=Date when M1 < Month ->
            Date;
        %% During an 'active' year on the target month before the
        %%   calculated occurrence day it is accurate
        {Y1, Month, D2}=Date when M1 =:= Month, D1 < D2 ->
            Date;
        %% During an 'inactive' year or after the calculated
        %%   occurrence, determine the next iteration
        _ ->
            find_next_yearly_ordinal_weekday(Y0 + Offset + I0, Month, Weekday, Ordinal, I0)
    end.

-spec find_next_yearly_ordinal_weekday(kz_time:year(), kz_time:month(), wday(), kz_time:ordinal(), interval()) -> kz_time:date().
find_next_yearly_ordinal_weekday(Y0, M0, Weekday, Ordinal, Interval) ->
    case find_ordinal_weekday(Y0, M0, Weekday, Ordinal) of
        {_Y1, M0, _D1}=Date ->
            %% found a date in the same month
            Date;
        {_Y1, _M1, _D1} ->
            %% might be a "fifth" day in the next month,
            %% let's try again
            find_next_yearly_ordinal_weekday(Y0 + Interval, M0, Weekday, Ordinal, Interval)
    end.

%%------------------------------------------------------------------------------
%% @doc Safety wrapper on date_of_dow used to loop over failing attempts
%% until the date can be calculated.  The date can be provided as an
%% improper date.
%%
%% <div class="notice">It is possible for this function to cross month/year boundaries.</div>
%% @end
%%------------------------------------------------------------------------------
-spec find_ordinal_weekday(kz_time:year(), improper_month(), wday(), kz_time:ordinal()) -> kz_time:date().
find_ordinal_weekday(Y1, M1, Weekday, Ordinal) when M1 =:= 13 ->
    find_ordinal_weekday(Y1 + 1, 1, Weekday, Ordinal);
find_ordinal_weekday(Y1, M1, Weekday, Ordinal) when M1 > 12 ->
    find_ordinal_weekday(Y1 + 1, M1 - 12, Weekday, Ordinal);
find_ordinal_weekday(Y1, M1, Weekday, Ordinal) ->
    try date_of_dow(Y1, M1, Weekday, Ordinal)
    catch
        _:_ ->
            find_ordinal_weekday(Y1, M1 + 1, Weekday, Ordinal)
    end.

%%------------------------------------------------------------------------------
%% @doc Calculates the date of the last occurrence of a weekday within a
%% given month/year.  The date can be provided as an improper date.
%%
%% Assumption/Principle:
%%   A DOW can never occur more than four times in a month.
%% @end
%%------------------------------------------------------------------------------
%% First attempt to calculate the date of the fourth DOW
%% occurrence.  Since the function corrects an invalid
%% date by crossing month/year boundaries, cause a badmatch
%% if this happens. Therefore, during the exception the last
%% occurrence MUST be in the third week.
%% @end
%%------------------------------------------------------------------------------
-spec find_last_weekday(improper_date(), wday()) -> kz_time:date().
find_last_weekday({Y, M, D}, Weekday) when M =:= 13 ->
    find_last_weekday({Y + 1, 1, D}, Weekday);
find_last_weekday({Y, M, D}, Weekday) when M > 12 ->
    find_last_weekday({Y + 1, M - 12, D}, Weekday);
find_last_weekday({Y, M, _}, Weekday) ->
    try
        {Y, M, _} = date_of_dow(Y, M, Weekday, <<"fifth">>)
    catch
        _:_ ->
            date_of_dow(Y, M, Weekday, <<"fourth">>)
    end.

%%------------------------------------------------------------------------------
%% @doc Unsafe calculation of the date for a specific day of the week, this
%% function will explode on occasion.
%% @end
%%------------------------------------------------------------------------------
-spec date_of_dow(kz_time:year(), improper_month(), wday(), strict_ordinal()) -> kz_time:date().
date_of_dow(Year, 1, Weekday, Ordinal) ->
    date_of_dow(Year - 1, 13, Weekday, Ordinal);
date_of_dow(Year, Month, Weekday, Ordinal) ->
    RefDate = {Year, Month - 1, calendar:last_day_of_the_month(Year, Month - 1)},
    RefDays = calendar:date_to_gregorian_days(RefDate),
    DOW = kz_date:wday_to_dow(Weekday),
    Occurance = kz_date:ordinal_to_position(Ordinal),
    Days = case calendar:day_of_the_week(RefDate) of
               DOW ->
                   RefDays + 7 + (7 * Occurance );
               RefDOW when DOW < RefDOW ->
                   RefDays + DOW + (7 - RefDOW) + (7 * Occurance);
               RefDOW ->
                   RefDays + abs(DOW - RefDOW) + (7 * Occurance)
           end,
    {Y, M, D} = calendar:gregorian_days_to_date(Days),
    kz_date:normalize({Y, M, D}).

%%------------------------------------------------------------------------------
%% @doc Calculates the distance, in total ISO weeks, between two dates
%% I rather dislike this approach, but it is the best of MANY evils that I came up with...
%% The idea here is to find the difference (in days) between the ISO 8601 Mondays
%% of the start and end dates.  This takes care of all the corner cases for us such as:
%%    - Start date in ISO week of previous year
%%    - End date in ISO week of previous year
%%    - Spanning years
%% All while remaining ISO 8601 compliant.
%% @end
%%------------------------------------------------------------------------------
-spec iso_week_difference(kz_time:date(), kz_time:date()) -> non_neg_integer().
iso_week_difference({Y0, M0, D0}, {Y1, M1, D1}) ->
    DS0 = calendar:date_to_gregorian_days(kz_date:from_iso_week(calendar:iso_week_number({Y0, M0, D0}))),
    DS1 = calendar:date_to_gregorian_days(kz_date:from_iso_week(calendar:iso_week_number({Y1, M1, D1}))),
    trunc( abs( DS0 - DS1 ) / 7 ).

-spec find_active_days(kz_term:ne_binaries(), kz_time:day()) -> [kz_time:daynum()].
find_active_days(Weekdays, DOW0) ->
    [DOW1
     || DOW1 <- [kz_date:wday_to_dow(D) || D <- Weekdays],
        DOW1 >= DOW0
    ].
