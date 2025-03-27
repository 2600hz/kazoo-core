%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2024-2025, 2600Hz
%%% @doc Monitors processes for various conditions and logs loudly
%%%
%%% There was an EEP that went nowhere: https://www.erlang.org/eeps/eep-0042
%%%   `max_heap_size' was implemented as a process flag, but not max
%%%   `message_queue_len'
%%%
%%% Blog article: https://www.erlang.org/blog/parallel-signal-sending-optimization/
%%    Talks about how setting message_queue_data to off_heap can improve perf for
%%%   receiving processes that have many senders.
%%%
%%%   FTA: Therefore, {message_queue_data, off_heap} provides much
%%%   better scalability than {message_queue_data, on_heap} when
%%%   multiple processes send signals to the same process concurrently
%%%   on a multicore system.
%%%
%%%   It seems, then, that any receiver with many parallel senders
%%%   should use off_heap. Adding a properly tracer process that
%%%   tracks from/to sending could prove useful in determining which
%%%   processes should use off_heap.
%%%
%%% Discussion: https://erlangforums.com/t/message-queue-data-off-heap-use-case/1119/9
%%%   Probably affects gen_listener that back up
%%%   Related PR: https://github.com/erlang/otp/pull/5768
%%%   Note: do not oscillate between on_heap/off_heap (switching is expensive
%%%   for large message queues)
%%%
%%% Discussion: https://github.com/erlang/otp/issues/5481#issuecomment-986081522
%%%   "If a process have the potential to build up a large message queue, you
%%%   typically always want to use the `off_heap' message queue data setting for
%%%   this reason."
%%%
%%% Blog: https://www.erlang.org/blog/message-passing/#sending-messages:~:text=By%20default%2C%20messages,further%20reduces%20latency
%%%   With off_heap, "GC doesn't need to consider unmatched messages which
%%%   further reduces latency."
%%%
%%% Check out erlang:system_monitor/2 to add system monitoring and
%%% send messages to this proc
%%%   TODO: after OTP 27, use `{long_message_queue, {Disable, Enable}}'
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @author James Aimonetti
%%% @author Daniel Finke <danielfinke2011@gmail.com>
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_monitor).
-behaviour(gen_server).

-export([start_link/0
        ,track_me/0, track_me/1
        ,track_pid/1, track_pid/2
        ,track_pids/1, track_pids/2
        ,tracked_pids/0, pp_tracked_pids/0
        ,set_thresholds/1, set_thresholds/2
        ]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-export_type([proc_thresholds/0]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(SERVER, ?MODULE).

-record(proc_info, {pid :: kz_term:api_pid()
                   ,monitor_ref :: reference()
                   ,tstamp = kz_time:now_ms() :: pos_integer()
                   ,gc_time = 0 :: time_ms()
                   ,total_heap_size :: size_words()
                   ,has_long_message_queue :: boolean()
                   ,message_queue_len :: message_queue_len()
                   ,thresholds :: proc_thresholds()
                   }).
-type proc_info() :: #proc_info{}.

-type state() :: #{pid() := proc_info()
                  ,'timer_ref' := reference()
                  }.

-type time_ms() :: non_neg_integer().
-type size_words() :: non_neg_integer().
-type message_queue_len() :: non_neg_integer().

%% Per-proc custom thresholds
-type proc_thresholds() :: #{'long_gc' => time_ms()
                            ,'large_heap' => size_words()
                            ,'long_message_queue_low' => message_queue_len()
                            ,'long_message_queue_high' => message_queue_len()
                            }.

-type system_monitor_msg() :: {'long_gc', long_gc_info()} |
                              {'large_heap', gc_info()}.
-type gc_info() :: [gc_info_item()].
-type gc_info_item() :: {gc_info_key(), size_words()}.
-type gc_info_key() :: 'heap_size' | 'heap_block_size' | 'stack_size' | 'mbuf_size' | 'old_heap_size' | 'old_heap_block_size'.
-type long_gc_info() :: [long_gc_info_item()].
-type long_gc_info_item() :: gc_info_item() | {'timeout', time_ms()}.

-define(CHECK_MQ_LEN_TIME_MS, ?MILLISECONDS_IN_SECOND).
-define(CHECK_MQ_LEN_MSG, 'check_mailboxes').
-define(THROTTLE_MIN_MS, 500). %% Don't exceed `?CHECK_MQ_LEN_TIME_MS' - no sys mon logging occurs
-define(LONG_GC_TIME_MS, 200).
-define(LONG_MQ_THRESHOLD_LOW, 20).
-define(LONG_MQ_THRESHOLD_HIGH, 100).
-define(LARGE_HEAP_SIZE_WORDS, 65536). %% Internal unspecified minimum, lower values adjusted up to this

