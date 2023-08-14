%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2023, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_nodes_notify).

-export([notify_new/0, notify_new/1
        ,notify_expire/0, notify_expire/1
        ,notify_heartbeat/0, notify_heartbeat/1
        ]).

-include("kazoo_nodes.hrl").

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec notify_new() -> 'ok'.
notify_new() ->
    catch(gproc:reg({'p', 'l', 'kz_nodes_notify_new'})).

-spec notify_expire() -> 'ok'.
notify_expire() ->
    catch(gproc:reg({'p', 'l', 'kz_nodes_notify_expire'})).

-spec notify_heartbeat() -> 'ok'.
notify_heartbeat() ->
    catch(gproc:reg({'p', 'l', 'kz_nodes_notify_heartbeat'})).

-spec notify_expire(kz_types:kz_nodes()) -> 'ok'.
notify_expire([]) -> 'ok';
notify_expire(Nodes) ->
    Pids = gproc:lookup_pids({'p', 'l', 'kz_nodes_notify_expire'}),
    lists:foreach(fun(Node) -> lists:foreach(fun(Pid) -> gen_server:cast(Pid, {'kz_nodes', {'expire', Node}}) end, Pids) end, Nodes).

-spec notify_new(kz_types:kz_node()) -> 'ok'.
notify_new(#kz_node{}=Node) ->
    Pids = gproc:lookup_pids({'p', 'l', 'kz_nodes_notify_new'}),
    lists:foreach(fun(Pid) -> gen_server:cast(Pid, {'kz_nodes', {'new', Node}}) end, Pids).

-spec notify_heartbeat(kz_types:kz_node()) -> 'ok'.
notify_heartbeat(#kz_node{}=Node) ->
    Pids = gproc:lookup_pids({'p', 'l', 'kz_nodes_notify_heartbeat'}),
    lists:foreach(fun(Pid) -> gen_server:cast(Pid, {'kz_nodes', {'heartbeat', Node}}) end, Pids).
