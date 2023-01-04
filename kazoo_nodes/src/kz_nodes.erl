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
-module(kz_nodes).

-compile({'no_auto_import', [nodes/0]}).

-export([nodes/0
        ,node_name/0
        ,node_hostname/0
        ,node_encoded/0
        ,local_zone/0
        ,globals_scope/0

        ,node_to_json/1
        ,status_to_json/0
        ,status/0

        ,with_role/1, with_role/2
        ,whapp_oldest_node/1, whapp_oldest_node/2
        ,whapp_zones/1, whapp_zone_count/1
        ,whapp_count/1, whapp_count/2

        ,notify_expire/0, notify_heartbeat/0, notify_new/0
        ,node_role_count/1, node_role_count/2

        ,bind_for_pool_state/2, unbind_for_pool_state/2

        ,wait_for_refresh/0
        ]).

-export([is_up/1]).

-include("kazoo_nodes.hrl").

-spec nodes() -> kz_types:kz_nodes().
nodes() ->
    kz_nodes_ets:nodes().

-spec node_hostname() -> binary().
node_hostname() ->
    [_Name, Host] = binary:split(kz_term:to_binary(node()), <<"@">>),
    Host.

-spec node_encoded() -> kz_term:ne_binary().
node_encoded() ->
    case application:get_env(?APP, 'node_encoded') of
        'undefined' ->
            Encoded = kz_base64url:encode(crypto:hash('md5', kz_term:to_binary(node()))),
            application:set_env(?APP, 'node_encoded', Encoded),
            Encoded;
        {'ok', Encoded} -> Encoded
    end.

-spec node_name() -> binary().
node_name() ->
    [Name, _Host] = binary:split(kz_term:to_binary(node()), <<"@">>),
    Name.

-spec node_to_json(kz_term:text() | kz_types:kz_node()) -> kz_json:object().
node_to_json(Node) ->
    kz_node:to_json(Node).

-spec status_to_json() -> kz_json:object().
status_to_json() ->
    kz_nodes_ets:status_to_json().

-spec status() -> 'ok'.
status() ->
    kz_nodes_ets:status().

-spec is_up(node()) -> boolean().
is_up(Node) ->
    kz_nodes_ets:is_up(Node).

-spec with_role(kz_term:text()) -> kz_types:kz_nodes().
with_role(Role) ->
    kz_nodes_ets:with_role(Role).

-spec with_role(kz_term:text(), kz_term:text() | boolean() | 'remote') -> kz_types:kz_nodes().
with_role(Role, Arg) ->
    kz_nodes_ets:with_role(Role, Arg).

-spec local_zone() -> atom().
local_zone() ->
    kz_nodes_ets:local_zone().

-spec whapp_oldest_node(kz_term:text()) -> kz_term:api_integer().
whapp_oldest_node(Whapp) ->
    kz_nodes_ets:whapp_oldest_node(Whapp).

-spec whapp_oldest_node(kz_term:text(), kz_term:text() | boolean() | atom()) -> kz_term:api_integer().
whapp_oldest_node(Whapp, Federated) ->
    kz_nodes_ets:whapp_oldest_node(Whapp, Federated).

-spec node_role_count(kz_term:text()) -> integer().
node_role_count(Role) ->
    kz_nodes_ets:node_role_count(Role).

-spec node_role_count(kz_term:text(), kz_term:text() | boolean() | 'remote') -> integer().
node_role_count(Role, Arg) ->
    kz_nodes_ets:node_role_count(Role, Arg).

-spec whapp_zones(kz_term:text()) -> list().
whapp_zones(Whapp) ->
    kz_nodes_ets:whapp_zones(Whapp).

-spec whapp_zone_count(kz_term:text()) -> integer().
whapp_zone_count(Whapp) ->
    kz_nodes_ets:whapp_zone_count(Whapp).

-spec whapp_count(kz_term:text()) -> integer().
whapp_count(Whapp) ->
    kz_nodes_ets:whapp_count(Whapp).

-spec whapp_count(kz_term:text(), kz_term:text() | boolean() | 'remote') -> integer().
whapp_count(Whapp, Arg) ->
    kz_nodes_ets:whapp_count(Whapp, Arg).

-spec notify_expire() -> 'ok'.
notify_expire() ->
    kz_nodes_listener:notify_expire().

-spec notify_new() -> 'ok'.
notify_new() ->
    kz_nodes_listener:notify_new().

-spec notify_heartbeat() -> 'ok'.
notify_heartbeat() ->
    kz_nodes_listener:notify_heartbeat().

-spec bind_for_pool_state(atom(), pid()) -> kazoo_bindings:bind_result().
bind_for_pool_state(Module, Pid) ->
    kz_nodes_bindings:bind_for_pool_state(Module, Pid).

-spec unbind_for_pool_state(atom(), kz_term:api_pid()) -> kazoo_bindings:unbind_result().
unbind_for_pool_state(Module, Pid) ->
    kz_nodes_bindings:unbind_for_pool_state(Module, Pid).

-spec globals_scope() -> integer().
globals_scope() ->
    kz_nodes_ets:globals_scope().

-spec wait_for_refresh() -> 'ok'.
wait_for_refresh() ->
    kz_nodes_listener:wait_for_refresh().
