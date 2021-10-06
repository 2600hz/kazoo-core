%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_events_maintenance).

-export([running_listeners/0]).

-include("kazoo_events.hrl").

-define(FMT_LISTENER, "~-15s | ~-12s | ~s~n").

-spec running_listeners() -> 'ok'.
running_listeners() ->
    Listeners = kz_event_listeners_sup:running_listeners(),
    io:format(?FMT_LISTENER, ["Event Type","Supervisor", "Worker PIDs"]),
    lists:foreach(fun print_listener/1, Listeners).

-spec print_listener({pid(), event_type()}) -> 'ok'.
print_listener({Pid, EventType}) ->
    Workers = kz_event_listener_sup:workers(Pid),
    WorkersBin = kz_binary:join(Workers),
    io:format(?FMT_LISTENER
             ,[EventType, kz_term:to_binary(Pid), WorkersBin]
             ).
