%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_tests).

-include_lib("eunit/include/eunit.hrl").
-include("../src/kz_auth_scope.hrl").

-define(ACCOUNT_4, <<"account%2Fac%2Fco%2Funt0000000000000000000000004">>).
-define(USER_4, <<"user0000000000000000000000000004">>).

create_token_test_() ->
    {'setup'
    ,fun setup/0
    ,fun cleanup/1
    ,fun(_) ->
             [create_tokens_normal()
             ,{"Validating mocked functions", validate_mock()}
             ]
     end
    }.

create_tokens_normal() ->
    Token1 = create_token([{<<"account_id">>, ?ACCOUNT_4}
                          ,{<<"owner_id">>, ?USER_4}
                          ]
                         ,true
                         ),
    Decoded1 = validate_token(Token1, [], true),
    [{"a token created token"
     ,?_assert(kz_term:is_ne_binary(Token1))
     }
    ,{"token is valid"
     ,?_assert(kz_term:is_not_empty(Decoded1))
     }
    ].

create_token(Prop, Log) ->
    case kz_auth:create_token(Prop) of
        {'ok', Token} -> Token;
        {'error', _Error} when Log ->
            ?debugFmt("~nfailed to create token ~p~n", [_Error]),
            'undefined';
        {'error', _ } -> 'undefined'
    end.

validate_token(Token, Options, Log) ->
    case kz_auth:validate_token(Token, Options) of
        {'ok', Claim} -> Claim;
        {'error', _Error} when Log ->
            ?debugFmt("~nfailed to validate token ~p~n", [_Error]),
            'undefined';
        {'error', _Error} -> kz_json:new()
    end.

setup() ->
    mock_them_all(),
    LinPid = kzd_test_fixtures:setup(),
    LinPid.

cleanup(LinkPid) ->
    kzd_test_fixtures:cleanup(LinkPid),
    meck:unload().

mock_them_all() ->
    meck:new('kz_cache', ['unstick', 'passthrough']),
    meck:expect('kz_cache', 'store_local', kz_cache_store_local()),
    'ok'.

validate_mock() ->
    [{"Validating mocked " ++ kz_term:to_list(Mocked)
     ,?_assertEqual('true', meck:validate(Mocked))
     }
     || Mocked <- ['kz_cache'
                  ]
    ].

kz_cache_store_local() ->
    fun(?PK_CACHE, _KeyId, _Key, _Options) ->
            'ok';
       (Cache, KeyId, Key, Options) ->
            meck:passthrough([Cache, KeyId, Key, Options])
    end.
