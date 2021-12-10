%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_endpoint).

-export([id/1]).
-export([type/1]).
-export([owner_id/1]).
-export([account_id/1, account_name/1, account_realm/1]).
-export([language/1, language/2]).
-export([get_prompt/2, get_prompt_url/2]).
-export([moh/1, moh_media_path/1, moh_url/1]).
-export([presence_id/1]).
-export([build_options/1]).

-type endpoint() :: kz_json:object().
-export_type([endpoint/0]).

-spec id(endpoint()) -> kz_term:ne_binary().
id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"Endpoint-ID">>, Endpoint).

-spec type(endpoint()) -> kz_term:ne_binary().
type(Endpoint) ->
    kz_json:get_ne_binary_value(<<"Endpoint-Type">>, Endpoint).

-spec account_id(endpoint()) -> kz_term:ne_binary().
account_id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"Account-ID">>, Endpoint, kz_doc:account_id(Endpoint)).

-spec account_name(endpoint()) -> kz_term:ne_binary().
account_name(Endpoint) ->
    kz_json:get_ne_binary_value(<<"account_name">>, Endpoint).

-spec account_realm(endpoint()) -> kz_term:ne_binary().
account_realm(Endpoint) ->
    kz_json:get_ne_binary_value(<<"account_realm">>, Endpoint).

-spec owner_id(endpoint()) -> kz_term:api_ne_binary().
owner_id(Endpoint) ->
    kz_json:get_ne_binary_value([<<"owner_id">>], Endpoint).

-spec language(endpoint()) -> kz_term:ne_binary().
language(Endpoint) ->
    language(Endpoint, default_endpoint_language()).

-spec language(endpoint(), kz_term:api_ne_binary()) -> kz_term:ne_binary().
language(Endpoint, Default) ->
    endpoint_language(kz_json:get_ne_binary_value([<<"language">>], Endpoint, Default)).

-spec endpoint_language(kz_term:api_binary()) -> kz_term:ne_binary().
endpoint_language(undefined) -> default_endpoint_language();
endpoint_language(Lang) -> kz_term:to_lower_binary(Lang).

-spec default_endpoint_language() -> kz_term:ne_binary().
default_endpoint_language() -> <<"en-us">>.

-spec get_prompt(endpoint(), kz_term:ne_binary()) -> kz_term:api_ne_binary().
get_prompt(Endpoint, PromptId) ->
    kz_media_util:get_prompt(PromptId, language(Endpoint), account_id(Endpoint)).

-spec get_prompt_url(endpoint(), kz_term:ne_binary()) -> kz_term:api_ne_binary().
get_prompt_url(Endpoint, PromptId) ->
    case get_prompt(Endpoint, PromptId) of
        undefined -> undefined;
        MediaPath -> kz_media_url:playback(MediaPath)
    end.

-spec moh(endpoint()) -> kz_term:api_ne_binary().
moh(Endpoint) ->
    kz_json:get_ne_binary_value([<<"music_on_hold">>, <<"media_id">>], Endpoint).

-spec moh_media_path(endpoint()) -> kz_term:api_ne_binary().
moh_media_path(Endpoint) ->
    case moh(Endpoint) of
        undefined -> undefined;
        MediaId -> kz_media_util:media_path(MediaId, account_id(Endpoint))
    end.

-spec moh_url(endpoint()) -> kz_term:api_ne_binary().
moh_url(Endpoint) ->
    case moh_media_path(Endpoint) of
        undefined -> undefined;
        MediaPath -> moh_playback_url(MediaPath)
    end.

moh_playback_url(MediaPath) ->
    case kz_media_url:playback(MediaPath) of
        {error, _} -> undefined;
        URL -> URL
    end.

-spec presence_id(endpoint()) -> kz_term:api_ne_binary().
presence_id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"presence_id">>, Endpoint).

-spec build_options(endpoint()) -> kz_term:api_object().
build_options(Endpoint) ->
    kz_json:get_json_value(<<"Endpoint-Build-Options">>, Endpoint).
