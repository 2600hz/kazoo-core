%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_view_cursor).

%% Cursor executation functions
-export([count/1
        ,all/1
        ,next/1
        ,next_batch/1
        ,rest/1
        ,take/2
        ]).

%% Compute the total result functions
-export([it_count/1, it_count/2
        ,mapfold/3, mapfold/4
        ,mapfold_batch/3
        ,foreach/2, foreach/3
        ,foreach_batch/2
        ]).

%% Cursor accessors
-export([new/4]).
-export([is_exhausted/1]).
-export([is_cursor/1]).
-export([bookmark_encoded/1]).
-export([decode_bookmark/1]).
-export([encode_bookmark/1]).
-export([bookmark_compat/1]).

-export([get_batch_size/1, set_batch_size/2
        ,get_bookmark/1, set_bookmark/2
        ,get_databases/1, set_databases/2
        ,get_db_errors/1, set_db_errors/2
        ,get_direction/1, set_direction/2
        ,get_driver_params/1, set_driver_params/2
        ,get_filtermap/1, set_filtermap/2
        ,get_is_exhausted/1, set_is_exhausted/2
        ,get_module/1, set_module/2
        ,get_other_options/1, set_other_options/2
        ,get_page_size/1, set_page_size/2
        ,get_size/1, set_size/2
        ,get_reductions/1, set_reductions/2
        ,get_memory_limit/1, set_memory_limit/2
        ,get_user_params/1, set_user_params/2
        ]).

-export([is_last_db/1
        ,last_db_error/1
        ]).

-include("kz_data.hrl").

-type cursor() :: #{batch_size := kz_view:limit()
                   ,bookmark := kz_view:bookmark()
                   ,cursor_module := atom()
                   ,cursor_size := non_neg_integer()
                   ,databases := kz_term:ne_binaries()
                   ,db_errors := kz_term:proplist()
                   ,direction := kz_view:direction()
                   ,driver_params := any()
                   ,fields_fun := kz_view:fields_fun()
                   ,filtermap := kz_view:filtermap_fun()
                   ,is_exhausted := boolean()
                   ,other_options := kz_term:proplist()
                   ,page_size := kz_view:limit()
                   ,reductions := non_neg_integer()
                   ,reductions_max := kz_view:limit()
                   ,memory_limit := 'false' | 'undefined' | kz_view:limit()
                   ,no_batch := boolean()
                   ,user_params := any()
                   }.

-type result() :: kz_either:either(kz_view:error(), {cursor(), kz_view:result_value()} | 'cursor_exhausted').


-type user_fold_fun() :: fun((Result::kz_view:result_value(), Acc::term()) -> user_fold_ret()).
-type user_fold_ret() :: kz_either:either({Error::term(), Acc::term()}, Acc::term()) |
                         {'stop', Acc::term()} |
                         'stop' |
                         term().
-type user_foreach_fun() :: fun((kz_view:result_value()) -> 'ok' | 'stop').

-export_type([cursor/0
             ,result/0

             ,user_foreach_fun/0
             ,user_fold_fun/0
             ,user_fold_ret/0
             ]).

-callback bookmark(Cursor::cursor()) -> any().
-callback count(Cursor::cursor()) -> kz_either:either(kz_view:error(), non_neg_integer()).
-callback next_batch(Cursor::cursor(), Limit::kz_view:limit()) -> result().