-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?SERVER}, ?MODULE, [], []).

%% @doc Start tracking metrics for a process
-spec track_me() -> 'ok'.
track_me() ->
    track_pid(self()).

-spec track_me(proc_thresholds()) -> 'ok'.
track_me(Thresholds) ->
    track_pid(self(), Thresholds).

-spec track_pid(pid()) -> 'ok'.
track_pid(Pid) when is_pid(Pid) ->
    track_pids([Pid]).

-spec track_pid(pid(), proc_thresholds()) -> 'ok'.
track_pid(Pid, Thresholds) when is_pid(Pid) ->
    track_pids([{Pid, Thresholds}]).

-spec track_pids(kz_term:pids() | kz_term:proplist_kv(pid(), proc_thresholds())) -> 'ok'.
track_pids(Pids) when is_list(Pids) ->
    gen_server:cast(?SERVER, {'track', Pids}).

-spec track_pids(kz_term:pids(), proc_thresholds()) -> 'ok'.
track_pids(Pids, Thresholds) when is_list(Pids) ->
    track_pids([{Pid, Thresholds} || Pid <- Pids]).

-spec tracked_pids() -> [proc_info()].
tracked_pids() ->
    gen_server:call(?SERVER, 'tracked_pids').

-spec pp_tracked_pids() -> 'ok'.
pp_tracked_pids() ->
    Tracked = tracked_pids(),
    pp_tracked_pids(Tracked).

