%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2024, 2600Hz
%%% @doc Listens for a list of events and gproc-sends them out to folks who
%%% want them
%%%
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_call_events).

-export([start_link/0
        ,handle_event/1
        ,is_destroyed/1, is_destroyed/2
        ,get_event/1, get_event/2
        ]).

-include("kapps_call_command.hrl").

-define(EXPIRES_S, 30).

-spec start_link() -> 'ignore'.
start_link() ->
    _ = kz_hooks:bind(<<"*">>, <<"CHANNEL_DESTROY">>, {?MODULE, 'handle_event', []}),
    'ignore'.

-spec handle_event(kz_call_event:payload()) -> 'ok'.
handle_event(EventJObj) ->
    Keys = [kz_call_event:call_id(EventJObj)
           ,{kz_call_event:call_id(EventJObj), kz_call_event:switch_nodename(EventJObj)}
           ],
    lists:foreach(fun(Key) -> cache_entry(Key, EventJObj) end, Keys).

-spec cache_entry(kz_term:ne_binary() | {kz_term:ne_binary(), kz_term:ne_binary()}, any()) -> ok | error.
cache_entry(Key, Value) ->
    kz_cache:store_local(?KAPPS_CALL_CACHE, {?MODULE, Key}, Value, [{'expires', ?EXPIRES_S}]).

-spec is_destroyed(kapps_call:call() | kz_term:ne_binary()) -> boolean().
is_destroyed(Call) ->
    {'error', 'not_found'} =/= get_event(Call).

-spec is_destroyed(kz_term:ne_binary(), kz_term:ne_binary()) -> boolean().
is_destroyed(<<CallId/binary>>, <<MediaNode/binary>>) ->
    {'error', 'not_found'} =/= get_event(CallId, MediaNode).

-spec get_event(kapps_call:call() | kz_term:ne_binary()) -> {'ok', any()} | {'error', 'not_found'}.
get_event(<<CallId/binary>>) ->
    kz_cache:peek_local(?KAPPS_CALL_CACHE, {?MODULE, CallId});
get_event(Call) ->
    get_event(kapps_call:call_id(Call), kapps_call:switch_nodename(Call)).

-spec get_event(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', any()} | {'error', 'not_found'}.
get_event(<<CallId/binary>>, <<MediaNode/binary>>) ->
    kz_cache:peek_local(?KAPPS_CALL_CACHE, {?MODULE, {CallId, MediaNode}}).
