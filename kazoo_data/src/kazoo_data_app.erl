%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_data_app).

-behaviour(application).

-include("kz_data.hrl").

%% Application callbacks
-export([start/2, stop/1]).

%% kz_nodes info binding
-export([request/0]).

%%==============================================================================
%% Application callbacks
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Implement the application start behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec start(application:start_type(), any()) -> kz_types:startapp_ret().
start(_StartType, _StartArgs) ->
    _ = kz_nodes_bindings:bind_info('kazoo_data_app', 'request'),
    kazoo_data_sup:start_link().

%%------------------------------------------------------------------------------
%% @doc Implement the application stop behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec stop(any()) -> any().
stop(_State) ->
    kz_nodes_bindings:unbind_info('kazoo_data_app', 'request').

-spec request() -> {kz_json:key(), kz_json:object()}.
request() ->
    Membership = kz_datamgr:membership(),
    JObj = kz_json:from_list([{kz_term:to_binary(K), V} || {K, V} <- Membership]),
    {<<"couch">>, JObj}.
