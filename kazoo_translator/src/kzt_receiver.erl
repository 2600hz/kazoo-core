%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc Receive call events for various scenarios
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzt_receiver).

-export([wait_for_offnet/3
        ,wait_for_noop/2
        ,wait_for_hangup/1
        ,wait_for_conference/1
        ,say_loop/6, say_loop/7
        ,play_loop/3, play_loop/4
        ,wait_for_record/3
        ,collect_dtmfs/4, collect_dtmfs/5
        ,recording_meta/2
        ]).

-include("kzt.hrl").

-type dial_type() :: 'bridge' | 'conference' | 'offnet'.
-record(dial_req, {call :: kapps_call:call() | 'undefined'
                  ,has_caller_hungup :: boolean() | 'undefined'
                  ,hangup_dtmf :: kz_term:api_binary()
                  ,collect_dtmf = 'false' :: boolean()
                  ,record_call :: kz_term:api_boolean()
                  ,call_timeout :: timeout() | 'undefined'
                  ,call_time_limit :: timeout() | 'undefined'
                  ,start = kz_time:start_time():: kz_time:start_time() | 'undefined'
                  ,call_b_leg :: kz_term:api_ne_binary()
                  ,dial_type :: dial_type()
                  }).
-type dial_req() :: #dial_req{}.

-define(DEFAULT_EVENT_WAIT, 10 * ?MILLISECONDS_IN_SECOND). % 10s or 10000ms

-type collect_dtmfs_return() :: {'ok', kapps_call:call()} |
                                {'ok', 'timeout', kapps_call:call()} |
                                {'ok', 'dtmf_finish', kapps_call:call()} |
                                {'stop', kapps_call:call()}.
-export_type([collect_dtmfs_return/0]).

-spec default_on_first_fun(any()) -> 'ok'.
default_on_first_fun(_) -> 'ok'.

-spec collect_dtmfs(kapps_call:call(), kz_term:api_ne_binary(), timeout(), timeout()) ->
          collect_dtmfs_return().
collect_dtmfs(Call, FinishKey, Timeout, MaxDigits) ->
    collect_dtmfs(Call
                 ,FinishKey
                 ,Timeout
                 ,MaxDigits
                 ,fun default_on_first_fun/1
                 ,kzt_util:get_digits_collected(Call)
                 ).

-spec collect_dtmfs(kapps_call:call(), kz_term:api_ne_binary(), timeout(), timeout(), function()) ->
          collect_dtmfs_return().
collect_dtmfs(Call, FinishKey, Timeout, MaxDigits, OnFirstFun) when is_function(OnFirstFun, 1) ->
    collect_dtmfs(Call
                 ,FinishKey
                 ,Timeout
                 ,MaxDigits
                 ,OnFirstFun
                 ,kzt_util:get_digits_collected(Call)
                 ).

-spec collect_dtmfs(kapps_call:call(), kz_term:api_ne_binary(), timeout(), timeout(), function(), binary()) ->
          collect_dtmfs_return().
collect_dtmfs(Call,_ ,_ , MaxDigits, _, Collected)
  when is_integer(MaxDigits)
       andalso byte_size(Collected) =:= MaxDigits ->
    {'ok', Call};
collect_dtmfs(Call, FinishKey, Timeout, MaxDigits, OnFirstFun, Collected) ->
    lager:debug("collecting ~p dtmfs, so far collected: ~s", [MaxDigits, Collected]),
    Start = kz_time:start_time(),

    case kapps_call_command:receive_event(collect_timeout(Call, Timeout), 'false') of
        {'ok', JObj} ->
            collect_dtmfs(Call, FinishKey, collect_decr_timeout(Call, Timeout, Start)
                         ,MaxDigits, OnFirstFun, Collected, JObj
                         );
        {'error', 'timeout'} ->
            {'ok', 'timeout', Call};
        {'other', {'DOWN', Ref, 'process', Pid, _Reason}} ->
            case kzt_util:get_gather_pidref(Call) of
                {Pid, Ref} when is_pid(Pid), is_reference(Ref) ->
                    lager:info("subactions are done, timer can start"),
                    collect_dtmfs(kzt_util:set_gather_pidref('undefined', Call)
                                 ,FinishKey, collect_decr_timeout(Call, Timeout, Start), MaxDigits, OnFirstFun, Collected
                                 );
                _ ->
                    collect_dtmfs(Call, FinishKey, collect_decr_timeout(Call, Timeout, Start), MaxDigits, OnFirstFun, Collected)
            end;
        {'other', OtherJObj} ->
            lager:debug("other message: ~p", [OtherJObj]),
            collect_dtmfs(Call, FinishKey, collect_decr_timeout(Call, Timeout, Start), MaxDigits, OnFirstFun, Collected)
    end.

-spec collect_dtmfs(kapps_call:call(), kz_term:api_ne_binary(), timeout(), timeout(), function(), binary(), kz_json:object()) ->
          collect_dtmfs_return().
collect_dtmfs(Call, FinishKey, Timeout, MaxDigits, OnFirstFun, Collected, JObj) ->
    case kz_api:event_type(JObj) of
        {<<"call_event">>, <<"CHANNEL_DESTROY">>} ->
            {'stop', Call};
        {<<"call_event">>, <<"DTMF">>} ->
            handle_dtmf(Call
                       ,FinishKey
                       ,Timeout
                       ,MaxDigits
                       ,OnFirstFun
                       ,Collected
                       ,kz_call_event:dtmf_digit(JObj)
                       );
        _Evt ->
            collect_dtmfs(Call, FinishKey, Timeout, MaxDigits, OnFirstFun, Collected)
    end.