pp_tracked_pids([]) -> 'ok';
pp_tracked_pids(Tracked) ->
    Sorted = lists:keysort(#proc_info.message_queue_len, Tracked),

    Header = [<<"PID">>, <<"MsgQueue Length">>, <<"Total Heap">>, <<"Snapshot At">>],
    Rows = [[kz_term:to_binary(Pid)
            ,MQLen
            ,kz_term:pretty_print_bytes(Heap, 'truncated')
            ,kz_time:pretty_print_datetime(TStamp div 1000)
            ]
            || #proc_info{pid=Pid
                         ,tstamp=TStamp
                         ,message_queue_len=MQLen
                         ,total_heap_size=Heap
                         } <- Sorted
           ],
    kz_log:print_table([Header | Rows], #{header_divider => $=}).

-spec set_thresholds(proc_thresholds()) -> 'ok'.
set_thresholds(Thresholds) ->
    set_thresholds(self(), Thresholds).

-spec set_thresholds(pid(), proc_thresholds()) -> 'ok'.
set_thresholds(Pid, Thresholds) ->
    gen_server:cast(?SERVER, {'set_thresholds', Pid, Thresholds}).

-spec init(any()) -> {'ok', state()}.
init(_) ->
    lager:info("starting kz_monitor"),
    _ = kz_process:set_startup(),
    _ = erlang:system_monitor(self(), [{'long_gc', ?LONG_GC_TIME_MS}
                                      ,{'large_heap', ?LARGE_HEAP_SIZE_WORDS}
                                      ]),
    {'ok', #{'timer_ref' => start_check_timer()}}.

-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call('tracked_pids', _From, State) ->
    Tracking = maps:fold(fun tracked_pid_info/3, [], State),
    {'reply', Tracking, State};
handle_call(_Call, _From, State) ->
    {'noreply', State}.

tracked_pid_info(Pid, #proc_info{}=Info, Acc) when is_pid(Pid) ->
    [Info#proc_info{pid=Pid} | Acc];
tracked_pid_info(_, _, Acc) -> Acc.

-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'track', Pids}, State) ->
    NewState = lists:foldl(fun do_track_pid/2, State, Pids),
    {'noreply', NewState};
handle_cast({'set_thresholds', Pid, Thresholds}, State) ->
    case State of
        #{Pid := #proc_info{}=Info} ->
            {'noreply', State#{Pid => Info#proc_info{thresholds=Thresholds}}};
        #{} -> {'noreply', State}
    end;
handle_cast(_Cast, State) ->
    {'noreply', State}.

-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info({'DOWN', _Ref, 'process', Pid, _Reason}, State) ->
    case maps:take(Pid, State) of
        'error' -> {'noreply', State};
        {_ProcInfo, NewState} ->
            lager:info("pid ~p down: ~p", [Pid, _Reason]),
            {'noreply', NewState}
    end;
handle_info({'monitor', Pid, Event, Info}, State) ->
    State1 = handle_system_monitor_msg(Pid, {Event, Info}, State),
    {'noreply', State1};
handle_info({'timeout', TimerRef, ?CHECK_MQ_LEN_MSG}, #{'timer_ref' := TimerRef}=State) ->
    NewState = update_tracked_pids(State),
    {'noreply', NewState#{'timer_ref' => start_check_timer()}};
handle_info(_Msg, State) ->
    lager:debug("unhandled ~p", [_Msg]),
    {'noreply', State}.

-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:info("terminating monitoring: ~p", [_Reason]).

-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Start tracking the message queue length and heap size of `Pid'. Will
%% warn if thresholds are exceeded as of the start of tracking.
%% @end
%%------------------------------------------------------------------------------
-spec do_track_pid(pid() | {pid(), proc_thresholds()}, state()) -> state().
do_track_pid(Pid, State) when is_pid(Pid) ->
    do_track_pid({Pid, #{}}, State);
do_track_pid({Pid, Thresholds}, State) ->
    case State of
        #{Pid := _} -> State;
        #{} -> track_pid_if_alive({Pid, Thresholds}, State)
    end.

-spec track_pid_if_alive({pid(), proc_thresholds()}, state()) -> state().
track_pid_if_alive({Pid, Thresholds}, State) ->
    %% It is possible for `Pid' to die before we get here, handle gracefully
    case process_info(Pid, ['total_heap_size', 'message_queue_len']) of
        'undefined' ->
            %% Process died too soon :(...
            State;
        [{'total_heap_size', TotalHeapSize}, {'message_queue_len', MQLen}] ->
            MonitorRef = erlang:monitor('process', Pid),
            HasLongMQ = has_long_message_queue('false', MQLen, Thresholds),

            maybe_warn_large_heap(Pid, TotalHeapSize, Thresholds, 'true'),
            maybe_log_long_message_queue(Pid, 'false', HasLongMQ, MQLen),

            State#{Pid => #proc_info{pid=Pid
                                    ,monitor_ref=MonitorRef
                                    ,total_heap_size=TotalHeapSize
                                    ,has_long_message_queue=HasLongMQ
                                    ,message_queue_len=MQLen
                                    ,thresholds=Thresholds
                                    }}
    end.

%%------------------------------------------------------------------------------
%% @doc Handle a system monitor message sent by ERTS. Handling is throttled per
%% PID.
%% @end
%%------------------------------------------------------------------------------
-spec handle_system_monitor_msg(pid(), system_monitor_msg(), state()) -> state().
handle_system_monitor_msg(Pid, Msg, State) ->
    case State of
        #{Pid := #proc_info{tstamp=TStamp}=Info} ->
            Now = kz_time:now_ms(),
            IsThrottled = TStamp + ?THROTTLE_MIN_MS > Now,
            {Info1, IsThrottled} = maybe_update_timestamp(Info, Now),
            State#{Pid => update_monitored_info(Pid, Msg, Info1, not IsThrottled)};
        #{} -> State
    end.

update_tracked_pids(State) ->
    maps:map(fun update_tracked_pid/2, State).

update_tracked_pid('timer_ref', TimerRef) -> TimerRef;
update_tracked_pid(Pid, #proc_info{has_long_message_queue=HasLongMQ
                                  ,thresholds=Thresholds
                                  }=Info
                  ) ->
    case process_info(Pid, 'message_queue_len') of
        'undefined' ->
            %% Process `DOWN' coming soon!
            Info;
        {'message_queue_len', MQLen} ->
            HasLongMQ1 = has_long_message_queue(HasLongMQ, MQLen, Thresholds),
            maybe_log_long_message_queue(Pid, HasLongMQ, HasLongMQ1, MQLen),
            Info#proc_info{tstamp=kz_time:now_ms()
                          ,has_long_message_queue=HasLongMQ1
                          ,message_queue_len=MQLen
                          }
    end.

%%------------------------------------------------------------------------------
%% @doc Update some monitored info for `Pid' as a result of a system monitor
%% message. Will warn if thresholds are exceeded.
%% @end
%%------------------------------------------------------------------------------
-spec update_monitored_info(pid(), system_monitor_msg(), proc_info(), boolean()) -> proc_info().
update_monitored_info(Pid, {'long_gc', MonInfo}, #proc_info{thresholds=Thresholds}=Info, ShouldWarn) ->
    GCTime = props:get_integer_value('timeout', MonInfo),
    TotalHeapSize = total_heap_size(MonInfo),
    maybe_warn_long_gc(Pid, GCTime, TotalHeapSize, Thresholds, ShouldWarn),
    Info#proc_info{gc_time=GCTime
                  ,total_heap_size=TotalHeapSize
                  };
update_monitored_info(Pid, {'large_heap', MonInfo}, #proc_info{thresholds=Thresholds}=Info, ShouldWarn) ->
    TotalHeapSize = total_heap_size(MonInfo),
    maybe_warn_large_heap(Pid, TotalHeapSize, Thresholds, ShouldWarn),
    Info#proc_info{total_heap_size=total_heap_size(MonInfo)}.

%%------------------------------------------------------------------------------
%% @doc Update the timestamp of the last recorded monitored info if past the
%% throttle time delta since the last recording.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_update_timestamp(proc_info(), time_ms()) -> {proc_info(), boolean()}.
maybe_update_timestamp(#proc_info{tstamp=TStamp}=Info, NowMs) when TStamp + ?THROTTLE_MIN_MS > NowMs ->
    {Info, 'true'};
maybe_update_timestamp(#proc_info{}=Info, NowMs) ->
    {Info#proc_info{tstamp=NowMs}, 'false'}.

-spec total_heap_size(long_gc_info()) -> size_words().
total_heap_size(Info) ->
    lists:sum([V || {K, V} <- Info, is_total_heap_size_summand(K)]).

%%------------------------------------------------------------------------------
%% @doc
%% See: [https://www.erlang.org/doc/apps/erts/erlang.html#process_flag_max_heap_size]
%% as reference for the calculation
%% @end
%%------------------------------------------------------------------------------
-spec is_total_heap_size_summand(gc_info_key() | 'timeout') -> boolean().
is_total_heap_size_summand('heap_block_size') -> 'true';
is_total_heap_size_summand('old_heap_block_size') -> 'true';
is_total_heap_size_summand('mbuf_size') -> 'true';
is_total_heap_size_summand(_K) -> 'false'.

-spec has_long_message_queue(boolean()
                            ,message_queue_len()
                            ,proc_thresholds() | {message_queue_len(), message_queue_len()}
                            ) -> boolean().
has_long_message_queue(PrevHasLongMQ, MQLen, Thresholds) when is_map(Thresholds) ->
    MQThresholds = {maps:get('long_message_queue_low', Thresholds, ?LONG_MQ_THRESHOLD_LOW)
                   ,maps:get('long_message_queue_high', Thresholds, ?LONG_MQ_THRESHOLD_HIGH)
                   },
    has_long_message_queue(PrevHasLongMQ, MQLen, MQThresholds);
has_long_message_queue('false', MQLen, {_, HighThreshold}) when MQLen >= HighThreshold -> 'true';
has_long_message_queue('true', MQLen, {LowThreshold, _}) when MQLen =< LowThreshold -> 'false';
has_long_message_queue(PrevHasLongMQ, _MQLen, _MQThresholds) -> PrevHasLongMQ.

-spec maybe_warn_long_gc(pid(), time_ms(), size_words(), proc_thresholds() | time_ms(), boolean()) -> 'ok'.
maybe_warn_long_gc(Pid, Time, TotalHeapSize, Thresholds, 'true') when is_map(Thresholds) ->
    TimeThreshold = maps:get('long_gc', Thresholds, ?LONG_GC_TIME_MS),
    maybe_warn_long_gc(Pid, Time, TotalHeapSize, TimeThreshold, 'true');
maybe_warn_long_gc(Pid, Time, TotalHeapSize, TimeThreshold, 'true') when Time >= TimeThreshold ->
    lager:warning("long GC (time: ~bms) detected for pid ~p! (heap: ~b B)"
                 ,[Time, Pid, kz_term:words_to_bytes(TotalHeapSize)]
                 );
maybe_warn_long_gc(_, _, _, _, _ShouldWarn) -> 'ok'.

-spec maybe_warn_large_heap(pid(), size_words(), proc_thresholds() | size_words(), boolean()) -> 'ok'.
maybe_warn_large_heap(Pid, Size, Thresholds, 'true') when is_map(Thresholds) ->
    SizeThreshold = maps:get('large_heap', Thresholds, ?LARGE_HEAP_SIZE_WORDS),
    maybe_warn_large_heap(Pid, Size, SizeThreshold, 'true');
maybe_warn_large_heap(Pid, Size, SizeThreshold, 'true') when Size >= SizeThreshold ->
    lager:warning("large heap (~b B) detected for pid ~p"
                 ,[kz_term:words_to_bytes(Size), Pid]
                 );
maybe_warn_large_heap(_, _, _, _ShouldWarn) -> 'ok'.

-spec maybe_log_long_message_queue(pid(), boolean(), boolean(), message_queue_len()) -> 'ok'.
maybe_log_long_message_queue(Pid, 'false', 'true', MQLen) ->
    lager:warning("long message queue (~b msgs) detected for pid ~p!", [MQLen, Pid]);
maybe_log_long_message_queue(Pid, 'true', 'false', MQLen) ->
    lager:info("message queue (~b msgs) back under low threshold for pid ~p", [MQLen, Pid]);
maybe_log_long_message_queue(_, _PrevHasLongMQ, _HasLongMQ, _) -> 'ok'.

start_check_timer() ->
    erlang:start_timer(?CHECK_MQ_LEN_TIME_MS, self(), ?CHECK_MQ_LEN_MSG).
