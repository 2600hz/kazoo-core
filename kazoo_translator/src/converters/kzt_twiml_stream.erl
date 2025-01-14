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
          {'stop', kapps_call:call()}.
start(Call, [#xmlElement{name='Stream', content=Stream, attributes=Attrs}|_], Type) ->
    kapps_call_command:answer(Call),
    Props = kz_xml:attributes_to_proplist(Attrs),
    CustomParams = get_stream_custom_params(Stream),
    setup_call_for_stream(Call, Type, CustomParams, Props);
start(Call, _Rest, _Attrs) ->
    lager:debug("unhandled XML object: ~p", [_Rest]),
    {'ok', Call}.

-spec stop(kapps_call:call(), kz_types:xml_els() | kz_types:xml_texts()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
stop(Call, [#xmlElement{name='Stream', content=_Stream, attributes=Attrs}|_]) ->
    Props = kz_xml:attributes_to_proplist(Attrs),
    Id = props:get_ne_binary_value('id', Props),
    Name = props:get_ne_binary_value('name', Props),

    gen_listener:cast(kzt_util:get_amqp_listener(Call), {'stream_stop', Id, Name}),
    {'ok', Call};
stop(Call, _Rest) ->
    lager:debug("unhandled XML object: ~p", [_Rest]),
    {'ok', Call}.

-spec setup_call_for_stream(kapps_call:call(), stream_type(), kz_term:api_object(), kz_term:proplist()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
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
            {'error', Reason, kzt_util:add_error(Call, <<"stream">>, kz_binary:format(<<"invalid websocket url: ~s">>, [Reason]))};
        #{scheme := <<"ws">>, host := Host}=Uri when Host =/= <<>> ->
            {'ok', uri_string:recompose(maps:without(['query', 'fragment'], Uri))};
        #{scheme := <<"wss">>, host := Host}=Uri when Host =/= <<>> ->
            {'ok', uri_string:recompose(maps:without(['query', 'fragment'], Uri))};
        #{scheme := Scheme, host := Host} when Host =/= <<>> ->
            {'error', 'invalid_scheme', kzt_util:add_error(Call, <<"stream">>, kz_binary:format(<<"invalid websocket url scheme: ~s">>, [Scheme]))};
        _ ->
            {'error', 'invalid_wss_url', kzt_util:add_error(Call, <<"stream">>, <<"invalid websocket url">>)}
    end.

-spec current_wss_uri(kz_term:api_binary()) -> binary().
current_wss_uri(<<"https://", Rest/binary>>) -> <<"wss://", Rest/binary>>;
current_wss_uri(<<"http://", Rest/binary>>) -> <<"wss://", Rest/binary>>;
current_wss_uri(_) -> <<>>.

-spec start_call_stream(kapps_call:call(), kz_term:ne_binary(), stream_type(), kz_term:api_object(), kz_term:proplist()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
start_call_stream(Call, Url, Type, CustomParams, Props) ->
    Name = props:get_ne_binary_value('name', Props, kz_binary:rand_hex(6)),
    Data = [{<<"url">>, Url}
           ,{<<"type">>, stream_type(Type, Props)}
           ,{<<"name">>, Name}
           ,{<<"track">>, stream_audio_tracks(Props)}
           ,{<<"mix">>, stream_audio_mix(Props)}
           ,{<<"sample_rate">>, stream_audio_sample_rate(Props)}
           ,{<<"custom_params">>, CustomParams}
           ],

    gen_listener:cast(kzt_util:get_amqp_listener(Call), {'stream_start', self(), kz_json:from_list(Data)}),
    wait_for_stream_start(Type, Name, Call, ?START_WAIT_TIMEOUT_MS).

-spec stream_type(stream_type(), kz_term:proplist()) -> kz_term:ne_binary().
stream_type('unidirectional' = Type, Props) ->
    case props:is_true('rawAudio', Props, 'false') of
        'true' -> <<"raw">>;
        'false' -> kz_term:to_binary(Type)
    end;
stream_type(Type, _) ->
    kz_term:to_binary(Type).

-spec stream_audio_tracks(kz_term:proplist()) -> kz_term:ne_binary().
stream_audio_tracks(Props) ->
    Tracks = [<<"inbound_track">>, <<"outbound_track">>, <<"both_tracks">>],
    Track = props:get_ne_binary_value('track', Props, <<"inbound_track">>),
    case lists:member(Track, Tracks) of
        'true' ->
            Track;
        'false' ->
            lager:debug("invalid stream audio track ~s, falling back to inbound_track"),
            <<"inbound_track">>
    end.

-spec stream_audio_mix(kz_term:proplist()) -> kz_term:ne_binary().
stream_audio_mix(Props) ->
    Mixes = [<<"mono">>, <<"stereo">>],
    Mix = props:get_ne_binary_value('audioMix', Props, <<"mono">>),
    case lists:member(Mix, Mixes) of
        'true' ->
            Mix;
        'false' ->
            lager:debug("invalid stream audio mix ~s, falling back to mono"),
            <<"mono">>
    end.

-spec stream_audio_sample_rate(kz_term:proplist()) -> kz_term:ne_binary().
stream_audio_sample_rate(Props) ->
    SampleRate = props:get_ne_binary_value('sampleRate', Props, <<"8000">>),
    case kz_binary:reverse(SampleRate) of
        <<"k", Etar/binary>> ->
            RateInt = kz_term:safe_cast(kz_binary:reverse(Etar), 'undefined', fun kz_term:to_integer/1),
            safe_sample_rate(SampleRate, RateInt, 1000);
        _ ->
            RateInt = kz_term:safe_cast(SampleRate, 'undefined', fun kz_term:to_integer/1),
            safe_sample_rate(SampleRate, RateInt, 1)
    end.

-spec safe_sample_rate(kz_term:ne_binary(), kz_term:api_integer(), integer()) -> kz_term:ne_binary().
safe_sample_rate(_Value, 'undefined', _) ->
    lager:debug("invalid stream audio samplerate ~s, using 8000 as fallback", [_Value]),
    <<"8000">>;
safe_sample_rate(_Value, RateInt, Multiply1K) ->
    Rate = (RateInt * Multiply1K),
    case Rate rem 8000 of
        0 ->
            kz_term:to_binary(Rate);
        _ ->
            lager:debug("stream audio samplerate ~s is not divisable by 8000, using 8000 as fallback", [_Value]),
            <<"8000">>
    end.

-spec wait_for_stream_start(stream_type(), kz_term:ne_binary(), kapps_call:call(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
wait_for_stream_start(Type, Name, Call, Timeout) ->
    Start = kz_time:start_time(),
    case kapps_call_command:receive_event(Timeout) of
        {'ok', JObj} ->
            process_stream_start_event(Type, Name, Call, JObj, kz_time:decr_timeout(Timeout, Start));
        {'error', _Reason} ->
            lager:debug("failed to start stream: ~p", [_Reason]),
            {'stop', kzt_util:add_error(Call, <<"stream">>, <<"unabled to start stream">>)}
    end.

-spec process_stream_start_event(stream_type(), kz_term:ne_binary(), kapps_call:call(), kz_json:object(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
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
                    {'stop', Call};
                {Name, Error, _} ->
                    lager:debug("stream failed is before receiving stream_start, ending the call: ~s", [Error]),
                    {'stop', kzt_util:add_error(Call, <<"stream">>, Error)};
                {_OtherName, _Error, _Type} ->
                    wait_for_stream_start(Type, Name, Call, Timeout)
            end;
        {<<"call_event">>, <<"CHANNEL_DESTROY">>} ->
            HangupCause = kz_call_event:hangup_cause(JObj),
            lager:debug("channel was destroyed: ~s", [HangupCause]),
            {'stop', kzt_util:set_is_caller_hungup('true', Call)};
        {_Cat, _Event} ->
            wait_for_stream_start(Type, Name, Call, Timeout)
    end.

-spec maybe_continue(kz_term:ne_binary(), stream_type(), kapps_call:call()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
maybe_continue(_Id, 'unidirectional', Call) ->
    {'ok', Call};
maybe_continue(Id, 'bidirectional', Call) ->
    wait_for_stream_end(Id, Call, ?MAX_TIMEOUT_MS).

-spec wait_for_stream_end(kz_term:ne_binary(), kapps_call:call(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
wait_for_stream_end(Id, Call, Timeout) ->
    Start = kz_time:start_time(),
    case kapps_call_command:receive_event(Timeout) of
        {'ok', JObj} ->
            process_stream_stop_event(Id, Call, JObj, kz_time:decr_timeout(Timeout, Start));
        {'error', _Reason} ->
            lager:debug("failed to start stream: ~p", [_Reason]),
            {'stop', kzt_util:add_error(Call, <<"stream">>, <<"unabled to start stream">>)}
    end.

-spec process_stream_stop_event(kz_term:ne_binary(), kapps_call:call(), kz_json:object(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'stop', kapps_call:call()}.
process_stream_stop_event(Id, Call, JObj, Timeout) ->
    case kz_api:event_type(JObj) of
        {<<"call_event">>, <<"CHANNEL_DESTROY">>} ->
            HangupCause = kz_call_event:hangup_cause(JObj),
            lager:debug("channel was destroyed: ~s", [HangupCause]),
            {'stop', kzt_util:set_is_caller_hungup('true', Call)};
        {<<"pivot">>, <<"stream_stop">>} ->
            case {kz_json:get_ne_binary_value(<<"Stream-ID">>, JObj)
                 ,kz_json:get_ne_binary_value(<<"Error-Message">>, JObj)
                 }
            of
                {Id, 'undefined'} ->
                    lager:debug("bidirectional stream is ended, ending the call"),
                    {'stop', Call};
                {Id, Error} ->
                    lager:debug("bidirectional stream failed: ~s", [Error]),
                    {'stop', kzt_util:add_error(Call, <<"stream">>, Error)};
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
