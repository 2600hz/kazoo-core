%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_yaml_tests).

-include_lib("eunit/include/eunit.hrl").

-define(STRING_TYPES_FILE, filename:join([code:lib_dir(kazoo_stdlib)
                                         , "test/fixtures/string_types.yml"
                                         ])).

encode_test_() ->
    {'setup'
    ,fun setup/0
    ,fun cleanup/1
    ,fun(_ReturnOfSetup) ->
             [test_string_types()
             ,styling_string_number_is_bad_for_you()
             ]
     end
    }.

setup() ->
    {'ok', _} = application:ensure_all_started('yamerl').

cleanup(_) ->
    application:stop('yamerl').

test_string_types() ->
    {'ok', Bin} = file:read_file(?STRING_TYPES_FILE),
    Yaml = kz_yaml:encode(kz_yaml:decode(Bin), #{string_style => 'best'}),
    [{"Encode various type of string scalars"
     ,[?_assertEqual(Bin, Yaml)]
     }
    ].

styling_string_number_is_bad_for_you() ->
    [{"Dp not use plain for non plain safe strings"
     ,[?_assertEqual(<<"$ref: '[a-z]'\n">>, kz_yaml:encode(#{<<"$ref">> => <<"[a-z]">>}, #{string_style => 'plain'}))
      ,?_assertEqual(<<"lol: '123'\n">>, kz_yaml:encode(#{<<"lol">> => <<"123">>}, #{string_style => 'plain'}))
      ,?_assertEqual(<<"lol: 'True'\n">>, kz_yaml:encode(#{<<"lol">> => <<"True">>}, #{string_style => 'plain'}))
      ,?_assertEqual(<<"lol: 'NULL'\n">>, kz_yaml:encode(#{<<"lol">> => <<"NULL">>}, #{string_style => 'plain'}))
      ,?_assertEqual(<<"lol: '~'\n">>, kz_yaml:encode(#{<<"lol">> => <<"~">>}, #{string_style => 'plain'}))
      ,?_assertEqual(<<"'1': '~'\n">>, kz_yaml:encode(#{<<"1">> => <<"~">>}, #{key_string_style => 'plain'}))
      ,?_assertEqual(<<"'False': '~'\n">>, kz_yaml:encode(#{<<"False">> => <<"~">>}, #{key_string_style => 'plain'}))
      ,?_assertEqual(<<"'null': '~'\n">>, kz_yaml:encode(#{<<"null">> => <<"~">>}, #{key_string_style => 'plain'}))
      ,?_assertEqual(<<"lol: \"false\"\n">>, kz_yaml:encode(#{<<"lol">> => <<"false">>}, #{string_style => 'best', preferred_string_style => 'double_quote'}))

      ,?_assertEqual(<<"undefined: lol\n">>, kz_yaml:encode(#{<<"undefined">> => <<"lol">>}, #{key_string_style => 'plain'}))
      ,?_assertEqual(#{<<"undefined">> => <<"lol">>}, kz_yaml:decode(kz_yaml:encode(#{<<"undefined">> => <<"lol">>})))

      ,?_assertEqual(#{<<"12">> => <<"False">>}, kz_yaml:decode(kz_yaml:encode(#{<<"12">> => <<"False">>})))
      ,?_assertNotEqual(#{12 => 'false'}, kz_yaml:decode(kz_yaml:encode(#{<<"12">> => <<"False">>})))

      ,?_assertEqual(#{<<"~">> => <<"2.1">>}, kz_yaml:decode(kz_yaml:encode(#{<<"~">> => <<"2.1">>})))
      ,?_assertNotEqual(#{null => 2.1}, kz_yaml:decode(kz_yaml:encode(#{<<"~">> => <<"2.1">>})))
      ]
     }
    ].
