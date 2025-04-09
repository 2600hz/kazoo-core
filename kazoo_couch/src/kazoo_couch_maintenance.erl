%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_couch_maintenance).

-include("kz_couch.hrl").

-export([get_read/0
        ,get_write/0
        ,set_read/1
        ,set_write/1
        ,unset_read/0
        ,unset_write/0
        ]).

-define(SECTION_CONFIG, kz_dataconfig:get_config_section()).

-spec get_read() -> 'ok'.
get_read() -> get_config_val(<<"read">>).

-spec get_write() -> 'ok'.
get_write() -> get_config_val(<<"write">>).

get_config_val(Config) ->
    Section = ?SECTION_CONFIG,
    case kz_config:get_integer(Section, Config) of
        [] ->
            io:format("~s value empty in section ~s ~n", [Config, Section]);
        [Value] ->
            io:format("~s value: ~p ~n", [Config, Value])
    end.

-spec set_read(kz_term:text() | integer()) -> 'ok'.
set_read(Value) when is_integer(Value) ->
    Section = ?SECTION_CONFIG,
    io:format("setting ~s read value to ~p ~n", [Section, Value]),
    kz_config:set(Section, <<"read">>, Value);
set_read(Value) when is_binary(Value) ->
    set_read(kz_term:to_integer(Value)).

-spec set_write(kz_term:text() | integer()) -> 'ok'.
set_write(Value) when is_integer(Value) ->
    Section = ?SECTION_CONFIG,
    io:format("setting ~s write value to ~p ~n", [Section, Value]),
    kz_config:set(Section, <<"write">>, Value);
set_write(Value) when is_binary(Value) ->
    set_write(kz_term:to_integer(Value)).

-spec unset_read() -> 'ok'.
unset_read() ->
    Section = ?SECTION_CONFIG,
    io:format("unsetting ~s read value ~n", [Section]),
    kz_config:unset(Section, <<"read">>).

-spec unset_write() -> 'ok'.
unset_write() ->
    Section = ?SECTION_CONFIG,
    io:format("unsetting ~s write value ~n", [Section]),
    kz_config:unset(Section, <<"write">>).
