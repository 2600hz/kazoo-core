%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Kazoo API Tests
%%% @author James Aimonetti
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_api_tests).

%% EUNIT TESTING
-include_lib("eunit/include/eunit.hrl").
-define(_x_assertEqual(Expected, Received), ?_assert(kz_json:are_equal(Expected, Received))).

has_all_test_() ->
    Prop = [{<<"k1">>, <<"v1">>}
           ,{<<"k2">>, <<"v2">>}
           ,{<<"k3">>, <<"v3">>}
           ],
    Headers = [<<"k1">>, <<"k2">>, <<"k3">>],
    [?_assertEqual('true', kz_api:has_all(Prop, Headers))
    ,?_assertEqual('false', kz_api:has_all(Prop, [<<"k4">> | Headers]))
    ].

has_any_test_() ->
    Prop = [{<<"k1">>, <<"v1">>}
           ,{<<"k2">>, <<"v2">>}
           ,{<<"k3">>, <<"v3">>}
           ],
    Headers = [<<"k1">>, <<"k2">>, <<"k3">>],
    [?_assertEqual('true', kz_api:has_any(Prop, Headers))
    ,?_assertEqual('false', kz_api:has_any(Prop, [<<"k4">>]))
    ].

get_event_type_test_() ->
    EventCategory = {<<"Event-Category">>, <<"call">>},
    EventName = {<<"Event-Name">>, <<"CHANNEL_CONNECTED">>},
    [?_assertEqual({'undefined','undefined'}, kz_api:event_type([]))
    ,?_assertEqual({'undefined','undefined'}, kz_api:event_type(kz_json:from_list([])))
    ,?_assertEqual({<<"call">>,'undefined'}, kz_api:event_type([EventCategory]))
    ,?_assertEqual({<<"call">>,'undefined'}, kz_api:event_type(kz_json:from_list([EventCategory])))
    ,?_assertEqual({'undefined',<<"CHANNEL_CONNECTED">>}, kz_api:event_type([EventName]))
    ,?_assertEqual({'undefined',<<"CHANNEL_CONNECTED">>}, kz_api:event_type(kz_json:from_list([EventName])))
    ,?_assertEqual({<<"call">>,<<"CHANNEL_CONNECTED">>}, kz_api:event_type([EventCategory,EventName]))
    ,?_assertEqual({<<"call">>,<<"CHANNEL_CONNECTED">>}, kz_api:event_type(kz_json:from_list([EventCategory,EventName])))
    ].

