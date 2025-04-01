%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Execute the 'Stream' verb
%%% @author
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzt_twiml_stream).

-export([start/3, stop/2]).

-include("kzt.hrl").

-define(START_WAIT_TIMEOUT_MS, 10 * ?MILLISECONDS_IN_SECOND). %% 5 seconds
-define(MAX_TIMEOUT_MS, 5 * ?MILLISECONDS_IN_HOUR). %% 5 hours

-type stream_type() :: 'unidirectional' | 'bidirectional'.

-spec start(kapps_call:call(), kz_types:xml_els() | kz_types:xml_texts(), stream_type()) ->
          {'ok', kapps_call:call()} |
          {'error', kapps_call:call()} |
          {'stop', kapps_call:call()}.
start(Call, [#xmlElement{name='Stream', content=Stream, attributes=Attrs}|_], Type) ->
    kapps_call_command:answer(Call),
    Props = kz_xml:attributes_to_proplist(Attrs),
    CustomParams = get_stream_custom_params(Stream),
    Call1 = kzt_util:update_call_status(?STATUS_IN_PROGRESS, Call),
    setup_call_for_stream(Call1, Type, CustomParams, Props);
start(Call, _Rest, _Attrs) ->
    lager:debug("unhandled XML object: ~p", [_Rest]),
    {'ok', Call}.

-spec stop(kapps_call:call(), kz_types:xml_els() | kz_types:xml_texts()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
stop(Call, [#xmlElement{name='Stream', content=_Stream, attributes=Attrs}|_]) ->
    Props = kz_xml:attributes_to_proplist(Attrs),
    Id = props:get_ne_binary_value('id', Props),
    Name = props:get_ne_binary_value('name', Props),
    Call1 = kzt_util:update_call_status(?STATUS_IN_PROGRESS, Call),
    gen_listener:cast(kzt_util:get_amqp_listener(Call1), {'stream_stop', Id, Name}),
    {'ok', Call1};
stop(Call, _Rest) ->
    lager:debug("unhandled XML object: ~p", [_Rest]),
    {'ok', Call}.

-spec setup_call_for_stream(kapps_call:call(), stream_type(), kz_term:api_object(), kz_term:proplist()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
setup_call_for_stream(Call, Type, CustomParams, Props) ->
    case parse_ws_url(Call, Props) of
        {'error', _Reason, Call1} ->
            lager:debug("invalid stream websocket url, stop processing twiml: ~s", [_Reason]),
            {'stop', Call1};
        {'ok', Url} ->
            start_call_stream(Call, Url, Type, CustomParams, Props)
    end.

-spec parse_ws_url(kapps_call:call(), kz_term:proplist()) ->
          {'ok', kz_term:ne_binary()} |
          {'error', atom(), kapps_call:call()}.
parse_ws_url(Call, Props) ->
    CurrentUri = current_wss_uri(kzt_util:get_voice_uri(Call)),
    Url = props:get_ne_binary_value('url', Props, CurrentUri),
    case uri_string:resolve(Url, CurrentUri, ['return_map']) of
        {'error', Reason, _} ->
            Setters = [{fun kzt_util:add_error/3, <<"stream">>, kz_binary:format(<<"invalid websocket url: ~s">>, [Reason])}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                      ],
            {'error', Reason, kapps_call:exec(Setters, Call)};
        #{scheme := <<"ws">>, host := Host}=Uri when Host =/= <<>> ->
            {'ok', uri_string:recompose(maps:without(['query', 'fragment'], Uri))};
        #{scheme := <<"wss">>, host := Host}=Uri when Host =/= <<>> ->
            {'ok', uri_string:recompose(maps:without(['query', 'fragment'], Uri))};
        #{scheme := Scheme, host := Host} when Host =/= <<>> ->
            Setters = [{fun kzt_util:add_error/3, <<"stream">>, kz_binary:format(<<"invalid websocket url scheme: ~s">>, [Scheme])}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                      ],
            {'error', 'invalid_scheme', kapps_call:exec(Setters, Call)};
        _ ->
            Setters = [{fun kzt_util:add_error/3, <<"stream">>, <<"invalid websocket url">>}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                      ],
            {'error', 'invalid_wss_url', kapps_call:exec(Setters, Call)}
    end.

-spec current_wss_uri(kz_term:api_binary()) -> binary().
current_wss_uri(<<"https://", Rest/binary>>) -> <<"wss://", Rest/binary>>;
current_wss_uri(<<"http://", Rest/binary>>) -> <<"wss://", Rest/binary>>;
current_wss_uri(_) -> <<>>.

-spec start_call_stream(kapps_call:call(), kz_term:ne_binary(), stream_type(), kz_term:api_object(), kz_term:proplist()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
start_call_stream(Call, Url, Type, CustomParams, Props) ->
    Name = props:get_ne_binary_value('name', Props, kz_binary:rand_hex(6)),
    Data0 = [{<<"url">>, Url}
            ,{<<"type">>, stream_type(Type, Props)}
            ,{<<"name">>, Name}
            ,{<<"custom_params">>, CustomParams}
            ],
    case get_audio_data(Props) of
        {'ok', AudioData} ->
            Data = props:set_values(AudioData, Data0),
            gen_listener:cast(kzt_util:get_amqp_listener(Call), {'stream_start', self(), kz_json:from_list(Data)}),
            wait_for_stream_start(Type, Name, Call, ?START_WAIT_TIMEOUT_MS);
        {'error', Error} ->
            Setters = [{fun kzt_util:add_error/3, <<"stream">>, Error}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                      ],
            {'error', kapps_call:exec(Setters, Call)}
    end.

-spec stream_type(stream_type(), kz_term:proplist()) -> kz_term:ne_binary().
stream_type('unidirectional' = Type, Props) ->
    case props:is_true('rawAudio', Props, 'false') of
        'true' -> <<"raw">>;
        'false' -> kz_term:to_binary(Type)
    end;
stream_type(Type, _) ->
    kz_term:to_binary(Type).

get_audio_data(Props) ->
    case stream_audio_tracks(Props) of
        {'ok', Track} ->
            get_audio_data(Props, Track);
        {'error', _}=Error ->
            Error
    end.

-spec get_audio_data(kz_term:proplist(), kz_term:ne_binary()) ->
          {'ok', kz_term:proplist()} |
          {'error', kz_term:ne_binary()}.
get_audio_data(Props, Track) ->
    case kz_term:to_lower_binary(props:get_ne_binary_value('audioCodec', Props, <<"pcm">>)) of
        <<"pcm">> ->
            get_audio_data(Props, Track, <<"pcm">>);
        <<"pcm16">> ->
            get_audio_data(Props, Track, <<"pcm16">>);
        <<"g711_ulaw">> ->
            get_audio_data(Props, Track, <<"g711_ulaw">>);
        <<"pcmu">> ->
            get_audio_data(Props, Track, <<"g711_ulaw">>);
        _Unsupported ->
            {'error', <<"unsupported audio format">>}
    end.

-spec get_audio_data(kz_term:proplist(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_term:proplist()} |
          {'error', kz_term:ne_binary()}.
get_audio_data(Props, Track, <<"pcm">>) ->
    Data0 = [{<<"format">>, <<"L16">>}
            ,{<<"track">>, Track}
            ],
    Funs = [fun maybe_set_audio_mix/1
           ,fun maybe_set_audio_sample_rate/1
           ],
    case kz_either:pipe({'ok', {Props, Data0}}, Funs) of
        {'ok', {_, Data}} -> {'ok', Data};
        {'error', _}=Error -> Error
    end;
get_audio_data(_Props, Track, <<"pcm16">>) ->
    {'ok'
    ,[{<<"format">>, <<"L16">>}
     ,{<<"track">>, Track}
     ,{<<"mix">>, <<"mono">>}
     ,{<<"sample_rate">>, <<"24000">>}
     ]
    };
get_audio_data(_Props, Track, <<"g711_ulaw">>) ->
    {'ok'
    ,[{<<"format">>, <<"PCMU">>}
     ,{<<"track">>, Track}
     ,{<<"mix">>, <<"mono">>}
     ,{<<"sample_rate">>, <<"8000">>}
     ]
    }.

-spec stream_audio_tracks(kz_term:proplist()) -> {'ok', kz_term:ne_binary()} | {'error', kz_term:ne_binary()}.
stream_audio_tracks(Props) ->
    Tracks = [<<"inbound_track">>, <<"outbound_track">>, <<"both_tracks">>],
    Track = props:get_ne_binary_value('track', Props, <<"inbound_track">>),
    case lists:member(Track, Tracks) of
        'true' ->
            {'ok', Track};
        'false' ->
            {'error', <<"invalid stream audio track">>}
    end.

-spec maybe_set_audio_mix({kz_term:proplist(), kz_term:proplist()}) ->
          {'ok', {kz_term:proplist(), kz_term:proplist()}} |
          {'error', kz_term:ne_binary()}.
maybe_set_audio_mix({Props, Data}) ->
    Mixes = [<<"mono">>, <<"stereo">>],
    Mix = props:get_ne_binary_value('audioMix', Props, <<"mono">>),
    case lists:member(Mix, Mixes) of
        'true' ->
            {'ok', {Props, props:set_value(<<"mix">>, Mix, Data)}};
        'false' ->
            {'error', <<"invalid stream audio mix">>}
    end.

-spec maybe_set_audio_sample_rate({kz_term:proplist(), kz_term:proplist()}) ->
          {'ok', {kz_term:proplist(), kz_term:proplist()}} |
          {'error', kz_term:ne_binary()}.
maybe_set_audio_sample_rate({Props, Data}) ->
    case get_sample_rate(Props) of
        {'ok', Rate} ->
            {'ok', {Props, props:set_value(<<"sample_rate">>, Rate, Data)}};
        {'error', _}=Error ->
            Error
    end.

-spec get_sample_rate(kz_term:proplist()) ->
          {'ok', kz_term:ne_binary()} |
          {'error', kz_term:ne_binary()}.
get_sample_rate(Props) ->
    SampleRate = props:get_ne_binary_value('sampleRate', Props, <<"8000">>),
    case kz_binary:reverse(SampleRate) of
        <<"k", Etar/binary>> ->
            RateInt = kz_term:safe_cast(kz_binary:reverse(Etar), 'undefined', fun kz_term:to_integer/1),
            safe_sample_rate(SampleRate, RateInt, 1000);
        _ ->
            RateInt = kz_term:safe_cast(SampleRate, 'undefined', fun kz_term:to_integer/1),
            safe_sample_rate(SampleRate, RateInt, 1)
    end.

-spec safe_sample_rate(kz_term:ne_binary(), kz_term:api_integer(), integer()) ->
          {'ok', kz_term:ne_binary()} |
          {'error', kz_term:ne_binary()}.
safe_sample_rate(_Value, 'undefined', _) ->
    {'error', <<"invalid stream audio samplerate">>};
safe_sample_rate(_Value, RateInt, Multiply1K) ->
    Rate = (RateInt * Multiply1K),
    case Rate rem 8000 of
        0 ->
            {'ok', kz_term:to_binary(Rate)};
        _ ->
            {'error', <<"stream audio samplerate is not divisable by 8000">>}
    end.

-spec wait_for_stream_start(stream_type(), kz_term:ne_binary(), kapps_call:call(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
wait_for_stream_start(Type, Name, Call, Timeout) ->
    Start = kz_time:start_time(),
    case kapps_call_command:receive_event(Timeout) of
        {'ok', JObj} ->
            process_stream_start_event(Type, Name, Call, JObj, kz_time:decr_timeout(Timeout, Start));
        {'error', _Reason} ->
            lager:debug("failed to start stream: ~p", [_Reason]),
            Setters = [{fun kzt_util:add_error/3, <<"stream">>,  <<"unabled to start stream">>}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                      ],
            {'error', kapps_call:exec(Setters, Call)}
    end.

-spec process_stream_start_event(stream_type(), kz_term:ne_binary(), kapps_call:call(), kz_json:object(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
process_stream_start_event(Type, Name, Call, JObj, Timeout) ->
    case kz_api:event_type(JObj) of
        {<<"pivot">>, <<"stream_start">>} ->
            case kz_json:get_value(<<"Stream-Name">>, JObj) of
                Name ->
                    StreamId = kz_json:get_binary_value(<<"Stream-ID">>, JObj),
                    lager:debug("streaming media to server started with id ~s", [StreamId]),
                    Call1 = kzt_util:add_stream(StreamId, Name, Call),
                    maybe_continue(StreamId, Type, Call1);
                _OtherName ->
                    lager:debug("ignoring stream_start event for other stream '~s' on the call", [_OtherName]),
                    wait_for_stream_start(Type, Name, Call, Timeout)
            end;
        {<<"pivot">>, <<"stream_stop">>} ->
            %% using name as default, in case proxy stopped before able to get
            %% data from freeswitch
            case {kz_json:get_ne_binary_value(<<"Stream-Name">>, JObj, Name)
                 ,kz_json:get_ne_binary_value(<<"Error-Message">>, JObj)
                 ,Type
                 }
            of
                {Name, 'undefined', 'unidirectional'} ->
                    lager:debug("unidirectional stream is ended before receiving stream_start, continuing the call"),
                    {'ok', Call};
                {Name, 'undefined', _} ->
                    lager:debug("bidirectional stream is ended before receiving stream_start, ending the call"),
                    {'stop', kzt_util:update_call_status(?STATUS_CANCELED, Call)};
                {Name, Error, _} ->
                    lager:debug("stream failed is before receiving stream_start, ending the call: ~s", [Error]),
                    Setters = [{fun kzt_util:add_error/3, <<"stream">>,  Error}
                              ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                              ],
                    {'stop', kapps_call:exec(Setters, Call)};
                {_OtherName, _Error, _Type} ->
                    wait_for_stream_start(Type, Name, Call, Timeout)
            end;
        {<<"call_event">>, <<"CHANNEL_DESTROY">>} ->
            HangupCause = kz_call_event:hangup_cause(JObj),
            lager:debug("channel was destroyed: ~s", [HangupCause]),
            Setters = [{fun kzt_util:set_is_caller_hungup/2, 'true'}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                      ],
            {'stop', kapps_call:exec(Setters, Call)};
        {_Cat, _Event} ->
            wait_for_stream_start(Type, Name, Call, Timeout)
    end.

-spec maybe_continue(kz_term:ne_binary(), stream_type(), kapps_call:call()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
maybe_continue(_Id, 'unidirectional', Call) ->
    {'ok', Call};
maybe_continue(Id, 'bidirectional', Call) ->
    wait_for_stream_end(Id, Call, ?MAX_TIMEOUT_MS).

-spec wait_for_stream_end(kz_term:ne_binary(), kapps_call:call(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
wait_for_stream_end(Id, Call, Timeout) ->
    Start = kz_time:start_time(),
    case kapps_call_command:receive_event(Timeout) of
        {'ok', JObj} ->
            process_stream_stop_event(Id, Call, JObj, kz_time:decr_timeout(Timeout, Start));
        {'error', _Reason} ->
            lager:debug("failed to start stream: ~p", [_Reason]),
            Setters = [{fun kzt_util:add_error/3, <<"stream">>, <<"unabled to start stream">>}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_FAILED}
                      ],
            {'error', kapps_call:exec(Setters, Call)}
    end.

-spec process_stream_stop_event(kz_term:ne_binary(), kapps_call:call(), kz_json:object(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()} |
          {'error', kapps_call:call()}.
process_stream_stop_event(Id, Call, JObj, Timeout) ->
    case kz_api:event_type(JObj) of
        {<<"call_event">>, <<"CHANNEL_DESTROY">>} ->
            HangupCause = kz_call_event:hangup_cause(JObj),
            lager:debug("channel was destroyed: ~s", [HangupCause]),
            Setters = [{fun kzt_util:set_is_caller_hungup/2, 'true'}
                      ,{fun kzt_util:update_call_status/2, ?STATUS_CANCELED}
                      ],
            {'stop', kapps_call:exec(Setters, Call)};
        {<<"pivot">>, <<"stream_stop">>} ->
            case {kz_json:get_ne_binary_value(<<"Stream-ID">>, JObj)
                 ,kz_json:get_ne_binary_value(<<"Error-Message">>, JObj)
                 }
            of
                {Id, 'undefined'} ->
                    lager:debug("bidirectional stream is ended, ending the call"),
                    {'stop', kzt_util:update_call_status(?STATUS_CANCELED, Call)};
                {Id, Error} ->
                    lager:debug("bidirectional stream failed: ~s", [Error]),
                    Setters = [{fun kzt_util:add_error/3, <<"stream">>, Error}
                              ,{fun kzt_util:update_call_status/2, ?STATUS_FAILED}
                              ],
                    {'error', kapps_call:exec(Setters, Call)};
                _OtherId ->
                    lager:debug("ignoring stream_stop event for other stream '~s' on the call", [_OtherId]),
                    wait_for_stream_end(Id, Call, Timeout)
            end;
        {_Cat, _Event} ->
            wait_for_stream_end(Id, Call, Timeout)
    end.

-spec get_stream_custom_params(kz_types:xml_els()) -> kz_term:api_object().
get_stream_custom_params(Stream) ->
    %% TODO: Maybe limit the number of params to 100 KVs
    case lists:foldl(fun normalize_params/2, [], Stream) of
        [] -> 'undefined';
        KVs -> kz_json:from_list(KVs)
    end.

normalize_params(#xmlElement{name='Parameter', attributes=Attrs}, Acc) ->
    Prop = kz_xml:attributes_to_proplist(Attrs),
    case {props:get_ne_binary_value('name', Prop)
         ,props:get_ne_binary_value('value', Prop)
         }
    of
        {'undefined', 'undefined'} ->
            lager:debug("parameter is missing 'name' and 'value' attributes: ~tp", [Prop]),
            Acc;
        {'undefined', _} ->
            lager:debug("parameter is missing 'name' attribute: ~tp", [Prop]),
            Acc;
        {_, 'undefined'} ->
            lager:debug("parameter is missing 'value' attribute: ~tp", [Prop]),
            Acc;
        {Name, Value} ->
            [{kz_term:to_binary(Name), kz_term:to_binary(Value)} | Acc]
    end;
normalize_params(_, Acc) ->
    Acc.
