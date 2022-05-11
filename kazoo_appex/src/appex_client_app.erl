%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_client_app).

-behaviour(application).

-export([start/2, stop/1]).

-include("appex_client.hrl").

%%------------------------------------------------------------------------------
%% @doc Implement the application start behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec start(application:start_type(), any()) -> kz_types:startapp_ret().
start(_Type, _Args) ->
    case appex_client_config:is_enabled() of
        'true' ->
            maybe_start(appex_client_config:is_configured());
        'false' ->
            lager:info("~s is not enabled, not starting...", [?APP_NAME]),
            appex_client_sup:start_link('false')
    end.

-spec maybe_start(boolean()) -> kz_types:startapp_ret().
maybe_start('true') ->
    check_api_url(),
    appex_client_sup:start_link('true');
maybe_start('false') ->
    lager:error("~s is not configured properly, appex apps won't start", [?APP_NAME]),
    appex_client_sup:start_link('false').

-spec check_api_url() -> 'ok'.
check_api_url() ->
    case appex_client_config:api_url() of
        'undefined' ->
            lager:error("no api_url is configured, appex UI apps may not work with this setup");
        _ApiUrl ->
            'ok'
    end.

%%------------------------------------------------------------------------------
%% @doc Implement the application stop behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec stop(any()) -> 'ok'.
stop(_State) ->
    appex_cb_router:stop_link().
