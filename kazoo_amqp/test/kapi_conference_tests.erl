%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_conference_tests).

-include_lib("eunit/include/eunit.hrl").

conference_event_key_test_() ->
    Test = fun kapi_conference:conference_event_key/4,
    Event = kz_binary:rand_hex(4),
    AccountId = kz_binary:rand_hex(4),
    ConferenceId = kz_binary:rand_hex(4),
    CallId = kz_binary:rand_hex(4),
    Expected = <<Event/binary, ".", AccountId/binary, ".", ConferenceId/binary, ".", CallId/binary>>,
    Expected1 = <<"*.*.*.*">>,

    [{"CallId must be binary"
     ,[?_assertEqual(Expected, Test(Event, AccountId, ConferenceId, CallId))
      ,?_assertException('error'
                        ,'function_clause'
                        ,Test(Event, AccountId, ConferenceId, kz_term:to_list(CallId))
                        )
      ]
     }
    ,{"Event, AccountId, And ConferenceId may be binary"
     ,[?_assertEqual(Expected, Test(Event, AccountId, ConferenceId, CallId))
      ,?_assertEqual(Expected1, Test(<<"*">>, <<"*">>, <<"*">>, <<"*">>))
      ]
     }
    ,{"Event, AccountId, And ConferenceId may be string"
     ,[?_assertEqual(Expected
                    ,Test(kz_term:to_list(Event)
                         ,kz_term:to_list(AccountId)
                         ,kz_term:to_list(ConferenceId)
                         ,CallId
                         )
                    )
      ,?_assertEqual(Expected1, Test("*", "*", "*", <<"*">>))
      ]
     }
    ].