normalize_amqp_test_() ->
    Test = fun kz_api:normalize_amqp/1,
    Test2 = fun kz_api:normalize_amqp/2,
    ToJSON = fun(Prop) -> kz_json:from_list_recursive(Prop) end,

    TestJObj = ToJSON([{<<"apns">>
                       ,[{<<"alert">>
                         ,[{<<"subtitle_key">>, <<"subtitle">>}
                          ,{<<"subtitle_params">>, <<"params">>}
                          ]
                         }
                        ,{<<"thread_id">>, <<"so-me-id">>}
                        ,{<<"topic">>, <<"topic">>}
                        ]
                       }
                      ,{<<"fcm">>, <<"some value">>}
                      ]),
    ExplicitReplaces = [{<<"apns">>, <<"APNs">>}
                       ,{<<"subtitle">>, <<"Sub-Title">>}
                       ,{<<"fcm">>, <<"FCM">>}
                       ],

    [{"\"simple\" object"
     ,?_x_assertEqual(ToJSON([{<<"Three-Words-Key">>, <<"value">>}])
                     ,Test(ToJSON([{<<"three_words_key">>, <<"value">>}]))
                     )
     }
    ,{"single word key"
     ,?_x_assertEqual(ToJSON([{<<"Key">>, <<"value">>}])
                     ,Test(ToJSON([{<<"key">>, <<"value">>}]))
                     )
     }
    ,{"already normalized key"
     ,?_x_assertEqual(ToJSON([{<<"Normalized-Key">>, <<"value">>}])
                     ,Test(ToJSON([{<<"Normalized-Key">>, <<"value">>}]))
                     )
     }
    ,{"id -> ID: \"id\" should be all upper cased when present"
     ,[?_x_assertEqual(ToJSON([{<<"Some-ID">>, <<"value">>}])
                      ,Test(ToJSON([{<<"some_id">>, <<"value">>}]))
                      )
      ,?_x_assertEqual(ToJSON([{<<"ID">>, <<"unique-id">>}])
                      ,Test(ToJSON([{<<"id">>, <<"unique-id">>}]))
                      )
      ,?_x_assertEqual(ToJSON([{<<"ID">>, <<"other id">>}])
                      ,Test(ToJSON([{<<"_id">>, <<"other id">>}]))
                      )
       %% Even though an explicit replace for "id" is provided, the normalized value should be "ID".
      ,?_x_assertEqual(ToJSON([{<<"ID">>, <<"ran-dom-id">>}])
                      ,Test2(ToJSON([{<<"id">>, <<"ran-dom-id">>}])
                            ,[{'explicit_replaces', [{<<"id">>, <<"iD">>}]}]
                            )
                      )
      ]
     }
    ,{"empty nested object"
     ,?_x_assertEqual(ToJSON([{<<"Empty-Object-Value">>, kz_json:new()}])
                     ,Test(ToJSON([{<<"empty_object_value">>, kz_json:new()}]))
                     )
     }
     %% Only outer keys should be normalized.
    ,{"nested objects with normalize_nested_keys=false"
     ,[{"no explicit_replaces list provided"
       ,?_x_assertEqual(ToJSON([{<<"Apns">> %% Normalized.
                                ,[{<<"alert">>
                                  ,[{<<"subtitle_key">>, <<"subtitle">>}
                                   ,{<<"subtitle_params">>, <<"params">>}
                                   ]
                                  }
                                 ,{<<"thread_id">>, <<"so-me-id">>}
                                 ,{<<"topic">>, <<"topic">>}
                                 ]
                                }
                               ,{<<"Fcm">>, <<"some value">>} %% Normalized.
                               ])
                       ,Test(TestJObj)
                       )
       }
      ,{"explicit_replaces list provided"
       ,?_x_assertEqual(ToJSON([{<<"APNs">> %% Normalized, explicitly replaced.
                                ,[{<<"alert">>
                                  ,[{<<"subtitle_key">>, <<"subtitle">>}
                                   ,{<<"subtitle_params">>, <<"params">>}
                                   ]
                                  }
                                 ,{<<"thread_id">>, <<"so-me-id">>}
                                 ,{<<"topic">>, <<"topic">>}
                                 ]
                                }
                               ,{<<"FCM">>, <<"some value">>} %% Normalized, explicitly replaced.
                               ])
                       ,Test2(TestJObj, [{'explicit_replaces', ExplicitReplaces}])
                       )
       }
      ]
     }
     %% All the keys should be normalized.
    ,{"nested objects with normalize_nested_keys=true"
     ,[{"no explicit_replaces list provided"
       ,?_x_assertEqual(ToJSON([{<<"Apns">> %% Normalized.
                                ,[{<<"Alert">> %% Normalized.
                                  ,[{<<"Subtitle-Key">>, <<"subtitle">>} %% Normalized.
                                   ,{<<"Subtitle-Params">>, <<"params">>} %% Normalized.
                                   ]
                                  }
                                 ,{<<"Thread-ID">>, <<"so-me-id">>} %% Normalized.
                                 ,{<<"Topic">>, <<"topic">>} %% Normalized.
                                 ]
                                }
                               ,{<<"Fcm">>, <<"some value">>} %% Normalized.
                               ])
                       ,Test2(TestJObj, [{'normalize_nested_keys', 'true'}])
                       )
       }
      ,{"explicit_replaces list provided"
       ,?_x_assertEqual(ToJSON([{<<"APNs">> %% Normalized, and explicitly replaced.
                                ,[{<<"Alert">> %% Normalized.
                                  ,[{<<"Sub-Title-Key">>, <<"subtitle">>} %% Normalized, and explicitly replaced.
                                   ,{<<"Sub-Title-Params">>, <<"params">>} %% Normalized, and explicitly replaced.
                                   ]
                                  }
                                 ,{<<"Thread-ID">>, <<"so-me-id">>} %% Normalized.
                                 ,{<<"Topic">>, <<"topic">>} %% Normalized.
                                 ]
                                }
                               ,{<<"FCM">>, <<"some value">>} %% Normalized, and explicitly replaced.
                               ])
                       ,Test2(TestJObj, [{'normalize_nested_keys', 'true'}
                                        ,{'explicit_replaces', ExplicitReplaces}
                                        ])
                       )
       }
      ]
     }
    ].

-ifdef(PERF).
-define(Q, <<"pid://<0.1.0>/2bdace1ec243711cc5236e01d5849d18.2bdace1ec243711cc5236e01d5849d18.2bdace1ec243711cc5236e01d5849d18.2bdace1ec243711cc5236e01d5849d180">>).
-define(REPEAT, 100000).

%% when i run locally:
%% kz_api_tests:pid in 0.879099s
%% kz_api_tests:pid2 in 0.057182s


horse_pid() ->
    horse:repeat(?REPEAT
                ,kapi:decode_pid(?Q)
                ).

horse_pid2() ->
    horse:repeat(?REPEAT
                ,kapi:decode_pid2(?Q)
                ).
-endif.
