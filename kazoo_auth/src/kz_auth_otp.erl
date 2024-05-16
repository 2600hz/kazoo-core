%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc One-time passwords (OTP) library for generating a user's TOTP
%%% or HOTP passwords.
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_otp).

-export([totp/2, hotp/2
        ,totp_calc/2
        ]).

-export([user_passcode/2
        ,user_email/2

        ,totp_period/0
        ,hotp_initial_counter/0
        ]).

-include("kazoo_auth.hrl").

-define(PVT_ACCOUNT_PASSCODE, <<"pvt_account_passcode">>).
-define(PVT_USER_PASSCODE_32, <<"pvt_user_passcode_32">>).
-define(PVT_USER_COUNT, <<"pvt_hotp_count">>).

-spec totp(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()}.
totp(<<AccountId/binary>>, <<UserId/binary>>) ->
    UserPasscode32 = user_passcode(AccountId, UserId),
    UserPasscode = base32:decode(UserPasscode32),
    PeriodS = totp_period(),
    totp_calc(UserPasscode, PeriodS).

-spec totp_calc(kz_term:ne_binary(), pos_integer()) ->
          {kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()}.
totp_calc(<<UserPasscode/binary>>, PeriodS) when is_integer(PeriodS), PeriodS > 0 ->
    CurrentT = kz_time:current_unix_tstamp() div PeriodS,
    {hotp_calc(UserPasscode, CurrentT - 1)
    ,hotp_calc(UserPasscode, CurrentT)
    ,hotp_calc(UserPasscode, CurrentT + 1)
    }.

-spec hotp(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binary().
hotp(<<AccountId/binary>>, <<UserId/binary>>) ->
    UserPasscode32 = user_passcode(AccountId, UserId),
    UserPasscode = base32:decode(UserPasscode32),
    Count = user_count(AccountId, UserId),
    hotp_calc(UserPasscode, Count).

%% @doc initially lifted from qrcode_demo:hotp/2
hotp_calc(<<UserPasscode/binary>>, Count) when is_integer(Count) ->
    <<_:19/binary, _:4, Offset:4>> = HS = crypto:mac('hmac', 'sha', UserPasscode, <<Count:64>>),
    <<_:Offset/binary, _:1, P:31, _/binary>> = HS,
    HOTP = integer_to_list(P rem 1000000),
    Pad = lists:duplicate(6 - length(HOTP), $0),
    list_to_binary([Pad, HOTP]).

-spec totp_period() -> pos_integer().
totp_period() ->
    kapps_config:get_integer(?CONFIG_CAT, <<"totp_period_s">>, 30).

-spec hotp_initial_counter() -> non_neg_integer().
hotp_initial_counter() ->
    kapps_config:get_integer(?CONFIG_CAT, <<"qrcode_initial_counter">>, 2600).

account_passcode(AccountId) ->
    {'ok', AccountJObj} = kzd_accounts:fetch(AccountId),
    account_passcode(AccountJObj, kz_json:get_ne_binary_value(?PVT_ACCOUNT_PASSCODE, AccountJObj)).

account_passcode(_AccountJObj, <<AccountPasscode/binary>>) -> AccountPasscode;
account_passcode(AccountJObj, 'undefined') ->
    AccountPasscode = kz_binary:rand_hex(16),
    {'ok', _} = kzd_accounts:save(kz_json:set_value(?PVT_ACCOUNT_PASSCODE, AccountPasscode, AccountJObj)),
    lager:info("initialized account ~s OTP passcode", [kz_doc:id(AccountJObj)]),
    AccountPasscode.

-spec user_passcode(kz_term:ne_binary(), kz_term:ne_binary()) -> binary().
user_passcode(<<AccountId/binary>>, <<UserId/binary>>) ->
    <<AccountPasscode/binary>> = account_passcode(AccountId),

    {'ok', UserJObj} = kz_datamgr:open_cache_doc(AccountId, UserId),

    user_passcode(AccountId, AccountPasscode, UserJObj
                 ,kz_json:get_ne_binary_value(?PVT_USER_PASSCODE_32, UserJObj)
                 ).

user_passcode(_AccountId, _AccountPasscode, _UserJObj, <<PasscodeBase32/binary>>) ->
    PasscodeBase32;
user_passcode(AccountId, AccountPasscode, UserJObj, 'undefined') ->
    <<UserEmail/binary>> = user_email(AccountId, UserJObj),
    Passcode = crypto:hash('sha', <<AccountPasscode/binary, "-", UserEmail/binary>>),
    PasscodeBase32 = base32:encode(Passcode),

    {'ok', _} = save_passcode(AccountId, UserJObj, PasscodeBase32),
    lager:info("initialized user ~s (~s) passcode", [kz_doc:id(UserJObj), AccountId]),

    PasscodeBase32.

-spec user_email(kz_term:ne_binary(), kzd_users:doc() | kz_term:ne_binary()) -> kz_term:api_ne_binary().
user_email(<<AccountId/binary>>, <<UserId/binary>>) ->
    {'ok', UserJObj} = kz_datamgr:open_cache_doc(AccountId, UserId),
    user_email(AccountId, UserJObj);
user_email(_AccountId, UserJObj) ->
    kzd_users:email(UserJObj, kzd_users:username(UserJObj)).

save_passcode(AccountId, UserJObj, PasscodeBase32) ->
    kz_datamgr:save_doc(AccountId, kz_json:set_value(?PVT_USER_PASSCODE_32, PasscodeBase32, UserJObj)).

%% @doc get's the user's current hotp count
user_count(AccountId, <<UserId/binary>>) ->
    {'ok', UserJObj} = kz_datamgr:open_cache_doc(AccountId, UserId),
    user_count(AccountId, UserJObj);
user_count(AccountId, UserJObj) ->
    user_count(AccountId, UserJObj, kz_json:get_integer_value(?PVT_USER_COUNT, UserJObj)).

user_count(AccountId, UserJObj, 'undefined') ->
    Counter = hotp_initial_counter(),

    {'ok', _} = kz_datamgr:save_doc(AccountId, kz_json:set_value(?PVT_USER_COUNT, Counter, UserJObj)),
    lager:info("initialized user ~s (~s) counter to ~p", [kz_doc:id(UserJObj), AccountId, Counter]),
    Counter;
user_count(_AccountId, _UserJObj, Counter) -> Counter.
