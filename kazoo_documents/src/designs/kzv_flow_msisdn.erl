%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzv_flow_msisdn).

-export([find/3]).
-export([find_one/2, find_one/3, find_one/4, find_one/5, find_one/6]).
-export([find_all/2, find_all/3, find_all/4, find_all/5, find_all/6]).
-export([find_keys/3, find_keys/4]).
-export([find_range/10]).

-define(VIEW_NAME, <<"crossbar_listings/flow_msisdn">>).


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
%% @doc Find the first result with DocType.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, DocType, Options) ->
    Selector = range_selector(DocType, 'undefined', 'undefined', 'undefined', DocType, 'undefined', 'undefined', 'undefined'),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find the first result with DocType, Module.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, DocType, Module, Options) ->
    Selector = range_selector(DocType, Module, 'undefined', 'undefined', DocType, Module, 'undefined', 'undefined'),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find the first result with DocType, Module, DataId.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, DocType, Module, DataId, Options) ->
    Selector = range_selector(DocType, Module, DataId, 'undefined', DocType, Module, DataId, 'undefined'),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find the first result with DocType, Module, DataId, Number.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, DocType, Module, DataId, Number, Options) ->
    Selector = key_selector(DocType, Module, DataId, Number),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find all.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, Options) ->
    kz_view:find(Database, ?VIEW_NAME, [], set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find all with DocType.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, DocType, Options) ->
    Selector = range_selector(DocType, 'undefined', 'undefined', 'undefined', DocType, 'undefined', 'undefined', 'undefined'),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find all with DocType, Module.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, DocType, Module, Options) ->
    Selector = range_selector(DocType, Module, 'undefined', 'undefined', DocType, Module, 'undefined', 'undefined'),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find all with DocType, Module, DataId.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, DocType, Module, DataId, Options) ->
    Selector = range_selector(DocType, Module, DataId, 'undefined', DocType, Module, DataId, 'undefined'),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find all with DocType, Module, DataId, Number.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, DocType, Module, DataId, Number, Options) ->
    Selector = key_selector(DocType, Module, DataId, Number),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find keys.
%% @end
%%------------------------------------------------------------------------------
-spec find_keys(kz_term:ne_binary(), kz_term:proplists(), kz_view:options()) -> kz_view:result().
find_keys(Database, Props, Options) ->
    Selector = keys_selector(Props),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find keys for DocType with proplists of Module, DataId, Number.
%% @end
%%------------------------------------------------------------------------------
-spec find_keys(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplists(), kz_view:options()) -> kz_view:result().
find_keys(Database, DocType, Props0, Options) ->
    Props = [props:insert_value(<<"doc_type">>, DocType, Prop)
             || Prop <- Props0
            ],
    find_keys(Database, Props, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find all docs in range.
%% @end
%%------------------------------------------------------------------------------
-spec find_range(kz_term:ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_view:options()) -> kz_view:result().
find_range(Database, StartDocType, StartModule, StartDataId, StartNumber, EndDocType, EndModule, EndDataId, EndNumber, Options) ->
    Selector = range_selector(StartDocType, StartModule, StartDataId, StartNumber, EndDocType, EndModule, EndDataId, EndNumber),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
selector(DocType, Module, DataId, Number) ->
    props:filter_undefined(
      [{<<"doc_type">>, DocType}
      ,{<<"module">>, Module}
      ,{<<"data_id">>, DataId}
      ,{<<"number">>, Number}
      ]).

key_selector(DocType, Module, DataId, Number) ->
    [{'key', selector(DocType, Module, DataId, Number)}].

keys_selector(Props) ->
    [{'keys', Props}].

range_selector(StartDocType, StartModule, StartDataId, StartNumber, EndDocType, EndModule, EndDataId, EndNumber) ->
    [{'start', selector(StartDocType, StartModule, StartDataId, StartNumber)}
    ,{'end', selector(EndDocType, EndModule, EndDataId, EndNumber)}
    ].

maybe_set_options([{'key', Prop}], Options) ->
    set_options(Options, props:get_value(<<"doc_type">>, Prop));
maybe_set_options([{<<_/binary>>, _} | _]=Prop, Options) ->
    set_options(Options, props:get_value(<<"doc_type">>, Prop));
maybe_set_options(_, Options) ->
    set_options(Options).

set_options(Options) -> Options.
set_options(Options, Type) ->
    DocType = props:get_value('doc_type', Options, Type),
    props:set_value('doc_type', DocType, Options).
