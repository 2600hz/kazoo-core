%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
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
-export([apply_fields_fun/2]).
-export([build_fields_fun/2]).

%% deprecated, use {@link kz_term:high_unicode_value/0)}
-export([high_unicode_value/0]).

-include("kz_data.hrl").

-type direction() :: 'ascending' | 'descending'.
-type limit() :: non_neg_integer() | 'infinity'.
-type bookmark() :: kz_term:proplist() | map() | binary() | 'undefined' | any().
-type result_key() :: kz_term:ne_binary() | kz_json:path(). %% like `<<"key">>', `<<"id">>', `<<"value">>' and `<<"doc">>'

-type option() :: {'batch_size', limit()} |
                  {'bookmark', bookmark()} |
                  {'databases', kz_term:ne_binaries()} |
                  {'direction', direction()} |
                  {'doc_type', kz_term:ne_binary()} |
                  {'field_key', kz_term:ne_binary() | 'filtermap'} |
                  {'fields', fields()} |
                  {'fields_fun', fields_fun()} |
                  {'filtermap', filtermap_fun() | result_key()} |
                  {'first_when_multiple', boolean()} |
                  {'memory_limit', 'false' | pos_integer()} |
                  {'no_batch', boolean()} |
                  {'no_design_module', boolean()} | 'no_design_module' |
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
                  {atom() | kz_term:ne_binary(), any()}.

-type options() :: view_options() | [option()].

-type selector() :: [] |
                    [{'key', kz_term:proplist()}] |
                    [{'keys', kz_term:proplists()}] |
                    [{'start', kz_term:proplist()} |
                     {'end', kz_term:proplist()}
                    ].

-type result_value() :: kz_json:objects() | kz_json:get_key().
-type result() :: kz_either:either(error(), result_value()).
-type single_result() :: kz_either:either(any(), kz_json:object()).

-type filtermap_ret() :: 'false' | 'true' | {'true', kz_json:object()} | {'error', error()} | kz_json:objects().
-type filtermap_fun() :: fun((kz_json:objects()) -> 'false' | 'true' | {'error', error()} | kz_json:objects()) |
                         fun((kz_json:object(), result_value()) -> filtermap_ret()) |
                         fun((kz_view_cursor:cursor(), kz_json:object(), kz_json:objects()) -> filtermap_ret()) |
                         {fun((any(), kz_json:object(), kz_json:objects()) -> filtermap_ret()), any()}.

-type error() :: kazoo_data:data_errors().

-type get_key() :: kz_json:key() | kz_json:path().
-type field_update() :: fun((Key::kz_json:key(), Value::kz_json:json_term()) -> {Key::kz_json:key(), Value::kz_json:json_term()}).
-type fields() :: [get_key() | {get_key(), boolean() | field_update()}].
-type fields_fun() :: fun((kz_json:object()) -> kz_json:object()).

%% internal
-type fields_fun_arg() :: #{'fields' => fields()
                           ,'no_fields' => boolean() %% indicates this is only remove/update operations so use object as base
                           ,'remove' => [get_key()]
                           ,'update' => [{get_key(), field_update()}]
                           }.

-export_type([bookmark/0
             ,direction/0
             ,error/0
             ,limit/0
             ,options/0
             ,fields/0
             ,fields_fun/0
             ,filtermap_fun/0
             ,result_value/0
             ,result/0
             ,single_result/0
             ,selector/0
             ,ddoc/0
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
-spec find_one(kz_term:ne_binary(), ddoc()) ->
          result().
find_one(DbName, DesignDoc) ->
    find_one(DbName, DesignDoc, []).

-spec find_one(kz_term:ne_binary(), ddoc(), selector()) ->
          result().
find_one(DbName, DesignDoc, Selector) ->
    find_one(DbName, DesignDoc, Selector, []).

-spec find_one(kz_term:ne_binary(), ddoc(), selector(), options()) ->
          result().
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
-spec find_batch(kz_term:ne_binary(), ddoc()) -> kz_either:either(error(), kz_view_cursor:cursor()).
find_batch(DbName, DesignDoc) ->
    find_batch(DbName, DesignDoc, []).

-spec find_batch(kz_term:ne_binary(), ddoc(), selector()) -> kz_either:either(error(), kz_view_cursor:cursor()).
find_batch(DbName, DesignDoc, Selector) ->
    find_batch(DbName, DesignDoc, Selector, []).

-spec find_batch(kz_term:ne_binary(), ddoc(), selector(), options()) -> kz_either:either(error(), kz_view_cursor:cursor()).
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
    lager:debug("~s", [Msg]),
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
             ,{'fields_fun', fields_fun(Options)}
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

%%------------------------------------------------------------------------------
%% @doc Check filtermap option.
%%
%% Filtermap calls a Fun on a list of result JObjs. Fun must return either
%% a Boolean or a tuple {true, Value} or a Tuple {error, any} or the whole Acc.
%% The filtermap returns the list of result for which Fun returns a new value,
%% where a value of 'true' is synonymous with {true, Elem}.
%%
%% If result_key is passed instead, a filtermap Fun will be created. Result key
%% contains the a JSON path to fetch the result.
%%
%% @see apply_filtermap/2
%% @end
%%------------------------------------------------------------------------------
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
%% @doc Use the provided fields_fun or create one if fields option is specified.
%%
%% Fieldsfuns calls a function on a list of JObjs. Fun must return a JObj.
%%
%% This Fun will be called after filtermap is applied. The purpose of this Fun is
%% to return only requested fields of the JObjs.
%%
%% When fields_fun is undefined but fields (and maybe field_key) is specified,
%% a default fields_fun will be created.
%%
%% fields option is a list with elements of value:
%% * JObj path
%% * a tuple {Path, 'false'} specifies the exclusion of a field
%% * a tuple {Path, 'true'} specifies the inclusion of a field
%% * a tuple {Path, Fun}, Fun is a function Fun(Path, PathValue)
%%     and must return a tuple {NewKeyName, New Value}.
%% @end
%%------------------------------------------------------------------------------
-spec fields_fun(options()) -> 'undefined' | fields_fun().
fields_fun(Options) ->
    case props:get_value('fields_fun', Options) of
        'undefined' ->
            FieldKey = props:get_value('field_key', Options),
            Fields = props:get_value('fields', Options),
            build_fields_fun(Fields, FieldKey);
        FieldsFun when is_function(FieldsFun, 1) ->
            FieldsFun
    end.

-spec build_fields_fun(Fields :: fields() | 'undefined', FieldKeyOrFun :: kz_term:api_ne_binary() | 'filtermap' | fun((kz_json:object()) -> kz_json:object())) ->
          'undefined' | fields_fun().
build_fields_fun('undefined', _) ->
    'undefined';
build_fields_fun([], _) ->
    'undefined';
build_fields_fun(Fields, 'undefined') ->
    build_fields_fun(Fields, fun kz_term:identity/1);
build_fields_fun(Fields, 'filtermap') ->
    build_fields_fun(Fields, fun kz_term:identity/1);
build_fields_fun(Fields, <<FieldKey/binary>>) ->
    KeyFun = fun(JObj) ->
                     kz_doc:set_id(kz_json:get_json_value(FieldKey, JObj, kz_json:new())
                                  ,kz_doc:id(JObj)
                                  )
             end,
    build_fields_fun(Fields, KeyFun);
build_fields_fun(Fields, FieldKeyFun) when is_function(FieldKeyFun, 1) ->
    FieldsFunArg = build_fields_arg(Fields),
    fun(JObj) ->
            default_fields_fun(FieldsFunArg, FieldKeyFun(JObj))
    end.

-spec default_fields_fun(fields_fun_arg(), kz_json:object()) -> kz_json:object().
default_fields_fun(#{'no_fields' := 'true', 'remove' := ToRemove}=Arg, JObj0) ->
    JObj = kz_json:delete_keys(ToRemove, kz_doc:set_id(JObj0, kz_doc:id(JObj0))),
    fields_fun_get(Arg, JObj, JObj);
default_fields_fun(#{'remove' := ToRemove}=Arg, JObj0) ->
    JObj = kz_json:delete_keys(ToRemove, kz_doc:set_id(JObj0, kz_doc:id(JObj0))),
    fields_fun_get(Arg, JObj, kz_json:new()).

-spec fields_fun_get(fields_fun_arg(), kz_json:object(), kz_json:object()) -> kz_json:object().
fields_fun_get(#{'update' := ToUpdate
                ,'fields' := Fields
                }, JObj, Default) ->
    lists:foldl(fun({Key, Fun}, Acc) ->
                        Val = kz_json:get_value(Key, Acc),
                        case Fun(Key, Val) of
                            {Key, NewVal} ->
                                kz_json:set_value(Key, NewVal, Acc);
                            {NewKey, NewVal} ->
                                kz_json:set_value(NewKey, NewVal, kz_json:delete_key(Key, Acc))
                        end
                end
               ,kz_json:get_fields(Fields, JObj, Default)
               ,ToUpdate
               ).

-spec build_fields_arg(fields()) -> fields_fun_arg().
build_fields_arg(Fields) ->
    Acc = #{'remove' => [], 'update' => []
           ,'fields' => [], 'no_fields' => 'false'
           },
    #{'update' := ToUpdate
     ,'fields' := NewFields
     } = Arg = build_fields_arg(Fields, Acc),
    {UFields, _} = lists:unzip(ToUpdate),
    Arg#{'fields' => lists:usort(NewFields ++ UFields)}.

-spec build_fields_arg(fields(), fields_fun_arg()) -> fields_fun_arg().
build_fields_arg([], #{'fields' := []}=Acc) ->
    Acc#{'fields' => [<<"_id">>]
        ,'no_fields' => 'true'
        };
build_fields_arg([], #{'fields' := Fields}=Acc) ->
    case props:get_value(<<"_id">>, Fields) of
        'undefined' ->
            Acc#{'fields' => [<<"_id">> | Fields]};
        _ ->
            Acc#{'fields' => Fields}
    end;
build_fields_arg([{F, 'false'}|Fs], #{'remove' := ToRemove}=Acc) ->
    build_fields_arg(Fs, Acc#{'remove' => [F | ToRemove]});
build_fields_arg([{F, ProjectionFun}|Fs], #{'update' := ToUpdate}=Acc) when is_function(ProjectionFun, 2) ->
    build_fields_arg(Fs, Acc#{'update' => [{F, ProjectionFun} | ToUpdate]});
build_fields_arg([{F, 'true'}|Fs], #{'fields' := Fields}=Acc) ->
    build_fields_arg(Fs, Acc#{'fields' => [F | Fields]});
build_fields_arg([F|Fs], #{'fields' := Fields}=Acc) ->
    build_fields_arg(Fs, Acc#{'fields' => [F | Fields]}).

%%------------------------------------------------------------------------------
%% @doc Apply filter/mapper function if provided while keep maintaining
%% the result order.
%% @end
%%------------------------------------------------------------------------------
-spec apply_filtermap(kz_view_cursor:cursor(), kz_json:objects()) ->
          kz_json:objects() |
          {'error', any()}.
apply_filtermap(#{filtermap := Mapper}=Cursor, JObjs) when is_function(Mapper, 3) ->
    apply_filtermap_fold3(Cursor, Mapper, JObjs, []);
apply_filtermap(#{'filtermap' := Mapper}, JObjs) ->
    apply_filtermap(Mapper, JObjs);
apply_filtermap(#{}, JObjs) ->
    JObjs;
apply_filtermap('undefined', JObjs) ->
    JObjs;
apply_filtermap(Mapper, JObjs) ->
    apply_filtermap_fold(Mapper, JObjs, []).

apply_filtermap_fold(_, [], Acc) ->
    lists:reverse(
      [JObj
       || JObj <- Acc,
          not kz_term:is_empty(JObj)
      ]);
apply_filtermap_fold(Mapper, JObjs, _) when is_function(Mapper, 1) ->
    case Mapper(JObjs) of
        'false' -> [];
        'true' -> JObjs;
        {'error', _}=Error -> Error;
        NewAcc -> NewAcc
    end;
apply_filtermap_fold(Mapper, [JObj | JObjs], Acc) ->
    case apply_filtermap_fun(Mapper, JObj, Acc) of
        {'error', _} = Error -> Error;
        NewAcc -> apply_filtermap_fold(Mapper, JObjs, NewAcc)
    end.

apply_filtermap_fun(Mapper, JObj, Acc) when is_function(Mapper, 2) ->
    handle_filtermap(Mapper(JObj, Acc), JObj, Acc);
apply_filtermap_fun({Mapper, FirstArg}, JObj, Acc) when is_function(Mapper, 3) ->
    handle_filtermap(Mapper(FirstArg, JObj, Acc), JObj, Acc).

apply_filtermap_fold3(_, _, [], Acc) ->
    lists:reverse(
      [JObj
       || JObj <- Acc,
          not kz_term:is_empty(JObj)
      ]);
apply_filtermap_fold3(Cursor, Mapper, [JObj | JObjs], Acc) when is_function(Mapper, 3) ->
    case handle_filtermap(Mapper(Cursor, JObj, Acc), JObj, Acc) of
        {'error', _} = Error -> Error;
        NewAcc -> apply_filtermap_fold3(Cursor, Mapper, JObjs, NewAcc)
    end.

handle_filtermap(Filtered, JObj, Acc) ->
    case Filtered of
        'false' -> Acc;
        'true' -> [JObj | Acc];
        {'true', NewJObj} -> [NewJObj | Acc];
        {'error', _} = Error -> Error;
        NewAcc -> NewAcc
    end.

-spec apply_fields_fun(CursorOrFieldsFun :: kz_view_cursor:cursor() | fields_fun(), JObjs :: kz_json:objects()) ->
          kz_json:objects().
apply_fields_fun(FieldsFun, JObjs) when is_function(FieldsFun, 1) ->
    [FieldsFun(JObj) || JObj <- JObjs];
apply_fields_fun(#{'fields_fun' := FieldsFun}, JObjs) when is_function(FieldsFun, 1) ->
    apply_fields_fun(FieldsFun, JObjs);
apply_fields_fun(_, JObjs) ->
    JObjs.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_doc_type_from_view(ddoc(), view_options()) -> kz_term:api_ne_binary().
maybe_doc_type_from_view(ViewName, Options) ->
    case props:get_value('doc_type', Options) of
        'undefined' -> doc_type_from_view(ViewName);
        _ -> 'undefined'
    end.

-spec doc_type_from_view(ddoc()) -> kz_term:api_ne_binary().
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
