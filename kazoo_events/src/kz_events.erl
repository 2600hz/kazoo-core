%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_events).

-export([bind_call_id/1, unbind_call_id/1]).

-include("kazoo_events.hrl").

-spec bind_call_id(kz_term:ne_binary()) -> 'ok'.
bind_call_id(CallId) ->
    gproc:reg({'p', 'l', {'call_event', CallId}}).

-spec unbind_call_id(kz_term:ne_binary()) -> 'ok'.
unbind_call_id(CallId) ->
    gproc:unreg({'p', 'l', {'call_event', CallId}}).
