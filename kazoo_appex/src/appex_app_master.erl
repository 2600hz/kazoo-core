%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
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

-export([remove_app/1, remove_app/2]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-spec start_app(atom(), application:start_type(), {atom(), any()}) -> kz_types:sup_startchild_ret().
start_app(_App, Type, {AppCallback, AppStartArgs}) ->
    AppCallback:start(Type, AppStartArgs).

-spec stop_app(atom(), {atom(), any()}) -> any().
stop_app(App, {AppCallback, State}) ->
    _Pid = spawn(?MODULE, 'remove_app', [self(), App]),
    AppCallback:stop(State).

-spec remove_app(atom()) -> 'ok'.
remove_app(App) ->
    remove_app('undefined', App).

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
            timer:sleep(10),
            wait_for_app_to_stop('undefined', App)
    catch
        _E:_R ->
            timer:sleep(10),
            wait_for_app_to_stop('undefined', App)
    end;
wait_for_app_to_stop(ShutdownPid, _App) when is_pid(ShutdownPid) ->
    Ref = erlang:monitor('process', ShutdownPid),
    wait_for_pid(ShutdownPid, Ref).

-spec wait_for_pid(pid(), reference()) -> 'ok'.
wait_for_pid(ShutdownPid, Ref) ->
    receive
        {'DOWN', Ref, 'process', ShutdownPid, _Reason} ->
            lager:info("pid ~p finished: ~p", [ShutdownPid, _Reason])
    after 10 * ?MILLISECONDS_IN_SECOND ->
            lager:info("timed out waiting for ~p to finish", [ShutdownPid])
    end.

-spec is_running(atom()) -> boolean().
is_running(App) ->
    'false' =/= lists:keyfind(App, 1, application:which_applications()).
