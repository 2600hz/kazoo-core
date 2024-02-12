%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc User document: tests
%%% @author SIPLABS, LLS (Ilya Ashchepkov)
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_users_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_fixturedb/include/kz_fixturedb.hrl").

-define(DOC, kz_json:set_values([{<<"first_name">>, "F"}
                                ,{<<"last_name">>, "L"}
                                ,{<<"email">>, <<"email@example.com">>}
                                ,{<<"vm_to_email_enabled">>, 'true'}]
                               ,kz_json:new()
                               )
       ).
-define(USER_ADDRESSES_LIST, [kz_json:from_list([{<<"address">>, <<"test addr">>}])]).
-define(DOC_WITH_ADDRESSES(Addresses), kz_json:set_value(<<"addresses">>, Addresses, ?DOC)).
-define(EMPTY, kz_json:new()).

email_test_() ->
    [?_assertEqual(<<"email@example.com">>,   kzd_users:email(?DOC))
    ,?_assertEqual('undefined',               kzd_users:email(?EMPTY))
    ,?_assertEqual(<<"email@example.com">>,   kzd_users:email(?EMPTY, <<"email@example.com">>))
    ].

voicemail_notification_enabled_test_() ->
    [?_assertEqual('true',    kzd_users:vm_to_email_enabled(?DOC))
    ,?_assertEqual('false',   kzd_users:vm_to_email_enabled(?EMPTY, 'false'))
    ,?_assertEqual('true',    kzd_users:vm_to_email_enabled(?EMPTY, 'true'))
    ].

to_vcard_test_() ->
    BaseBin = <<"BEGIN:VCARD\n"
                "VERSION:3.0\n"
                "FN:F L\n"
                "N:L;F\n"
                "EMAIL:email@example.com\n"
              >>,
    EndBin = <<"END:VCARD">>,
    AddressesJObj = kz_json:from_list([{<<"vcard">>, ?USER_ADDRESSES_LIST}]),
    [{"without addresses"
     ,?_assertEqual(<<BaseBin/binary, EndBin/binary>>, kzd_users:to_vcard(?DOC))
     }
    ,{"with addresses.vcard (object)"
     ,?_assertEqual(<<BaseBin/binary, "ADR;TYPE=intl,postal,parcel,work:test addr\n", EndBin/binary>>
                   ,kzd_users:to_vcard(?DOC_WITH_ADDRESSES(AddressesJObj))
                   )
     }
    ,{"with addresses (list)"
     ,?_assertEqual(<<BaseBin/binary, "ADR;TYPE=intl,postal,parcel,work:test addr\n", EndBin/binary>>
                   ,kzd_users:to_vcard(?DOC_WITH_ADDRESSES(?USER_ADDRESSES_LIST))
                   )
     }
    ].

maybe_migrate_user_addresses_test_() ->
    Test = fun kzd_users:maybe_migrate_user_addresses/1,
    AddressesJObj = kz_json:from_list([{<<"vcard">>, ?USER_ADDRESSES_LIST}]),
    Expected = kz_json:set_value(<<"addresses">>, AddressesJObj, ?DOC),

    [{"old schema"
     ,?_assert(kz_json:are_equal(Expected, Test(?DOC_WITH_ADDRESSES(?USER_ADDRESSES_LIST))))
     },
     {"new schema"
     ,?_assert(kz_json:are_equal(Expected, Test(Expected)))
     }
    ].

validate_test_() ->
    [{"simple new user validation"
     ,?_assertMatch({'true', _}
                   ,kzd_users:validate(?FIXTURE_RESELLER_ACCOUNT_DB, 'undefined', new_user_obj())
                   )
     }
    ,password_tests()
    ].

-define(set_pass(U, P), kzd_users:set_password(U, P)).
password_tests() ->
    User = new_user_obj(),
    Disabled = ?FIXTURE_RESELLER_ACCOUNT_DB,
    Enabled = ?FIXTURE_PARENT_ACCOUNT_ID,
    {'setup'
    ,fun kazoo_apps_test_util:setup/0 %% we need this because we need kapps_account_config cache
    ,fun kazoo_apps_test_util:cleanup/1
    ,fun(_) ->
             [{"password requirements passes when it is disabled"
              ,?_assertMatch({'true', _}
                            ,with_password(Disabled, User, <<"1234567890aA!">>)
                            )
              }
             ,{"password requirements passes for valid passwords"
              ,?_assertMatch({'true', _}, with_password(Enabled, User, <<"1234567890aA!">>))
              }
             ,{"password requirements failes for invalid passwords"
              ,?_assertEqual({'validation_errors'
                             ,passowrd_validation_err(
                                [<<"at least one special character is required">>
                                ,<<"at least one upper case character is required">>
                                ,<<"at least one lower case character is required">>
                                ]
                               )
                             }
                            ,with_password(Enabled, User, <<"1234567890">>)
                            )
              }
             ]
     end
    }.

passowrd_validation_err(Errors) ->
    [{[<<"password">>]
     ,<<"insecure">>
     ,kz_json:from_list(
        [{<<"message">>, <<"The provided password is non-compliant with your account's security level">>}
        ,{<<"cause">>, <<"password">>}
        ,{<<"details">>, Errors}
        ]
       )
     }
    ].

with_password(AccountId, User, Password) ->
    kzd_users:validate(AccountId, 'undefined', ?set_pass(User, Password)).

new_user_obj() ->
    Routines = [{fun kzd_users:set_first_name/2, kz_binary:rand_hex(4)}
               ,{fun kzd_users:set_last_name/2, kz_binary:rand_hex(4)}
               ],
    kz_doc:setters(kzd_users:new(), Routines).
