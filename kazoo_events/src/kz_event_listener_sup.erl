%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_event_listener_sup).

-behaviour(supervisor).

-include("kazoo_events.hrl").

-define(SERVER, ?MODULE).

-export([start_link/1
        ,start_workers/0
        ,stop_workers/0
        ,server_name/1
        ]).
-export([init/1]).

-define(CHILDREN(Name), [?WORKER_ARGS_TYPE('kz_event_listener', [Name], 'temporary')]).

%% ===================================================================
%% API functions
%% ===================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the supervisor
%% @end
%%------------------------------------------------------------------------------
-spec start_link(atom()) -> kz_types:startlink_ret().
start_link(Name) ->
    handle_started(supervisor:start_link({'local', server_name(Name)}, ?MODULE, [Name])).

handle_started({'ok', Pid}) ->
    _ = start_workers(),
    {'ok', Pid};
handle_started(Error) -> Error.

-spec server_name(event_type()) -> atom().
server_name(Name) ->
    kz_term:to_atom(?MODULE_STRING ++ [$_ | kz_term:to_list(Name)], 'true').

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
init([Name]) ->
    RestartStrategy = 'simple_one_for_one',
    MaxRestarts = 0,
    MaxSecondsBetweenRestarts = 1,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {'ok', {SupFlags, ?CHILDREN(Name)}}.

-spec start_workers() -> 'ok'.
start_workers() ->
    Workers = kz_app_config:get_integer(?APP, <<"event_listeners">>, 5),
    {Pid, Ref} = kz_process:spawn_monitor(fun start_workers/1, [Workers]),
    wait_for_workers(Pid, Ref).

wait_for_workers(Pid, Ref) ->
    receive
        {'DOWN', Ref, 'process', Pid, 'normal'} -> 'ok';
        {'DOWN', Ref, 'process', Pid, _Reason} ->
            lager:info("starting workers in ~p failed: ~p", [Pid, _Reason])
    after
        5 * ?MILLISECONDS_IN_SECOND ->
            lager:info("timed out waiting for workers in ~p", [Pid])
    end.

start_workers(Workers) ->
    [start_worker()
     || _N <- lists:seq(1, Workers)
    ].

start_worker() ->
    _ = supervisor:start_child(?SERVER, []),
    timer:sleep(500).

-spec stop_workers() -> ['ok' | {'error', atom()}].
stop_workers() ->
    [stop_worker(Child) || {_Id, Child, _Type, _Modules} <- supervisor:which_children(?SERVER)].

-spec stop_worker(pid()) -> 'ok' | {'error', atom()}.
stop_worker(Child) ->
    supervisor:terminate_child(?SERVER, Child).
