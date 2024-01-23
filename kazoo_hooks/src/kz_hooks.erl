%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2024, 2600Hz
%%% @doc
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_hooks).

-export([register/0, register/1, register/2
        ,deregister/0, deregister/1, deregister/2

        ,bind/0, bind/1, bind/2, bind/3
        ,unbind/0, unbind/1, unbind/2, unbind/3
        ]).

-include("kazoo_hooks.hrl").

-spec register() -> 'true'.
register() -> kz_hooks_util:register().

-spec register(kz_term:ne_binary()) -> 'true'.
register(AccountId) -> kz_hooks_util:register(AccountId).

-spec register(kz_term:ne_binary(), kz_term:ne_binary()) -> 'true'.
register(AccountId, EventName) -> kz_hooks_util:register(AccountId, EventName).

-spec deregister() -> 'true'.
deregister() -> kz_hooks_util:deregister().

-spec deregister(kz_term:ne_binary()) -> 'true'.
deregister(AccountId) -> kz_hooks_util:deregister(AccountId).

-spec deregister(kz_term:ne_binary(), kz_term:ne_binary()) -> 'true'.
deregister(AccountId, EventName) -> kz_hooks_util:deregister(AccountId, EventName).

-spec bind() -> kazoo_bindings:bind_result().
bind() ->
    bind(<<"*">>, <<"*">>).

-spec bind(kz_term:ne_binary()) -> kazoo_bindings:bind_result().
bind(AccountId) ->
    bind(AccountId, <<"*">>).

-spec bind(kz_term:ne_binary(), kz_term:ne_binary()) -> kazoo_bindings:bind_result().
bind(AccountId, EventName) ->
    bind(AccountId, EventName, {'kapps_call_command', 'relay_event', [self()]}).

-spec bind(kz_term:ne_binary(), kz_term:ne_binary(), bind_fun()) -> kazoo_bindings:bind_result().
bind(AccountId, EventName, BindFun) ->
    kz_hooks_util:bind(AccountId, EventName, BindFun).

-spec unbind() -> kazoo_bindings:unbind_result().
unbind() ->
    unbind(<<"*">>, <<"*">>).

-spec unbind(kz_term:ne_binary()) -> kazoo_bindings:unbind_result().
unbind(AccountId) ->
    unbind(AccountId, <<"*">>).

-spec unbind(kz_term:ne_binary(), kz_term:ne_binary()) -> kazoo_bindings:unbind_result().
unbind(AccountId, EventName) ->
    unbind(AccountId, EventName, {'kapps_call_command', 'relay_event', [self()]}).

-spec unbind(kz_term:ne_binary(), kz_term:ne_binary(), bind_fun()) -> kazoo_bindings:unbind_result().
unbind(AccountId, EventName, BindFun) ->
    kz_hooks_util:unbind(AccountId, EventName, BindFun).