-spec handle_dtmf(kapps_call:call(), kz_term:api_ne_binary(), timeout(), timeout(), function(), binary(), kz_term:api_ne_binary()) ->
          collect_dtmfs_return().
handle_dtmf(Call, FinishKey, _, _, _, _, FinishKey) when is_binary(FinishKey) ->
    lager:info("finish key '~s' pressed", [FinishKey]),
    {'ok', 'dtmf_finish', Call};
handle_dtmf(Call, _, _, _, _, _, <<>>) ->
    lager:info("no dtmf pressed in time"),
    {'ok', 'timeout', Call};
handle_dtmf(Call, _, _, _, _, _, 'undefined') ->
    lager:info("no dtmf pressed in time"),
    {'ok', 'timeout', Call};
handle_dtmf(Call, FinishKey, Timeout, MaxDigits, OnFirstFun, <<>>, DTMF) ->
    lager:info("first dtmf pressed: ~s", [DTMF]),
    Call1 = kzt_util:add_digit_collected(DTMF, Call),
    _ = try OnFirstFun(Call1) of _ -> 'ok' catch _:_ -> 'ok' end,
    collect_dtmfs(kzt_util:set_gather_pidref('undefined', Call1)
                 ,FinishKey
                 ,Timeout
                 ,MaxDigits
                 ,fun default_on_first_fun/1
                 ,DTMF
                 );
handle_dtmf(Call, FinishKey, Timeout, MaxDigits, OnFirstFun, Collected, DTMF) ->
    lager:debug("dtmf pressed: '~s'", [DTMF]),
    collect_dtmfs(kzt_util:add_digit_collected(DTMF, Call)
                 ,FinishKey
                 ,Timeout
                 ,MaxDigits
                 ,OnFirstFun
                 ,<<DTMF/binary, Collected/binary>>
                 ).

-spec collect_decr_timeout(kapps_call:call(), timeout(), kz_time:start_time()) ->
          timeout().
collect_decr_timeout(Call, Timeout, Start) ->
    case kzt_util:get_gather_pidref(Call) of
        {_Pid, _Ref} when is_pid(_Pid)
                          andalso is_reference(_Ref) ->
            Timeout;
        _ -> kz_time:decr_timeout(Timeout, Start)
    end.

-spec collect_timeout(kapps_call:call(), timeout()) -> timeout().
collect_timeout(Call, Timeout) ->
    case kzt_util:get_gather_pidref(Call) of
        {_Pid, _Ref} when is_pid(_Pid)
                          andalso is_reference(_Ref) ->
            'infinity';
        _ -> Timeout
    end.

