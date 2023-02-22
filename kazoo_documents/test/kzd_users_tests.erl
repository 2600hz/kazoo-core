%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
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
