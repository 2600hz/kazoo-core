%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2024, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzv_endpoints_lookup).

-export([find/3]).
-export([find_one/2, find_one/3, find_one/4]).
-export([find_all/2, find_all/3, find_all/4]).
-export([find_keys/3]).
-export([find_range/6]).

-define(VIEW_NAME, <<"crossbar_listings/endpoints_lookup">>).


%%------------------------------------------------------------------------------
%% @doc Find a key with proplist.
%% @end
%%------------------------------------------------------------------------------
-spec find(kz_term:ne_binary(), kz_term:proplist(), kz_view:options()) -> kz_view:result().
find(Database, [], Options) ->
    find_all(Database, Options);
find(Database, [{<<_/binary>>, _}|_]=Prop, Options) ->
    Selector = [{'key', Prop}],
    kz_view:find(Database, ?VIEW_NAME, Selector, maybe_set_options(Prop, Options));
find(Database, [[{<<_/binary>>, _} | _] | _]=Props, Options) ->
    Selector = [{'keys', Props}],
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options));
find(Database, Selector, Options) ->
    kz_view:find(Database, ?VIEW_NAME, Selector, maybe_set_options(Selector, Options)).

%%------------------------------------------------------------------------------
%% @doc Find the first result.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, Options) ->
    kz_view:find_one(Database, ?VIEW_NAME, [], set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find the first result with CallerIdNumber.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, CallerIdNumber, Options) ->
    Selector = range_selector(CallerIdNumber, 'undefined', CallerIdNumber, 'undefined'),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find the first result with CallerIdNumber, CallerIdType.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, CallerIdNumber, CallerIdType, Options) ->
    Selector = key_selector(CallerIdNumber, CallerIdType),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find all.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, Options) ->
    kz_view:find(Database, ?VIEW_NAME, [], set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find all with CallerIdNumber.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, CallerIdNumber, Options) ->
    Selector = range_selector(CallerIdNumber, 'undefined', CallerIdNumber, 'undefined'),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find all with CallerIdNumber, CallerIdType.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, CallerIdNumber, CallerIdType, Options) ->
    Selector = key_selector(CallerIdNumber, CallerIdType),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find keys.
%% @end
%%------------------------------------------------------------------------------
-spec find_keys(kz_term:ne_binary(), kz_term:proplists(), kz_view:options()) -> kz_view:result().
find_keys(Database, Props, Options) ->
    Selector = keys_selector(Props),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find all docs in range.
%% @end
%%------------------------------------------------------------------------------
-spec find_range(kz_term:ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_view:options()) -> kz_view:result().
find_range(Database, StartCallerIdNumber, StartCallerIdType, EndCallerIdNumber, EndCallerIdType, Options) ->
    Selector = range_selector(StartCallerIdNumber, StartCallerIdType, EndCallerIdNumber, EndCallerIdType),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
selector(CallerIdNumber, CallerIdType) ->
    props:filter_undefined(
      [{<<"caller_id_number">>, CallerIdNumber}
      ,{<<"caller_id_type">>, CallerIdType}
      ]).

key_selector(CallerIdNumber, CallerIdType) ->
    [{'key', selector(CallerIdNumber, CallerIdType)}].

keys_selector(Props) ->
    [{'keys', Props}].

range_selector(StartCallerIdNumber, StartCallerIdType, EndCallerIdNumber, EndCallerIdType) ->
    [{'start', selector(StartCallerIdNumber, StartCallerIdType)}
    ,{'end', selector(EndCallerIdNumber, EndCallerIdType)}
    ].

maybe_set_options(_, Options) ->
    set_options(Options).

set_options(Options) -> Options.