-spec say_loop(kapps_call:call(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'error', _, kapps_call:call()}.
say_loop(Call, SayMe, Voice, Lang, Engine, N) ->
    say_loop(Call, SayMe, Voice, Lang, 'undefined', Engine, N).

-spec say_loop(kapps_call:call(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), list() | 'undefined', kz_term:ne_binary(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'error', _, kapps_call:call()}.
say_loop(Call, _SayMe, _Voice, _Lang, _Terminators, _Engine, N) when N =< 0 ->
    {'ok', Call};
say_loop(Call, SayMe, Voice, Lang, Terminators, Engine, N) ->
    NoopId = kapps_call_command:tts(SayMe, Voice, Lang, Terminators, Engine, Call),
    case wait_for_noop(Call, NoopId) of
        {'ok', Call1} ->
            say_loop(Call1
                    ,SayMe
                    ,Voice
                    ,Lang
                    ,Terminators
                    ,Engine
                    ,decr_loop_counter(N)
                    );
        {'error', _, _}=ERR -> ERR
    end.

-spec play_loop(kapps_call:call(), binary(), timeout()) ->
          {'ok', kapps_call:call()} |
          {'error', _, kapps_call:call()}.
play_loop(Call, PlayMe, N) ->
    play_loop(Call, PlayMe, 'undefined', N).

-spec play_loop(kapps_call:call(), binary(), list() | 'undefined', timeout()) ->
          {'ok', kapps_call:call()} |
          {'error', _, kapps_call:call()}.
play_loop(Call, <<>>, _Terminators, _N) ->
    {'error', 'no_media', Call};
play_loop(Call, _, _, 0) ->
    {'ok', Call};
play_loop(Call, PlayMe, Terminators, N) ->
    NoopId = kapps_call_command:play(PlayMe, Terminators, Call),
    lager:debug("terminators: ~p loop: ~p noop: ~s", [Terminators, N, NoopId]),
    case wait_for_noop(Call, NoopId) of
        {'ok', C} ->
            lager:debug("noop recv"),
            play_loop(C, PlayMe, Terminators, decr_loop_counter(N));
        {'error', _, _}=ERR ->
            lager:debug("err: ~p", [ERR]),
            ERR
    end.

-spec wait_for_record(kapps_call:call(), pos_integer(), kz_term:ne_binaries()) ->
          {'ok', kapps_call:call()} |
          {'error', kz_json:object() | 'timeout'}.
wait_for_record(Call, Timeout, Terminators) ->
    Start = kz_time:start_time(),
    case kapps_call_command:receive_event(Timeout) of
        {'ok', JObj} ->
            case kapps_call_command:get_event_type(JObj) of
                {<<"error">>, _, <<"record">>} ->
                    lager:debug("channel execution error while waiting for record to start ~p", [kz_json:encode(JObj)]),
                    {'error', JObj};
                {<<"call_event">>,<<"CHANNEL_DESTROY">>, _} ->
                    lager:debug("channel has gone down before record started"),
                    Fs = [{fun kzt_util:set_digit_pressed/2, <<"hangup">>}
                         ,{fun kzt_util:set_recording_duration/2, 0}
                         ],
                    {'ok', kapps_call:exec(Fs, Call)};
                {<<"call_event">>, <<"RECORD_START">>, <<"record">>} ->
                    lager:debug("recording have started"),
                    record_loop(Call, Timeout, Terminators);
                {<<"call_event">>, <<"RECORD_STOP">>, <<"record">>} ->
                    record_finished(Call, JObj);
                {<<"call_event">>, <<"DTMF">>, _} ->
                    handle_record_dtmf(Call, kz_time:decr_timeout(Timeout, Start), Terminators, JObj, fun wait_for_record/3);
                _T ->
                    lager:debug("ignoring non recrod event ~p", [_T]),
                    wait_for_record(Call, kz_time:decr_timeout(Timeout, Start), Terminators)
            end;
        {'error', _}=Error ->
            Error
    end.

-spec record_loop(kapps_call:call(), pos_integer(), kz_term:ne_binaries()) ->
          {'ok', kapps_call:call()} |
          {'error', kz_json:object() | 'timeout'}.
record_loop(Call, Timeout, Terminators) ->
    Start = kz_time:start_time(),
    case kapps_call_command:receive_event(Timeout) of
        {'ok', JObj} ->
            case kapps_call_command:get_event_type(JObj) of
                {<<"error">>, _, <<"record">>} ->
                    lager:debug("channel execution error while waiting for end of recording", [kz_json:encode(JObj)]),
                    {'error', JObj};
                {<<"call_event">>,<<"CHANNEL_DESTROY">>, _} ->
                    Length = kz_time:milliseconds_to_seconds(kz_json:get_value(<<"Length">>, JObj, 0)),
                    lager:debug("destroy occurred while recording (length: ~b), waiting 60000 ms for RECORD_STOP", [Length]),
                    record_loop(kzt_util:set_digit_pressed(<<"hangup">>, Call), 60 * ?MILLISECONDS_IN_SECOND, Terminators);
                {<<"call_event">>, <<"RECORD_STOP">>, <<"record">>} ->
                    record_finished(Call, JObj);
                {<<"call_event">>, <<"DTMF">>, _} ->
                    handle_record_dtmf(Call, kz_time:decr_timeout(Timeout, Start), Terminators, JObj, fun record_loop/3);
                _T ->
                    lager:debug("ignore non record event ~p", [_T]),
                    record_loop(Call, kz_time:decr_timeout(Timeout, Start), Terminators)
            end;
        {'error', _}=Error ->
            Error
    end.

-spec record_finished(kapps_call:call(), kz_json:object()) -> {'ok', kapps_call:call()}.
record_finished(Call, JObj) ->
    DocId = kz_recording:id(JObj),
    Length = recording_length(JObj),

    Data = kz_recording:data(JObj, kz_json:new()),
    DefaultUrl = kz_binary:join([<<"accounts">>, kapps_call:account_id(Call), <<"recordings">>, DocId], <<"/">>),
    Url = kz_json:get_ne_binary_value(<<"url">>, Data, <<"/", DefaultUrl/binary>>),

    lager:debug("recording is finished, length: ~b doc_id: ~s", [Length, DocId]),

    Updates = [{fun kzt_util:set_recording_sid/2, DocId}
              ,{fun kzt_util:set_recording_duration/2, Length}
              ,{fun kzt_util:set_recording_url/2, Url}
              ],
    {'ok', kapps_call:exec(Updates, Call)}.

-type record_dtmf_loopfun() :: fun((kapps_call:call(), pos_integer(), kz_term:ne_binaries()) -> {'ok', kapps_call:call()} | {'error', kz_json:object() | 'timeout'}).
-spec handle_record_dtmf(kapps_call:call(), pos_integer(), kz_term:ne_binaries(), kz_json:object(), record_dtmf_loopfun()) ->
          {'ok', kapps_call:call()} |
          {'error', kz_json:object() | 'timeout'}.
handle_record_dtmf(Call, Timeout, [], JObj, LoopFun) ->
    LoopFun(Call, Timeout, JObj);
handle_record_dtmf(Call, Timeout, Terminators, JObj, LoopFun) ->
    case kz_call_event:dtmf_digit(JObj) of
        'undefined' ->
            LoopFun(Call, Timeout, Terminators);
        DTMF ->
            case lists:member(DTMF, Terminators) of
                'true' ->
                    lager:debug("recveived record stop DTMF, stopping record and waiting 60000 ms for RECORD_STOP"),
                    LoopFun(kapps_call:stop_recording(Call), 60 * ?MILLISECONDS_IN_SECOND, []);
                'false' ->
                    LoopFun(Call, Timeout, Terminators)
            end
    end.

-spec recording_length(kz_json:object()) -> integer().
recording_length(JObj) ->
    case kz_call_event:recording_length(JObj) of
        'undefined' -> 0;
        Length -> kz_time:milliseconds_to_seconds(Length)
    end.

-spec decr_loop_counter(timeout()) -> timeout().
decr_loop_counter('infinity') -> 'infinity';
decr_loop_counter(N) when is_integer(N), N > 0 -> N-1;
decr_loop_counter(_) -> 0.

-spec wait_for_noop(kapps_call:call(), kz_term:ne_binary()) ->
          {'ok', kapps_call:call()} |
          {'error', noop_error(), kapps_call:call()}.
wait_for_noop(Call, NoopId) ->
    case kapps_call_command:receive_event(?DEFAULT_EVENT_WAIT) of
        {'ok', JObj} ->
            process_noop_event(Call, NoopId, JObj);
        {'error', 'timeout'} ->
            case kapps_call_command:b_channel_status(Call) of
                {'ok', _} -> wait_for_noop(Call, NoopId);
                {'error', E} -> {'error', E, Call}
            end
    end.

-type noop_error() :: 'channel_destroy' | 'channel_hungup'.
-spec process_noop_event(kapps_call:call(), kz_term:ne_binary(), kz_json:object()) ->
          {'ok', kapps_call:call()} |
          {'error', noop_error(), kapps_call:call()}.
process_noop_event(Call, NoopId, JObj) ->
    case kz_api:event_type(JObj) of
        {<<"call_event">>, <<"CHANNEL_DESTROY">>} ->
            {'error', 'channel_destroy', Call};
        {<<"call_event">>, <<"DTMF">>} ->
            DTMF = kz_call_event:dtmf_digit(JObj),
            lager:info("adding dtmf tone '~s' to collection", [DTMF]),
            wait_for_noop(kzt_util:add_digit_collected(DTMF, Call), NoopId);
        {<<"call_event">>, <<"CHANNEL_EXECUTE_COMPLETE">>} ->
            case kz_call_event:application_response(JObj) of
                NoopId -> {'ok', Call};
                _ -> wait_for_noop(Call, NoopId)
            end;
        {_, _} ->
            wait_for_noop(Call, NoopId)
    end.

-spec wait_for_offnet(kapps_call:call(), kz_term:proplist(), dial_type()) ->
          {'ok', kapps_call:call()}.
wait_for_offnet(Call, DialProps, DialType) ->
    HangupDTMF = kzt_util:get_hangup_dtmf(Call),
    RecordCall = kzt_util:get_record_call(Call),

    CollectDTMF = props:get_is_true('collect_dtmf', DialProps, 'false'),

    CallTimeLimit = kzt_util:get_call_time_limit(Call) * ?MILLISECONDS_IN_SECOND,
    CallTimeout = kzt_util:get_call_timeout(Call) * ?MILLISECONDS_IN_SECOND,

    lager:debug("waiting for offnet with call timeLimit: ~bs and answer timeout: ~bs"
               ,[kzt_util:get_call_time_limit(Call)
                ,kzt_util:get_call_timeout(Call)
                ]),

    Updates = [fun kzt_util:clear_digits_collected/1
              ,{fun kzt_util:update_call_status/2, ?STATUS_RINGING}
              ,{fun kzt_util:set_dial_call_status/2, ?STATUS_RINGING}
              ],

    wait_for_offnet_events(#dial_req{call=kapps_call:exec(Updates, Call)
                                    ,hangup_dtmf=HangupDTMF
                                    ,collect_dtmf=CollectDTMF
                                    ,record_call=RecordCall
                                    ,call_timeout=CallTimeout
                                    ,call_time_limit=CallTimeLimit
                                    ,start=kz_time:start_time()
                                    ,dial_type=DialType
                                    }).

-spec wait_for_hangup(kapps_call:call()) -> {'ok', kapps_call:call()}.
wait_for_hangup(Call) ->
    case kapps_call_command:receive_event(?DEFAULT_EVENT_WAIT) of
        {'ok', JObj} ->
            case kz_api:event_type(JObj) of
                { <<"resource">>, <<"offnet_resp">> } ->
                    RespMsg = kz_call_event:response_message(JObj),
                    RespCode = kz_call_event:response_code(JObj),
                    lager:info("offnet resp finished: ~s(~s)", [RespCode, RespMsg]),
                    {'ok', kzt_util:update_call_status(call_status(RespMsg), Call)};
                {<<"call_event">>,<<"CHANNEL_DESTROY">>} ->
                    lager:debug("channel was destroyed"),
                    {'ok', kzt_util:update_call_status(call_status(kz_json:get_value(<<"Hangup-Cause">>, JObj)), Call)};
                _Type -> wait_for_hangup(Call)
            end;
        {'error', 'timeout'} ->
            lager:debug("timeout waiting for hangup...seems peculiar"),
            {'ok', kzt_util:update_call_status(?STATUS_COMPLETED, Call)}
    end.

-spec wait_for_conference(kapps_call:call()) -> {'ok', kapps_call:call()}.
wait_for_conference(Call) ->
    HangupDTMF = kzt_util:get_hangup_dtmf(Call),
    RecordCall = kzt_util:get_record_call(Call),

    CallTimeLimit = kzt_util:get_call_time_limit(Call) * ?MILLISECONDS_IN_SECOND,
    CallTimeout = kzt_util:get_call_timeout(Call) * ?MILLISECONDS_IN_SECOND,

    lager:debug("waiting for conference with call timeLimit: ~bs and answer timeout: ~bs"
               ,[kzt_util:get_call_time_limit(Call)
                ,kzt_util:get_call_timeout(Call)
                ]),
    Updates = [fun kzt_util:clear_digits_collected/1
              ,{fun kzt_util:update_call_status/2, ?STATUS_RINGING}
              ,{fun kzt_util:set_dial_call_status/2, ?STATUS_RINGING}
              ],

    wait_for_conference_events(#dial_req{call=kapps_call:exec(Updates, Call)
                                        ,hangup_dtmf=HangupDTMF
                                        ,collect_dtmf='true'
                                        ,record_call=RecordCall
                                        ,call_timeout=CallTimeout
                                        ,call_time_limit=CallTimeLimit
                                        ,start=kz_time:start_time()
                                        ,dial_type='conference'
                                        }).

