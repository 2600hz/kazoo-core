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
-module(kz_hooks_util).

-export([register/0, register/1, register/2
        ,deregister/0, deregister/1, deregister/2
        ,registered/0, registered/1, registered/2
        ,all_registered/0
        ]).
-export([bind/3, unbind/3]).
-export([handle_call_event/2]).

-include("kazoo_hooks.hrl").

-define(HOOK_REG, {'p', 'l', 'kz_hook'}).
-define(HOOK_REG(AccountId), {'p', 'l', {'kz_hook', AccountId}}).
-define(HOOK_REG(AccountId, EventName), {'p', 'l', {'kz_hook', AccountId, EventName}}).

-spec register() -> 'true'.
register() ->
    maybe_add_hook(?HOOK_REG).

-spec register(kz_term:ne_binary()) -> 'true'.
register(AccountId) ->
    maybe_add_hook(?HOOK_REG(AccountId)).

-spec register(kz_term:ne_binary(), kz_term:ne_binary()) -> 'true'.
register(AccountId, EventName) ->
    maybe_add_hook(?HOOK_REG(AccountId, EventName)).

-spec deregister() -> 'true'.
deregister() ->
    maybe_remove_hook(?HOOK_REG).

-spec deregister(kz_term:ne_binary()) -> 'true'.
deregister(AccountId) ->
    maybe_remove_hook(?HOOK_REG(AccountId)).

-spec deregister(kz_term:ne_binary(), kz_term:ne_binary()) -> 'true'.
deregister(AccountId, EventName) ->
    maybe_remove_hook(?HOOK_REG(AccountId, EventName)).

-spec registered() -> kz_term:pids().
registered() ->
    gproc:lookup_pids(?HOOK_REG).

-spec registered(kz_term:ne_binary()) -> kz_term:pids().
registered(AccountId) ->
    gproc:lookup_pids(?HOOK_REG(AccountId)).

