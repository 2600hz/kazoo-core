-module(kz_okko_tests).

-include_lib("eunit/include/eunit.hrl").

default_resolver() ->
    kz_okko:build_conflict_resolver([]).

merge_keyed_ok_test() ->
    FirstOkko = #{'ok'=> [{'a', 1}],'ko'=> [] },
    SecondOkko = #{'ok'=> [{'a', 2}],'ko'=> [] },
    Got = kz_okko:merge_keyed([FirstOkko, SecondOkko], default_resolver()),
    ?assertEqual(#{'ok'=> [{'a', 2}],ko => []}, Got).

merge_keyed_error_test() ->
    FirstOkko = #{'ko'=> [{'a', 1}],'ok'=> [] },
    SecondOkko = #{'ko'=> [{'a', 2}],'ok'=> [] },
    Got = kz_okko:merge_keyed([FirstOkko, SecondOkko], default_resolver()),
    ?assertEqual(#{'ko'=> [{'a', 2}],'ok'=> []}, Got).

merge_keyed_diff_test() ->
    FirstOkko = #{'ok'=> [{'a', 1}],'ko'=> [] },
    SecondOkko = #{'ko'=> [{'a', 2}],'ok'=> [] },
    Got = kz_okko:merge_keyed([FirstOkko, SecondOkko], default_resolver()),
    ?assertEqual(#{'ko'=> [{'a', 2}],'ok'=> []}, Got).
