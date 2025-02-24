%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
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
    ,no_password_requirements_tests()
    ,password_tests()
    ].

no_password_requirements_tests() ->
    {'setup'
    ,fun kazoo_apps_test_util:setup/0
    ,fun kazoo_apps_test_util:cleanup/1
    ,fun(_) ->
             [{"password requirements passes with insecure pass when it is disabled"
              ,?_assertMatch({'true', _}, with_password(existing_user_obj(), <<"changeme">>))
              }
             ]
     end
    }.

password_tests() ->
    User = existing_user_obj(),

    SecurePass = <<"1234567890aA!">>,
    UnSecurePass = <<"1234567890">>,

    {'setup'
    ,fun setup_test_password/0
    ,fun unsetup_test_password/1
    ,fun(_) ->
             [{"password requirements passes for valid passwords"
              ,?_assertMatch({'true', _}, with_password(User, SecurePass))
              }
             ,{"password requirements failes for invalid passwords"
              ,?_assertEqual({'validation_errors'
                             ,passowrd_validation_err(
                                [<<"at least one upper case character is required">>
                                ,<<"at least one special character is required">>
                                ,<<"at least one lower case character is required">>
                                ]
                               )
                             }
                            ,with_password(User, UnSecurePass)
                            )
              }
             ,{"prevent reuse of passowrd"
              ,?_assertEqual({'validation_errors'
                             ,passowrd_validation_err(
                                [<<"cannot use same password">>
                                ]
                               )
                             }
                            ,with_password(User, <<"changeme">>)
                            )
              }
             ]
     end
    }.

setup_test_password() ->
    'ok' = kz_fixturedb_maintenance:persist_doc(<<"system_config">>, auth_password_config()),
    kazoo_apps_test_util:setup().

unsetup_test_password(Map) ->
    kz_fixturedb_maintenance:unpersist_doc(<<"system_config">>, auth_password_config()),
    kazoo_apps_test_util:cleanup(Map).

auth_password_config() ->
    kz_json:from_list(
      [{<<"_id">>,<<"auth.password">>}
      ,{<<"_rev">>,<<"1-1db8a605fc856cc951bce63bdc12e2fd">>}
      ,{<<"pvt_account_id">>, <<"system_config">>}
      ,{<<"pvt_account_db">>, <<"system_config">>}
      ,{<<"default">>, kz_json:from_list(
                         [{<<"should_enforce_strength">>,true}
                         ,{<<"should_prevent_reuse">>,true}
                         ]
                        )
       }
      ]
     ).

passowrd_validation_err(Errors) ->
    [{[<<"password">>]
     ,<<"insecure">>
     ,kz_json:from_list(
        [{<<"message">>, <<"The provided password is non-compliant with security level">>}
        ,{<<"cause">>, <<"password">>}
        ,{<<"details">>, Errors}
        ]
       )
     }
    ].

with_password(User, Password) ->
    AccountId = ?FIXTURE_PARENT_ACCOUNT_ID,
    kzd_users:validate(AccountId, <<"user0000000000000000000000000003">>, kzd_users:set_password(User, Password)).

existing_user_obj() ->
    {MD5, SHA1} = kzd_module_utils:pass_hashes(<<"userthree">>, <<"changeme">>),

    Routines = [{fun kzd_users:set_first_name/2, kz_binary:rand_hex(4)}
               ,{fun kzd_users:set_last_name/2, kz_binary:rand_hex(4)}
               ,{fun kzd_users:set_username/2, <<"userthree">>}
               ,{fun kz_doc:set_id/2, <<"user0000000000000000000000000003">>}
               ,{fun(Doc, V) -> kz_json:set_value(<<"pvt_md5_auth">>, V, Doc) end, MD5}
               ,{fun(Doc, V) -> kz_json:set_value(<<"pvt_sha1_auth">>, V, Doc) end, SHA1}
               ],
    kz_doc:setters(kzd_users:new(), Routines).

new_user_obj() ->
    Routines = [{fun kzd_users:set_first_name/2, kz_binary:rand_hex(4)}
               ,{fun kzd_users:set_last_name/2, kz_binary:rand_hex(4)}
               ],
    kz_doc:setters(kzd_users:new(), Routines).
