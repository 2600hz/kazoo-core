%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2020, 2600Hz
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
    format_prompt([Prompt]).

-spec get_prompt(kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
get_prompt(DB, Media) ->
    format_prompt([DB, Media]).

-spec get_prompt(kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
get_prompt(DB, Media, Language) ->
    format_prompt([DB, Media, Language]).

format_prompt(Parts) ->
    case lists:filter(fun kz_term:is_not_empty/1, Parts) of
        [] -> undefined;
        Filtered -> list_to_binary([?PROMPT, kz_binary:join(Filtered, <<"/">>)])
    end.
