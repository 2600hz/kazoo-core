%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_binary_tests).

-ifdef(PROPER).
-include_lib("proper/include/proper.hrl").
-endif.

-include_lib("eunit/include/eunit.hrl").

-ifdef(PROPER).
proper_test_() ->
    {"Runs kz_json PropEr tests"
    ,{'timeout'
     ,10000
     ,[{atom_to_list(F)
       ,fun () ->
                ?assert(proper:quickcheck(?MODULE:F(), [{'to_file', 'user'}
                                                       ,{'numtests', 500}
                                                       ]))
        end
       }
       || {F, 0} <- ?MODULE:module_info('exports'),
          F > 'prop_',
          F < 'prop`'
      ]
     }
    }.

prop_bin_reverse() ->
    ?FORALL(Bin
           ,binary()
           ,?WHENFAIL(?debugFmt("failed to reverse binary ~p~n", [Bin])
                     ,kz_binary:reverse(kz_binary:reverse(Bin)) =:= Bin
                     )
           ).

prop_to_from_hex() ->
    ?FORALL(Bin
           ,binary(),
            begin
                Bin =:= kz_binary:from_hex(kz_term:to_hex_binary(Bin))
            end).

-endif.

pad_binary_test() ->
    ?assertEqual(<<"1234500000">>, kz_binary:pad(<<"12345">>, 10, <<"0">>)).

pos_test_() ->
    [?_assertEqual(-1, kz_binary:pos($A, <<>>))
    ,?_assertEqual(0, kz_binary:pos($A, <<$A>>))
    ,?_assertEqual(0, kz_binary:pos($,, <<",,,">>))
    ,?_assertEqual(1, kz_binary:pos($,, <<"A,,">>))
    ,?_assertEqual(2, kz_binary:pos($', <<"A,'">>))
    ,?_assertEqual(-1, kz_binary:pos($B, <<"A,'">>))
    ].

closests_test_() ->
    [?_assertEqual([], kz_binary:closests([$A], <<>>))
    ,?_assertEqual([{$B,1}], kz_binary:closests([$B,$i], <<"ABAAABA">>))
    ,?_assertEqual([{$B,1}, {$i,6}], kz_binary:closests([$B,$i], <<"ABAAABiA">>))
    ].

to_hex_test_() ->
    [?_assertEqual(<<"626c61">>, kz_binary:hexencode('bla'))
    ,?_assertEqual(<<"626c61">>, kz_binary:hexencode("bla"))
    ,?_assertEqual(<<"626c61">>, kz_binary:hexencode(<<"bla">>))
    ,?_assertEqual(30, byte_size(kz_binary:rand_hex("15")))
    ,?_assertEqual(32, byte_size(kz_binary:rand_hex(<<"16">>)))
    ].

join_binary_test_() ->
    [?_assertEqual(<<>>, kz_binary:join([]))
    ,?_assertEqual(<<"f, o, o">>, kz_binary:join([<<"f">>, <<"o">>, <<"o">>]))
    ,?_assertEqual(<<"foo">>, kz_binary:join([<<"foo">>], <<", ">>))
    ,?_assertEqual(<<"foo, bar">>, kz_binary:join([<<"foo">>, <<"bar">>], <<", ">>))
    ,?_assertEqual(<<"foo, bar, baz">>, kz_binary:join([<<"foo">>, <<"bar">>, <<"baz">>], <<", ">>))
    ].

ucfirst_binary_test_() ->
    [?_assertEqual(<<"Foo">>, kz_binary:ucfirst(<<"foo">>))
    ,?_assertEqual(<<"Foo">>, kz_binary:ucfirst(<<"Foo">>))
    ,?_assertEqual(<<"FOO">>, kz_binary:ucfirst(<<"FOO">>))
    ,?_assertEqual(<<"1oo">>, kz_binary:ucfirst(<<"1oo">>))
    ,?_assertEqual(<<"100">>, kz_binary:ucfirst(<<"100">>))
    ,?_assertEqual(<<"1FF">>, kz_binary:ucfirst(<<"1FF">>))
    ].

lcfirst_binary_test_() ->
    [?_assertEqual(<<"foo">>, kz_binary:lcfirst(<<"foo">>))
    ,?_assertEqual(<<"foo">>, kz_binary:lcfirst(<<"Foo">>))
    ,?_assertEqual(<<"fOO">>, kz_binary:lcfirst(<<"FOO">>))
    ,?_assertEqual(<<"1oo">>, kz_binary:lcfirst(<<"1oo">>))
    ,?_assertEqual(<<"100">>, kz_binary:lcfirst(<<"100">>))
    ,?_assertEqual(<<"1FF">>, kz_binary:lcfirst(<<"1FF">>))
    ].

strip_binary_test_() ->
    [?_assertEqual(<<"foo">>, kz_binary:strip(<<"foo">>))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<"foo ">>))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<" foo ">>))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<"  foo  ">>))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<"     foo">>))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<"     foo   ">>, 'both'))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<"     foo   ">>, ['left','right']))

    ,?_assertEqual(<<"foo">>, kz_binary:strip_left(<<"foo">>, $\s))
    ,?_assertEqual(<<"foo">>, kz_binary:strip_left(<<" foo">>, $\s))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<" foo">>, 'left'))
    ,?_assertEqual(<<"foo ">>, kz_binary:strip_left(<<" foo ">>, $\s))
    ,?_assertEqual(<<"foo ">>, kz_binary:strip_left(<<"foo ">>, $\s))

    ,?_assertEqual(<<"foo">>, kz_binary:strip_right(<<"foo">>, $\s))
    ,?_assertEqual(<<" foo">>, kz_binary:strip_right(<<" foo">>, $\s))
    ,?_assertEqual(<<" foo">>, kz_binary:strip_right(<<" foo ">>, $\s))
    ,?_assertEqual(<<"foo">>, kz_binary:strip_right(<<"foo ">>, $\s))
    ,?_assertEqual(<<"foo">>, kz_binary:strip(<<"foo ">>, 'right'))
    ].

