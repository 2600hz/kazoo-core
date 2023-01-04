%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_prompt).

-export([get_prompt/1, get_prompt/2, get_prompt/3]).

-define(PROMPT, "prompt://").

-spec get_prompt(kz_term:ne_binary()) -> kz_term:api_ne_binary().
get_prompt(Prompt) ->
    case is_valid_for_encode(Prompt) of
        'true' -> format_prompt([Prompt]);
        'false' -> Prompt
    end.

-spec get_prompt(kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
get_prompt(DB, Media) ->
    case is_valid_for_encode(Media) of
        'true' -> format_prompt([DB, Media]);
        'false' -> Media
    end.

-spec get_prompt(kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
get_prompt(DB, Media, Language) ->
    case is_valid_for_encode(Media) of
        'true' -> format_prompt([DB, Media, Language]);
        'false' -> Media
    end.

format_prompt(Parts) ->
    case lists:filter(fun kz_term:is_not_empty/1, Parts) of
        [] -> 'undefined';
        Filtered -> list_to_binary([?PROMPT, kz_binary:join(Filtered, <<"/">>)])
    end.

-spec is_valid_for_encode(kz_term:api_binary()) -> boolean().
is_valid_for_encode('undefined') -> 'false';
is_valid_for_encode(<<>>) -> 'false';
is_valid_for_encode(<<"silence">>) -> 'false';
is_valid_for_encode(<<"silence_stream://", _/binary>>) -> 'false';
is_valid_for_encode(<<"tone_stream://", _/binary>>) -> 'false';
is_valid_for_encode(<<"shout://", _/binary>>) -> 'false';
is_valid_for_encode(<<"local_stream://", _/binary>>) -> 'false';
is_valid_for_encode(<<"http://", _/binary>>) -> 'false';
is_valid_for_encode(<<"https://", _/binary>>) -> 'false';
is_valid_for_encode(<<"prompt://", _/binary>>) -> 'false';
is_valid_for_encode(<<_:8,_/binary>> = _Media) -> 'true'.
