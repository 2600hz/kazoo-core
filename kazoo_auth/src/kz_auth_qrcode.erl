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
-include_lib("qrcode/src/qrcode.hrl").

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
    PNG = simple_png_encode(QRCode),

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
    PNG = simple_png_encode(QRCode),

    {'ok', _} = kz_datamgr:put_attachment(AccountId, UserId, ?ATT_QRCODE(<<"hotp">>), PNG),
    {'ok', PNG}.

%% Very simple PNG encoder for demo purposes
%% taken from qrcode_demo.erl
simple_png_encode(#qrcode{dimension = Dim, data = Data}) ->
    MAGIC = <<137, 80, 78, 71, 13, 10, 26, 10>>,
    Size = Dim * 8,
    IHDR = png_chunk(<<"IHDR">>, <<Size:32, Size:32, 8:8, 2:8, 0:24>>),
    PixelData = get_pixel_data(Dim, Data),
    IDAT = png_chunk(<<"IDAT">>, PixelData),
    IEND = png_chunk(<<"IEND">>, <<>>),
    <<MAGIC/binary, IHDR/binary, IDAT/binary, IEND/binary>>.

png_chunk(Type, Bin) ->
    Length = byte_size(Bin),
    CRC = erlang:crc32(<<Type/binary, Bin/binary>>),
    <<Length:32, Type/binary, Bin/binary, CRC:32>>.

get_pixel_data(Dim, Data) ->
    Pixels = get_pixels(Data, 0, Dim, <<>>),
    zlib:compress(Pixels).

get_pixels(<<>>, Dim, Dim, Acc) -> Acc;
get_pixels(Bin, Count, Dim, Acc) ->
    <<RowBits:Dim/bits, Bits/bits>> = Bin,
    Row = get_pixels0(RowBits, <<0>>), % row filter byte
    FullRow = binary:copy(Row, 8),
    get_pixels(Bits, Count + 1, Dim, <<Acc/binary, FullRow/binary>>).

get_pixels0(<<>>, Acc) -> Acc;
get_pixels0(<<1:1, Bits/bits>>, Acc) ->
    Black = binary:copy(<<0>>, 24),
    get_pixels0(Bits, <<Acc/binary, Black/binary>>);
get_pixels0(<<0:1, Bits/bits>>, Acc) ->
    White = binary:copy(<<255>>, 24),
    get_pixels0(Bits, <<Acc/binary, White/binary>>).
