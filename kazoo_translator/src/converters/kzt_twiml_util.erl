%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzt_twiml_util).

-export([get_terminators/1
        ,loop_count/1
        ,get_voice/1
        ,get_engine/2
        ,get_lang/2
        ,finish_dtmf/1, finish_dtmf/2
        ,get_finish_key/1
        ,get_max_length/1
        ,pause_for/1
        ,action_url/1
        ,timeout_s/1, timeout_s/2
        ,num_digits/1
        ,reject_prompt/1
        ,reject_reason/1
        ,reject_code/1
        ,reject_status/1
        ,record_silence_vars/1
        ,get_element_name/1
        ]).

-include("kzt.hrl").

-spec get_terminators(kz_term:proplist()) -> kz_term:ne_binaries().
get_terminators(Props) ->
    kapi_dialplan:terminators(props:get_binary_value('terminators', Props)).

-spec get_lang(kapps_call:call(), kz_term:proplist()) -> kz_term:ne_binary().
get_lang(Call, Props) ->
    case props:get_binary_value('language', Props) of
        <<"en">> -> <<"en-US">>;
        <<"en-gb">> -> <<"en-GB">>;
        <<"es">> -> <<"es">>;
        <<"fr">> -> <<"fr">>;
        <<"de">> -> <<"de">>;
        <<"it">> -> <<"it">>;
        _ -> kapps_call:language(Call)
    end.

-spec get_voice(kz_term:proplist()) -> kz_term:ne_binary().
get_voice(Props) ->
    case props:get_ne_binary_value('voice', Props) of
        <<"man">> -> <<"male">>;
        <<"male">> -> <<"male">>;
        <<"woman">> -> <<"female">>;
        <<"female">> -> <<"female">>;
        _ -> ?DEFAULT_TTS_VOICE
    end.

-spec get_engine(kapps_call:call(), kz_term:proplist()) -> kz_term:ne_binary().
get_engine(Call, Props) ->
    case props:get_ne_binary_value('engine', Props) of
        'undefined' -> ?DEFAULT_TTS_ENGINE(Call);
        Engine ->
            case lists:member(Engine, kazoo_tts:supported_tts_providers()) of
                'true' -> Engine;
                'false' -> ?DEFAULT_TTS_ENGINE(Call)
            end
    end.

-spec loop_count(kz_term:proplist()) -> integer().
loop_count(Props) ->
    case props:get_integer_value('loop', Props, 1) of
        N when N =< 0 -> 0;
        N -> N
    end.

-spec finish_dtmf(kz_term:proplist()) -> kz_term:ne_binary().
finish_dtmf(Props) -> finish_dtmf(Props, <<"#">>).

-spec finish_dtmf(kz_term:proplist(), kz_term:ne_binary()) -> kz_term:api_ne_binary().
finish_dtmf(Props, Default) when is_list(Props) ->
    case props:get_binary_value('finishOnKey', Props) of
        'undefined' -> Default;
        <<>> -> 'undefined';
        DTMF ->
            case lists:member(DTMF, ?ANY_DIGIT) of
                'true' ->
                    DTMF;
                'false' ->
                    lager:debug("invalid dtmf key for finishOnKey ~s", [DTMF]),
                    Default
            end
    end.

-spec get_finish_key(kz_term:proplist()) -> kz_term:ne_binaries().
get_finish_key(Props) ->
    kapi_dialplan:terminators(props:get_binary_value('finishOnKey', Props)).

-spec get_max_length(kz_term:proplist()) -> pos_integer().
get_max_length(Props) ->
    Max = kapps_config:get_integer(<<?MODULE_STRING>>, <<"max_length">>, ?SECONDS_IN_HOUR),
    case props:get_integer_value('maxLength', Props, Max) of
        N when N =< 1 -> 1;
        N when N =< Max -> N;
        _ -> Max
    end.

%% limit pause to 1 hour (3600000 ms)
-spec pause_for(kz_term:proplist()) -> 1000..3600000.
pause_for(Props) ->
    case props:get_integer_value('length', Props) of
        'undefined' -> ?MILLISECONDS_IN_SECOND;
        N when N =< 0 -> ?MILLISECONDS_IN_SECOND;
        N when N =< ?SECONDS_IN_HOUR -> N * ?MILLISECONDS_IN_SECOND;
        _ -> ?MILLISECONDS_IN_HOUR
    end.

-spec action_url(kz_term:proplist()) -> kz_term:api_ne_binary().
action_url(Props) -> props:get_ne_binary_value('action', Props).

-spec reject_prompt(kz_term:proplist()) -> kz_term:api_ne_binary().
reject_prompt(Props) -> props:get_ne_binary_value('prompt', Props).

-spec timeout_s(kz_term:proplist()) -> pos_integer().
timeout_s(Props) -> timeout_s(Props, 30).

-spec timeout_s(kz_term:proplist(), pos_integer()) -> pos_integer().
timeout_s(Props, Default) ->
    case props:get_integer_value('timeout', Props, Default) of
        N when N =< 0 -> Default;
        N when N =< ?SECONDS_IN_HOUR -> N;
        _ -> Default
    end.

-spec num_digits(kz_term:proplist()) -> timeout().
num_digits(Props) ->
    case props:get_integer_value('numDigits', Props) of
        'undefined' -> 'infinity';
        N when N =< 0 -> 'infinity';
        N -> N
    end.

-spec reject_reason(kz_term:proplist()) -> kz_term:ne_binary().
reject_reason(Props) ->
    case props:get_ne_binary_value('reason', Props) of
        <<"rejected">> -> <<"rejected">>;
        <<"busy">> -> <<"busy">>;
        _ -> <<"rejected">>
    end.

-spec reject_code(kz_term:ne_binary()) -> kz_term:ne_binary().
reject_code(<<"busy">>) -> <<"486">>;
reject_code(<<"rejected">>) -> <<"603">>.

-spec reject_status(kz_term:ne_binary()) -> kz_term:ne_binary().
reject_status(<<"486">>) -> ?STATUS_BUSY;
reject_status(<<"603">>) -> ?STATUS_REJECTED.

-spec record_silence_vars(kz_term:proplist()) -> kz_term:proplist().
record_silence_vars(Props) ->
    case props:get_integer_value('timeout', Props, 5) of
        0 ->
            [];
        N when N < 0 ->
            [{<<"silence_initial_timeout">>, 5 * ?MILLISECONDS_IN_SECOND}
            ,{<<"silence_final_timeout">>, 5 * ?MILLISECONDS_IN_SECOND}
            ,{<<"silence_detection">>, 'true'}
            ];
        N ->
            [{<<"silence_initial_timeout">>, N * ?MILLISECONDS_IN_SECOND}
            ,{<<"silence_final_timeout">>, N * ?MILLISECONDS_IN_SECOND}
            ,{<<"silence_detection">>, 'true'}
            ]
    end.

-spec get_element_name(kz_types:xml_el()) -> kz_term:ne_binary().
get_element_name(#xmlElement{name=Name}) -> kz_term:to_binary(Name).
