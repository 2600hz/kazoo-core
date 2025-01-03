%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_app_master).

-export([start_app/3
        ,stop_app/2
        ]).

%% internal usage
-export([force_cleanse_app/1]).
-export([remove_app/2]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(WAIT_FOR_APP_STOP_MS, 10 * ?MILLISECONDS_IN_SECOND).

-spec start_app(atom(), application:start_type(), {atom(), any()}) -> kz_types:sup_startchild_ret().
start_app(_App, Type, {AppCallback, AppStartArgs}) ->
    AppCallback:start(Type, AppStartArgs).

-spec stop_app(atom(), {atom(), any()}) -> any().
stop_app(App, {AppCallback, State}) ->
    _Pid = spawn(?MODULE, 'remove_app', [self(), App]),
    AppCallback:stop(State).

%% @doc Use this to cleanse a rogue app.
%%
%% Waits 10s for the the app to stop before cleaning it from VM.
%%
%% This expected to be called for premature loaded apps or apps that
%% are loaded but not running. For stopping a running app use:
%% kapps_controller:stop_app/1
-spec force_cleanse_app(atom()) -> 'ok'.
force_cleanse_app(App) ->
    _Pid = spawn(?MODULE, 'remove_app', ['undefined', App]),
    'ok'.

%% @doc Internal function expected to be called from application
%% master. This will wait to app to stop properly and cleanse the app
%% afterward. Waits 10s for the the app to stop before cleaning it
%% from VM
-spec remove_app(kz_term:api_pid(), atom()) -> 'ok'.
remove_app(ShutdownPid, App) ->
    process_flag('trap_exit', 'true'),
    group_leader(self(), self()),
    try
        wait_for_app_to_stop(ShutdownPid, App),
        {'ok', Modules} = application:get_key(App, 'modules'),
        _Rm = [remove_module(Module) || Module <- Modules],
        _Unload = application:unload(App),
        lager:debug("unloaded app ~s: ~p", [App, _Unload]),
        delete_app(App)
    catch
        _E:_R ->
            lager:info("failed to remove ~s: ~s: ~p", [App, _E, _R])
    end.

-spec delete_app(atom()) -> 'ok'.
delete_app(App) ->
    case code:lib_dir(App) of
        {'error', _} -> 'ok';
        AppDir ->
            _ = file:del_dir_r(AppDir),
            _ = code:set_path(lists:delete(AppDir, code:get_path())),
            _ = code:set_path(lists:delete(kz_term:to_list(filename:join([AppDir, "ebin"]))
                                          ,code:get_path()
                                          )
                             ),
            'ok'
    end.

-spec remove_module(module()) -> module().
remove_module(Module) ->
    _Purged = code:purge(Module),
    code:delete(Module).

-spec wait_for_app_to_stop(kz_term:api_pid(), atom()) -> 'ok'.
wait_for_app_to_stop('undefined', App) ->
    try is_running(App) of
        'false' -> 'ok';
        'true' ->
            lager:debug("app ~p is still running, giving it 10s to stop before cleaning it", [App]),
            timer:sleep(?WAIT_FOR_APP_STOP_MS)
    catch
        _E:_R ->
            timer:sleep(?WAIT_FOR_APP_STOP_MS)
    end;
wait_for_app_to_stop(ShutdownPid, _App) when is_pid(ShutdownPid) ->
    Ref = erlang:monitor('process', ShutdownPid),
    wait_for_pid(ShutdownPid, Ref).

-spec wait_for_pid(pid(), reference()) -> 'ok'.
wait_for_pid(ShutdownPid, Ref) ->
    receive
        {'DOWN', Ref, 'process', ShutdownPid, _Reason} ->
            lager:info("pid ~p finished: ~p", [ShutdownPid, _Reason])
    after ?WAIT_FOR_APP_STOP_MS ->
            lager:info("timed out waiting for ~p to finish", [ShutdownPid])
    end.

-spec is_running(atom()) -> boolean().
is_running(App) ->
    lists:member(App, kz_application:running_apps()).
