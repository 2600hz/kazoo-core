%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc Wait for Globals
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_nodes_init).

-export([start_link/0]).

-include("kazoo_nodes.hrl").

-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    wait_for_nodes('false').

wait_for_nodes('true') ->
    lager:info("kazoo nodes is ready"),
    'ignore';
wait_for_nodes('false') ->
    timer:sleep(?MILLISECONDS_IN_SECOND),
    wait_for_nodes(kz_nodes:is_ready()).
