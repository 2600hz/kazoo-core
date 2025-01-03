%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2024-2025, 2600Hz
%%% @doc Supervises the named `kz_monitor' proc
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @author Daniel Finke <danielfinke2011@gmail.com>
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_monitor_sup).
-behaviour(supervisor).

%%%=============================================================================
%%% Export and Defs
%%%=============================================================================

%% External API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(SERVER, ?MODULE).

-define(CHILDREN, [?WORKER('kz_monitor')]).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts and links the supervisor process
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    supervisor:start_link({'local', ?SERVER}, ?MODULE, []).

%%%=============================================================================
%%% Supervisor callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Supervisor init callback method
%% @end
%%------------------------------------------------------------------------------
-spec init([]) -> kz_types:sup_init_ret().
init([]) ->
    _ = kz_process:set_startup(),
    RestartStrategy = 'one_for_one',
    MaxRestarts = 5,
    MaxSecondsBetweenRestarts = 5,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    {'ok', {SupFlags, ?CHILDREN}}.
