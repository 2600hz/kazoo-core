%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_events_app).
-behaviour(application).

-include("kazoo_events.hrl").
-include_lib("kazoo_amqp/include/kz_amqp.hrl").

-export([start/2, stop/1]).


%% Application callbacks

%% @doc Implement the application start behaviour
-spec start(application:start_type(), any()) -> kz_types:startapp_ret().
start(_StartType, _StartArgs) ->
    kazoo_events_sup:start_link().

%% @doc Implement the application stop behaviour
-spec stop(any()) -> any().
stop(_State) ->
    'ok'.
