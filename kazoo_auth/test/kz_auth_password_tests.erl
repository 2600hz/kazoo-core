%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_password_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_fixturedb/include/kz_fixturedb.hrl").
-include("kazoo_auth.hrl").

enforce_test_() ->
    Disabled = ?FIXTURE_RESELLER_ACCOUNT_DB,
    NoPrevent = ?FIXTURE_PARENT_ACCOUNT_ID,
    PreventEnabled = ?FIXTURE_CHILD_ACCOUNT_ID,
    User = new_user_obj(),
    HasCreds = with_existing_creds(User),
    {'setup'
    ,fun kazoo_apps_test_util:setup/0 %% we need this because we need kapps_account_config cache
    ,fun kazoo_apps_test_util:cleanup/1
    ,fun(_) ->
             [{"password is valid when enforce is disabled"
              ,?_assertMatch({'valid', _}
                            ,kz_auth_password:enforce(Disabled, User, <<"123456">>)
                            )
              }
             ,{"password is valid when enforce is enabled"
              ,?_assertMatch({'valid', _}
                            ,kz_auth_password:enforce(NoPrevent, User, <<"1234567890aA!">>)
                            )
              }
             ,{"password is valid even pass is reused when prevent is disabled"
              ,?_assertMatch({'valid', _}
                            ,kz_auth_password:enforce(NoPrevent, HasCreds, <<"1234567890aA!">>)
                            )
              }
             ,{"password is valid when prevent is enabled"
              ,?_assertMatch({'valid', _}
                            ,kz_auth_password:enforce(PreventEnabled, HasCreds, <<"1234567890aA!2">>)
                            )
              }
             ,{"reject password when prevent is enabled and old pass is reused"
              ,?_assertMatch({'invalid', [<<"cannot use same password">>]}
                            ,kz_auth_password:enforce(PreventEnabled, HasCreds, <<"1234567890aA!">>)
                            )
              }
             ,{"reject password in all conditions (pass is empty)"
              ,?_assertEqual({'invalid'
                             ,[<<"at least one special character is required">>
                              ,<<"at least one digit is required">>
                              ,<<"at least one upper case character is required">>
                              ,<<"at least one lower case character is required">>
                              ,<<"minimum password length is 10 characters">>
                              ]
                             }
                            ,kz_auth_password:enforce(NoPrevent, User, <<>>)
                            )
              }
             ,{"reject password when length is invalid"
              ,?_assertEqual({'invalid'
                             ,[<<"minimum password length is 10 characters">>
                              ]
                             }
                            ,kz_auth_password:enforce(NoPrevent, User, <<"123aA!">>)
                            )
              }
             ,{"reject password when no lower case"
              ,?_assertEqual({'invalid'
                             ,[<<"at least one lower case character is required">>
                              ]
                             }
                            ,kz_auth_password:enforce(NoPrevent, User, <<"1234567890AA]">>)
                            )
              }
             ,{"reject password when no upper case"
              ,?_assertEqual({'invalid'
                             ,[<<"at least one upper case character is required">>
                              ]
                             }
                            ,kz_auth_password:enforce(NoPrevent, User, <<"123456789aa\"">>)
                            )
              }
             ,{"reject password when no digit"
              ,?_assertEqual({'invalid'
                             ,[<<"at least one digit is required">>
                              ]
                             }
                            ,kz_auth_password:enforce(NoPrevent, User, <<"aaaaaaaaaA$">>)
                            )
              }
             ,{"reject password when no special chars"
              ,?_assertEqual({'invalid'
                             ,[<<"at least one special character is required">>
                              ]
                             }
                            ,kz_auth_password:enforce(NoPrevent, User, <<"aaaaaaaa1A">>)
                            )
              }
             ,{"reject password when no special chars and upper case"
              ,?_assertEqual({'invalid'
                             ,[<<"at least one special character is required">>
                              ,<<"at least one upper case character is required">>
                              ]
                             }
                            ,kz_auth_password:enforce(NoPrevent, User, <<"123456789aa">>)
                            )
              }
             ]
     end
    }.

with_existing_creds(User) ->
    Username = <<"user_", (kz_binary:rand_hex(5))/binary>>,
    Password = <<"1234567890aA!">>,
    {MD5, SHA1} = kzd_module_utils:pass_hashes(Username, Password),
    kz_json:set_values([{<<"username">>, Username}
                       ,{<<"pvt_md5_auth">>, MD5}
                       ,{<<"pvt_sha1_auth">>, SHA1}
                       ]
                      ,User
                      ).

new_user_obj() ->
    Routines = [{fun kzd_users:set_first_name/2, kz_binary:rand_hex(4)}
               ,{fun kzd_users:set_last_name/2, kz_binary:rand_hex(4)}
               ],
    kz_doc:setters(kzd_users:new(), Routines).
