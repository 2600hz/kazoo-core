%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc Creates QR codes for setting up totp/hotp multi-factor auth
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_qrcode).

-export([create/2]).

-include("kazoo_auth.hrl").

-define(ATT_QRCODE(TYPE), <<TYPE/binary, "_qrcode">>).

%% @doc create a QR code, add as attachment to user doc, and return PNG binary data
-spec create(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', binary()}.
create(<<AccountId/binary>>, <<UserId/binary>>) ->
    create(AccountId, UserId, kapps_config:get_atom(?CONFIG_CAT, <<"qrcode_key_type">>, 'totp')).

create(AccountId, UserId, 'totp') ->
    create_totp(AccountId, UserId, kz_auth_otp:totp_period());
create(AccountId, UserId, 'hotp') ->
    create_hotp(AccountId, UserId, kz_auth_otp:hotp_initial_counter()).

create_totp(AccountId, UserId, PeriodS) ->
    UserEmail = kz_auth_otp:user_email(AccountId, UserId),

    UserPasscode = kz_auth_otp:user_passcode(AccountId, UserId),

    PeriodBin = kz_term:to_binary(PeriodS),

    Issuer = kapps_config:get_ne_binary(?CONFIG_CAT, <<"qrcode_issuer">>, <<"KAZOO">>),

    Token = <<"otpauth://totp/", Issuer/binary, ":", UserEmail/binary
             ,"?secret=", UserPasscode/binary
             ,"&issuer=", Issuer/binary
             ,"&period=", PeriodBin/binary
            >>,

    QRCode = qrcode:encode(Token),
    PNG = qrcode_png:encode(QRCode),

    {'ok', _} = kz_datamgr:put_attachment(AccountId, UserId, ?ATT_QRCODE(<<"totp">>), PNG),
    {'ok', PNG}.

create_hotp(AccountId, UserId, InitialCounter) ->
    PeriodS = kz_auth_otp:totp_period(),
    UserEmail = kz_auth_otp:user_email(AccountId, UserId),

    UserPasscode = kz_auth_otp:user_passcode(AccountId, UserId),

    PeriodBin = kz_term:to_binary(PeriodS),
    InitialCounterBin = kz_term:to_binary(InitialCounter),

    Issuer = kapps_config:get_ne_binary(?CONFIG_CAT, <<"qrcode_issuer">>, <<"KAZOO">>),

    Token = <<"otpauth://totp/", Issuer/binary, ":", UserEmail/binary
             ,"?secret=", UserPasscode/binary
             ,"&issuer=", Issuer/binary
             ,"&period=", PeriodBin/binary
             ,"&counter=", InitialCounterBin/binary
            >>,

    QRCode = qrcode:encode(Token),
    PNG = qrcode_png:encode(QRCode),

    {'ok', _} = kz_datamgr:put_attachment(AccountId, UserId, ?ATT_QRCODE(<<"hotp">>), PNG),
    {'ok', PNG}.
