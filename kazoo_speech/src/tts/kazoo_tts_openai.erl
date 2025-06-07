%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_tts_openai).

-behaviour(gen_tts_provider).

-export([create/4
        ,set_api_key/1
        ]).

-include("kazoo_speech.hrl").

-define(OPENAI_VOICE_MAPPINGS
       ,[{<<"female/en-us">>, <<"alloy">>}
        ,{<<"male/en-us">>, <<"ash">>}
        ,{<<"female/en-gb">>, <<"alloy">>}
        ,{<<"male/en-gb">>, <<"ash">>}
        ]
       ).

-define(OPENAI_CONFIG_CAT, <<(?MOD_CONFIG_CAT)/binary, ".openai">>).
-define(OPENAI_TTS_URL, kapps_config:get_string(?OPENAI_CONFIG_CAT, <<"tts_url_openai">>, <<"https://api.openai.com/v1/audio/speech">>)).
-define(OPENAI_TTS_API_KEY, kapps_config:get_string(?OPENAI_CONFIG_CAT, <<"tts_api_key">>)).
-define(OPENAI_TTS_MODEL, kapps_config:get_ne_binary(?OPENAI_CONFIG_CAT, <<"tts_model">>, <<"tts-1-hd">>)).
-define(OPENAI_TTS_SPEED, kapps_config:get_ne_binary(?OPENAI_CONFIG_CAT, <<"tts_speed">>, <<"1.0">>)).

-spec set_api_key(kz_term:ne_binary()) -> 'ok'.
set_api_key(Key) ->
    {'ok', _} = kapps_config:set_default(?OPENAI_CONFIG_CAT, <<"tts_api_key">>, Key),
    'ok'.

-spec create(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> create_resp().
create(Text, Voice, Format, Options) ->
    VoiceMappings = ?OPENAI_VOICE_MAPPINGS,
    case props:get_value(kz_term:to_lower_binary(Voice), VoiceMappings) of
        'undefined' ->
            {'error', 'invalid_voice'};
        TTSVoice ->
            make_request(Text, TTSVoice, Format, Options)
    end.

-spec make_request(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> create_resp().
make_request(Text, Voice, Format, Options) ->
    BaseUrl = ?OPENAI_TTS_URL,

    Props = [{<<"input">>, Text}
            ,{<<"model">>, ?OPENAI_TTS_MODEL}
            ,{<<"voice">>, Voice}
            ,{<<"response_format">>, Format}
            ,{<<"speed">>, ?OPENAI_TTS_SPEED}
            ],
    Headers = [{"Content-Type", "application/json"}
              ,{"Authorization", "Bearer " ++ ?OPENAI_TTS_API_KEY}
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
