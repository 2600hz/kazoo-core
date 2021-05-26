%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_nodes_bindings).

-export([bind/1, bind/2, bind/3
        ,bind_info/1, bind_info/2
        ,unbind/1, unbind/2, unbind/3
        ,unbind_info/1, unbind_info/2
        ,request/1

        ,binding_node_info/0

        ,pool_state_binding/0, bind_for_pool_state/1, bind_for_pool_state/2
        ,unbind_for_pool_state/1, unbind_for_pool_state/2
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").

-define(DEFAULT_MODULE, 'kz_nodes_ets').
-define(DEFAULT_FUNCTION, 'request').
-define(CALLBACK_ARITY, 1).

-type bind_result() :: kazoo_bindings:bind_result().
-type unbind_result() :: kazoo_bindings:unbind_result().

-spec bind(atom()) -> bind_result().
bind(App) ->
    bind(App, App).

-spec bind(atom(), atom()) -> bind_result().
bind(App, Module) ->
    bind(App, Module, ?DEFAULT_FUNCTION).

-spec bind(atom(), atom(), atom()) -> bind_result().
bind(App, Module, Function)
  when is_atom(App)
       andalso is_atom(Module)
       andalso is_atom(Function)
       ->
    Binding = routing_key(App),
    case erlang:function_exported(Module, Function, ?CALLBACK_ARITY) of
        'true' ->
            kazoo_bindings:bind(Binding, Module, Function);
        'false' ->
            kazoo_bindings:bind(Binding, ?DEFAULT_MODULE, ?DEFAULT_FUNCTION)
    end.

-spec bind_info(module()) -> bind_result().
bind_info(Module) ->
    bind_info(Module, 'node_info').

-spec bind_info(module(), atom()) -> bind_result().
bind_info(Module, Function)
  when is_atom(Module)
       andalso is_atom(Function) ->
    'true' = erlang:function_exported(Module, Function, 0),
    kazoo_bindings:bind(binding_node_info(), Module, Function).

-spec unbind(atom()) -> kazoo_bindings:unbind_result().
unbind(App) ->
    unbind(App, App).

-spec unbind(atom(), atom()) -> kazoo_bindings:unbind_result().
unbind(App, Module) ->
    unbind(App, Module, ?DEFAULT_FUNCTION).

-spec unbind(atom(), atom(), atom()) -> kazoo_bindings:unbind_result().
unbind(App, Module, Function)
  when is_atom(App)
       andalso is_atom(Module)
       andalso is_atom(Function)
       ->
    Binding = routing_key(App),
    case erlang:function_exported(Module, Function, ?CALLBACK_ARITY) of
        'true' ->
            kazoo_bindings:unbind(Binding, Module, Function);
        'false' ->
            kazoo_bindings:unbind(Binding, ?DEFAULT_MODULE, ?DEFAULT_FUNCTION)
    end.

-spec unbind_info(module()) -> unbind_result().
unbind_info(Module) ->
    unbind_info(Module, 'node_info').

-spec unbind_info(module(), atom()) -> unbind_result().
unbind_info(Module, Function)
  when is_atom(Module)
       andalso is_atom(Function) ->
    kazoo_bindings:unbind(binding_node_info(), Module, Function).

routing_key(App) ->
    <<"kz_nodes.request.", (kz_term:to_binary(App))/binary>>.

-spec request(atom()) -> kazoo_bindings:fold_results().
request(App) when is_atom(App) ->
    case ets:info(kazoo_bindings:table_id()) of
        'undefined' ->
            lager:debug("kazoo bindings ets table not ready"),
            [];
        _ ->
            Routing = routing_key(App),
            kazoo_bindings:fold(Routing, [[{'app', App}]])
    end.

-spec binding_node_info() -> kz_term:ne_binary().
binding_node_info() ->
    <<"kz_nodes.node.info">>.

-spec pool_state_binding() -> kz_term:ne_binary().
pool_state_binding() -> <<?MODULE_STRING, ".amqp.pools">>.

%% @doc binding callback when kz_nodes wants to know pool states for status updates
-spec bind_for_pool_state(atom()) -> kazoo_bindings:bind_result().
bind_for_pool_state(Module) ->
    bind_for_pool_state(Module, self()).

-spec bind_for_pool_state(atom(), pid()) -> kazoo_bindings:bind_result().
bind_for_pool_state(Module, Pid) ->
    _ = kazoo_bindings:bind(pool_state_binding(), Module, 'pools', Pid).

-spec unbind_for_pool_state(atom()) -> kazoo_bindings:unbind_result().
unbind_for_pool_state(Module) ->
    unbind_for_pool_state(Module, self()).

-spec unbind_for_pool_state(atom(), kz_term:api_pid()) -> kazoo_bindings:unbind_result().
unbind_for_pool_state(_Module, 'undefined') -> 'ok';
unbind_for_pool_state(Module, Pid) when is_pid(Pid) ->
    kazoo_bindings:unbind(pool_state_binding(), Module, 'pools', Pid).
