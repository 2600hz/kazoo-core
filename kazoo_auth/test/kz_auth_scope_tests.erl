%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope_tests).

-include_lib("eunit/include/eunit.hrl").
-include("kazoo_auth.hrl").

-define(ISSUED_SCOPES, [<<"foo">>, <<"bar">>, <<"baz:qux">>, <<"quux">>, <<"z:y:w">>]).
-define(EXPECTED_TO_LIST, [<<"foo">>, <<"bar">>, [<<"baz">>, <<"qux">>], <<"quux">>, [<<"z">>, <<"y">>, <<"w">>]]).
-define(EXPECTED_TO_STR, <<"foo bar baz:qux quux z:y:w">>).
-define(AVAILABLE_SCOPES, [{<<"quux">>, [<<"corge">>, <<"grault:garply">>]}
                          ,{<<"corge">>, [<<"waldo">>, <<"fred:plugh">>]}
                          ,{<<"zyzzy">>, [<<"waldo">>, <<"fred:plugh">>]}
                          ,{<<"thud">>, [<<"baz:qux">>, <<"fred:plugh">>]}
                          ]).
-define(EXPECTED_SCOPES, [<<"bar">>
                         ,<<"baz">>
                         ,<<"baz:qux">>
                         ,<<"corge">>
                         ,<<"foo">>
                         ,<<"fred">>
                         ,<<"fred:plugh">>
                         ,<<"grault">>
                         ,<<"grault:garply">>
                         ,<<"quux">>
                         ,<<"waldo">>
                         ,<<"z">>
                         ,<<"z:y">>
                         ,<<"z:y:w">>
                         ]).
-define(CLAIMS, [{<<"foo">>, <<"bar">>}]).


key() ->
    {ok, Key} = kz_auth_keys:gen_private_key(),
    Key.

token(Key, Claims) ->
    TK = #{claims => Claims
          ,issuer => <<"kazoo">>
          ,auth_app => #{}
          ,kid => kz_binary:rand_hex(16)
          ,key => Key
          },
    {ok, Token} = kz_auth_jwt:encode(TK),
    Token.

transform_test_() ->
    [{"Verifying that to_str works"
     ,?_assertEqual(kz_auth_scope:to_str(?ISSUED_SCOPES), ?EXPECTED_TO_STR)
     }
    ,{"Verifying that to_list works"
     ,?_assertEqual(kz_auth_scope:to_list(kz_auth_scope:to_str(?ISSUED_SCOPES)), ?EXPECTED_TO_LIST)
     }
    ,{"Verifying that to_str and to_list work together"
     ,?_assertEqual(kz_auth_scope:to_str(kz_auth_scope:to_list(kz_auth_scope:to_str(?ISSUED_SCOPES))), ?EXPECTED_TO_STR)
     }
    ].


has_test_() ->
    Key = key(),
    PK = kz_auth_keys:get_public_key_from_private_key(Key),
    Scope = kz_auth_scope:to_str(?ISSUED_SCOPES),
    Claims = [{<<"scope">>, Scope} | ?CLAIMS],
    Encoded = token(Key, Claims),
    {ok, T0} = kz_auth_jwt:parse(Encoded),
    T1 = T0#{jwt_public_key => PK},
    Decoded = T1#{scopes_available => ?AVAILABLE_SCOPES},

    [{"exploded scopes match"
     ,?_assertEqual(kz_auth_scope:scopes(Decoded), ?EXPECTED_SCOPES)
     }
    ,{"has foo"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"foo">>), true)
     }
    ,{"has foo & bar"
     ,?_assertEqual(kz_auth_scope:all(Decoded, [<<"foo">>, <<"bar">>]), true)
     }
    ,{"composed baz:qux"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"baz:qux">>), true)
     }
    ,{"composed baz:qux has baz"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"baz">>), true)
     }
    ,{"composed baz:qux doesn't have qux"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"qux">>), false)
     }
    ,{"resolved simple"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"corge">>), true)
     }
    ,{"resolve composed"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"grault:garply">>), true)
     }
    ,{"resolve composed base"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"grault">>), true)
     }
    ,{"resolve composed extended"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"garply">>), false)
     }
    ,{"resolve recursive"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"waldo">>), true)
     }
    ,{"composed 3 levels"
     ,?_assertEqual(kz_auth_scope:has(Decoded, <<"z:y">>), true)
     }
    ].

