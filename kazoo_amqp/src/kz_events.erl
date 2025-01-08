%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_events).

-export([start_call_events/0, start_link_call_events/0
        ,stop_call_events/0
        ,restart_call_events/0
        ,bind_call_id/1, bind_call_id/2
        ,unbind_call_id/1, unbind_call_id/2
        ,call_event_binding/2
        ,add_async_call_event_handler/3
        ,delete_async_call_event_handler/3
        ]).

-export([start_conf_events/0, start_link_conf_events/0
        ,stop_conf_events/0
        ,restart_conf_events/0
        ,bind_conf_changes/4
        ,unbind_conf_changes/4
        ,conf_event_binding/4
        ]).

-export([start_presence_events/0, start_link_presence_events/0
        ,stop_presence_events/0
        ,restart_presence_events/0
        ,bind_presence_id/1
        ,unbind_presence_id/1
        ,presence_event_binding/1
        ]).

-export([publish_event/3]).

-export_type([call_id/0
             ,call_event_name/0
             ,call_event_names/0

             ,action/0
             ,db/0
             ,doc_type/0
             ,doc_id/0

             ,presence_id/0

             ,handler/0
             ]).

-include("kazoo_events.hrl").

-type bindings() :: [binding_call_id() | binding_conf_change() | binding_presence_id()].

-type call_id() :: kz_term:ne_binary().
-type call_event_name() :: kz_term:ne_binary().
-type call_event_names() :: [call_event_name()].
-type binding_call_id() :: {'call_events', call_id(), call_event_name()}.

-type action() :: kapi_conf:action_binary().
-type db() :: kz_term:ne_binary().
-type doc_type() :: kz_term:ne_binary().
-type doc_id() :: kz_term:ne_binary().
-type binding_conf_change() :: {'conf', action(), db(), doc_type(), doc_id()}.

-type presence_id() :: kz_term:ne_binary() | '_'.
-type binding_presence_id() :: {'presence', presence_id()}.

-type handler() :: {module(), kazoo_bindings:responder_fun(), kazoo_bindings:payload()} |
                   kazoo_bindings:responder_fun().
-type payload() :: {'kapi', kapi:delivery_message(kz_json:object())}.

%%------------------------------------------------------------------------------
%% @doc Get the representation of a call event binding. Both `CallId' and
%% `EventName' can be `<<"*">>' to match any value.
%% @end
%%------------------------------------------------------------------------------
-spec call_event_binding(call_id(), call_event_name()) -> binding_call_id().
call_event_binding(CallId, EventName) ->
    {'call_events', CallId, EventName}.

%% @doc starts pool of listeners for call events
-spec start_call_events() -> 'ok'.
start_call_events() ->
    maybe_start_call_events(is_call_events_started()).

-spec stop_call_events() -> 'ok'.
stop_call_events() ->
    stop_call_events(is_call_events_started()).

-spec stop_call_events(boolean()) -> 'ok'.
stop_call_events('false') -> 'ok';
stop_call_events('true') ->
    kz_event_listeners_sup:stop_pool('call_events').

-spec restart_call_events() -> 'ok'.
restart_call_events() ->
    stop_call_events(),
    start_call_events().

is_call_events_started() ->
    kz_event_listeners_sup:pool_exists('call_events').

maybe_start_call_events() ->
    maybe_start_call_events(is_call_events_started()).

maybe_start_call_events('false') ->
    _ = kz_event_listeners_sup:start_pool('call_events'),
    'ok';
maybe_start_call_events('true') -> 'ok'.

%% @equiv bind_call_id(CallId, [<<"*">>])
-spec bind_call_id(call_id()) -> 'ok'.
bind_call_id(CallId) ->
    bind_call_id(CallId, [<<"*">>]).

%%------------------------------------------------------------------------------
%% @doc Bind for pooled call events.
%% @end
%%------------------------------------------------------------------------------
-spec bind_call_id(call_id(), call_event_names()) -> 'ok'.
bind_call_id(CallId, EventNames) ->
    maybe_start_call_events(),
    _ = [reg_property(call_event_binding(CallId, EventName), self())
         || EventName <- EventNames
        ],
    'ok'.

%% @equiv unbind_call_id(CallId, [<<"*">>])
-spec unbind_call_id(call_id()) -> 'ok'.
unbind_call_id(CallId) ->
    unbind_call_id(CallId, [<<"*">>]).

%%------------------------------------------------------------------------------
%% @doc Unbind from pooled call events.
%% @end
%%------------------------------------------------------------------------------
-spec unbind_call_id(call_id(), call_event_names()) -> 'ok'.
unbind_call_id(CallId, EventNames) ->
    _ = [unreg_property(call_event_binding(CallId, EventName))
         || EventName <- EventNames
        ],
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Add a handler that is invoked asynchronously when a call event matching
%% `AccountId' and `EventName' is received.
%% @end
%%------------------------------------------------------------------------------
-spec add_async_call_event_handler(kz_term:ne_binary(), kz_term:ne_binary(), handler()) ->
          kazoo_bindings:bind_result().
add_async_call_event_handler(AccountId, EventName, Handler) ->
    add_async_handler('call_events', [AccountId, EventName], Handler).

