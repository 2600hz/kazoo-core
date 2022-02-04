%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc This is the "generic" application callback interface for
%%% app-store-provided Erlang applications. It adds the application's top-level
%%% supervisor to the appex_client's app controller (to ensure the
%%% application is stopped if appex_client is stopped).
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_client_app_loader).

-behaviour(application).

-export([start/2, stop/1]).

-define(LICENSES_CAT, <<"licenses">>).

%%------------------------------------------------------------------------------
%% @doc Implement the application start behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec start(application:start_type(), any()) -> kz_types:startapp_ret().
start(Type, StartArgs) ->
    try_start_app(Type, StartArgs, 1).

try_start_app(Type, {App, AppMod, StartArgs}, Counter) ->
    case appex_app_master:start_app(App, Type, {AppMod, StartArgs}) of
        {'ok', Pid} ->
            appex_client_client:add_running(App, Pid),
            {'ok', Pid, {?MODULE, {App, AppMod}, []}};
        {'ok', Pid, State} ->
            appex_client_client:add_running(App, Pid),
            {'ok', Pid, {?MODULE, {App, AppMod}, State}};
        {'error', 'invalid_license'}=Error
          when Counter < 3 ->
            case try_fetch_license(App) of
                'true' ->
                    try_start_app(Type, {App, AppMod, StartArgs}, Counter + 1);
                'false' ->
                    Error
            end;
        Error ->
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc Implement the application stop behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec stop(any()) -> any().
stop({?MODULE, {App, AppMod}, State}) ->
    appex_app_master:stop_app(App, {AppMod, State}).

try_fetch_license(App) ->
    case appex_client_client:fetch_license(App) of
        {'ok', JObj} ->
            Features = kz_json:get_keys(JObj),
            install_license(App, JObj, Features),
            'true';
        {'error', RespError} ->
            lager:error("fail fetching license for app ~p with error: ~p", [App, RespError]),
            'false'
    end.

-spec install_license(atom(), kz_json:object(), kz_term:ne_binaries()) -> 'ok'.
install_license(_App, _JObj, []) ->
    'ok';
install_license(App, JObj, [Feature|Features]) ->
    License = kz_json:get_ne_binary_value([Feature, <<"license">>], JObj),
    Type = kz_json:get_ne_binary_value([Feature, <<"type">>], JObj, <<"prime">>),
    Expiration = kz_json:get_integer_value([Feature, <<"expiration">>], JObj),
    _ = install_license(App, Feature, Expiration, Type, License),
    install_license(App, JObj, Features).

-spec install_license(atom(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
install_license(App, Feature, Expiration, Type, License) ->
    AppName = kz_term:to_binary(App),
    _ = kapps_config:set_string(?LICENSES_CAT, [AppName, Feature, <<"license">>], License),
    _ = kapps_config:set_string(?LICENSES_CAT, [AppName, Feature, <<"type">>], Type),
    _ = kapps_config:set_integer(?LICENSES_CAT, [AppName, Feature, <<"expiration">>], Expiration),
    'ok'.
