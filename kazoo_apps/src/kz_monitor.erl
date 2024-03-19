%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc Monitors processes for various conditions and logs loudly
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
        ]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-type state() :: #{{pid(), reference()} := any()}.

-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?MODULE}, ?MODULE, [], []).

%% @doc Start tracking metrics for a process
-spec track_me() -> 'ok'.
track_me() ->
    gen_server:cast(?MODULE, {'track', [self()]}).

-spec init(any()) -> {'ok', state()}.
init(_) ->
    {'ok', #{}}.

-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call(_Call, _From, State) ->
    {'noreply', State}.

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
    Ref = erlang:monitor('process', Pid),
    ProcessInfo = process_info(Pid, ['total_heap_size', 'message_queue_len']),
    State#{{Pid, Ref} => ProcessInfo}.