strip_test() ->
    ?assertEqual(kz_binary:strip(<<"...Hello.....">>, $.), <<"Hello">>).

suffix_binary_test_() ->
    [?_assertEqual('false', kz_binary:suffix(<<>>, <<"1">>))
    ,?_assertEqual('false', kz_binary:suffix(<<"1">>, <<>>))
    ,?_assertEqual('true', kz_binary:suffix(<<"34">>, <<"1234">>))
    ,?_assertEqual('false', kz_binary:suffix(<<"34">>, <<"12345">>))
    ,?_assertEqual('false', kz_binary:suffix(<<"1234">>, <<"1">>))
    ].

clean_binary_test_() ->
    [?_assertEqual(<<>>, kz_binary:clean(<<>>))
    ,?_assertEqual(<<"bla">>, kz_binary:clean(<<"bla">>))
    ,?_assertEqual(<<"bla">>, kz_binary:clean(<<"bla  ">>))
    ,?_assertEqual(<<"bla">>, kz_binary:clean(<<"  bla">>))
    ,?_assertEqual(<<"bla">>, kz_binary:clean(<<"  bla  ">>))
    ,?_assertEqual(<<"bla">>, kz_binary:clean(<<" b l a ">>))
    ,?_assertEqual(<<"bla\n">>, kz_binary:clean(<<" b l a \n">>))
    ].

binary_hashes_test_() ->
    [?_assertEqual(<<"d41d8cd98f00b204e9800998ecf8427e">>, kz_binary:md5(<<>>))
    ,?_assertEqual("44add22b6f3179b751eafd68ee370f7d", kz_math:a1hash(<<"u">>, <<"r">>, <<"p">>))
    ].

binary_reverse_test_() ->
    [?_assertEqual(<<>>, kz_binary:reverse(<<>>))
    ,?_assertEqual(<<"B a">>, kz_binary:reverse(<<"a B">>))
    ].