%%------------------------------------------------------------------------------
%% @end Ask Database about total_rows of views, regardless of limit and range
%% keys.
%% @end
%%------------------------------------------------------------------------------
-spec count(Cursor::cursor()) -> kz_either:either(kz_view:error(), non_neg_integer()).
count(#{is_exhausted := 'true'}) -> 0;
count(#{cursor_module := Mod}=Cursor) -> Mod:count(Cursor).

%%------------------------------------------------------------------------------
%% @equiv rest(Cursor)
%% @end
%%------------------------------------------------------------------------------
-spec all(Cursor::cursor()) -> result().
all(#{}=Cursor) -> rest(Cursor).

%%------------------------------------------------------------------------------
%% @doc Perform the query for the next page if request is limited, or for
%% remaining result left in cursor if requested limit is infinity.
%% @end
%%------------------------------------------------------------------------------
-spec next(Cursor::cursor()) -> result().
next(#{page_size := PageSize}=Cursor) -> take(Cursor, PageSize).

%%------------------------------------------------------------------------------
%% @doc Perform the query for next batch and return updated cursor and result.
%% @end
%%------------------------------------------------------------------------------
-spec next_batch(Cursor::cursor()) -> result().
next_batch(#{batch_size := Limit}=Cursor) -> get_more(Cursor, Limit).

%%------------------------------------------------------------------------------
%% @doc Peform query for all remaining result left in the cursor.
%% @end
%%------------------------------------------------------------------------------
-spec rest(Cursor::cursor()) -> result().
rest(#{}=Cursor) -> get_more(Cursor, 'infinity').

%%------------------------------------------------------------------------------
%% @doc Perform the query and limit and return updated cursor with result.
%% @end
%%------------------------------------------------------------------------------
-spec take(Cursor::cursor(), Limit::kz_view:limit()) -> result().
take(#{}=Cursor, Limit) ->
    get_more(Cursor, Limit).

%%------------------------------------------------------------------------------
%% @doc Compute the total number of result object client-side by fetching and
%% iterating the result set.
%% @end
%%------------------------------------------------------------------------------
-spec it_count(Cursor::cursor()) -> kz_either:either(kz_view:error(), non_neg_integer()).
it_count(#{batch_size := Limit}=Cursor) -> it_count(Cursor, Limit).

-spec it_count(Cursor::cursor(), Limit::kz_view:limit()) -> kz_either:either(kz_view:error(), non_neg_integer()).
it_count(#{}=Cursor, Limit) ->
    case get_more(Cursor, Limit) of
        {'ok', {_, Result}} -> length(Result);
        {'ok', 'cursor_exhausted'} -> 0;
        {'error', _}=Error -> Error
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec mapfold(user_fold_fun(), Acc::term(), Cursor::cursor()) ->
          kz_either:either({kz_view:error(), Acc::term()}, Acc::term()).
mapfold(Fun, Acc, #{}=Cursor) ->
    mapfold(Fun, Acc, Cursor, 'infinity').

-spec mapfold(user_fold_fun(), Acc::term(), Cursor::cursor(), Limit::kz_view:limit()) ->
          kz_either:either({kz_view:error(), Acc::term()}, Acc::term()).
mapfold(Fun, Acc, #{}=Cursor, Limit) ->
    case take(Cursor, Limit) of
        {'ok', 'cursor_exhausted'} ->
            {'ok', Acc};
        {'ok', {_, []}} ->
            {'ok', Acc};
        {'ok', {NextCursor, Result}} when is_function(Fun, 2) ->
            next_mapfold(Fun, Fun(Result, Acc), Acc, NextCursor, Limit);
        {'ok', {NextCursor, Result}} when is_function(Fun, 3) ->
            next_mapfold(Fun, Fun(Cursor, Result, Acc), Acc, NextCursor, Limit);
        {'error', Error} ->
            lager:debug("failed to get next batch ~s", [Error]),
            {'error', {Error, Acc}}
    end.

-spec mapfold_batch(user_fold_fun(), Acc::term(), Cursor::cursor()) ->
          kz_either:either({kz_view:error(), Acc::term()}, Acc::term()).
mapfold_batch(Fun, Acc, #{batch_size := Limit}=Cursor) ->
    mapfold(Fun, Acc, Cursor, Limit).

%% @private
next_mapfold(Fun, {'ok', Acc}, _, Cursor, Limit) ->
    mapfold(Fun, Acc, Cursor, Limit);
next_mapfold(_, {'error', Error}, Acc, _, _) ->
    {'error', {Error, Acc}};
next_mapfold(_, {'stop', NewAcc}, _, _, _) ->
    {'ok', NewAcc};
next_mapfold(_, 'stop', Acc, _, _) ->
    {'ok', Acc};
next_mapfold(Fun, NewAcc, _, Cursor, Limit) ->
    mapfold(Fun, NewAcc, Cursor, Limit).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec foreach(fun((kz_view:result_value()) -> 'ok'), Cursor::cursor()) -> 'ok'.
foreach(Fun, #{}=Cursor) ->
    foreach(Fun, Cursor, 'infinity').

-spec foreach(fun((kz_view:result_value()) -> 'ok'), Cursor::cursor(), Limit::kz_view:limit()) -> 'ok'.
foreach(Fun, #{}=Cursor, Limit) ->
    case take(Cursor, Limit) of
        {'ok', 'cursor_exhausted'} ->
            'ok';
        {'ok', {_, []}} -> 'ok';
        {'ok', {NextCursor, Result}} ->
            case Fun(Result) of
                'ok' -> foreach(Fun, NextCursor);
                'stop' -> 'ok'
            end;
        {'error', Error} ->
            lager:debug("failed to get next batch ~s", [Error]),
            'ok'
    end.

-spec foreach_batch(fun((kz_view:result_value()) -> 'ok'), Cursor::cursor()) -> 'ok'.
foreach_batch(Fun, #{'batch_size' := BatchSize}=Cursor) ->
    foreach(Fun, Cursor, BatchSize).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec is_exhausted(Cursor::cursor()) -> boolean().
is_exhausted(Cursor) -> get_is_exhausted(Cursor).

%% maybe use record?
-spec is_cursor(Cursor::cursor() | boolean()) -> boolean().
is_cursor(#{bookmark := _}) -> 'true';
is_cursor(_) -> 'false'.

-spec bookmark_encoded(Cursor::cursor()) -> kz_term:api_binary().
bookmark_encoded(#{bookmark := 'undefined'}) ->
    'undefined';
bookmark_encoded(#{}=Cursor) ->
    encode_bookmark(get_bookmark(Cursor)).

-spec decode_bookmark(Bookmark::kz_term:api_binary() | kz_term:proplist() | map()) ->
          kz_term:proplist() | any().
decode_bookmark(#{}=Bookmark) ->
    maps:to_list(Bookmark);
decode_bookmark(Bookmark) when is_list(Bookmark) ->
    Bookmark;
decode_bookmark('undefined') ->
    [];
decode_bookmark(<<>>) ->
    [];
decode_bookmark(<<Bookmark/binary>>) ->
    case erlang:binary_to_term(
           zlib:uncompress(
             base64url:decode(Bookmark)
            )
          )
    of
        Book when is_list(Book) -> Book;
        #{}=Book -> maps:to_list(Book);
        Book -> Book
    end.

-spec encode_bookmark(Bookmark::kz_term:proplist() | map()) -> kz_term:api_ne_binary().
encode_bookmark([]) ->
    'undefined';
encode_bookmark(Bookmark) when is_list(Bookmark) ->
    encode_bookmark(maps:from_list(Bookmark));
encode_bookmark(#{}=Bookmark) when map_size(Bookmark) =:= 0 ->
    'undefined';
encode_bookmark(#{}=Bookmark) ->
    base64url:encode(
      zlib:compress(
        erlang:term_to_binary(Bookmark)
       )
     ).

-spec bookmark_compat(Cursor::cursor()) -> kz_term:proplist().
bookmark_compat(#{bookmark := 'undefined'
                 ,cursor_size := Size
                 }) ->
    [{<<"page_size">>, Size}];
bookmark_compat(#{cursor_size := Size}=Cursor) ->
    Bookmark = get_bookmark(Cursor),
    StartKey = props:filter_undefined(
                 [{'next_startkey', maps:get('startkey', Bookmark, 'undefined')}
                 ,{'next_startkey_docid', maps:get('startkey_docid', Bookmark, 'undefined')}
                 ]),
    NextStartKey = props:filter_undefined(
                     [{'next_startkey', maps:get('next_startkey', Bookmark, 'undefined')}
                     ,{'next_startkey_docid', maps:get('next_startkey_docid', Bookmark, 'undefined')}
                     ]
                    ),
    props:filter_undefined(
      [{<<"page_size">>, Size}
      ,{<<"start_key">>, encode_bookmark(StartKey)}
      ,{<<"next_start_key">>, encode_bookmark(NextStartKey)}
      ]
     ).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec new(CursorMod::module(), Databases::kz_term:ne_binaries(), DriverParams::term(), Options::kz_view:options()) -> cursor().
new(CursorMod, Databases, DriverParams, Options) ->
    CursorOnly =  ['batch_size'
                  ,'bookmark'
                  ,'databases'
                  ,'direction'
                  ,'field_key'
                  ,'fields'
                  ,'fields_fun'
                  ,'filtermap'
                  ,'limit'
                  ,'reductions_max'
                  ,'memory_limit'
                  ,'no_batch'
                  ,'user_params'
                  ],
    #{batch_size => props:get_value('batch_size', Options, 'infinity')
     ,bookmark => 'undefined'
     ,cursor_module => CursorMod
     ,cursor_size => 0
     ,databases => Databases
     ,db_errors => []
     ,direction => props:get_value('direction', Options, 'ascending')
     ,driver_params => DriverParams
     ,fields_fun => props:get_value('fields_fun', Options)
     ,filtermap => props:get_value('filtermap', Options)
     ,is_exhausted => 'false'
     ,other_options => props:delete_keys(CursorOnly, Options)
     ,page_size => props:get_first_defined(['page_size', 'limit'], Options, 'infinity')
     ,reductions_max => props:get_value('reductions_max', Options, 'infinity')
     ,reductions => 0
     ,memory_limit => props:get_value('memory_limit', Options, 'false')
     ,no_batch => props:is_true('no_batch', Options, 'false')
     ,user_params => props:get_value('user_params', Options)
     }.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec get_batch_size(Cursor::cursor()) -> BatchSize::kz_view:limit().
get_batch_size(#{batch_size := Value}) -> Value.
-spec set_batch_size(Cursor::cursor(), BatchSize::kz_view:limit()) -> Cursor::cursor().
set_batch_size(Cursor, Value) -> Cursor#{batch_size => Value}.

-spec get_bookmark(Cursor::cursor()) -> Bookmark::kz_view:bookmark().
get_bookmark(#{cursor_module := Mod}=Cursor) -> Mod:bookmark(Cursor).
-spec set_bookmark(Cursor::cursor(), Bookmark::kz_view:bookmark()) -> Cursor::cursor().
set_bookmark(Cursor, Bookmark) -> Cursor#{bookmark => Bookmark}.

-spec get_databases(Cursor::cursor()) -> kz_term:ne_binaries().
get_databases(#{databases := Databases}) -> Databases.
-spec set_databases(Cursor::cursor(), Databases::kz_term:ne_binaries()) -> Cursor::cursor().
set_databases(Cursor, Databases) -> Cursor#{databases => Databases}.

-spec get_db_errors(Cursor::cursor()) -> kz_term:proplist().
get_db_errors(#{db_errors := Errors}) -> Errors.
-spec set_db_errors(Cursor::cursor(), Errors::kz_term:proplist()) -> Cursor::cursor().
set_db_errors(Cursor, Errors) -> Cursor#{db_errors => Errors}.

-spec get_direction(Cursor::cursor()) -> 'ascending' | 'descending'.
get_direction(#{direction := Value}) -> Value.
-spec set_direction(Cursor::cursor(), 'ascending' | 'descending') -> Cursor::cursor().
set_direction(Cursor, Value) -> Cursor#{direction => Value}.

-spec get_driver_params(Cursor::cursor()) -> any().
get_driver_params(#{driver_params := Value}) -> Value.
-spec set_driver_params(Cursor::cursor(), any()) -> Cursor::cursor().
set_driver_params(Cursor, Value) -> Cursor#{driver_params => Value}.

-spec get_filtermap(Cursor::cursor()) -> FiltermapFun::kz_view:filtermap_fun().
get_filtermap(#{filtermap := Value}) -> Value.
-spec set_filtermap(Cursor::cursor(), FiltermapFun::kz_view:filtermap_fun()) -> Cursor::cursor().
set_filtermap(Cursor, Value) -> Cursor#{filtermap => Value}.

-spec get_is_exhausted(Cursor::cursor()) -> boolean().
get_is_exhausted(#{is_exhausted := IsExhausted}) -> IsExhausted.
-spec set_is_exhausted(Cursor::cursor(), IsExhausted::boolean()) -> Cursor::cursor().
set_is_exhausted(Cursor, IsExhausted) -> Cursor#{is_exhausted => IsExhausted}.

-spec get_module(Cursor::cursor()) -> module().
get_module(#{cursor_module := Value}) -> Value.
-spec set_module(Cursor::cursor(), module()) -> Cursor::cursor().
set_module(Cursor, Value) -> Cursor#{cursor_module => Value}.

-spec get_other_options(Cursor::cursor()) -> Options::kz_view:options().
get_other_options(#{other_options := Value}) -> Value.
-spec set_other_options(Cursor::cursor(), Options::kz_view:options()) -> Cursor::cursor().
set_other_options(Cursor, Value) -> Cursor#{other_options => Value}.

-spec get_page_size(Cursor::cursor()) -> PageSize::kz_view:limit().
get_page_size(#{page_size := Value}) -> Value.
-spec set_page_size(Cursor::cursor(), PageSize::kz_view:limit()) -> Cursor::cursor().
set_page_size(Cursor, Value) -> Cursor#{page_size => Value}.

-spec get_size(Cursor::cursor()) -> Size::non_neg_integer().
get_size(#{cursor_size := Size}) -> Size.
-spec set_size(Cursor::cursor(), Size::non_neg_integer()) -> Cursor::cursor().
set_size(Cursor, Size) -> Cursor#{cursor_size => Size}.

-spec get_user_params(Cursor::cursor()) -> any().
get_user_params(#{user_params := Value}) -> Value.
-spec set_user_params(Cursor::cursor(), any()) -> Cursor::cursor().
set_user_params(Cursor, Value) -> Cursor#{user_params => Value}.

-spec get_reductions(Cursor::cursor()) -> non_neg_integer().
get_reductions(#{reductions := Value}) -> Value.
-spec set_reductions(Cursor::cursor(), non_neg_integer()) -> Cursor::cursor().
set_reductions(Cursor, Value) -> Cursor#{reductions => Value}.

-spec get_memory_limit(Cursor::cursor()) -> 'false' | non_neg_integer().
get_memory_limit(#{memory_limit := Value}) -> Value.
-spec set_memory_limit(Cursor::cursor(), 'false' | non_neg_integer()) -> Cursor::cursor().
set_memory_limit(Cursor, Value) -> Cursor#{memory_limit => Value}.

-spec is_last_db(Cursor::cursor()) -> boolean().
is_last_db(#{databases := []}) -> 'true';
is_last_db(_) -> 'false'.

-spec last_db_error(Cursor::cursor()) -> any().
last_db_error(#{db_errors := [{_Db, Error}|_]}) -> Error;
last_db_error(_) -> 'undefined'.

%%------------------------------------------------------------------------------
%% @doc
%% @private
%% @end
%%------------------------------------------------------------------------------
-spec get_more(cursor(), kz_view:limit()) -> result().
get_more(#{is_exhausted := 'true'}, _Limit) ->
    ?MAYBE_LOG("cursor exhausted", []),
    {'ok', 'cursor_exhausted'};
get_more(#{no_batch := 'true'
          ,cursor_module := Mod
          }=Cursor, 'infinity') ->
    ?MAYBE_LOG("performing non-batch infinity query", []),
    case Mod:next_batch(Cursor, 'infinity') of
        {'ok', {NewCursor, Result}} ->
            case apply_fields_fun(NewCursor, Result) of
                {'ok', UpdatedResult} ->
                    {'ok', {NewCursor, UpdatedResult}};
                {'error', _}=Error ->
                    Error
            end;
        {'error', _}=Error ->
            Error
    end;
get_more(#{no_batch := 'false'
          ,batch_size := BatchSize
          }=Cursor, 'infinity') ->
    ?MAYBE_LOG("explicitly infinity limit requested, but batch size '~p' is allowed", [BatchSize]),
    get_more_fold(Cursor, []);
get_more(Cursor, Limit) ->
    #{cursor_module := Mod
     ,page_size := PageSize
     ,cursor_size := CursorSize
     } = Cursor,
    case page_limit(PageSize, Limit, CursorSize) of
        0 ->
            ?MAYBE_LOG("(pagination) page size exhausted: ~b", [PageSize]),
            get_more(Cursor#{is_exhausted => 'true'}, 0);
        _Limit when _Limit < 0 ->
            ?MAYBE_LOG("(pagination) got more rows than page size: requested_page_size: ~b, requested_limit: ~b, cursor_size: ~p, remaining_page_size: ~b"
                      ,[PageSize, Limit, CursorSize, _Limit]
                      ),
            {'error', <<"got more rows than page size">>};
        PageLimit ->
            case Mod:next_batch(Cursor, PageLimit) of
                {'ok', {NewCursor, Result}} ->
                    case apply_fields_fun(NewCursor, Result) of
                        {'ok', UpdatedResult} ->
                            {'ok', {NewCursor, UpdatedResult}};
                        {'error', _}=Error ->
                            Error
                    end;
                {'error', _}=Error ->
                    Error
            end
    end.

%% explicitly disabled pagination
page_limit('infinity', Limit, _TotalRows) ->
    Limit;
%% same limit and page_size
page_limit(PageSize, PageSize, TotalRows) ->
    PageSize - TotalRows;
%% limit is lower than sum of remaining amount to query inpage, using limit
page_limit(PageSize, Limit, TotalRows) when Limit < (PageSize - TotalRows) ->
    Limit;
%% limit is bigger than page_size, using page_size
page_limit(PageSize, _Limit, TotalRows) ->
    PageSize - TotalRows.

-spec get_more_fold(cursor(), kz_view:result_value()) -> result().
get_more_fold(#{is_exhausted := 'true'}=Cursor, Rows) ->
    {'ok', {Cursor, Rows}};
get_more_fold(#{cursor_module := Mod, batch_size := BatchSize}=Cursor, Rows) ->
    case Mod:next_batch(Cursor, BatchSize) of
        {'ok', {NewCursor, Result}} ->
            case apply_fields_fun(NewCursor, Result) of
                {'ok', UpdatedResult} ->
                    get_more_fold(NewCursor, Rows ++ UpdatedResult);
                {'error', _}=Error ->
                    Error
            end;
        {'error', _}=Error ->
            Error
    end.

-spec apply_fields_fun(cursor(), kz_view:result_value()) -> kz_either:either('exception', kz_view:result_value()).
apply_fields_fun(Cursor, JObjs) ->
    try kz_view:apply_fields_fun(Cursor, JObjs) of
        UpdatedJObjs -> {'ok', UpdatedJObjs}
    catch
        _E:_T:ST ->
            kz_log:log_stacktrace(ST, "exception during applying fields_fun: ~p:~p", [_E, _T]),
            {'error', 'exception'}
    end.
