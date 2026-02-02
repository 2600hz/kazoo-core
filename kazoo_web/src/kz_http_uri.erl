%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2015-2026, 2600Hz
%%% @doc HTTP helper functions for Kazoo
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_http_uri).

-export([encode/1, decode/1]).

-type uri() :: string() | binary().
-type hex_uri() :: string() | binary(). %% Hexadecimal encoded URI.
-type maybe_hex_uri() :: string() | binary(). %% A possibly hexadecimal encoded URI.

%% known as RFC-3986 serialization
-spec encode(uri()) -> hex_uri().
encode(URI) when is_list(URI) ->
    Reserved = reserved(),
    lists:append([uri_encode(Char, Reserved) || Char <- URI]);
encode(URI) when is_binary(URI) ->
    Reserved = reserved(),
    << <<(uri_encode_binary(Char, Reserved))/binary>> || <<Char>> <= URI >>.

-spec decode(maybe_hex_uri()) -> uri().
decode(String) when is_list(String) ->
    do_decode(String);
decode(String) when is_binary(String) ->
    do_decode_binary(String).

do_decode([$%,Hex1,Hex2|Rest]) ->
    [hex2dec(Hex1)*16+hex2dec(Hex2)|do_decode(Rest)];
do_decode([First|Rest]) ->
    [First|do_decode(Rest)];
do_decode([]) ->
    [].

do_decode_binary(<<$%, Hex:2/binary, Rest/bits>>) ->
    <<(binary_to_integer(Hex, 16)), (do_decode_binary(Rest))/binary>>;
do_decode_binary(<<First:1/binary, Rest/bits>>) ->
    <<First/binary, (do_decode_binary(Rest))/binary>>;
do_decode_binary(<<>>) ->
    <<>>.


reserved() ->
    sets:from_list([$;, $:, $@, $&, $=, $+, $,, $/, $?,
                    $#, $[, $], $<, $>, $\", ${, $}, $|, %"
                    $\\, $', $^, $%, $ ]).

uri_encode(Char, Reserved) ->
    case sets:is_element(Char, Reserved) of
        'true' ->
            [ $% | http_util:integer_to_hexlist(Char)];
        'false' ->
            [Char]
    end.

uri_encode_binary(Char, Reserved) ->
    case sets:is_element(Char, Reserved) of
        'true' ->
            << $%, (integer_to_binary(Char, 16))/binary >>;
        'false' ->
            <<Char>>
    end.

hex2dec(X) when (X>=$0)
                andalso (X=<$9) -> X-$0;
hex2dec(X) when (X>=$A)
                andalso (X=<$F) -> X-$A+10;
hex2dec(X) when (X>=$a)
                andalso (X=<$f) -> X-$a+10.