truncate_binary_test_() ->
    [?_assertEqual(<<>>, kz_binary:truncate(<<>>, 0))
    ,?_assertEqual(<<>>, kz_binary:truncate(<<>>, 42))
    ,?_assertEqual(<<"b">>, kz_binary:truncate(<<"bla">>, 1))
    ,?_assertEqual(<<"bl">>, kz_binary:truncate_right(<<"bla">>, 2))
    ,?_assertEqual(<<"la">>, kz_binary:truncate_left(<<"bla">>, 2))
    ,?_assertEqual(<<"a">>, kz_binary:truncate_left(<<"bla">>, 1))
    ,?_assertEqual(<<"bla">>, kz_binary:truncate(<<"bla">>, 4))
    ,?_assertEqual(<<"bla">>, kz_binary:truncate_left(<<"bla">>, 4))
    ,?_assertEqual(<<"bla">>, kz_binary:truncate_right(<<"bla">>, 4))
    ].

to_proplist_test_() ->
    TestF = fun kz_binary:to_proplist/3,
    [to_proplist_with_properties(TestF)
    ,to_proplist_with_properties_without_values(TestF)
    ,to_proplist_without_properties(TestF)
    ].

to_proplist_with_properties(TestF) ->
    %% Property: key=value, key  =value, key = value, etc.
    Bins = [<<"a=A,b=B,c=C">> %% Well formatted.
           ,<<",a=A,b=B,c=C">> %% Starts with separator character.
           ,<<"a=A,,b=B,c=C">> %% No information between separator characters (empty property (?)).
           ,<<"a=A, b=B ,c=C">> %% Spaces anywhere.
           ,<<"a = A,b=B ,c= C">> %% Spaces anywhere.
           ,<<"   a = A,b=B ,c= C ">> %% Spaces anywhere.
           ,<<"  a   =   A , b =B , c= C ">> %% Spaces anywhere.
           ],
    Expected = [{<<"a">>, <<"A">>}
               ,{<<"b">>, <<"B">>}
               ,{<<"c">>, <<"C">>}
               ],
    Test = [{Bin, TestF(Bin, <<",">>, <<"=">>)} || Bin <- Bins],

    [{"binary: " ++ kz_term:to_list(Binary)
     ,[?_assertEqual(<<"A">>, props:get_value(<<"a">>, Proplist))
      ,?_assertEqual(<<"B">>, props:get_value(<<"b">>, Proplist))
      ,?_assertEqual(<<"C">>, props:get_value(<<"c">>, Proplist))
      ,?_assertEqual(Expected, Proplist) %% Test output's order matches input's order.
      ]
     } || {Binary, Proplist} <- Test
    ].

to_proplist_with_properties_without_values(TestF) ->
    Result0 = TestF(<<"hello=,a=A">>, <<",">>, <<"=">>),
    Result1 = TestF(<<"hello=world,a=, b=">>, <<",">>, <<"=">>),
    [{"binary: hello=,a=A"
     ,[?_assertEqual(<<>>, props:get_value(<<"hello">>, Result0))
      ,?_assertEqual(<<"A">>, props:get_value(<<"a">>, Result0))
      ]
     }
    ,{"binary: hello=world,a=, b="
     ,[?_assertEqual(<<"world">>, props:get_value(<<"hello">>, Result1))
      ,?_assertEqual(<<>>, props:get_value(<<"a">>, Result1))
      ,?_assertEqual(<<>>, props:get_value(<<"b">>, Result1))
      ]
     }
    ].

to_proplist_without_properties(TestF) ->
    Bins = [<<>>, <<" ">>, <<", , , ,">>, <<"hello">>, <<"hello,world">>],

    [{kz_term:to_list(Bin)
     ,?_assertEqual([], TestF(Bin, <<",">>, <<"=">>))
     } || Bin <- Bins
    ].

