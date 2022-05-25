%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_event_listener_sup).

-behaviour(supervisor).

-export([start_link/1
        ,start_workers/1
        ,stop_workers/1
        ,workers/1
        ,server_name/1, event_type/1
        ]).
-export([init/1]).

-include("kz_amqp_util.hrl").
-include("kazoo_events.hrl").

-define(SERVER, ?MODULE).

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
    Server = server_name(Name),
    lager:info("starting server ~p", [Server]),
    handle_started(supervisor:start_link({'local', Server}, ?MODULE, [Name])).

handle_started({'ok', Pid}) ->
    _ = kz_process:spawn(fun start_workers/1, [Pid]),
    {'ok', Pid};
handle_started(Error) -> Error.

-spec server_name(event_type()) -> atom().
server_name(Name) ->
    kz_term:to_atom(?MODULE_STRING ++ [$_ | kz_term:to_list(Name)], 'true').

-spec event_type(pid() | atom()) -> event_type() | 'undefined'.
event_type(Pid) when is_pid(Pid) ->
    event_type_from_pid(process_info(Pid, ['registered_name']));
event_type(RegisteredName) when is_atom(RegisteredName) ->
    event_type_from_binary(kz_term:to_binary(RegisteredName)).

event_type_from_pid('undefined') ->
    'undefined';
event_type_from_pid([{'registered_name', Name}]) ->
    event_type(Name).

event_type_from_binary(<<?MODULE_STRING, $_, Event/binary>>) ->
    kz_term:to_atom(Event);
event_type_from_binary(_Name) -> 'undefined'.

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
    lager:info("starting for pool ~p", [Name]),
    {'ok', {SupFlags, ?CHILDREN(Name)}}.

-spec workers(pid()) -> [pid()].
workers(Super) ->
    [W || {_, W, _, _} <- supervisor:which_children(Super)].

-spec start_workers(pid()) -> 'ok'.
start_workers(Super) ->
    EventType = event_type(Super),

    Workers = worker_count(EventType),

    lager:info("starting ~p workers", [Workers]),
    {Pid, Ref} = kz_process:spawn_monitor(fun start_workers/2, [Super, Workers]),
    wait_for_workers(Pid, Ref).

worker_count(EventType) ->
    case kz_app_config:get_integer(?APP_EVENTS, [kz_term:to_binary(EventType), <<"event_listeners">>]) of
        'undefined' -> default_worker_count();
        Count -> Count
    end.

default_worker_count() ->
    kz_app_config:get_integer(?APP_EVENTS, <<"event_listeners">>, 5).

wait_for_workers(Pid, Ref) ->
    receive
        {'DOWN', Ref, 'process', Pid, 'normal'} -> 'ok';
        {'DOWN', Ref, 'process', Pid, _Reason} ->
            lager:info("starting workers in ~p failed: ~p", [Pid, _Reason])
    after
        5 * ?MILLISECONDS_IN_SECOND ->
            lager:info("timed out waiting for workers in ~p", [Pid])
    end.

start_workers(Super, Workers) ->
    [start_worker(Super)
     || _N <- lists:seq(1, Workers)
    ].

start_worker(Super) ->
    _ = supervisor:start_child(Super, []),
    timer:sleep(500).

-spec stop_workers(pid()) -> ['ok' | {'error', atom()}].
stop_workers(Super) ->
    [stop_worker(Super, Child) || {_Id, Child, _Type, _Modules} <- supervisor:which_children(Super)].

-spec stop_worker(pid(), pid()) -> 'ok' | {'error', atom()}.
stop_worker(Super, Child) ->
    supervisor:terminate_child(Super, Child).
