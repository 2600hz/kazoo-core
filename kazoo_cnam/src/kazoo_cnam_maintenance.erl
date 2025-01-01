%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
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
        ,info/0
        ,lookup/1
        ]).

-include("cnam.hrl").

-elvis([{elvis_style, no_debug_call, disable}]).

%%------------------------------------------------------------------------------
%% @doc Flush the stepswitch local cache
%% @end
%%------------------------------------------------------------------------------
-spec flush() -> 'ok'.
flush() ->
    io:format("flushed ~p entries from cnam cache~n", [cnam:flush()]).

-spec info() -> 'ok'.
info() ->
    info(kapps_config:get_all_kvs(?CNAM_CONFIG_CAT)).

info([]) ->
    io:format("no CNAM provider configured~n");
info(KVs) ->
    io:format("CNAM settings in play:~n"),
    _ = [print_info(K, V) || {K, V} <- lists:sort(KVs)],
    'ok'.

print_info(K, V) ->
    io:format(" ~-25s | ~s~n", [kz_term:to_binary(K), kz_term:to_binary(V)]).

-spec lookup(kz_term:ne_binary()) -> 'no_return'.
lookup(Number) ->
    CNAM = cnam:lookup(Number),
    case kz_json:get_ne_binary_value(<<"Caller-ID-Name">>, CNAM) of
        'undefined' -> io:format("CNAM lookup for ~s has no result~n", [Number]);
        CIDName -> io:format("CNAM lookup for ~s has result '~s'~n", [Number, CIDName])
    end,
    'no_return'.