-spec call_status(kz_term:ne_binary()) -> kz_term:ne_binary().
call_status(<<"ORIGINATOR_CANCEL">>) -> ?STATUS_CANCELED;
call_status(<<"NORMAL_CLEARING">>) -> ?STATUS_COMPLETED;
call_status(<<"SUCCESS">>) -> ?STATUS_COMPLETED;
call_status(<<"NO_ANSWER">>) -> ?STATUS_NOANSWER;
call_status(<<"USER_BUSY">>) -> ?STATUS_BUSY;
call_status(<<"CALL_REJECTED">>) -> ?STATUS_BUSY;
call_status(_Status) ->
    lager:debug("unhandled call status: ~p", [_Status]),
    ?STATUS_FAILED.

-spec conference_call_status(kz_term:ne_binary()) -> kz_term:ne_binary().
conference_call_status(<<"NORMAL_CLEARING">>) -> ?STATUS_ANSWERED;
conference_call_status(<<"SUCCESS">>) -> ?STATUS_ANSWERED;
conference_call_status(Status) -> call_status(Status).

-spec wait_for_offnet_events(dial_req()) -> {'ok', kapps_call:call()}.
wait_for_offnet_events(#dial_req{call_timeout=CallTimeout
                                ,call_time_limit=CallTimeLimit
                                }=OffnetReq) ->
    RecvTimeout = which_timeout(CallTimeout, CallTimeLimit),
    case kapps_call_command:receive_event(RecvTimeout) of
        {'ok', JObj} -> process_offnet_event(OffnetReq, JObj);
        {'error', 'timeout'} -> handle_offnet_timeout(OffnetReq)
    end.