-spec registered(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:pids().
registered(AccountId, EventName) ->
    gproc:lookup_pids(?HOOK_REG(AccountId, EventName)).

-spec all_registered() -> kz_term:pids().
all_registered() ->
    lists:usort(
      lists:foldl(fun all_registered_fold/2
                 ,[]
                 ,[?HOOK_REG
                  ,?HOOK_REG('_')
                  ,?HOOK_REG('_', '_')
                  ])
     ).

all_registered_fold(HookPattern, Acc) ->
    Match = [{{HookPattern, '$1', '_'}
             ,[]
             ,['$1']
             }],
    gproc:select(Match) ++ Acc.

-spec maybe_add_hook(tuple()) -> 'true'.
maybe_add_hook(Hook) ->
    case gproc:lookup_pids(Hook) of
        [] -> hook_it_up(Hook);
        Pids -> maybe_add_hook(Hook, Pids)
    end.

-spec maybe_add_hook(tuple(), kz_term:pids()) -> 'true'.
maybe_add_hook(Hook, Pids) ->
    lists:member(self(), Pids)
        orelse hook_it_up(Hook).

-spec hook_it_up(tuple()) -> 'true'.
hook_it_up(Hook) ->
    maybe_add_binding(Hook),
    'true' = gproc:reg(Hook).

-spec maybe_add_binding(tuple()) -> 'ok'.
maybe_add_binding(?HOOK_REG) ->
    maybe_add_binding_to_listener();
maybe_add_binding(?HOOK_REG(_AccountId)) ->
    maybe_add_binding_to_listener();
maybe_add_binding(?HOOK_REG(_AccountId, EventName)) ->
    maybe_add_binding_to_listener(EventName).

-spec maybe_add_binding_to_listener() -> 'ok'.
maybe_add_binding_to_listener() ->
    maybe_add_binding_to_listener('all').

-spec maybe_add_binding_to_listener(kz_term:ne_binary() | 'all') -> 'ok'.
maybe_add_binding_to_listener(EventName) ->
    kz_hooks_listener:maybe_add_binding(EventName).

-spec maybe_remove_hook(tuple()) -> 'true'.
maybe_remove_hook(Hook) ->
    case hooks_remain(Hook) of
        'true' -> 'true';
        'false' -> unhook_it(Hook)
    end.

hooks_remain(?HOOK_REG=Hook) ->
    [] =/= gproc:lookup_pids(Hook);
hooks_remain(?HOOK_REG(_AccountId)) ->
    hooks_remain(?HOOK_REG);
hooks_remain(?HOOK_REG(_AccountId, CallEvent)) ->
    [] =/= gproc:lookup_pids(?HOOK_REG('_', CallEvent))
        orelse hooks_remain(?HOOK_REG).

-spec unhook_it(tuple()) -> 'true'.
unhook_it(Hook) ->
    maybe_remove_binding(Hook),
    'true' = gproc:unreg(Hook).

-spec maybe_remove_binding(tuple()) -> 'ok'.
maybe_remove_binding(?HOOK_REG) ->
    maybe_remove_binding_to_listener();
maybe_remove_binding(?HOOK_REG(_AccountId)) ->
    maybe_remove_binding_to_listener();
maybe_remove_binding(?HOOK_REG(_AccountId, EventName)) ->
    maybe_remove_binding_to_listener(EventName).

-spec maybe_remove_binding_to_listener() -> 'ok'.
maybe_remove_binding_to_listener() ->
    maybe_remove_binding_to_listener('all').

-spec maybe_remove_binding_to_listener(kz_term:ne_binary() | 'all') -> 'ok'.
maybe_remove_binding_to_listener(EventName) ->
    kz_hooks_listener:maybe_remove_binding(EventName).

-spec bind(kz_term:ne_binary(), kz_term:ne_binary(), bind_fun()) -> kazoo_bindings:bind_result().
bind(AccountId, EventName, {M, F, Args}) ->
    BindingKey = binding_key(AccountId, EventName),
    lager:debug("binding for hook event ~s in account ~s", [EventName, AccountId]),
    kazoo_bindings:bind(BindingKey, M, F, Args);
bind(AccountId, EventName, BindFun) ->
    BindingKey = binding_key(AccountId, EventName),
    lager:debug("binding for hook event ~s in account ~s", [EventName, AccountId]),
    kazoo_bindings:bind(BindingKey, BindFun).

binding_key(AccountId, EventName) ->
    kz_binary:join([<<?MODULE_STRING>>, AccountId, EventName], <<".">>).

-spec unbind(kz_term:ne_binary(), kz_term:ne_binary(), bind_fun()) -> kazoo_bindings:unbind_result().
unbind(AccountId, EventName, {M, F, Args}) ->
    BindingKey = binding_key(AccountId, EventName),
    lager:debug("unbinding for hook event ~s in account ~s", [EventName, AccountId]),
    kazoo_bindings:unbind(BindingKey, M, F, Args);
unbind(AccountId, EventName, BindFun) ->
    BindingKey = binding_key(AccountId, EventName),
    lager:debug("unbinding for hook event ~s in account ~s", [EventName, AccountId]),
    kazoo_bindings:unbind(BindingKey, BindFun).

-spec handle_call_event(kz_call_event:payload(), kz_term:proplist()) -> 'ok'.
handle_call_event(JObj, _Props) ->
    'true' = kapi_call:event_v(JObj),
    HookEvent = kz_api:event_name(JObj),
    AccountId = kz_call_event:account_id(JObj),
    CallId = kz_call_event:call_id(JObj),
    kz_log:put_callid(CallId),

    RoutingKey = binding_key(AccountId, HookEvent),
    _ = kazoo_bindings:map(RoutingKey, [JObj]),

    handle_call_event(JObj, AccountId, HookEvent, CallId).

-spec handle_call_event(kz_json:object(), kz_term:api_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
handle_call_event(JObj, AccountId, HookEvent, _CallId) ->
    Evt = ?HOOK_EVT(AccountId, HookEvent, JObj),
    gproc:send(?HOOK_REG, Evt),
    gproc:send(?HOOK_REG(AccountId), Evt),
    gproc:send(?HOOK_REG(AccountId, HookEvent), Evt).
