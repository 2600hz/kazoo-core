%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_tts_groq).

-behaviour(gen_tts_provider).

-export([create/4
        ,set_api_key/1
        ]).

-include("kazoo_speech.hrl").

-define(GROQ_VOICE_MAPPINGS
       ,[{<<"female/en-us">>, <<"Arista-PlayAI">>}
        ,{<<"male/en-us">>, <<"Briggs-PlayAI">>}
        ,{<<"female/en-gb">>, <<"Arista-PlayAI">>}
        ,{<<"male/en-gb">>, <<"Briggs-PlayAI">>}
        ]
       ).

-define(GROQ_CONFIG_CAT, <<(?MOD_CONFIG_CAT)/binary, ".groq">>).
-define(GROQ_TTS_URL, kapps_config:get_string(?GROQ_CONFIG_CAT, <<"tts_url_groq">>, <<"https://api.groq.com/openai/v1/audio/speech">>)).
-define(GROQ_TTS_API_KEY, kapps_config:get_string(?GROQ_CONFIG_CAT, <<"tts_api_key">>)).
-define(GROQ_TTS_MODEL, kapps_config:get_ne_binary(?GROQ_CONFIG_CAT, <<"tts_model">>, <<"playai-tts">>)).

-spec set_api_key(kz_term:ne_binary()) -> 'ok'.
set_api_key(Key) ->
    {'ok', _} = kapps_config:set_default(?GROQ_CONFIG_CAT, <<"tts_api_key">>, Key),
    'ok'.

-spec create(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> create_resp().
create(Text, Voice, Format, Options) ->
    VoiceMappings = ?GROQ_VOICE_MAPPINGS,
    case props:get_value(kz_term:to_lower_binary(Voice), VoiceMappings) of
        'undefined' ->
            {'error', 'invalid_voice'};
        TTSVoice ->
            make_request(Text, TTSVoice, Format, Options)
    end.

-spec make_request(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> create_resp().
make_request(Text, Voice, Format, Options) ->
    BaseUrl = ?GROQ_TTS_URL,

    Props = [{<<"input">>, Text}
            ,{<<"model">>, ?GROQ_TTS_MODEL}
            ,{<<"voice">>, Voice}
            ,{<<"response_format">>, Format}
            ],
    Headers = [{"Content-Type", "application/json"}
              ,{"Authorization", "Bearer " ++ ?GROQ_TTS_API_KEY}
              ],
    Body = kz_json:encode(kz_json:from_list(Props)),

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
