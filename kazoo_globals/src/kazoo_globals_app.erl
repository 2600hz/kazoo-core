%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_globals_app).
-behaviour(application).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-export([start/2, prep_stop/1, stop/1]).

%% Application callbacks

%% @doc Implement the application start behaviour.
-spec start(application:start_type(), any()) -> kz_types:startapp_ret().
start(_StartType, _StartArgs) ->
    kazoo_globals_sup:start_link().

%% @doc Implement the application stop behaviour.
-spec stop(any()) -> any().
stop(_State) ->
    'ok'.

-spec prep_stop(any()) -> 'ok'.
prep_stop(_State) ->
    _ = kazoo_bindings:flush_mod('kz_globals'),
    'ok'.
