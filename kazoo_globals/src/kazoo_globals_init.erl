%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Wait for Globals
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_globals_init).

-export([start_link/0]).

-include("kazoo_globals.hrl").

-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    wait_for_globals('false').

wait_for_globals('true') ->
    lager:info("kazoo globals is ready"),
    _ = kazoo_bindings:bind(<<"kz_nodes.globals">>, 'kz_globals', 'stats'),
    'ignore';
wait_for_globals('false') ->
    timer:sleep(?MILLISECONDS_IN_SECOND),
    wait_for_globals(kz_globals:is_ready()).
