%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_math_tests).

-ifdef(PROPER).
-include_lib("proper/include/proper.hrl").
-endif.
-include_lib("eunit/include/eunit.hrl").

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-ifdef(PROPER).

proper_test_() ->
    {"Runs the module's PropEr tests during eunit testing",
     {'timeout'
     ,20000
     ,[?_assertEqual([], proper:module(?MODULE, [{'to_file', 'user'}]))]
     }
    }.

-endif.

float_bounds_test_() ->
    [?_assertEqual(1, kz_math:floor(1.0))
    ,?_assertEqual(1, kz_math:floor(1.2))
    ,?_assertEqual(1, kz_math:floor(1.5))
    ,?_assertEqual(1, kz_math:floor(1.7))
    ,?_assertEqual(-1, kz_math:floor(-1))
    ,?_assertEqual(-2, kz_math:floor(-1.5))
    ,?_assertEqual(1, kz_math:ceiling(1.0))
    ,?_assertEqual(2, kz_math:ceiling(1.2))
    ,?_assertEqual(2, kz_math:ceiling(1.5))
    ,?_assertEqual(2, kz_math:ceiling(1.7))
    ,?_assertEqual(-1, kz_math:ceiling(-1))
    ].

clamp_test_() ->
    Lowerbound = 10,
    Upperbound = 100,

    Tests = [{9, Lowerbound}
            ,{10, 10}
            ,{11, 11}
            ,{99, 99}
            ,{100, 100}
            ,{101, Upperbound}
            ],
    [?_assertEqual(Result, Clamped)
     || {Number, Clamped} <- Tests,
        Result <- [kz_math:clamp(Upperbound, Lowerbound, Number)]
    ].

%% test taken from kz_amqp_util_tests to make sure kz_math:clamp is equivalent
trim_test_() ->
    Lower = 0,
    Upper = 255,

    Vals = [{Lower-100, Lower}
           ,{Lower-1, Lower}
           ,{Lower, Lower}
           ,{Lower+1, Lower+1}
           ,{Upper-1, Upper-1}
           ,{Upper, Upper}
           ,{Upper+1, Upper}
           ,{Upper+100, Upper}
           ],
    [check_trim(Upper, Lower, Test) || Test <- Vals].

check_trim(Upper, Lower, {N, T}) ->
    ?_assertEqual(T, kz_math:clamp(Upper, Lower, N)).

-ifdef(PERF).
-define(REPEAT, 1000000).
-define(UPPERBOUND, 100).
-define(LOWERBOUND, 10).
-define(NUMBER, 105).

clamp_min_max(Upperbound, Lowerbound, Number) ->
    erlang:min(erlang:max(Number, Lowerbound), Upperbound).

horse_clamp_min_max() ->
    horse:repeat(?REPEAT, clamp_min_max(?UPPERBOUND, ?LOWERBOUND, ?NUMBER)).

clamp_sort(Upperbound, Lowerbound, Number) ->
    [_, Result, _] = lists:sort([Upperbound, Lowerbound, Number]),
    Result.
horse_clamp_sort() ->
    horse:repeat(?REPEAT, clamp_sort(?UPPERBOUND, ?LOWERBOUND, ?NUMBER)).

clamp_head(_Upperbound, Lowerbound, Number) when Number < Lowerbound -> Lowerbound;
clamp_head(Upperbound, _Lowerbound, Number) when Number > Upperbound -> Upperbound;
clamp_head(_Upperbound, _Lowerbound, Number) -> Number.

horse_clamp_head() ->
    horse:repeat(?REPEAT, clamp_head(?UPPERBOUND, ?LOWERBOUND, ?NUMBER)).

%% n=5
%% kz_math_tests:clamp_min_max in 0.057191s
%% kz_math_tests:clamp_sort in 0.113642s
%% kz_math_tests:clamp_head in 0.030916s

%% n=15
%% kz_math_tests:clamp_min_max in 0.054993s
%% kz_math_tests:clamp_sort in 0.110151s
%% kz_math_tests:clamp_head in 0.042106s

%% n=105
%% kz_math_tests:clamp_min_max in 0.054678s
%% kz_math_tests:clamp_sort in 0.101581s
%% kz_math_tests:clamp_head in 0.038288s


-endif.