%%------------------------------------------------------------------------------
%% @doc Delete a previously-added asynchronous call event handler.
%% @end
%%------------------------------------------------------------------------------
-spec delete_async_call_event_handler(kz_term:ne_binary(), kz_term:ne_binary(), handler()) ->
          kazoo_bindings:unbind_result().
delete_async_call_event_handler(AccountId, EventName, Handler) ->
    delete_async_handler('call_events', [AccountId, EventName], Handler).

%%------------------------------------------------------------------------------
%% @doc Get the representation of a configuration event binding.
%% @end
%%------------------------------------------------------------------------------
-spec conf_event_binding(action(), db(), doc_type(), doc_id()) -> binding_conf_change().
conf_event_binding(Action, Db, DocType, DocId) ->
    {'conf', Action, Db, DocType, DocId}.

-spec start_conf_events() -> 'ok'.
start_conf_events() ->
    maybe_start_conf_events(is_conf_events_started()).

-spec stop_conf_events() -> 'ok'.
stop_conf_events() ->
    stop_conf_events(is_conf_events_started()).

-spec stop_conf_events(boolean()) -> 'ok'.
stop_conf_events('false') -> 'ok';
stop_conf_events('true') ->
    kz_event_listeners_sup:stop_pool('conf').

-spec restart_conf_events() -> 'ok'.
restart_conf_events() ->
    stop_conf_events(),
    start_conf_events().

-spec is_conf_events_started() -> boolean().
is_conf_events_started() ->
    kz_event_listeners_sup:pool_exists('conf').

-spec maybe_start_conf_events() -> 'ok'.
maybe_start_conf_events() ->
    maybe_start_conf_events(is_conf_events_started()).

-spec maybe_start_conf_events(boolean()) -> 'ok'.
maybe_start_conf_events('false') ->
    _ = kz_event_listeners_sup:start_pool('conf'),
    'ok';
maybe_start_conf_events('true') -> 'ok'.

-spec bind_conf_changes(action(), db(), doc_type(), doc_id()) -> 'ok'.
bind_conf_changes(Action, Db, DocType, DocId) ->
    maybe_start_conf_events(),
    _ = reg_property(conf_event_binding(Action, Db, DocType, DocId), self()),
    'ok'.

-spec unbind_conf_changes(action(), db(), doc_type(), doc_id()) -> 'ok'.
unbind_conf_changes(Action, Db, DocType, DocId) ->
    unreg_property(conf_event_binding(Action, Db, DocType, DocId)),
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Get the representation of a presence event binding.
%% @end
%%------------------------------------------------------------------------------
-spec presence_event_binding(presence_id()) -> binding_presence_id().
presence_event_binding(PresenceId) ->
    {'presence', PresenceId}.

%% @doc starts pool of listeners for call events
-spec start_presence_events() -> 'ok'.
start_presence_events() ->
    maybe_start_presence_events(is_presence_events_started()).

-spec stop_presence_events() -> 'ok'.
stop_presence_events() ->
    stop_presence_events(is_presence_events_started()).

-spec stop_presence_events(boolean()) -> 'ok'.
stop_presence_events('false') -> 'ok';
stop_presence_events('true') ->
    kz_event_listeners_sup:stop_pool('presence').

-spec restart_presence_events() -> 'ok'.
restart_presence_events() ->
    stop_presence_events(),
    start_presence_events().

is_presence_events_started() ->
    kz_event_listeners_sup:pool_exists('presence').

maybe_start_presence_events() ->
    maybe_start_presence_events(is_presence_events_started()).

maybe_start_presence_events('false') ->
    _ = kz_event_listeners_sup:start_pool('presence'),
    'ok';
maybe_start_presence_events('true') -> 'ok'.

-spec bind_presence_id(kz_term:ne_binary()) -> 'ok'.
bind_presence_id(PresenceId) ->
    maybe_start_presence_events(),
    _ = reg_property(presence_event_binding(PresenceId), self()),
    'ok'.

