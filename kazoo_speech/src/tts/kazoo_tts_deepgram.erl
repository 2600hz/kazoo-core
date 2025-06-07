%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_tts_deepgram).

-behaviour(gen_tts_provider).

-export([create/4
        ,set_api_key/1
        ]).

-include("kazoo_speech.hrl").

-define(DEEPGRAM_VOICE_MAPPINGS
       ,[{<<"female/en-us">>, <<"aura-2-thalia-en">>}
        ,{<<"male/en-us">>, <<"aura-2-andromeda-en">>}
        ,{<<"female/en-gb">>, <<"aura-2-pandora-en">>}
        ,{<<"male/en-gb">>, <<"aura-2-draco-en">>}
        ]
       ).

-define(DEEPGRAM_FORMAT_MAPPINGS
       ,[{<<"wav">>, <<"linear16">>}
        ,{<<"mp3">>, <<"mp3">>}
        ]
       ).

-define(DEEPGRAM_CONFIG_CAT, <<(?MOD_CONFIG_CAT)/binary, ".deepgram">>).
-define(DEEPGRAM_TTS_URL, kapps_config:get_string(?DEEPGRAM_CONFIG_CAT, <<"tts_url">>, <<"https://api.deepgram.com/v1/speak">>)).
-define(DEEPGRAM_TTS_API_KEY, kapps_config:get_string(?DEEPGRAM_CONFIG_CAT, <<"tts_api_key">>)).

-spec set_api_key(kz_term:ne_binary()) -> 'ok'.
set_api_key(Key) ->
    {'ok', _} = kapps_config:set_default(?DEEPGRAM_CONFIG_CAT, <<"tts_api_key">>, Key),
    'ok'.

-spec create(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> create_resp().
create(Text, Voice, Format, Options) ->
    VoiceMappings = ?DEEPGRAM_VOICE_MAPPINGS,
    case props:get_value(kz_term:to_lower_binary(Voice), VoiceMappings) of
        'undefined' ->
            {'error', 'invalid_voice'};
        TTSVoice ->
            get_format(Text, TTSVoice, Format, Options)
    end.

get_format(Text, Voice, Format, Options) ->
    case props:get_value(kz_term:to_lower_binary(Format), ?DEEPGRAM_FORMAT_MAPPINGS) of
        'undefined' ->
            {'error', 'invalid_format'};
        DeepgramFormat ->
            make_request(Text, Voice, DeepgramFormat, Options)
    end.

-spec make_request(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> create_resp().
make_request(Text, Voice, Format, Options) ->
    BaseUrl = kz_term:to_binary(?DEEPGRAM_TTS_URL, "?model=", Voice, "&encoding=", Format),

    Headers = [{"Content-Type", "application/json"}
              ,{"Authorization", "Token " ++ ?DEEPGRAM_TTS_API_KEY}
              ],
    Body = kz_json:encode(kz_json:set_value(<<"text">>, Text, kz_json:new())),

    lager:debug("sending TTS request to ~s", [BaseUrl]),

    HTTPOptions = props:delete('receiver', Options),
    case props:get_value('receiver', Options) of
        Pid when is_pid(Pid) ->
            Response = kz_http:async_req(Pid, 'post', BaseUrl, Headers, Body, HTTPOptions),
            kazoo_tts_utils:create_response(Response);
        _ ->
            Response = kz_http:post(BaseUrl, Headers, Body, HTTPOptions),
            kazoo_tts_utils:create_response(Response)
    end.
