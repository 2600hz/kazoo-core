%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc Monitors processes for various conditions and logs loudly
%%% There was an EEP that went nowhere: https://www.erlang.org/eeps/eep-0042
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_monitor).
-behaviour(gen_server).

-export([start_link/0
        ,track_me/0
        ,track_pid/1
        ,track_pids/1

        ,tracked_pids/0, pp_tracked_pids/0
        ]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-record(proc_info, {monitor_ref :: reference()
                   ,tstamp :: kz_time:gregorian_seconds()
                   ,proc_info :: kz_term:proplist()
                   }).
-type proc_info() :: #proc_info{}.

-type state() :: #{pid() := proc_info()
                  ,'timer_ref' := reference()
                  }.

-define(CHECK_TIMER_MSG, 'check_mailboxes').

-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?MODULE}, ?MODULE, [], []).

%% @doc Start tracking metrics for a process
-spec track_me() -> 'ok'.
track_me() ->
    track_pid(self()).

-spec track_pid(pid()) -> 'ok'.
track_pid(Pid) when is_pid(Pid) ->
    track_pids([Pid]).

-spec track_pids([pid()]) -> 'ok'.
track_pids(Pids) when is_list(Pids) ->
    gen_server:cast(?MODULE, {'track', Pids}).

-spec tracked_pids() -> [{pid(), any()}].
tracked_pids() ->
    gen_server:call(?MODULE, 'tracked_pids').

-spec pp_tracked_pids() -> 'ok'.
pp_tracked_pids() ->
    Tracked = tracked_pids(),
    pp_tracked_pids(Tracked).

pp_tracked_pids([]) -> io:format("no processes being tracked~n");
pp_tracked_pids(Tracked) ->
    io:format("~15s | ~20s | ~s~n", ["PID", "Time", "MsgQueue Length"]),
    lists:foreach(fun pp_tracked_pid/1, Tracked).

pp_tracked_pid({Pid, {TStamp, ProcInfo}}) ->
    io:format("~15s | ~20s | ~p~n"
             ,[kz_term:to_binary(Pid)
              ,kz_time:pretty_print_datetime(TStamp)
              ,props:get_integer_value('message_queue_len', ProcInfo)
              ]).

-spec init(any()) -> {'ok', state()}.
init(_) ->
    lager:info("starting kz_monitor"),
    {'ok', #{'timer_ref' => start_check_timer()}}.

-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call('tracked_pids', _From, State) ->
    lager:info("tracked: ~p", [State]),
    Tracking = maps:fold(fun tracked_pid_info/3, [], State),
    {'reply', Tracking, State};
handle_call(_Call, _From, State) ->
    {'noreply', State}.

tracked_pid_info(Pid, #proc_info{tstamp=TStamp, proc_info=Info}, Acc) when is_pid(Pid) ->
    [{Pid, {TStamp, Info}} | Acc];
tracked_pid_info(_, _, Acc) -> Acc.

-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'track', Pids}, State) ->
    NewState = lists:foldl(fun track_pid/2, State, Pids),
    {'noreply', NewState};
handle_cast(_Cast, State) ->
    {'noreply', State}.

-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info({'DOWN', Ref, 'process', Pid, _Reason}, State) ->
    case maps:take({Pid, Ref}, State) of
        'error' -> {'noreply', State};
        {_MonitorInfo, NewState} ->
            lager:info("pid ~p down: ~p", [Pid, _Reason]),
            {'noreply', NewState}
    end;
handle_info({'timeout', TimerRef, ?CHECK_TIMER_MSG}, #{'timer_ref' := TimerRef}=State) ->
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

track_pid(Pid, State) ->
    case State of
        #{Pid := _} -> State;
        #{} ->
            MonitorRef = erlang:monitor('process', Pid),
            ProcessInfo = process_info(Pid, ['total_heap_size', 'message_queue_len']),
            State#{Pid => #proc_info{monitor_ref=MonitorRef
                                    ,tstamp=kz_time:now_s()
                                    ,proc_info=ProcessInfo
                                    }}
    end.

update_tracked_pids(State) ->
    maps:map(fun update_tracked_pid/2, State).

update_tracked_pid('timer_ref', TimerRef) -> TimerRef;
update_tracked_pid(Pid, #proc_info{monitor_ref=MonitorRef}) ->
    #proc_info{monitor_ref=MonitorRef
              ,tstamp=kz_time:now_s()
              ,proc_info=process_info(Pid, ['total_heap_size', 'message_queue_len'])
              }.

start_check_timer() ->
    erlang:start_timer(?MILLISECONDS_IN_SECOND, self(), ?CHECK_TIMER_MSG).