-spec unbind_presence_id(kz_term:ne_binary()) -> 'ok'.
unbind_presence_id(PresenceId) ->
    unreg_property(presence_event_binding(PresenceId)),
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Add a handler that is invoked asynchronously when an event matching the
%% binding key (based on `EventType' and `Args') is received.
%% @end
%%------------------------------------------------------------------------------
-spec add_async_handler(event_type(), list(), handler()) -> kazoo_bindings:bind_result().
add_async_handler(EventType, Args, Handler) ->
    BindingKey = binding_key(EventType, Args),
    case Handler of
        {M, F, A} -> kazoo_bindings:bind(BindingKey, M, F, A);
        _ -> kazoo_bindings:bind(BindingKey, Handler)
    end.

%%------------------------------------------------------------------------------
%% @doc Delete a previously-added asynchronous event handler.
%% @end
%%------------------------------------------------------------------------------
-spec delete_async_handler(event_type(), list(), handler()) -> kazoo_bindings:unbind_result().
delete_async_handler(EventType, Args, Handler) ->
    BindingKey = binding_key(EventType, Args),
    case Handler of
        {M, F, A} -> kazoo_bindings:unbind(BindingKey, M, F, A);
        _ -> kazoo_bindings:unbind(BindingKey, Handler)
    end.

%%------------------------------------------------------------------------------
%% @doc Publish a pooled event.
%% @end
%%------------------------------------------------------------------------------
-spec publish_event(kz_json:object(), kz_term:proplist(), event_type()) -> 'ok'.
publish_event(JObj, Props, 'call_events'=EventType) ->
    Bindings = [call_event_binding(CallId, EventName)
                || CallId    <- [<<"*">>, kz_call_event:call_id(JObj)],
                   EventName <- [<<"*">>, kz_api:event_name(JObj)]
               ],
    publish_event(JObj, Props, EventType, Bindings);
publish_event(JObj, Props, 'conf'=EventType) ->
    Bindings = [conf_event_binding(Action, Db, DocType, DocId)
                || Action  <- [<<"*">>, kz_api:event_name(JObj)],
                   Db      <- [<<"*">>, kapi_conf:get_database(JObj)],
                   DocType <- [<<"*">>, kapi_conf:get_type(JObj)],
                   DocId   <- [<<"*">>, kapi_conf:get_id(JObj)]
               ],
    publish_event(JObj, Props, EventType, Bindings);
publish_event(JObj, Props, 'presence'=EventType) ->
    PresenceId = kz_json:get_ne_binary_value(<<"Presence-ID">>, JObj),
    Bindings = [presence_event_binding(PresenceId)],
    publish_event(JObj, Props, EventType, Bindings).

%%------------------------------------------------------------------------------
%% @doc Publish a pooled event. The event is first distributed asynchronously to
%% matching async event handlers, then sent to bound procs (i.e. `gen_listener's
%% with pooled bindings).
%% @end
%%------------------------------------------------------------------------------
-spec publish_event(kz_json:object(), kz_term:proplist(), event_type(), bindings()) -> 'ok'.
publish_event(JObj, Props, EventType, Bindings) ->
    handle_async(EventType, JObj),
    send_event(Bindings, {'kapi', kapi:delivery_message(JObj, Props)}).

%%------------------------------------------------------------------------------
%% @doc Asynchronously distribute an event to matching async event handlers.
%% @end
%%------------------------------------------------------------------------------
-spec handle_async(event_type() | kz_term:ne_binary(), kz_json:object()) -> 'ok'.
handle_async(BindingKey, JObj) when is_binary(BindingKey) ->
    _ = kz_process:spawn(fun() -> kazoo_bindings:pmap(BindingKey, JObj) end),
    'ok';
handle_async('call_events'=EventType, JObj) ->
    BindingKey = binding_key(EventType, [kz_call_event:account_id(JObj)
                                        ,kz_api:event_name(JObj)
                                        ]),
    handle_async(BindingKey, JObj);
handle_async('conf'=EventType, JObj) ->
    BindingKey = binding_key(EventType, [kz_api:event_name(JObj)
                                        ,kapi_conf:get_database(JObj)
                                        ,kapi_conf:get_type(JObj)
                                        ,kapi_conf:get_id(JObj)
                                        ]),
    handle_async(BindingKey, JObj);
handle_async('presence'=EventType, JObj) ->
    BindingKey = binding_key(EventType, []),
    handle_async(BindingKey, JObj).

%%------------------------------------------------------------------------------
%% @doc Send an event to all procs bound to any of the given bindings.
%% @end
%%------------------------------------------------------------------------------
-spec send_event(bindings(), payload()) -> 'ok'.
send_event(Bindings, Payload) ->
    Pids = lists:usort([Pid || Binding <- Bindings,
                               Pid <- gproc:lookup_pids({'p', 'l', Binding})
                       ]),
    log(Pids, Payload),
    lists:foreach(fun(Pid) -> Pid ! Payload end, Pids).

-spec log(kz_term:pids(), payload()) -> 'ok'.
log([], _) -> 'ok';
log(Pids, {'kapi', {{Exchange, RK, _}, {Category, Event}, _}}) ->
    _ = lager:debug("sending ~s/~s/~s (~s) to ~p", [Exchange, Category, Event, RK, Pids]),
    'ok'.

reg_property(Binding, Value) ->
    gproc:ensure_reg({'p', 'l', Binding}, Value).

unreg_property(Binding) ->
    gproc:unreg({'p', 'l', Binding}).

%%------------------------------------------------------------------------------
%% @doc Get the handler binding key for the given event type and extra handler
%% args.
%% @end
%%------------------------------------------------------------------------------
-spec binding_key(event_type(), list()) -> kz_term:ne_binary().
binding_key(EventType, Args) ->
    kz_binary:join([<<?MODULE_STRING>>, kz_term:to_binary(EventType) | Args], <<".">>).

-spec start_link_call_events() -> ignore.
start_link_call_events() ->
    start_call_events(),
    ignore.

-spec start_link_presence_events() -> ignore.
start_link_presence_events() ->
    start_presence_events(),
    ignore.

-spec start_link_conf_events() -> ignore.
start_link_conf_events() ->
    start_conf_events(),
    ignore.
