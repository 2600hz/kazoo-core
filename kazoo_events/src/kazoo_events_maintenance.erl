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

-spec running_listeners() -> 'ok'.
running_listeners() ->
    Listeners = [Pid || {_, Pid, _, _} <- supervisor:which_children(kz_event_listeners_sup)],
    lists:foreach(fun print_listener/1, Listeners).

print_listener(Listener) ->
    io:format("~p~n", [Listener]).