-spec process_offnet_event(dial_req(), kz_json:object()) ->
          {'ok', kapps_call:call()}.

process_offnet_event(#dial_req{call=Call
                              ,dial_type=DialType
                              }=OffnetReq0
                    ,JObj) ->
    OffnetReq = update_offnet_timers(OffnetReq0),
    CallId = kapps_call:call_id(Call),
    case {kz_api:event_type(JObj), kz_call_event:call_id(JObj)} of
        {{<<"resource">>, <<"offnet_resp">>}, _} ->
            handle_resource_offnet_resp(OffnetReq0, JObj);

        {{<<"call_event">>, <<"DTMF">>}, CallId} ->
            case handle_offnet_dtmf_event(OffnetReq, JObj, ?STATUS_ANSWERED) of
                {'hangup', Call1} ->
                    OffnetReq2 = OffnetReq0#dial_req{call=Call1
                                                    ,has_caller_hungup='true'
                                                    },
                    maybe_wait_for_offnet_record_stop(OffnetReq2);
                {'loop', OffnetReq1} ->
                    wait_for_offnet_events(OffnetReq1)
            end;

        {{<<"call_event">>, <<"CHANNEL_BRIDGE">>}, CallId} ->
            OtherLegId = kz_call_event:other_leg_call_id(JObj),
            lager:debug("caller bridged to ~s", [OtherLegId]),
            Updates = [{fun kzt_util:set_dial_call_sid/2, OtherLegId}
                      ,{fun kapps_call:set_other_leg_call_id/2, OtherLegId}
                      ],
            Call1 = kapps_call:exec(Updates, Call),
            wait_for_offnet_events(OffnetReq#dial_req{call_b_leg=OtherLegId, call=Call1});

        {{<<"call_event">>, <<"CHANNEL_EXECUTE_COMPLETE">>}, CallId} ->
            case {kz_call_event:application_name(JObj), DialType} of
                {<<"bridge">>, 'offnet'} ->
                    lager:debug("offnet bridge execution completed: ~s, waiting for offnet_resp...", [kz_call_event:application_response(JObj)]),
                    wait_for_offnet_events(update_offnet_timers(OffnetReq));
                {<<"bridge">>, 'bridge'} ->
                    lager:debug("bridge execution completed: ~s", [kz_call_event:application_response(JObj)]),
                    Call1 = handle_called_party_ended(Call, call_status(kz_call_event:application_response(JObj))),
                    maybe_stop_offnet_recording(OffnetReq#dial_req{call=Call1});
                _ ->
                    wait_for_offnet_events(update_offnet_timers(OffnetReq))
            end;

        {{<<"call_event">>, <<"CHANNEL_DESTROY">>}, CallId} ->
            HangupCause = kz_call_event:hangup_cause(JObj),
            lager:debug("caller channel finished: ~s", [HangupCause]),
            maybe_wait_for_offnet_record_stop(
              OffnetReq#dial_req{call=handle_hangup(Call, call_status(HangupCause))
                                ,has_caller_hungup='true'
                                }
             );

        {{<<"call_event">>, <<"CHANNEL_ANSWER">>}, CallId} ->
            lager:debug("channel answered"),
            Updates = [{fun kzt_util:update_call_status/2, ?STATUS_IN_PROGRESS}
                      ,{fun kzt_util:set_dial_call_status/2, ?STATUS_COMPLETED}
                      ],
            wait_for_offnet_events(OffnetReq#dial_req{call=kapps_call:exec(Updates, Call)
                                                     ,call_timeout='undefined'
                                                     });

        {{<<"call_event">>, <<"RECORD_START">>}, CallId} ->
            lager:debug("offnet call recording started"),
            wait_for_offnet_events(update_offnet_timers(OffnetReq));

        {{<<"call_event">>, <<"RECORD_STOP">>}, CallId} ->
            lager:debug("offnet call recording stopped"),
            {'ok', Call1} = record_finished(Call, JObj),
            OffnetReq1 = update_offnet_timers(OffnetReq),
            wait_for_offnet_events(OffnetReq1#dial_req{call=Call1, record_call='false'});

        {{_Cat, _Name}, _CallId}=_Other ->
            wait_for_offnet_events(update_offnet_timers(OffnetReq))
    end.

-spec maybe_wait_for_offnet_record_stop(dial_req()) -> {'ok', kapps_call:call()}.
maybe_wait_for_offnet_record_stop(#dial_req{record_call='true'}=OffnetReq) ->
    lager:debug("dial was recording, waiting 60000 ms for RECORD_STOP"),
    wait_for_offnet_record_stop(OffnetReq, 60 * ?MILLISECONDS_IN_SECOND);
maybe_wait_for_offnet_record_stop(#dial_req{call=Call}) ->
    {'ok', Call}.

maybe_stop_offnet_recording(#dial_req{record_call='true', call=Call}=OffnetReq) ->
    lager:debug("offnet dial is ended, stop recording and wait 60000 ms for RECORD_STOP"),
    Call1 = kapps_call:stop_recording(Call),
    wait_for_offnet_record_stop(OffnetReq#dial_req{call=Call1}, 60 * ?MILLISECONDS_IN_SECOND);
maybe_stop_offnet_recording(#dial_req{call=Call}) ->
    {'ok', Call}.

-spec wait_for_offnet_record_stop(dial_req(), pos_integer()) ->
          {'ok', kapps_call:call()}.
wait_for_offnet_record_stop(#dial_req{call=Call}=OffnetReq, Timeout) ->
    Start = kz_time:start_time(),
    case kapps_call_command:receive_event(Timeout) of
        {'ok', JObj} ->
            case kapps_call_command:get_event_type(JObj) of
                {<<"call_event">>, <<"RECORD_STOP">>, <<"record">>} ->
                    record_finished(Call, JObj);
                _ ->
                    wait_for_offnet_record_stop(OffnetReq, kz_time:decr_timeout(Timeout, Start))
            end;
        {'error', 'timeout'} ->
            lager:debug("timeout waiting for offnet RECORD_STOP event"),
            {'ok', Call}
    end.

-spec handle_resource_offnet_resp(dial_req(), kz_json:object()) -> {'ok', kapps_call:call()}.
handle_resource_offnet_resp(#dial_req{call=Call}=OffnetReq, JObj) ->
    CallId = kapps_call:call_id(Call),
    RespMsg = kz_call_event:response_message(JObj),
    RespCode = kz_call_event:response_code(JObj),
    ErrorMsg = kz_call_event:error_message(JObj),

    lager:debug("offnet resp: ~s(~s) (error: ~s)", [RespMsg, RespCode, ErrorMsg]),

    Updates = [{fun kzt_util:update_call_status/2, call_status(RespMsg)}
              ,{fun kzt_util:set_dial_call_status/2, offnet_dial_status(call_status(RespMsg))}
              ],
    Call1 = kapps_call:exec(Updates, Call),

    ResourceResp = kz_json:get_json_value(<<"Resource-Response">>, JObj, kz_json:new()),
    HangupCause = kz_call_event:hangup_cause(ResourceResp),
    OffnetReqHangup = OffnetReq#dial_req{has_caller_hungup='true'
                                        ,call=kzt_util:set_is_caller_hungup('true', Call1)
                                        },
    case {kz_api:event_type(ResourceResp), kz_call_event:call_id(ResourceResp)} of
        {{<<"call_event">>, <<"CHANNEL_DESTROY">>}, CallId} ->
            lager:debug("caller hungup during offnet bridge: ~s", [HangupCause]),
            maybe_wait_for_offnet_record_stop(OffnetReqHangup);
        {{<<"call_event">>, <<"CHANNEL_EXECUTE_COMPLETE">>}, CallId} ->
            case kz_call_event:channel_state(ResourceResp) of
                <<"HANGUP">> ->
                    lager:debug("caller hungup during offnet bridge: ~s", [HangupCause]),
                    maybe_wait_for_offnet_record_stop(OffnetReqHangup);
                _Other ->
                    maybe_stop_offnet_recording(OffnetReq#dial_req{call=Call1})
            end;
        _Other ->
            %% unabled to bridge DID number
            %% or other part ended the bridge
            %% or other reasons
            maybe_stop_offnet_recording(OffnetReq#dial_req{call=Call1})
    end.

-spec handle_offnet_dtmf_event(dial_req(), kz_json:object(), kz_term:ne_binary()) ->
          {'hangup', kapps_call:call()} |
          {'loop', dial_req()}.
handle_offnet_dtmf_event(#dial_req{call=Call
                                  ,hangup_dtmf=HangupDTMF
                                  ,collect_dtmf=CollectDTMF
                                  }=DialReq
                        ,JObj
                        ,DialCallStatus
                        ) ->
    case kz_call_event:dtmf_digit(JObj) of
        HangupDTMF ->
            lager:info("recv'd hangup DTMF '~s'", [HangupDTMF]),
            kapps_call_command:hangup(Call),
            Updates = [{fun kzt_util:update_call_status/2, ?STATUS_COMPLETED}
                      ,{fun kzt_util:set_dial_call_status/2, DialCallStatus}
                      ,{fun kzt_util:set_is_caller_hungup/2, 'true'}
                      ],

            {'hangup', kapps_call:exec(Updates, Call)};
        DTMF when CollectDTMF ->
            lager:info("collecting dtmf ~s", [DTMF]),
            {'loop', update_offnet_timers(
                       DialReq#dial_req{call=kzt_util:add_digit_collected(DTMF, Call)}
                      )};
        _DTMF ->
            lager:info("caller pressed dtmf tone but we're not collecting it"),
            {'loop', update_offnet_timers(DialReq)}
    end.

-spec handle_hangup(kapps_call:call(), kz_term:ne_binary()) -> kapps_call:call().
handle_hangup(Call, Status) ->
    Updates = [{fun kzt_util:update_call_status/2, Status}
              ,{fun kzt_util:set_dial_call_status/2, offnet_dial_status(Status)}
              ,{fun kzt_util:set_is_caller_hungup/2, 'true'}
              ],

    kapps_call:exec(Updates, Call).

-spec handle_called_party_ended(kapps_call:call(), kz_term:ne_binary()) -> kapps_call:call().
handle_called_party_ended(Call, Status) ->
    handle_called_party_ended(Call, Status, ?STATUS_COMPLETED).

-spec handle_called_party_ended(kapps_call:call(), kz_term:ne_binary(), kz_term:ne_binary()) -> kapps_call:call().
handle_called_party_ended(Call, Status, DialCallStatus) ->
    Updates = [{fun kzt_util:update_call_status/2, Status}
              ,{fun kzt_util:set_dial_call_status/2, DialCallStatus}
              ],
    kapps_call:exec(Updates, Call).

-spec maybe_hangup_other_leg(kapps_call:call()) -> 'ok'.
maybe_hangup_other_leg(Call) ->
    maybe_hangup_other_leg(Call, kapps_call:other_leg_call_id(Call)).

-spec maybe_hangup_other_leg(kapps_call:call(), kz_term:api_binary()) -> 'ok'.
maybe_hangup_other_leg(_Call, 'undefined') -> 'ok';
maybe_hangup_other_leg(Call, OtherLeg) ->
    lager:debug("sending hangup to other leg ~s", [OtherLeg]),

    Req = [{<<"Application-Name">>, <<"hangup">>}
          ,{<<"Insert-At">>, <<"now">>}
          ,{<<"Call-ID">>, OtherLeg}
          ],
    kapps_call_command:send_command(Req, Call).

-spec offnet_dial_status(kz_term:ne_binary()) -> kz_term:ne_binary().
offnet_dial_status(?STATUS_RINGING) -> ?STATUS_NOANSWER;
offnet_dial_status(?STATUS_IN_PROGRESS) -> ?STATUS_COMPLETED;
offnet_dial_status(?STATUS_QUEUED) -> ?STATUS_COMPLETED;
offnet_dial_status(CallStatus) -> CallStatus.

-spec wait_for_conference_events(dial_req()) -> {'ok', kapps_call:call()}.
wait_for_conference_events(#dial_req{call_timeout=CallTimeout
                                    ,call_time_limit=CallTimeLimit
                                    }=OffnetReq) ->
    RecvTimeout = which_timeout(CallTimeout, CallTimeLimit),

    case kapps_call_command:receive_event(RecvTimeout) of
        {'ok', JObj} -> process_conference_event(OffnetReq, JObj);
        {'error', 'timeout'} -> handle_conference_timeout(OffnetReq)
    end.

process_conference_event(#dial_req{call=Call}=OffnetReq, JObj) ->
    case kz_api:event_type(JObj) of
        {<<"call_event">>, <<"DTMF">>} ->
            case handle_offnet_dtmf_event(OffnetReq, JObj, ?STATUS_COMPLETED) of
                {'hangup', Call1} ->
                    {'ok', Call1};
                {'loop', OffnetReq1} ->
                    wait_for_conference_events(OffnetReq1)
            end;

        {<<"call_event">>, <<"CHANNEL_EXECUTE">>} ->
            case kz_call_event:application_name(JObj) of
                <<"conference">> ->
                    lager:info("conferencing has started to execute"),
                    wait_for_conference_events(
                      update_offnet_timers(
                        OffnetReq#dial_req{call_timeout='undefined'}
                       )
                     );
                _App ->
                    lager:debug("ignoring app ~s", [_App]),
                    wait_for_conference_events(update_offnet_timers(OffnetReq))
            end;

        {<<"call_event">>, <<"CHANNEL_EXECUTE_COMPLETE">>} ->
            case kz_call_event:application_name(JObj) of
                <<"conference">> ->
                    lager:info("conferencing has ended"),
                    kapps_call_command:park(Call),
                    {'ok', handle_called_party_ended(Call, ?STATUS_COMPLETED, ?STATUS_ANSWERED)};
                _App ->
                    lager:debug("app ~s has ended", [_App]),
                    wait_for_conference_events(update_offnet_timers(OffnetReq))
            end;

        {<<"call_event">>, <<"CHANNEL_DESTROY">>} ->
            lager:info("our call has ended"),
            {'ok', handle_hangup(Call, conference_call_status(kz_call_event:hangup_cause(JObj)))};

        {<<"conference">>, <<"event">>} ->
            case kz_json:get_ne_binary_value(<<"Event">>, JObj) of
                <<"conference-create">> ->
                    lager:info("conference has been created"),
                    wait_for_conference_events(
                      update_offnet_timers(
                        OffnetReq#dial_req{call_timeout='undefined'}
                       )
                     );
                <<"conference-destroy">> ->
                    lager:info("conference has been destroyed"),
                    kapps_call_command:park(Call),
                    {'ok', handle_called_party_ended(Call, ?STATUS_COMPLETED, ?STATUS_ANSWERED)};
                <<"add-member">> ->
                    case kz_api:call_id(JObj) =:= kapps_call:call_id_direct(Call) of
                        'true' ->
                            lager:info("call added as member of the conference"),
                            wait_for_conference_events(
                              update_offnet_timers(
                                OffnetReq#dial_req{call_timeout='undefined'}
                               )
                             );
                        'false' ->
                            lager:debug("member event not for us, skipping"),
                            wait_for_conference_events(update_offnet_timers(OffnetReq))
                    end;
                _Event ->
                    lager:debug("ignoring conference event ~s", [_Event]),
                    wait_for_conference_events(update_offnet_timers(OffnetReq))
            end;
        {_Cat, _Name} ->
            lager:debug("unhandled event for ~s: ~s: ~s"
                       ,[_Cat, _Name, kz_call_event:application_name(JObj)]
                       ),
            wait_for_conference_events(update_offnet_timers(OffnetReq))
    end.

-spec recording_meta(kapps_call:call(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
recording_meta(Call, MediaName) ->
    AccountDb = kapps_call:account_db(Call),
    BaseDoc = kz_json:from_list([{<<"name">>, MediaName}
                                ,{<<"description">>, <<"recording ", MediaName/binary>>}
                                ,{<<"content_type">>, <<"audio/mp3">>}
                                ,{<<"media_source">>, <<"recorded">>}
                                ,{<<"source_type">>, kz_term:to_binary(?MODULE)}
                                ,{<<"pvt_type">>, <<"private_media">>}
                                ,{<<"from">>, kapps_call:from(Call)}
                                ,{<<"to">>, kapps_call:to(Call)}
                                ,{<<"caller_id_number">>, kapps_call:caller_id_number(Call)}
                                ,{<<"caller_id_name">>, kapps_call:caller_id_name(Call)}
                                ,{<<"call_id">>, kapps_call:call_id(Call)}
                                ]),
    MediaDoc = kz_doc:update_pvt_parameters(BaseDoc, AccountDb),
    kz_datamgr:save_doc(AccountDb, MediaDoc).

-spec handle_offnet_timeout(dial_req()) -> {'ok', kapps_call:call()}.
handle_offnet_timeout(#dial_req{call=Call
                               ,call_timeout='undefined'
                               }) ->
    lager:debug("call timeLimit exceeded, hanging up the called party"),
    maybe_hangup_other_leg(Call),
    Updates = [{fun kzt_util:update_call_status/2, ?STATUS_COMPLETED}
              ,{fun kzt_util:set_dial_call_status/2, ?STATUS_COMPLETED}
              ],
    {'ok', kapps_call:exec(Updates, Call)};
handle_offnet_timeout(#dial_req{call=Call}) ->
    lager:debug("timed out waiting for call to be answered by endpoint(s)"),
    Updates = [{fun kzt_util:update_call_status/2, ?STATUS_COMPLETED}
              ,{fun kzt_util:set_dial_call_status/2, ?STATUS_COMPLETED}
              ],
    {'ok', kapps_call:exec(Updates, Call)}.

-spec handle_conference_timeout(dial_req()) -> {'ok', kapps_call:call()}.
handle_conference_timeout(#dial_req{call=Call
                                   ,call_timeout='undefined'
                                   }) ->
    lager:debug("time timeLimit for conference exceeded, exiting conference"),
    kapps_call_command:park(Call),
    Updates = [{fun kzt_util:update_call_status/2, ?STATUS_COMPLETED}
              ,{fun kzt_util:set_dial_call_status/2, ?STATUS_ANSWERED}
              ],
    {'ok', kapps_call:exec(Updates, Call)};
handle_conference_timeout(#dial_req{call=Call}) ->
    lager:debug("timed out waiting for call to be answered by the conference"),
    Updates = [{fun kzt_util:update_call_status/2, ?STATUS_COMPLETED}
              ,{fun kzt_util:set_dial_call_status/2, ?STATUS_ANSWERED}
              ],
    {'ok', kapps_call:exec(Updates, Call)}.

-spec which_timeout(kz_term:api_integer(), pos_integer()) -> non_neg_integer().
which_timeout('undefined', Timelimit)
  when is_integer(Timelimit), Timelimit > 0 ->
    Timelimit;
which_timeout(Timeout, _)
  when is_integer(Timeout), Timeout > 0 ->
    Timeout;
which_timeout(_, _) -> 0.

-spec update_offnet_timers(dial_req()) -> dial_req().
update_offnet_timers(#dial_req{call_timeout='infinity'}=OffnetReq) ->
    OffnetReq;
update_offnet_timers(#dial_req{call_time_limit='undefined'
                              ,call_timeout='undefined'
                              }=OffnetReq
                    ) ->
    OffnetReq;
update_offnet_timers(#dial_req{call_timeout='undefined'
                              ,call_time_limit='infinity'
                              }=OffnetReq
                    ) ->
    OffnetReq;
update_offnet_timers(#dial_req{call_timeout='undefined'
                              ,call_time_limit=CallTimeLimit
                              ,start=Start
                              }=OffnetReq
                    ) ->
    Left = kz_time:decr_timeout(CallTimeLimit, Start),
    OffnetReq#dial_req{call_time_limit=Left
                      ,start=kz_time:start_time()
                      };
update_offnet_timers(#dial_req{call_timeout=CallTimeout
                              ,start=Start
                              }=OffnetReq
                    ) ->
    Left = kz_time:decr_timeout(CallTimeout, Start),
    OffnetReq#dial_req{call_timeout=Left
                      ,start=kz_time:start_time()
                      }.
