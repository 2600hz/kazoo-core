%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Preforms maintenance operations against the stepswitch dbs
%%% @author Karl Anderson
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_cnam_maintenance).

-export([flush/0
        ,flush/1
        ]).

-include("cnam.hrl").

%%------------------------------------------------------------------------------
%% @doc Flush the stepswitch local cache
%% @end
%%------------------------------------------------------------------------------
-spec flush() -> 'ok'.
flush() ->
    io:format("flushed ~p entries from cnam cache~n", [cnam:flush()]).

-spec flush(kz_term:ne_binary()) -> 'ok'.
flush(Number) ->
    cnam:flush(Number),
    io:format("flushed ~s from cnam cache~n", [Number]).
