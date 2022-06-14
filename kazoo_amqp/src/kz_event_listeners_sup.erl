%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_event_listeners_sup).

-behaviour(supervisor).

-export([start_link/0
        ,start_pool/1
        ,stop_pool/1
        ,pool_exists/1

        ,running_listeners/0
        ]).
-export([init/1]).

-include("kz_amqp_util.hrl").
-include("kazoo_events.hrl").

-define(SERVER, ?MODULE).

-define(CHILDREN, [?WORKER_ARGS_TYPE('kz_event_listener_sup', [], 'temporary')]).

%% ===================================================================
%% API functions
%% ===================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the supervisor
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    supervisor:start_link({'local', ?SERVER}, ?MODULE, []).

-spec running_listeners() -> [{pid(), event_type()}].
running_listeners() ->
    [{Pid, kz_event_listener_sup:event_type(Pid)}
     || {_, Pid, _, _} <- supervisor:which_children('kz_event_listeners_sup')
    ].

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

%%------------------------------------------------------------------------------
%% @doc Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%% @end
%%------------------------------------------------------------------------------
-spec init(list()) -> kz_types:sup_init_ret().
init([]) ->
    RestartStrategy = 'simple_one_for_one',
    MaxRestarts = 0,
    MaxSecondsBetweenRestarts = 1,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {'ok', {SupFlags, ?CHILDREN}}.

-spec start_pool(event_type()) -> kz_types:sup_startchild_ret().
start_pool(Name) ->
    supervisor:start_child(?SERVER, [Name]).

-spec stop_pool(event_type()) -> 'ok' | {'error', atom()}.
stop_pool(Name) ->
    case whereis(kz_event_listener_sup:server_name(Name)) of
        Pid when is_pid(Pid) ->
            supervisor:terminate_child(?SERVER, Pid);
        _ ->
            {'error', 'not_found'}
    end.

-spec pool_exists(event_type()) -> boolean().
pool_exists(Name) ->
    is_pid(whereis(kz_event_listener_sup:server_name(Name))).
