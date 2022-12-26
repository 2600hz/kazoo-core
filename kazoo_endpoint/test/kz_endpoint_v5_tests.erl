%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoint_v5_tests).

-include_lib("eunit/include/eunit.hrl").
merge_attribute_test_() ->
    merge_attribute_tests(<<"call_limits">>).

merge_attribute_tests(<<"call_limits">>=Key) ->
    Test = fun(InAccount, InEndpoint, InOwner) ->
                   kz_endpoint_v5:merge_attribute(Key, InAccount, InEndpoint, InOwner)
           end,
    AccountLimit = {kzd_accounts:type(), kz_term:rand_integer(1, 10)},
    OwnerLimit = {kzd_users:type(), kz_term:rand_integer(1, 10)},
    EndpointLimit = {kzd_devices:type(), kz_term:rand_integer(1, 10)},
    NotLimit = new_limited_entity(),
    Account = new_limited_entity(AccountLimit),
    Owner = new_limited_entity(OwnerLimit),
    Endpoint = new_limited_entity(EndpointLimit),
    Resp = Test(Account, NotLimit, NotLimit),
    ?debugFmt("Resp: ~p", [Resp]), %% TODO: Remove this debug line

    [{"not configured at any level"
     ,?_assert(match_merge_call_limits_response([], Test(NotLimit, NotLimit, NotLimit)))
     }
    ,{"configured at account level"
     ,?_assert(match_merge_call_limits_response([AccountLimit], Test(Account, NotLimit, NotLimit)))
     }
    ,{"configured at owner level"
     ,?_assert(match_merge_call_limits_response([OwnerLimit], Test(NotLimit, NotLimit, Owner)))
     }
    ,{"configured at endpoint level"
     ,?_assert(match_merge_call_limits_response([EndpointLimit], Test(NotLimit, Endpoint, NotLimit)))
     }
    ,{"configured at account and owner level"
     ,?_assert(match_merge_call_limits_response([AccountLimit, OwnerLimit]
                                               ,Test(Account, NotLimit, Owner)
                                               ))
     }
    ,{"configured at account and endpoint level"
     ,?_assert(match_merge_call_limits_response([AccountLimit, EndpointLimit]
                                               ,Test(Account, Endpoint, NotLimit)
                                               ))
     }
    ,{"configured at owner and endpoint level"
     ,?_assert(match_merge_call_limits_response([OwnerLimit, EndpointLimit]
                                               ,Test(NotLimit, Endpoint, Owner)
                                               ))
     }
    ,{"configured at all levels"
     ,?_assert(match_merge_call_limits_response([AccountLimit, OwnerLimit, EndpointLimit]
                                               ,Test(Account, Endpoint, Owner)
                                               ))
     }
    ,{"configured at all levels with the same limit"
     ,?_assert(match_merge_call_limits_response([OwnerLimit, OwnerLimit, OwnerLimit]
                                               ,Test(Owner, Owner, Owner)
                                               ))
     }
    ].

-spec match_merge_call_limits_response([{kz_term:api_ne_binary(), kz_term:api_pos_integer()}], kz_json:object()) -> boolean().
match_merge_call_limits_response([], Response) ->
    kz_json:are_equal('undefined', kzd_endpoint:call_limits(Response));
match_merge_call_limits_response(ExpectedKeys, Response) ->
    kz_json:are_equal(kz_json:from_list(ExpectedKeys), kzd_endpoint:call_limits(Response)).


%% Helpers
-spec new_limited_entity() -> kz_json:object().
new_limited_entity() ->
    new_limited_entity({'undefined', 'undefined'}).

-spec new_limited_entity({kz_term:api_ne_binary(), kz_term:api_pos_integer()}) -> kz_json:object().
new_limited_entity({DocType, CallLimit}) ->
    kz_json:from_list_recursive([{<<"call_limits">>, [{<<"max_concurrent">>, CallLimit}
                                                     ]}
                                ,{<<"pvt_type">>, DocType}
                                ]).
