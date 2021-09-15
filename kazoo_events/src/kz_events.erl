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

-export([publish_event/3]).

-include("kazoo_events.hrl").

-type call_id() :: kz_term:ne_binary() | '_'.
-type binding_call_id() :: {'call_events', call_id()}.
-type event_binding() :: binding_call_id().

-spec event_binding(event_type(), [call_id()]) -> event_binding().
event_binding('call_events', [CallId]) ->
    call_event_binding(CallId).

-spec call_event_binding(call_id()) -> binding_call_id().
call_event_binding(CallId) ->
    {'call_events', CallId}.

%% @doc starts pool of listeners for call events
-spec start_call_events() -> 'ok'.
start_call_events() ->
    {'ok', Pid} = kz_event_listeners_sup:start_pool('call_events'),
    Ref = erlang:monitor('process', Pid),
    wait_for_workers(Pid, Ref).

maybe_start_call_events() ->
    case kz_event_listeners_sup:pool_exists('call_events') of
        'false' -> start_call_events();
        'true' -> 'ok'
    end.

-spec bind_call_id(kz_term:ne_binary()) -> 'ok'.
bind_call_id(CallId) ->
    maybe_start_call_events(),
    reg_property(call_event_binding(CallId), self()).

-spec unbind_call_id(kz_term:ne_binary()) -> 'ok'.
unbind_call_id(CallId) ->
    unreg_property(call_event_binding(CallId)).

wait_for_workers(Pid, Ref) ->
    receive
        {'DOWN', Ref, 'process', Pid, 'normal'} -> 'ok';
        {'DOWN', Ref, 'process', Pid, _Reason} ->
            lager:info("worker init ~p died with reason ~p", [Pid, _Reason])
    after
        5 * ?MILLISECONDS_IN_SECOND ->
            lager:info("timed out waiting for worker init in ~p", [Pid])
    end.

-spec publish_event(kz_json:object(), kz_term:proplist(), event_type()) -> 'ok'.
publish_event(JObj, Props, 'call_events') ->
    Binding = call_event_binding(kz_call_event:call_id(JObj)),
    _ = send_event(Binding, {'kapi', kapi:delivery_message(JObj, Props)}),
    'ok'.

send_event(Binding, Payload) ->
    gproc:send({'p', 'l', Binding}, Payload).

reg_property(Binding, Value) ->
    gproc:reg({'p', 'l', Binding}, Value).

unreg_property(Binding) ->
    gproc:unreg({'p', 'l', Binding}).
