%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Functions for interacting with the underlying system (assumes Linux).
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_phonetic).

-export([double_metaphone/1]).

-type double_metaphone_result() :: {binary(), binary()}.

%% Main function to generate primary and alternate codes
-spec double_metaphone(binary() | string()) -> double_metaphone_result().
double_metaphone(Word) when is_binary(Word) ->
    double_metaphone(kz_term:to_list(Word));
double_metaphone(Word) when is_list(Word) ->
    UpperWord = string:to_upper(Word),
    {Primary, Alternate} = encode(UpperWord, [], []),
    {kz_term:to_binary(lists:flatten(Primary)), kz_term:to_binary(lists:flatten(Alternate))}.

%% Core function for encoding with dual codes
encode([], Primary, Alternate) ->
    {Primary, Alternate};

encode([H | T], Primary, Alternate) ->
    case H of
        $B -> encode_b(T, Primary, Alternate);
        $C -> encode_c(T, Primary, Alternate);
        $D -> encode_d(T, Primary, Alternate);
        $G -> encode_g(T, Primary, Alternate);
        $H -> encode_h(T, Primary, Alternate);
        $K -> encode_k(T, Primary, Alternate);
        $P -> encode_p(T, Primary, Alternate);
        $S -> encode_s(T, Primary, Alternate);
        $T -> encode_t(T, Primary, Alternate);
        $X -> encode_x(T, Primary, Alternate);
        $Z -> encode_z(T, Primary, Alternate);
        _ -> encode_other(H, T, Primary, Alternate) % Skip unknown characters
    end.

%% Encoding functions for each letter

%% Encode 'B': Silent when at end after another 'B'
encode_b([$B | T], Primary, Alternate) ->
    encode(T, Primary, Alternate);
encode_b(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$B], Alternate ++ [$B]).

%% Encode 'C': Handle 'CH', 'CIA', 'CI', 'CE', 'CY' and default
encode_c([$H | T], Primary, Alternate) ->
    encode(T, Primary ++ [$X], Alternate ++ [$K]);
encode_c([$I, $A | T], Primary, Alternate) ->
    encode(T, Primary ++ [$X], Alternate ++ [$X]);
encode_c([$I, $E | T], Primary, Alternate) ->
    encode(T, Primary ++ [$S], Alternate ++ [$S]);
encode_c([$I, $Y | T], Primary, Alternate) ->
    encode(T, Primary ++ [$S], Alternate ++ [$S]);
encode_c(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$K], Alternate ++ [$K]).

%% Encode 'D': 'DG' becomes 'J', 'D' otherwise remains 'T'
encode_d([$G, $E | T], Primary, Alternate) ->
    encode(T, Primary ++ [$J], Alternate ++ [$J]);
encode_d([$G, $I | T], Primary, Alternate) ->
    encode(T, Primary ++ [$J], Alternate ++ [$J]);
encode_d([$G, $Y | T], Primary, Alternate) ->
    encode(T, Primary ++ [$J], Alternate ++ [$J]);
encode_d(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$T], Alternate ++ [$T]).

%% Encode 'G': Silent after 'N' or with 'H', otherwise 'K'
encode_g([$H | T], Primary, Alternate) ->
    encode(T, Primary, Alternate);
encode_g([$N | T], Primary, Alternate) ->
    encode(T, Primary, Alternate);
encode_g(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$K], Alternate ++ [$K]).

%% Encode 'H': Silent after a vowel
encode_h([Prev | T], Primary, Alternate) when Prev == $A; Prev == $E; Prev == $I; Prev == $O; Prev == $U ->
    encode(T, Primary ++ [Prev], Alternate  ++ [Prev]);
encode_h(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$H], Alternate ++ [$H]).

%% Encode 'K': Silent if first letter or after 'N'
encode_k([$N | T], Primary, Alternate) ->
    encode(T, Primary, Alternate);
encode_k(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$K], Alternate ++ [$K]).

%% Encode 'P': 'PH' becomes 'F'
encode_p([$H | T], Primary, Alternate) ->
    encode(T, Primary ++ [$F], Alternate ++ [$F]);
encode_p(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$P], Alternate ++ [$P]).

%% Encode 'S': 'SH' becomes 'X'
encode_s([$E, $N | T], Primary, Alternate) ->
    encode(T, Primary ++ [$O, $N], Alternate ++ [$O, $N]);
encode_s([$H | T], Primary, Alternate) ->
    encode(T, Primary ++ [$X], Alternate ++ [$X]);
encode_s(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$S], Alternate ++ [$S]).

%% Encode 'T': 'TH' becomes '0' for both primary and alternate
encode_t([$H | T], Primary, Alternate) ->
    encode(T, Primary ++ [48], Alternate ++ [48]);  % ASCII 48 for '0'
encode_t(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$T], Alternate ++ [$T]).

%% Encode 'X': Always 'KS' in both codes
encode_x(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$K, $S], Alternate ++ [$K, $S]).

%% Encode 'Z': 'Z' becomes 'S' in both codes
encode_z(Rest, Primary, Alternate) ->
    encode(Rest, Primary ++ [$S], Alternate ++ [$S]).

encode_other(H , T, Primary, Alternate) -> encode(T, Primary ++ [H], Alternate ++ [H]).
