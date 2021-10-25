%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_events).

-export([event_binding/2]).

-export([start_call_events/0, call_event_binding/1
        ,bind_call_id/1, unbind_call_id/1
        ]).

-export([start_presence_events/0, presence_event_binding/1
        ,bind_presence_id/1, unbind_presence_id/1
        ]).

-export([publish_event/3]).

-include("kazoo_events.hrl").

-type call_id() :: kz_term:ne_binary() | '_'.
-type binding_call_id() :: {'call_events', call_id()}.

-type presence_id() :: kz_term:ne_binary() | '_'.
-type binding_presence_id() :: {'presence', presence_id()}.

-type event_binding() :: binding_call_id() |
                         binding_presence_id().

-spec event_binding(event_type(), [call_id()]) -> event_binding().
event_binding('call_events', [CallId]) ->
    call_event_binding(CallId);
event_binding('presence', [PresenceId]) ->
    presence_event_binding(PresenceId).

-spec call_event_binding(call_id()) -> binding_call_id().
call_event_binding(CallId) ->
    {'call_events', CallId}.

%% @doc starts pool of listeners for call events
-spec start_call_events() -> 'ok'.
start_call_events() ->
    {'ok', _Pid} = kz_event_listeners_sup:start_pool('call_events'),
    'ok'.

maybe_start_call_events() ->
    case kz_event_listeners_sup:pool_exists('call_events') of
        'false' -> start_call_events();
        'true' -> 'ok'
    end.

-spec bind_call_id(kz_term:ne_binary()) -> 'ok'.
bind_call_id(CallId) ->
    maybe_start_call_events(),
    reg_property(call_event_binding(CallId), self()),
    'ok'.

-spec unbind_call_id(kz_term:ne_binary()) -> 'ok'.
unbind_call_id(CallId) ->
    unreg_property(call_event_binding(CallId)),
    'ok'.

-spec presence_event_binding(presence_id()) -> binding_presence_id().
presence_event_binding(PresenceId) ->
    {'presence', PresenceId}.

%% @doc starts pool of listeners for call events
-spec start_presence_events() -> 'ok'.
start_presence_events() ->
    {'ok', _} = kz_event_listeners_sup:start_pool('presence'),
    'ok'.

maybe_start_presence() ->
    case kz_event_listeners_sup:pool_exists('presence') of
        'false' -> start_presence_events();
        'true' -> 'ok'
    end.

-spec bind_presence_id(kz_term:ne_binary()) -> 'ok'.
bind_presence_id(PresenceId) ->
    maybe_start_presence(),
    reg_property(presence_event_binding(PresenceId), self()),
    'ok'.

-spec unbind_presence_id(kz_term:ne_binary()) -> 'ok'.
unbind_presence_id(PresenceId) ->
    unreg_property(presence_event_binding(PresenceId)),
    'ok'.

-spec publish_event(kz_json:object(), kz_term:proplist(), event_type()) -> 'ok'.
publish_event(JObj, Props, 'call_events') ->
    Binding = call_event_binding(kz_call_event:call_id(JObj)),
    _ = send_event(Binding, {'kapi', kapi:delivery_message(JObj, Props)}),
    'ok';
publish_event(JObj, Props, 'presence') ->
    Binding = presence_event_binding(kz_json:get_ne_binary_value(<<"Presence-ID">>, JObj)),
    _ = send_event(Binding, {'kapi', kapi:delivery_message(JObj, Props)}),
    'ok'.

send_event(Binding, Payload) ->
    gproc:send({'p', 'l', Binding}, Payload).

reg_property(Binding, Value) ->
    gproc:reg({'p', 'l', Binding}, Value).

unreg_property(Binding) ->
    gproc:unreg({'p', 'l', Binding}).
