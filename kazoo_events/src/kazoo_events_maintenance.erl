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

-spec running_listeners() -> 'ok'.
running_listeners() ->
    Listeners = kz_event_listeners_sup:running_listeners(),
    io:format("~-15s | ~-15s | ~p |~n", ["Event Type","Supervisor", "Worker PIDs"]),
    lists:foreach(fun print_listener/1, Listeners).

-spec print_listener({pid(), event_type()}) -> 'ok'.
print_listener({Pid, EventType}) ->
    Workers = kz_event_listener_sup:workers(Pid),
    io:format("~-15s | ~-15p | ~p~n", [EventType, Pid, Workers]).
