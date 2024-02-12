%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_nodes_sup).

-behaviour(supervisor).

-export([start_link/0
        ,init/1
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(SERVER, ?MODULE).

-define(CHILDREN, [?WORKER_ARGS('kazoo_etsmgr_srv', ?ETSMGR_ARGS)
                  ,?WORKER('kz_nodes_listener')
                  ,?WORKER('kazoo_nodes_init')
                  ]).

-define(ETSMGR_ARGS
       ,[[{'table_id', kz_nodes_ets:table_id()}
         ,{'find_me_function', fun kz_nodes_listener:find_me/0}
         ,{'table_options', kz_nodes_ets:table_options()}
         ,{'gift_data', kz_nodes_ets:gift_data()}
         ]]
       ).

%%==============================================================================
%% API functions
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the supervisor.
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    supervisor:start_link({'local', ?SERVER}, ?MODULE, []).

%%==============================================================================
%% Supervisor callbacks
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Whenever a supervisor is started using `supervisor:start_link/[2,3]',
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%% @end
%%------------------------------------------------------------------------------
-spec init(any()) -> kz_types:sup_init_ret().
init([]) ->
    _ = kz_process:set_startup(),
    RestartStrategy = 'one_for_one',
    MaxRestarts = 25,
    MaxSecondsBetweenRestarts = 1,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    {'ok', {SupFlags, ?CHILDREN}}.