matches_test_() ->
    Regexes = [{<<"^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$">> %% IP addresses.
               ,[<<"0.0.0.0">>, <<"1.2.3.4">>, <<"10.0.0.1">>, <<"192.168.0.1">>, <<"255.255.255.255">>]
               ,[<<"1.2.3">>, <<"256.0.0.1">>, <<"999.999.999.999">>]
               }
              ,{<<"^[\\w\\d_\\+]+@[\\w\\d_\\]+\.[a-z]+$">> %% Non-strict user@domain.com.
               ,[<<"hello@example.com">>, <<"h3l10@d0ma1n.sub">>]
               ,[<<"hello-example.com">>, <<"he-llo@example">>, <<"user@">>, <<"user.com">>, <<"@domain.sub">>, <<"user @domain.sub">>]
               }
              ,{<<"[\\d]+">> %% Contains numbers
               ,[<<"abc1">>, <<"1a2b3c">>, <<"0">>, <<"+123">>, <<"123-abc_">>]
               ,[<<>>, <<" ">>, <<"hello">>, <<"+one">>]
               }
              ,{<<"^sips?">> %% Starts with sip or sips.
               ,[<<"sip">>, <<"sips">>, <<"sip:something">>, <<"sips:something">>]
               ,[<<>>, <<"<sip">>, <<"<sips:user@domain.com>">>, <<"s ip">>, <<"si-ps">>, <<"s1ps">>]
               }
              ,{<<".+">> %% Everything that is not an empty string.
               ,[<<"He">>, <<"+1234@QwErTy -_$">>]
               ,[<<>>]
               }
              ],
    [{"regex: " ++ kz_term:to_list(Regex)
     ,[{"Should match"
       ,[{kz_term:to_list(Subject), ?_assert(kz_binary:matches(Subject, Regex))} || Subject <- ShouldMatch]
       }
      ,{"Should NOT match"
       ,[{kz_term:to_list(Subject), ?_assertNot(kz_binary:matches(Subject, Regex))} || Subject <- ShouldNotMatch]
       }
      ]
     } || {Regex, ShouldMatch, ShouldNotMatch} <- Regexes
    ].

-ifdef(PERF).
-define(REPEAT, 100000).

%% from https://stackoverflow.com/questions/20830201/better-way-to-reverse-binary#20832625
%% Bin size 4:
%% kz_binary_test:rev in 0.171672s
%% kz_binary_test:rev2 in 0.023417s
%% kz_binary_test:reverse in 0.031123s

%% Bin size 16:
%% kz_binary_test:rev in 0.635037s
%% kz_binary_test:rev2 in 0.029335s
%% kz_binary_test:reverse in 0.047751s

%% Bin size: 128
%% kz_binary_test:rev in 3.322764s
%% kz_binary_test:rev2 in 0.059977s
%% kz_binary_test:reverse in 0.338276s

%% Bin size: 1024
%% kz_binary_test:rev in 31.880859s
%% kz_binary_test:rev2 in 0.363329s
%% kz_binary_test:reverse in 1.530542s

-define(BIN, <<"75d46db34465e620c214bdeaf214eac1c87833851166fbbd59aeb0a35aa1bd901abac59eb53fe4c076261537632aefba8ab16889550f84bb51c6934a97ba813c">>).

-spec rev1(binary()) -> binary().
rev1(Bin) -> rev1(Bin, <<>>).
rev1(<<>>, Acc) -> Acc;
rev1(<<H:1/binary, Rest/binary>>, Acc) ->
    rev1(Rest, <<H/binary, Acc/binary>>).

horse_rev() ->
    horse:repeat(?REPEAT, rev1(?BIN)).

horse_rev2() ->
    horse:repeat(?REPEAT, kz_binary:reverse(?BIN)).


old_reverse(Bin) ->
    kz_term:to_binary(lists:reverse(kz_term:to_list(Bin))).

horse_reverse() ->
    horse:repeat(?REPEAT, old_reverse(?BIN)).

-endif.
