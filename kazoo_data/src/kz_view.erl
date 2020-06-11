%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_view).

-export([find/2, find/3, find/4]).
-export([find_one/2, find_one/3, find_one/4]).
-export([find_batch/2, find_batch/3, find_batch/4]).

-export([apply_filtermap/2]).

%% deprecated, use {@link kz_term:high_unicode_value/0)}
-export([high_unicode_value/0]).

-include("kz_data.hrl").

-type direction() :: 'ascending' | 'descending'.
-type limit() :: non_neg_integer() | 'infinity'.
-type bookmark() :: kz_term:proplist() | map() | binary() | 'undefined' | any().
-type result_key() :: kz_term:ne_binary() | kz_json:path(). %% like `<<"key">>', `<<"id">>', `<<"value">>' and `<<"doc">>'

-type options() :: [couch_view_options() |
                    {'batch_size', limit()} |
                    {'bookmark', bookmark()} |
                    {'databases', kz_term:ne_binaries()} |
                    {'direction', direction()} |
                    {'doc_type', kz_term:ne_binary()} |
                    {'filtermap', filtermap_fun() | result_key()} |
                    {'first_when_multiple', boolean()} |
                    {'memory_limit', 'false' | pos_integer()} |
                    {'no_batch', boolean()} |
                    {'no_design_module', boolean()} |
                    {'page_size', limit()} |
                    {'reductions_max', pos_integer()} |
                    {'result_key', result_key()} |
                    {'user_params', any()} |
                    {'verbose_log', 'console' |
                     'undefined' |
                     'user' |
                     atom() | %% Severity
                     boolean() |
                     {atom(), atom()} %% {Sink, Severity}
                    } | %% control how to log, critical errors are always reported using default sink with error severity.
                    {'lager_md', kz_term:proplist()} |
                    {'lager_prefix', string() | binary()} |

                    %% static options
                    {'db_classification', db_classification()} |

                    %% other_options
                    {atom() | kz_term:ne_binary(), any()}
                   ].

-type selector() :: [] |
                    [{'key', kz_term:proplist()}] |
                    [{'keys', kz_term:proplists()}] |
                    [{'start', kz_term:proplist()} |
                     {'end', kz_term:proplist()}
                    ].

-type result_value() :: kz_json:objects() | kz_json:path().
-type result() :: kz_either:either(error(), result_value()).
-type single_result() :: kz_either:either(any(), kz_json:object()).

-type filtermap_ret() :: 'false' | 'true' | {'true', kz_json:object()} | {'error', error()} | kz_json:objects().
-type filtermap_fun() :: fun((kz_json:objects()) -> 'false' | 'true' | {'error', error()} | kz_json:objects()) |
                         fun((kz_json:object(), result_value()) -> filtermap_ret()) |
                         fun((kz_view_cursor:cursor(), kz_json:object(), kz_json:objects()) -> filtermap_ret()) |
                         {fun((any(), kz_json:object(), kz_json:objects()) -> filtermap_ret()), any()}.

-type error() :: kazoo_data:db_errors().

-export_type([bookmark/0
             ,direction/0
             ,error/0
             ,limit/0
             ,options/0
             ,filtermap_fun/0
             ,result_value/0
             ,result/0
             ,single_result/0
             ,selector/0
             ]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec find(kz_term:ne_binary(), ddoc()) -> result().
find(DbName, DesignDoc) ->
    find(DbName, DesignDoc, []).

-spec find(kz_term:ne_binary(), ddoc(), selector()) -> result().
find(DbName, DesignDoc, Selector) ->
    find(DbName, DesignDoc, Selector, []).

-spec find(kz_term:ne_binary(), any(), selector(), options()) -> result().
find(DbName, DesignDoc, Selector, Options) ->
    lager(Options),
    ?MAYBE_LOG("~s:find(~100p, ~100p, ~1000p, ~1000p)", [?MODULE, DbName, DesignDoc, Selector, Options]),
    case find_batch(DbName, DesignDoc, Selector, Options) of
        {'ok', Cursor} ->
            case find_next(Cursor) of
                {'ok', _}=OK -> OK;
                {'error', 'not_found'} ->
                    maybe_create_view(Cursor, DbName, DesignDoc);
                {'error', _}=Error -> Error
            end;
        {'error', _}=Error ->
            Error
    end.

maybe_create_view(#{'other_options' := Options}=Cursor, DbName, DesignDoc) ->
    Database = kzs_util:to_database(DbName),
    Plan = kzs_plan:plan(Database, Options),
    kz_either:bind(kz_datamgr:maybe_create_view(Plan, Database, DesignDoc, Options)
                  ,fun(_) -> find_next(Cursor) end
                  ).

%% @private
-spec find_next(kz_view_cursor:cursor()) -> result().
find_next(Cursor) ->
    kz_either:bind(kz_view_cursor:next(Cursor)
                  ,fun({_, Result}) -> {'ok', Result} end
                  ).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec find_one(kz_term:ne_binary(), ddoc()) -> result().
find_one(DbName, DesignDoc) ->
    find_one(DbName, DesignDoc, []).

-spec find_one(kz_term:ne_binary(), ddoc(), selector()) -> result().
find_one(DbName, DesignDoc, Selector) ->
    find_one(DbName, DesignDoc, Selector, []).

-spec find_one(kz_term:ne_binary(), ddoc(), selector(), options()) -> result().
find_one(DbName, DesignDoc, Selector, Options) ->
    lager(Options),
    ?MAYBE_LOG("~s:find_one(~100p, ~100p, ~1000p, ~1000p)", [?MODULE, DbName, DesignDoc, Selector, Options]),
    case find(DbName, DesignDoc, Selector, Options) of
        {'ok', [Result]} -> {'ok', Result};
        {'ok', []} -> {'error', 'not_found'};
        {'ok', [Result | _]} ->
            case props:is_true('first_when_multiple', Options, 'false') of
                'true' -> {'ok', Result};
                'false' -> {'error', 'multiple_results'}
            end;
        {'error', _}=E -> E
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec find_batch(kz_term:ne_binary(), ddoc()) -> result().
find_batch(DbName, DesignDoc) ->
    find_batch(DbName, DesignDoc, []).

-spec find_batch(kz_term:ne_binary(), ddoc(), selector()) -> result().
find_batch(DbName, DesignDoc, Selector) ->
    find_batch(DbName, DesignDoc, Selector, []).

-spec find_batch(kz_term:ne_binary(), ddoc(), selector(), options()) -> kz_either:either(any(), kz_view_cursor:cursor()).
find_batch(DbName, DesignDoc, Selector, Options) ->
    lager(Options),
    ?MAYBE_LOG("~s:find_batch(~100p, ~100p, ~1000p, ~1000p)", [?MODULE, DbName, DesignDoc, Selector, Options]),
    case build_query(DbName, DesignDoc, Selector, Options) of
        {'ok', {#{server := {App, Conn}}=_Plan, Database, NormSelector, NewOptions}} ->
            App:find(Conn, Database, DesignDoc, NormSelector, NewOptions);
        {'error', _}=Error ->
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @deprecated Please use the module {@link kz_term:high_unicode_value/0} instead.
%% @end
%%------------------------------------------------------------------------------
-spec high_unicode_value() -> kz_term:ne_binary().
high_unicode_value() -> kz_term:high_unicode_value().

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
build_query(DbName, DesignDoc, Selector, Options) ->
    case normalize_selector(Selector) of
        {'ok', NormSelector} ->
            Database = kzs_util:to_database(DbName),
            NewOptions = build_options(DbName, DesignDoc, Options),
            Plan = kzs_plan:plan(Database, NewOptions),
            {'ok', {Plan, Database, NormSelector, NewOptions}};
        {'error', _}=Error ->
            Error
    end.

-spec normalize_selector(selector()) -> kz_either:either(error(), selector()).
normalize_selector([{'key', _}]=Selector) ->
    {'ok', Selector};
normalize_selector([{'keys', _}]=Selector) ->
    {'ok', Selector};
normalize_selector([{'start', _}]=Selector) ->
    {'ok', Selector ++ [{'end', []}]};
normalize_selector([{'end', _}]=Selector) ->
    {'ok', [{'start', []} | Selector]};
normalize_selector([{'start', _}, {'end', _}]=Selector) ->
    {'ok', Selector};
normalize_selector([End={'end', _}, Start={'start', _}]) ->
    {'ok', [Start, End]};
normalize_selector([]) ->
    {'ok', []};
normalize_selector(_S) ->
    Msg = kz_binary:format("bad selector: ~p, please define one of 'key', 'keys' or 'start','end'", [_S]),
    lager:debug("~s", Msg),
    {'error', Msg}.

build_options(Database, DesignDoc, Options) ->
    %% it feels a bit like monkey patching, but lets user
    %% provide databases if there is no design module yet.
    %%
    %% The caller is responsible for creating proper startkey/endkey
    %% with regards to direction and set the databases.
    %%
    %% This especially useful for MODBs, CDRs, Ledgers to take advantage of cursor
    %% and chunking. For now use the first db as Database here for getting db_classification.
    %%
    %% In the future either we need to find a way to get classification for multiple db
    %% or have a constrain that all dbs in the list should be of same classification.
    Prop = props:filter_empty(
             [{'databases', [kzs_util:to_database(D) || D <- props:get_value('databases', Options, [])]}
             ,{'bookmark', kz_view_cursor:decode_bookmark(props:get_value('bookmark', Options, <<>>))}
             ,{'db_classification', kzs_util:db_classification(Database)}
             ,{'direction', direction(Options)}
             ,{'doc_type', maybe_doc_type_from_view(DesignDoc, Options)}
             ,{'filtermap', filtermap(Options)}
             ]),
    props:set_values(Prop, Options).

direction(Options) ->
    case {props:get_value('direction', Options)
         ,props:is_true('descending', Options)
         ,props:is_true('ascending', Options)
         }
    of
        {'undefined', 'true', _} -> 'descending';
        {'undefined', 'false', 'true'} -> 'ascending';
        {'undefined', _, _} -> 'ascending';
        {'descending', _, _} -> 'descending';
        {'ascending', _, _} -> 'ascending'
    end.

-spec filtermap(options()) -> 'undefined' | filtermap_fun().
filtermap(Options) ->
    case props:get_first_defined(['filtermap', 'result_key'], Options) of
        'undefined' -> 'undefined';
        <<Key/binary>> -> fun(Elem, Acc) -> [kz_json:get_value(Key, Elem) | Acc] end;
        Path when is_list(Path) -> fun(Elem, Acc) -> [kz_json:get_value(Path, Elem) | Acc] end;
        Fun when is_function(Fun, 1) -> Fun;
        Fun when is_function(Fun, 2) -> Fun;
        Fun when is_function(Fun, 3) -> Fun;
        {Fun, _FirstArg}=FunArg when is_function(Fun, 3) -> FunArg
    end.

%%------------------------------------------------------------------------------
%% @doc Apply filter/mapper function if provided while keep maintaining
%% the result order.
%% @end
%%------------------------------------------------------------------------------
-spec apply_filtermap(kz_view_cursor:cursor(), kz_json:objects()) ->
          kz_json:objects() |
          {'error', any()}.
apply_filtermap(#{'filtermap' := 'undefined'}, JObjs) ->
    JObjs;
apply_filtermap(#{'filtermap' := Mapper}, JObjs) when is_function(Mapper, 1) ->
    case Mapper(JObjs) of
        'false' -> [];
        'true' -> JObjs;
        {'error', _}=Error -> Error;
        NewAcc -> NewAcc
    end;
apply_filtermap(#{filtermap := Mapper}=Cursor, JObjs) when is_function(Mapper, 2) ->
    apply_filtermap_fold(Cursor, Mapper, JObjs, []);
apply_filtermap(#{filtermap := Mapper}=Cursor, JObjs) when is_function(Mapper, 3) ->
    apply_filtermap_fold(Cursor, Mapper, JObjs, []);
apply_filtermap(#{filtermap := {Mapper, _FirstArg}=MapperArg}=Cursor, JObjs) when is_function(Mapper, 3) ->
    apply_filtermap_fold(Cursor, MapperArg, JObjs, []);
apply_filtermap(_, JObjs) ->
    JObjs.

apply_filtermap_fold(_, _, [], Acc) ->
    lists:reverse(
      [JObj
       || JObj <- Acc,
          not kz_term:is_empty(JObj)
      ]);
apply_filtermap_fold(Cursor, Mapper, [JObj | JObjs], Acc) when is_function(Mapper, 2) ->
    case apply_filtermap_fold(Mapper(JObj, Acc), JObj, Acc) of
        {'error', _} = Error -> Error;
        NewAcc -> apply_filtermap_fold(Cursor, Mapper, JObjs, NewAcc)
    end;
apply_filtermap_fold(Cursor, Mapper, [JObj | JObjs], Acc) when is_function(Mapper, 3) ->
    case Mapper(Cursor, JObj, Acc) of
        {'error', _} = Error -> Error;
        NewAcc -> apply_filtermap_fold(Cursor, Mapper, JObjs, NewAcc)
    end;
apply_filtermap_fold(Cursor, {Mapper, FirstArg}, [JObj | JObjs], Acc) when is_function(Mapper, 3) ->
    case apply_filtermap_fold(Mapper(FirstArg, JObj, Acc), JObj, Acc) of
        {'error', _} = Error -> Error;
        NewAcc -> apply_filtermap_fold(Cursor, Mapper, JObjs, NewAcc)
    end.

apply_filtermap_fold(Filtered, JObj, Acc) ->
    case Filtered of
        'false' -> Acc;
        'true' -> [JObj | Acc];
        {'true', NewJObj} -> [NewJObj | Acc];
        {'error', _} = Error -> Error;
        NewAcc -> NewAcc
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_doc_type_from_view('all_docs' | kz_term:ne_binary(), view_options()) -> kz_term:api_ne_binary().
maybe_doc_type_from_view(ViewName, Options) ->
    case props:get_value('doc_type', Options) of
        'undefined' -> doc_type_from_view(ViewName);
        _ -> 'undefined'
    end.

-spec doc_type_from_view(kz_term:ne_binary() | 'all_docs') -> kz_term:api_ne_binary().
doc_type_from_view('all_docs') -> 'undefined';
doc_type_from_view(View) ->
    case binary:split(View, <<"/">>, ['global']) of
        [ViewType, ViewName] ->
            kzs_view:doc_type_from_view(ViewType, ViewName);
        _ -> 'undefined'
    end.

lager(Options) ->
    Verbose = props:get_value('verbose_log', Options, 'false'),
    _ = erlang:put('verbose_log', Verbose),
    _ = case props:get_value('lager_md', Options) of
            'undefined' -> 'ok';
            MD -> erlang:put('lager_md', MD)
        end,
    _ = case props:get_value('lager_prefix', Options) of
            'undefined' -> 'ok';
            Prefix -> erlang:put('lager_prefix', Prefix)
        end,
    'ok'.
