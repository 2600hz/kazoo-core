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
-module(kzv_owners_by_docid_type).

-export([find/3]).
-export([find_one/2, find_one/3, find_one/4]).
-export([find_all/2, find_all/3, find_all/4]).
-export([find_keys/3, find_keys/4]).
-export([find_range/6]).

-define(VIEW_NAME, <<"crossbar_listings/owners_by_docid_type">>).


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
%% @doc Find the first result with DocId.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, DocId, Options) ->
    Selector = range_selector(DocId, 'undefined', DocId, 'undefined'),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find the first result with DocId, DocType.
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_one(Database, DocId, DocType, Options) ->
    Selector = key_selector(DocId, DocType),
    kz_view:find_one(Database, ?VIEW_NAME, Selector, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find all.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, Options) ->
    kz_view:find(Database, ?VIEW_NAME, [], set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find all with DocId.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, DocId, Options) ->
    Selector = range_selector(DocId, 'undefined', DocId, 'undefined'),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc Find all with DocId, DocType.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, DocId, DocType, Options) ->
    Selector = key_selector(DocId, DocType),
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
%% @doc Find keys for DocType with proplists of DocId.
%% @end
%%------------------------------------------------------------------------------
-spec find_keys(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binaries() | kz_term:proplists(), kz_view:options()) -> kz_view:result().
find_keys(Database, DocType, [<<_/binary>> | _]=DocIds, Options) ->
    Props = [selector(DocId, DocType)
             || DocId <- DocIds
            ],
    find_keys(Database, Props, set_options(Options, DocType));
find_keys(Database, DocType, Props0, Options) ->
    Props = [props:insert_value(<<"doc_type">>, DocType, Prop)
             || Prop <- Props0
            ],
    find_keys(Database, Props, set_options(Options, DocType)).

%%------------------------------------------------------------------------------
%% @doc Find all docs in range.
%% @end
%%------------------------------------------------------------------------------
-spec find_range(kz_term:ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_view:options()) -> kz_view:result().
find_range(Database, StartDocId, StartDocType, EndDocId, EndDocType, Options) ->
    Selector = range_selector(StartDocId, StartDocType, EndDocId, EndDocType),
    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
selector(DocId, DocType) ->
    props:filter_undefined(
      [{<<"doc_id">>, DocId}
      ,{<<"doc_type">>, DocType}
      ]).

key_selector(DocId, DocType) ->
    [{'key', selector(DocId, DocType)}].

keys_selector(Props) ->
    [{'keys', Props}].

range_selector(StartDocId, StartDocType, EndDocId, EndDocType) ->
    [{'start', selector(StartDocId, StartDocType)}
    ,{'end', selector(EndDocId, EndDocType)}
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
