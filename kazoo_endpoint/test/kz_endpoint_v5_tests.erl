%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2025, 2600Hz
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
    lists:flatten([merge_attribute_tests(<<"call_limits">>)
                  ,merge_attribute_tests(<<"addresses">>)
                  ]).

merge_attribute_tests(<<"call_limits">>=Key) ->
    Test = fun(InAccount, InEndpoint, InOwner) ->
                   Resp = kz_endpoint_v5:merge_attribute(Key, InAccount, InEndpoint, InOwner),
                   %% Get merged object.
                   kzd_endpoint:call_limits(Resp)
           end,
    AccountLimit = {kzd_accounts:type(), kz_term:rand_integer(1, 10)},
    OwnerLimit = {kzd_users:type(), kz_term:rand_integer(1, 10)},
    EndpointLimit = {kzd_devices:type(), kz_term:rand_integer(1, 10)},
    NotLimit = new_limited_entity(),
    Account = new_limited_entity(AccountLimit),
    Owner = new_limited_entity(OwnerLimit),
    Endpoint = new_limited_entity(EndpointLimit),

    [{"not configured at any level"
     ,?_assert(match_merge_attribute_response('undefined', Test(NotLimit, NotLimit, NotLimit)))
     }
    ,{"configured at account level"
     ,?_assert(match_merge_attribute_response([AccountLimit], Test(Account, NotLimit, NotLimit)))
     }
    ,{"configured at owner level"
     ,?_assert(match_merge_attribute_response([OwnerLimit], Test(NotLimit, NotLimit, Owner)))
     }
    ,{"configured at endpoint level"
     ,?_assert(match_merge_attribute_response([EndpointLimit], Test(NotLimit, Endpoint, NotLimit)))
     }
    ,{"configured at account and owner level"
     ,?_assert(match_merge_attribute_response([AccountLimit, OwnerLimit]
                                             ,Test(Account, NotLimit, Owner)
                                             ))
     }
    ,{"configured at account and endpoint level"
     ,?_assert(match_merge_attribute_response([AccountLimit, EndpointLimit]
                                             ,Test(Account, Endpoint, NotLimit)
                                             ))
     }
    ,{"configured at owner and endpoint level"
     ,?_assert(match_merge_attribute_response([OwnerLimit, EndpointLimit]
                                             ,Test(NotLimit, Endpoint, Owner)
                                             ))
     }
    ,{"configured at all levels"
     ,?_assert(match_merge_attribute_response([AccountLimit, OwnerLimit, EndpointLimit]
                                             ,Test(Account, Endpoint, Owner)
                                             ))
     }
    ,{"configured at all levels with the same limit"
     ,?_assert(match_merge_attribute_response([OwnerLimit, OwnerLimit, OwnerLimit]
                                             ,Test(Owner, Owner, Owner)
                                             ))
     }
    ];
merge_attribute_tests(<<"addresses">>=Key) ->
    Test = fun(InAccount, InEndpoint, InOwner) ->
                   Resp = kz_endpoint_v5:merge_attribute(Key, InAccount, InEndpoint, InOwner),
                   %% Get merged object.
                   kzd_addresses:emergency(kz_json:get_json_value(Key, Resp, kz_json:new()))
           end,
    AccountAddr = new_address(<<"Account Address">>),
    OwnerAddr = new_address(<<"Owner Address">>),
    EndpointAddr = new_address(<<"Endpoint Address">>),
    NotAddr = kz_json:new(),
    Account = new_addressed_entity(kzd_accounts:type(), AccountAddr),
    Owner = new_addressed_entity(kzd_users:type(), OwnerAddr),
    Endpoint = new_addressed_entity(kzd_devices:type(), EndpointAddr),

    [{"not configured at any level"
     ,?_assert(match_merge_attribute_response('undefined', Test(NotAddr, NotAddr, NotAddr)))
     }
    ,{"configured at account level"
     ,?_assert(match_merge_attribute_response(AccountAddr, Test(Account, NotAddr, NotAddr)))
     }
    ,{"configured at owner level"
     ,?_assert(match_merge_attribute_response(OwnerAddr, Test(NotAddr, NotAddr, Owner)))
     }
    ,{"configured at endpoint level"
     ,?_assert(match_merge_attribute_response(EndpointAddr, Test(NotAddr, Endpoint, NotAddr)))
     }
    ,{"configured at account and owner level"
     ,?_assert(match_merge_attribute_response(OwnerAddr, Test(Account, NotAddr, Owner)))
     }
    ,{"configured at account and endpoint level"
     ,?_assert(match_merge_attribute_response(EndpointAddr, Test(Account, Endpoint, NotAddr)))
     }
    ,{"configured at owner and endpoint level"
     ,?_assert(match_merge_attribute_response(EndpointAddr, Test(NotAddr, Endpoint, Owner)))
     }
    ,{"configured at all levels"
     ,?_assert(match_merge_attribute_response(EndpointAddr, Test(Account, Endpoint, Owner)))
     }
    ].


-spec match_merge_attribute_response([{kz_term:api_ne_binary(), kz_term:api_pos_integer()}] | kz_json:object()
                                    ,kz_term:api_object()
                                    ) -> boolean().
match_merge_attribute_response([_ | _]=ExpectedKeys, MergedJObj) ->
    match_merge_attribute_response(kz_json:from_list(ExpectedKeys), MergedJObj);
match_merge_attribute_response(ExpectedJObj, MergedJObj) ->
    kz_json:are_equal(ExpectedJObj, MergedJObj).


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

-spec new_addressed_entity(kz_term:ne_binary(), kz_term:api_object()) -> kz_json:object().
new_addressed_entity(Type, Address) ->
    kzd_endpoint:set_addresses_emergency(kz_doc:set_type(kz_json:new(), Type), Address).

-spec new_address(kz_term:ne_binary()) -> kz_json:object().
new_address(Name) ->
    kz_json:from_list([{<<"country">>, <<"US">>}
                      ,{<<"house_number">>, <<"123">>}
                      ,{<<"locality">>, <<"New York">>}
                      ,{<<"name">>, Name}
                      ,{<<"postal_code">>, <<"10027-0401">>}
                      ,{<<"region">>, <<"New York">>}
                      ,{<<"street">>, <<"Broadway">>}
                      ]).
