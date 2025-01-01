%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc Util functions used by kazoo_couch
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_couch_view).

-behaviour(kz_view_cursor).

%% View-related
-export([design_compact/3
        ,design_info/3
        ,all_design_docs/2, all_design_docs/3
        ,get_results/4
        ,get_results_count/4
        ,all_docs/1, all_docs/2, all_docs/3
        ,show/5
        ]).

%% View-Selector
-export([find/5
        ]).

%% kz_view_cursor callbacks
-export([bookmark/1
        ,count/1
        ,next_batch/2
        ]).

-include("kz_couch.hrl").

-define(RANGE_KEYS, ['endkey'
                    ,'end_key'
                    ,'key'
                    ,'keys'
                    ,'startkey'
                    ,'start_key'
                    ]).

-define(RANGE_KEY_IDS, ['endkey_docid'
                       ,'end_key_doc_id'
                       ,'startkey_docid'
                       ,'start_key_doc_id'
                       ]).

-define(ALL_COUCH_VIEW_OPTIONS
       ,['limit'
        | ?COUCH_ONLY_OPTIONS
        ]
       ).

-define(COUCH_ONLY_OPTIONS
       ,['conflicts'
        ,'descending'
        ,'group'
        ,'group_level'
        ,'include_docs'
        ,'attachments'
        ,'att_encoding_info'
        ,'inclusive_end'
        ,'reduce'
        ,'skip'
        ,'sorted'
        ,'stable'
        ,'stale'
        ,'update'
        ,'update_seq'
        ] ++ ?RANGE_KEYS ++ ?RANGE_KEY_IDS
       ).

-type ddoc() :: kazoo_data:ddoc() |
                {kz_term:ne_binary(), kz_term:ne_binary()}.

-type show_doc() :: binary() |
                    {binary(), binary()}.

-type params() :: #{ddoc := kz_term:ne_binary()
                   ,ddoc_module := module() | 'undefined'
                   ,design_view := kazoo_data:ddoc()
                   ,view_name := kz_term:ne_binary()
                   ,view_options => view_options()
                   ,server => server()
                   }.

-type key_type() :: 'start' | 'end' | 'key'.
-type key_fields() :: 'null' | binary() | number() | ['null' | binary() | number()].

-type build_key_fun() :: fun((params(), kz_view:selector(), kz_view:options()) -> view_options() | 'empty').
-type databases_fun() :: fun((params()) -> kz_term:ne_binaries()).

-export_type([build_key_fun/0
             ,databases_fun/0
             ,params/0
             ]).

%%% View-related functions -----------------------------------------------------
-spec design_compact(server(), kz_term:ne_binary(), kz_term:ne_binary()) -> boolean().
design_compact(#server{}=Conn, DbName, Design) ->
    case couchbeam:compact(kz_couch_util:get_db(Conn, DbName), Design) of
        {'error', _E} ->
            lager:info("failed to compact design doc ~s/~s: ~p", [DbName, Design, kz_couch_util:format_error(_E)]),
            'false';
        'ok' -> 'true'
    end.

-spec design_info(server(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          couchbeam_error().
design_info(#server{}=Conn, DBName, Design) ->
    Db = kz_couch_util:get_db(Conn, DBName),
    do_get_design_info(Db, Design).

-spec all_design_docs(kz_data:connection(), kz_term:ne_binary()) ->
          {'ok', kz_json:objects()} |
          couchbeam_error().
all_design_docs(#server{}=Conn, DBName) ->
    all_design_docs(#server{}=Conn, DBName, []).

-spec all_design_docs(kz_data:connection(), kz_term:ne_binary(), view_options()) ->
          {'ok', kz_json:objects()} |
          couchbeam_error().
all_design_docs(#server{}=Conn, DBName, Options) ->
    Db = kz_couch_util:get_db(Conn, DBName),
    Filter = props:set_values([{'startkey', <<"_design/">>}
                              ,{'endkey', <<"_design0">>}
                              ]
                             ,Options
                             ),
    do_fetch_results(Db, 'all_docs', Filter).

-spec all_docs(db()) -> {'ok', kz_json:objects()} | couchbeam_error().
all_docs(Db) -> all_docs(Db, []).

-spec all_docs(db(), view_options()) -> {'ok', kz_json:objects()} |
          couchbeam_error().
all_docs(#db{}=Db, Options) ->
    do_fetch_results(Db, 'all_docs', Options).

-spec all_docs(server(), kz_term:ne_binary(), view_options()) ->
          {'ok', kz_json:objects()} |
          couchbeam_error().
all_docs(#server{}=Conn, DbName, Options) ->
    Db = kz_couch_util:get_db(Conn, DbName),
    do_fetch_results(Db, 'all_docs', Options).

-spec get_results(server(), kz_term:ne_binary(), kazoo_data:ddoc(), view_options()) ->
          {'ok', kz_json:objects() | kz_json:path()} |
          couchbeam_error().
get_results(#server{}=Conn, DbName, DesignDoc, ViewOptions) ->
    Db = kz_couch_util:get_db(Conn, DbName),
    do_fetch_results(Db, DesignDoc, ViewOptions).

%% This function assumes a "reduce" function that returns the count of docs exists
%% Need to see how to get couchbeam to return the "rows" property instead of the result
%% list; that would be better, but for not, setting the view's "reduce" to the _count
%% function will suffice (provided a reduce isn't already defined).
-spec get_results_count(server(), 'all_docs' | kz_term:ne_binary(), kz_term:ne_binary(), view_options()) ->
          {'ok', kz_term:api_integer()} |
          couchbeam_error().
get_results_count(#server{}=Conn, DbName, DesignDoc, ViewOptions) ->
    Db = kz_couch_util:get_db(Conn, DbName),
    do_fetch_results_count(Db, DesignDoc, ViewOptions).

%% Design Doc/View internal functions
-spec do_fetch_results(couchbeam_db(), ddoc(), view_options()) ->
          {'ok', kz_json:objects() | kz_term:ne_binaries()} |
          couchbeam_error().
do_fetch_results(Db, <<DesignDoc/binary>>, Options) ->
    case binary:split(DesignDoc, <<"/">>, ['global']) of
        [DesignName, ViewName|_] ->
            do_fetch_results(Db, {DesignName, ViewName}, map_options(Options));
        _Error ->
            lager:warning("failed to parse design doc ~s: ~p", [DesignDoc, _Error]),
            {'error', 'not_found'}
    end;
do_fetch_results(Db, 'all_docs'=DesignDoc, Options) ->
    fetch_results(Db, DesignDoc, Options);
do_fetch_results(Db, {_DesignName, _ViewName}=DesignDoc, Options) ->
    fetch_results(Db, DesignDoc, Options).

-spec fetch_results(couchbeam_db(), ddoc(), view_options()) ->
          {'ok', kz_json:objects() | kz_term:ne_binaries()} |
          couchbeam_error().
fetch_results(Db, DesignDoc, Options) ->
    ?RETRY_504(
       case couchbeam_view:fetch(Db, DesignDoc, Options) of
           {'ok', JObjs} -> {'ok', JObjs};
           {'error', Error, []} -> {'error', Error};
           {'error', Error, Rows} ->
               lager:error("error ~p with results, ~p", [Error, Rows]),
               {'error', Error};
           {'error', _}=Error -> Error
       end
      ).

-spec map_options(view_options()) -> view_options().
map_options(Options) ->
    [map_view_option(O) || O <- Options].

-spec map_view_option(any()) -> any().
map_view_option({K, V})
  when is_binary(K) ->
    {kz_term:to_atom(K, 'true'), V};
map_view_option(KV) -> KV.

-spec do_fetch_results_count(couchbeam_db(), kz_term:ne_binary() | ddoc(), view_options()) ->
          {'ok', kz_term:api_integer()} |
          couchbeam_error().
do_fetch_results_count(Db, <<DesignDoc/binary>>, Options) ->
    [DesignName, ViewName | _] = binary:split(DesignDoc, <<"/">>, ['global']),
    do_fetch_results_count(Db, {DesignName, ViewName}, map_options(Options));
do_fetch_results_count(Db, DesignDoc, Options) ->
    ?RETRY_504(
       case couchbeam_view:count(Db, DesignDoc, Options) of
           {'error', E} -> {'error', kz_couch_util:format_error(E)};
           N -> {'ok', N}
       end
      ).

-spec do_get_design_info(couchbeam_db(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          couchbeam_error().
do_get_design_info(#db{}=Db, Design) ->
    ?RETRY_504(couchbeam:design_info(Db, Design)).

-spec show(server(), kz_term:ne_binary(), show_doc(), binary() | 'null', [{'query_string', binary()}]) ->
          {'ok', kz_json:object()} |
          couchbeam_error().
show(#server{}=Conn, <<DbName/binary>>, <<DesignDoc/binary>>, DocId, Options) ->
    [DesignName, ViewName|_] = binary:split(DesignDoc, <<"/">>, ['global']),
    show(Conn, DbName, {DesignName, ViewName}, DocId, Options);
show(#server{}=Conn, DbName, {_, _}=Design, DocId, Options) ->
    Db = kz_couch_util:get_db(Conn, DbName),
    couchbeam_view:show(Db, Design, DocId, Options).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec find(server(), kz_term:ne_binary(), kazoo_data:ddoc(), kz_view:selector(), kz_view:options()) -> kz_either:either(kz_view:error(), kz_view_cursor:cursor()).
find(#server{}=Conn, Database, DesignDoc, Selector, Options) ->
    case build_load_params(Database, DesignDoc, Selector, Options) of
        {'ok', 'empty'} ->
            {'ok', []};
        {'ok', {#{view_options := _ViewOptions}=Params, Databases}} ->
            ?MAYBE_LOG("view_options: ~1000p", [_ViewOptions]),
            NewOptions = props:delete_keys(?COUCH_ONLY_OPTIONS, Options),
            LoadParams = Params#{server => Conn},
            {'ok', kz_view_cursor:new(?MODULE, Databases, LoadParams, NewOptions)};
        {'error', _}=Error ->
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec bookmark(Cursor::kz_view_cursor:cursor()) -> map().
bookmark(#{'bookmark' := 'undefined', 'batch_size' := BatchSize}=Cursor) ->
    bookmark(Cursor#{'bookmark' => new_bookmark(Cursor, BatchSize)});
bookmark(#{'bookmark' := Bookmark}) ->
    maps:with(['startkey', 'startkey_docid', 'next_startkey', 'next_startkey_docid'], Bookmark).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec count(Cursor :: kz_view_cursor:cursor()) -> kz_either:either(kz_view:error(), non_neg_integer()).
count(Cursor) -> count(Cursor, 0).

count(#{'databases' := []}, Acc) ->
    {'ok', Acc};
count(#{'databases' := [Database | RestDbs], 'driver_params' := Params}=Cursor, Acc) ->
    #{'server' := Server
     ,'design_view' := View
     } = Params,
    ViewOptions = [{'reduce', 'false'}
                  ,{'group', 'false'}
                  ],
    {'ok', Db} = couchbeam:open_db(Server, Database),
    ?MAYBE_LOG("kz_datamgr:get_results_count(~p, ~p, ~p)", [Database, View, ViewOptions]),
    case do_fetch_results_count(Db, View, ViewOptions) of
        {'ok', Count} ->
            count(Cursor#{'databases' => RestDbs}, Count + Acc);
        {'error', _}=Error ->
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec next_batch(Cursor :: kz_view_cursor:cursor(), BatchSize::kz_view:limit()) ->
          kz_view_cursor:result().
next_batch(Cursor, BatchSize) ->
    fetch_more(Cursor, new_bookmark(Cursor, BatchSize), []).

%% build_load_params {{{
%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec build_load_params(kz_term:ne_binary(), kazoo_data:ddoc(), kz_view:selector(), view_options()) ->
          kz_either:either(kz_view:error(), {params(), kz_term:ne_binaries()} | 'empty').
build_load_params(Database, 'all_docs', Selector, Options) ->
    Params = #{'design_view' => 'all_docs'
              ,'view_name' => <<"all_docs">>
              ,'ddoc' => <<"all_docs">>
              ,'ddoc_module' => 'kzc_all_docs'
              },
    maybe_design_options(Database, Params, Selector, Options);
build_load_params(Database, DesignDoc, Selector, Options) ->
    DbClass = kzs_util:db_classification(Database),
    [Design, ViewName] = split_ddoc_view(DesignDoc),
    Params = #{'design_view' => DesignDoc
              ,'ddoc' => Design
              ,'view_name' => ViewName
              },
    case ensure_loaded(Database, DbClass, Design, props:is_true('no_design_module', Options, 'false')) of
        'false' ->
            lager:warning("no module for db '~s' and design '~s'", [Database, <<Design/binary, "/", ViewName/binary>>]),
            {'error', 'not_found'};
        'undefined' ->
            %% it feels a bit like monkey patching, but lets user
            %% provide databases if there is no design module yet.
            %% Useful for MODBs, the caller needs to set their own start/end keys and databases
            %% but still can use cursor.
            maybe_design_options(Database, Params#{'ddoc_module' => 'undefined'}, Selector, Options);
        Module ->
            case Module:has_view(ViewName) of
                'true' ->
                    maybe_design_options(Database, Params#{'ddoc_module' => Module}, Selector, Options);
                'false' ->
                    lager:warning("design module '~s' does not have view '~s' in db ~s", [Module, ViewName, Database]),
                    {'error', 'not_found'}
            end
    end.

split_ddoc_view('all_docs') ->
    ['all_docs', 'all_docs'];
split_ddoc_view(DesignDoc) ->
    binary:split(DesignDoc, <<$/>>, ['global']).

%% ensure_loaded {{{

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec ensure_loaded(kz_term:ne_binary(), kazoo_data:db_classification(), kazoo_data:ddoc(), boolean()) ->
          'false' | module() | 'undefined'.
ensure_loaded(_, _, 'all_docs', _) ->
    'kzc_all_docs';
ensure_loaded(_, _, _, 'true') ->
    %% it feels a bit like monkey patching, but lets user
    %% provide databases if there is no design module yet.
    %% Useful for MODBs, the caller needs to set their own start/end keys and databases
    %% but still can use cursor.
    'undefined';
ensure_loaded(DbName, Class, Design, 'false') ->
    Thing = db_or_class(DbName, Class),
    case kz_module:ensure_loaded(<<"kzc_", Thing/binary, "_", Design/binary>>) of
        'false' ->
            case kz_module:ensure_loaded(<<"kz_design_", Thing/binary, "_", Design/binary>>) of
                'false' -> 'false';
                Mod -> Mod
            end;
        Mod -> Mod
    end.

db_or_class(_, 'account'=Class) ->
    kz_term:to_binary(Class);
db_or_class(_, 'modb'=Class) ->
    kz_term:to_binary(Class);
db_or_class(_, 'numbers'=Class) ->
    kz_term:to_binary(Class);
db_or_class(_, 'provisioner'=Class) ->
    kz_term:to_binary(Class);
db_or_class(_, 'ratedeck'=Class) ->
    kz_term:to_binary(Class);
db_or_class(_, 'resource_selectors'=Class) ->
    kz_term:to_binary(Class);
db_or_class(_, 'yodb'=Class) ->
    kz_term:to_binary(Class);
db_or_class(Db, _) ->
    Db.
%% ensure_loaded }}}

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_design_options(kz_term:ne_binary(), params(), kz_view:selector(), view_options()) ->
          kz_either:either(kz_view:error(), {params(), kz_term:ne_binaries()} | 'empty').
maybe_design_options(Database, #{'ddoc_module' := Module, 'view_name' := View}=Params, Selector, Options) ->
    case maybe_build_range_keys(Params, Selector, Options) of
        {'ok', 'empty'}=Empty ->
            Empty;
        {'ok', RangeKey} when Module =:= 'undefined' ->
            maybe_design_databases(Database, Params#{'view_options' => set_view_options(RangeKey, Options)}, Options);
        {'ok', RangeKey} ->
            DesignOpts =  Module:metadata('options', View),
            NewOptions = set_view_options(props:set_values(DesignOpts, RangeKey), Options),
            maybe_design_databases(Database, Params#{'view_options' => NewOptions}, NewOptions);
        {'error', _}=Error ->
            Error
    end.

-spec maybe_design_databases(kz_term:ne_binary(), params(), kz_view:options()) ->
          kz_either:either(kz_view:error(), {params(), kz_term:ne_binaries()}).
maybe_design_databases(Database, #{'ddoc_module' := 'undefined'}=Params, Options) ->
    {'ok', {Params, props:get_value('databases', Options, [Database])}};
maybe_design_databases(Database, #{'ddoc_module' := Module, 'view_name' := View}=Params, Options) ->
    case props:get_value('databases', Options) of
        'undefined' ->
            case Module:metadata('databases_fun', View) of
                'undefined' ->
                    {'ok', {Params, [Database]}};
                Fun when is_function(Fun, 2) ->
                    case Fun(Params, [Database]) of
                        {'ok', Databases} ->
                            {'ok', Params, Databases};
                        {'error', _}=Error ->
                            Error
                    end
            end;
        Databases ->
            {'ok', {Params, Databases}}
    end.

set_view_options(DesignOptions, Options) ->
    Opts = props:delete_keys(?RANGE_KEYS, Options),
    %% removing limit, use kz_view_cursor:next/2 to retrive custom limit or
    %% let kz_view_cursor:next/1 uses batch_size or limit options
    ViewOptions = props:insert_values(DesignOptions, props:delete('limit', cleanse_options(Opts))),
    case props:get_first_defined(['reduce', 'group', 'group_level'], ViewOptions) of
        'undefined' -> set_direction(ViewOptions, Options);
        'false' -> set_direction(ViewOptions, Options);
        _V -> set_direction(props:delete('include_docs', ViewOptions), Options)
    end.

set_direction(ViewOptions, Options) ->
    case props:get_value('direction', Options) of
        'undefined' -> props:delete('descending', ViewOptions);
        'ascending' -> props:delete('descending', ViewOptions);
        'descending' -> ['descending' | props:delete('descending', ViewOptions)]
    end.

%% build_ranges_keys {{{
%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec range_keys_from_bookmark(kz_view:options() | 'undefined') -> view_options().
range_keys_from_bookmark('undefined') ->
    [];
range_keys_from_bookmark([]) ->
    [];
range_keys_from_bookmark(Bookmark) ->
    ?MAYBE_LOG("importing range keys from bookmark", []),
    props:filter_undefined(
      [{'startkey', props:get_value('next_startkey', Bookmark)}
      ,{'startkey_docid', props:get_value('next_startkey_docid', Bookmark)}
      ]).

-spec maybe_build_range_keys(params(), kz_view:selector(), kz_view:options()) ->
          kz_either:either(kz_view:error(), view_options() | 'empty').
maybe_build_range_keys(#{ddoc_module := 'undefined'}, _Selector, Options) ->
    Keys = keys_from_option(Options),
    sanity_and_boomark(Options, Keys);
maybe_build_range_keys(#{ddoc_module := Module}=Params, Selector, Options) ->
    Keys = keys_from_option(Options),
    %% we want to allow the caller to set their custom key/range keys if they don't want those to be generated
    %% automatically. So if see any key related in options we stop auto key generation and pass key options as-is to
    %% couchdb.
    %%
    %% In this case it is up to caller to make sure they have the correct view options. Here we only check if key and
    %% range keys are not mixed as a per caution to avoid pagination issues.
    case kz_term:is_empty(Keys) of
        'false' ->
            ?MAYBE_LOG("some range keys are overwritten in option, not calling ~s module to generate range keys"
                      ,[Module]
                      ),
            sanity_and_boomark(Options, Keys);
        'true' ->
            case build_design_range_keys(Params, Selector, Options) of
                {'ok', 'empty'}=Empty -> Empty;
                {'error', _}=Error -> Error;
                {'ok', GeneratedKeys} ->
                    sanity_and_boomark(Options, GeneratedKeys)
            end
    end.

-spec sanity_and_boomark(kz_view:options(), view_options()) ->
          {'ok', view_options()} |
          {'error', kz_term:ne_binary()}.
sanity_and_boomark(Options, Keys) ->
    Bookmark = range_keys_from_bookmark(props:get_value('bookmark', Options)),
    sanity_and_boomark(Options, Keys, Bookmark).

-spec sanity_and_boomark(kz_view:options(), view_options(), view_options()) ->
          {'ok', view_options()} |
          {'error', kz_term:ne_binary()}.
sanity_and_boomark(_Options, Keys, []) ->
    {'ok', Keys};
sanity_and_boomark(Options, Keys, Bookmark) ->
    case key_keys_sanity_check(Options, Keys) of
        'no_keys' ->
            ?MAYBE_LOG("overwriting bookmark on generated range keys", []),
            {'ok', props:set_values(Bookmark, Keys)};
        {'ok', _}=Ok ->
            %% Also note we *intentionally* refuse to merge bookmark when key/keys is in use
            %% since bookmark contains startkey and this is not valid couchDb view query.
            ?MAYBE_LOG("rejecting imported bookmark because of using of key/keys", []),
            Ok;
        {'error', _}=Error ->
            Error
    end.

%% @doc check you're using key or range keys and not mixing them.
%%
%% If you're seeing a error log from here that means you're mixing [{'key', ....}] or [{'keys', ...}] view options with
%% [{startkey, ...}, {'endkey', ...}]. This is invalid operation in couchDb.
%% You can try and use the same key for both start/end. If u are using keys then remove start/end from your view
%% options.
%%
%% Also note we *intentionally* refuse to merge bookmark when key/key is in use since bookmark contains startkey and
%% this is not valid.
%%
%% We also not allowing batching because it works by setting startkey for next batch and again startkey and key/keys
%% are not compatible.
%%
%% In other words, if you're making a query with key/keys, DO NOT EVER DO pagination or batching!!!
-spec key_keys_sanity_check(kz_view:options(), view_options()) ->
          'no_keys' |
          kz_either:either(kz_term:ne_binary(), view_options()).
key_keys_sanity_check(Options, Keys) ->
    case has_key_options(Keys) of
        'true' ->
            case has_start_end_options(Keys) of
                'true' ->
                    lager:critical("mixing key/keys and start/end keys is invalid"),
                    {'error', <<"mixing key and range key is invalid">>};
                'false' ->
                    batch_not_allowed_on_keys(Options, Keys)
            end;
        'false' ->
            'no_keys'
    end.

-spec has_key_options(kz_view:options()) -> boolean().
has_key_options(Options) ->
    lists:any(fun(K) -> lists:member(K, ['key', 'keys']) end, Options).

-spec has_start_end_options(kz_view:options()) -> boolean().
has_start_end_options(Options) ->
    lists:any(fun(K) -> lists:member(K, ['start_key', 'startkey', 'end_key', 'endkey']) end, Options).

%% We not allowing batching because it works by setting startkey for next batch and startkey and key/keys are not
%% compatible.
%%
%% In other words, if you're making a query with key/keys, DO NOT EVER DO pagination or batching!!!
-spec batch_not_allowed_on_keys(kz_view:options(), view_options()) -> kz_either:either(kz_term:ne_binary(), view_options()).
batch_not_allowed_on_keys(Options, Keys) ->
    %% FIXME: same thing with pagee_size, but maybe just allow it but log it?
    %% pagination is the caller's concern??
    case props:is_true('no_batch', Options, 'false')
        orelse 'infinity' =:= props:get_value('batch_size', Options, 'infinity')
    of
        'true' ->
            {'ok', Keys};
        'false' ->
            lager:critical("batch options and key is not allowed"),
            {'error', <<"batch options and key is not allowed">>}
    end.

-spec keys_from_option(kz_view:options()) -> view_options().
keys_from_option(Options) ->
    case [{Key, Value} || {Key, Value} <- Options,
                          lists:member(Key, ?RANGE_KEYS)
         ]
    of
        [] -> [];
        Keys ->
            ?MAYBE_LOG("importing range keys from options", []),
            Keys
    end.

build_design_range_keys(#{ddoc_module := Module, view_name := View}=Params, Selector, Options) ->
    case Module:metadata('build_key_fun', View) of
        'undefined' ->
            build_range_keys(Params, Selector, Options);
        Fun when is_function(Fun, 3) ->
            Fun(Params, Selector, Options)
    end.

-spec build_range_keys(params(), kz_view:selector(), kz_view:options()) -> kz_either:either(kz_view:error(), view_options() | 'empty').
%% key
build_range_keys(_, [{'key', []}], _) ->
    lager:warning("selector 'key' is empty, returning empty to not make unnecessary db request"),
    {'ok', 'empty'};
build_range_keys(Params, [{'key', Selector}], Options) ->
    case field_range('key', Params, Selector, Options) of
        {'ok', 'empty'} ->
            {'ok', 'empty'};
        {'ok', Key} ->
            {'ok', [{'key', Key}]};
        {'error', _}=E ->
            E
    end;

%% keys
build_range_keys(Params, [{'keys', Selectors}], Options) ->
    case [Key
          || Selector <- Selectors,
             {'ok', Key} <- [field_range('key', Params, Selector, Options)],
             'empty' =/= Key
         ]
    of
        [] ->
            {'ok', 'empty'};
        Keys ->
            {'ok', [{'keys', Keys}]}
    end;

%% start/end
build_range_keys(Params, [{'start', Start}, {'end', End}], Options) ->
    case {field_range('start', Params, Start, Options)
         ,field_range('end', Params, End, Options)
         }
    of
        {{'ok', StartK}, {'ok', EndK}} ->
            case {StartK, EndK} of
                {'empty', 'empty'} ->
                    {'ok', 'empty'};
                {'empty', EndK} ->
                    {'ok', [{'endkey', EndK}]};
                {StartK, 'empty'} ->
                    {'ok', [{'startkey', StartK}]};
                {StartK, EndK} ->
                    {'ok', [{'startkey', StartK}, {'endkey', EndK}]}
            end;
        {{'error', SMsg}, {'error', EMsg}} ->
            {'error', kz_binary:format("startkey: ~s, endkey: ~s", [SMsg, EMsg])};
        {{'error', SMsg}, _} ->
            {'error', kz_binary:format("startkey: ~s", [SMsg])};
        {_, {'error', EMsg}} ->
            {'error', kz_binary:format("endkey: ~s", [EMsg])}
    end;
build_range_keys(Params, [], Options) ->
    %% this is specifically handling the case when the view key is `null'
    %% otherwise we don't care and we just make query as-is.
    case field_range('key', Params, [], Options) of
        {'ok', 'null'} ->
            {'ok', [{'key', 'null'}]};
        _ ->
            {'ok', []}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec field_range(key_type(), params(), kz_view:selector(), kz_view:options()) ->
          kz_either:either(kz_view:error(), kazoo_data:key_range()).
field_range(KeyType, #{ddoc_module := Module, view_name := View}, Selector, Options) ->
    Fields =  Module:metadata('query_fields', View),
    field_range(KeyType, Selector, Options, Fields, []).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec field_range(key_type(), kz_view:selector(), kz_view:options(), key_fields(), kz_term:proplist()) ->
          kz_either:either(kz_view:error(), kazoo_data:key_range()).
field_range(_, _, _, 'null', _) ->
    {'ok', 'null'};
%% selector is empty, do not create range keys automagically
field_range(_, [], _, _, _) ->
    {'ok', []};
field_range(KeyType, Selector, Options, <<Field/binary>>, _) ->
    Direction = props:get_value('direction', Options, 'ascending'),
    case props:get_value(Field, Selector, 'null') of
        'null' when KeyType =:= 'key' ->
            lager:warning("required field '~s' is missing from selector", [Field]),
            {'error', 'failed'};
        'null' when KeyType =:= 'start'
                    orelse KeyType =:= 'end' ->
            {'ok', min_max_key(KeyType, 'min_max', Direction)};
        Value ->
            {'ok', Value}
    end;
field_range(KeyType, _, Options, [], Acc) ->
    Direction = props:get_value('direction', Options, 'ascending'),
    {'ok', lists:reverse(
             [min_max_key(KeyType, Value, Direction)
              || {_, Value} <- Acc
             ]
            )
    };
field_range(KeyType, Selector, Options, [Field | Fields], Acc) ->
    case props:get_value(Field, Selector, 'null') of
        'null' when KeyType =:= 'key' ->
            lager:warning("required field '~s' is missing from selector", [Field]),
            {'error', 'failed'};
        'null' ->
            KeyAcc = [{ForField, 'min_max'} || ForField <- [Field | Fields]] ++ Acc,
            field_range(KeyType, Selector, Options, [], KeyAcc);
        Value ->
            field_range(KeyType, Selector, Options, Fields, [{Field,Value}|Acc])
    end.

%%------------------------------------------------------------------------------
%% @doc for start/end key it does matter what is min or max.
%% @end
%%------------------------------------------------------------------------------
-spec min_max_key(key_type(), 'min_max' | kazoo_data:key_range(), kz_view:direction()) -> kazoo_data:key_range().
min_max_key('start', 'min_max', 'ascending') ->
    'null';
min_max_key('end', 'min_max', 'ascending') ->
    kz_term:high_unicode_value();
min_max_key('start', 'min_max', 'descending') ->
    kz_term:high_unicode_value();
min_max_key('end', 'min_max', 'descending') ->
    'null';
min_max_key(_, RangeKey, _) -> RangeKey.
%% build_range_keys }}}

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec cleanse_options(kz_view:options()) -> view_options().
cleanse_options(Options) ->
    [KV || KV <- Options,
           is_couch_options(KV)
    ].

is_couch_options({K, _}) -> lists:member(K, ?ALL_COUCH_VIEW_OPTIONS);
is_couch_options(K) -> lists:member(K, ?ALL_COUCH_VIEW_OPTIONS).

%% }}} build_load_params

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
handle_ret(#{'cursor_size' := TotalRows}=Cursor, #{'size' := Size}=Bookmark, Rows) ->
    NewCursor = Cursor#{'bookmark' => Bookmark
                       ,'cursor_size' => TotalRows + Size
                       },
    {'ok', {NewCursor, Rows}}.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
new_bookmark(#{'bookmark' := 'undefined'
              ,'driver_params' := #{'view_options' := ViewOptions}
              }, BatchSize) ->
    StartKeyOpts = props:get_value('startkey', ViewOptions),
    StartDocIdOpts = props:get_first_defined(["startkey_docid", 'startkey_docid', <<"startkey_docid">>], ViewOptions),
    #{'batch_size' => BatchSize
     ,'next_startkey' => 'undefined'
     ,'next_startkey_docid' => 'undefined'
     ,'size' => 0
     ,'startkey' => StartKeyOpts
     ,'startkey_docid' => StartDocIdOpts
     };
new_bookmark(#{'bookmark' := Bookmark}, BatchSize) ->
    Bookmark#{'batch_size' => BatchSize
             ,'size' => 0
             }.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec fetch_more(kz_view_cursor:cursor(), map(), kz_json:objects()) -> kz_view_cursor:result().
fetch_more(#{'reductions' := Reductions, 'reductions_max' := ReductionsMax}=Cursor, Bookmark, Rows)
  when is_integer(ReductionsMax)
       andalso Reductions =:= ReductionsMax ->
    lager:error("reached to the maximum allowed loop ~b for cursor", [Reductions]),
    handle_ret(Cursor#{'is_exhausted' => 'true'}, Bookmark, Rows);
fetch_more(#{'databases' := []}=Cursor, Bookmark, Rows) ->
    ?MAYBE_LOG("databases exhausted", []),
    handle_ret(Cursor#{'is_exhausted' => 'true'}, Bookmark, Rows);
fetch_more(Cursor, Bookmark, Rows) ->
    %% pagination flow {{{
    %% * set [next_startkey, next_startkey_docid] to undefined when bookmark is undefined (start of the query)
    %% * set [startkey, startkey_docid] from view options's startkey_* for the first query
    %% * for view_options set startkey* to next_startkey* from bookmark if not defined set startkey* from bookmark
    %% * dbs is empty:
    %%   * stop, databases exhausted
    %% * query with the first db in the list
    %%   * set startkey_* to the current startkey* of bookmark:
    %%     * if any of [startkey, endkey] are set remove [key, keys] since this is not the first query anymore
    %%       and these range keys are not compatible with each other
    %%     * the goal here to find start/end keys, if the request initially doesn't have [startkey, endkey] we query
    %%       the db with what other range key we have (or we don't have) for the first time.
    %%       Then we have now [startkey, endkey] to continue pagination.
    %%     * set limit if batch_size is not infinity:
    %%       * add 1 to limit if batch_size is not infinity so we can calculate next_startkey
    %% * check memory usage if requested and return error if it is exceeded
    %% * find the next_startkey and remove that one extra row (get_rows_and_next_key)
    %% * apply filtermap
    %%   * add length of rows returned from filtermap to the size
    %%   * add rows returned from filtermap to rows
    %% * decide how to continue from here:
    %%   * (NEXT_DB) Condition:
    %%     - the batch_size is infinity
    %%       * basically we are looping over dbs and getting all rows that dbs can give
    %%       * continue to next db
    %%   * (EXHAUSTED) Condition:
    %%     - batch_size is equal to rows length
    %%     - next_startkey IS FOUND
    %%       * the page is exhausted
    %%       * the current db has more rows to give
    %%       * stop because batch_size is exhausted and we found the next_startkey
    %%   * (SAME_DB) Condition:
    %%     - next_startkey IS FOUND
    %%     - next_startkey =/= old next_startkey
    %%       * the page IS NOT exhausted
    %%       * filtermap may have filtered out some rows
    %%       * current db *has* more rows to give
    %%       * query same db again
    %%   * (SAME_DB) Condition:
    %%     - next_startkey IS FOUND
    %%     - next_startkey =:= old next_startkey
    %%       - AND next_startkey_docid =/= undefined
    %%       - AND old next_startkey_docid =/= new next_startkey_docid
    %%         * the page IS NOT exhausted
    %%         * filtermap may have filtered out some rows
    %%         * current db *has* more rows to give
    %%         * query same db again
    %%   * (INCONCLUSIVE) Condition:
    %%     - next_startkey IS FOUND
    %%     - next_startkey =:= old next_startkey
    %%         * the page IS NOT exhausted
    %%         * filtermap may have filtered out some rows
    %%         * current db *has* more rows to give
    %%         * inconclusive, we have repeating startkey and both old and new
    %%           next_startkey_docid are either undefined (because of reduce?) or equal
    %%         * return error
    %%   * (NEXT_DB) Condition:
    %%     - next_startkey IS NOT found
    %%       * the page is exhausted OR rows length is under batch_size
    %%       * if the page is exhausted that means current dn has NO more rows to give
    %%         we need to continue to next db to get *one* more row (if any) and find the next_startkey
    %%       * if rows length in under continue to next db to fulfill the batch_size
    %% }}}
    #{'driver_params' := Params
     ,'databases' := [Db|RestDbs]
     ,'reductions' := Reductions
     } = Cursor,
    #{'design_view' := View
     ,'server' := Server
     } = Params,
    Cursor1 = Cursor#{'reductions' => Reductions + 1},
    ViewOptions = next_view_options(Cursor1, Bookmark),

    ?MAYBE_LOG("kz_datamgr:get_results(~p, ~p, ~1000p)", [Db, View, ViewOptions]),

    case get_results(Server, Db, View, ViewOptions) of
        {'error', 'not_found'} ->
            NewCursor = update_db_errors(Cursor1, Db, db_or_view_not_found(Server, Db, View)),
            handle_db_not_found(NewCursor#{'databases' => RestDbs}, Bookmark, Rows);
        {'error', _Reason}=Error ->
            ?MAYBE_LOG("failed to query view ~s from db ~s: ~p", [View, Db, _Reason]),
            {'error', Error};
        {'ok', JObjs} ->
            NewCursor = update_db_errors(Cursor1, Db, 'ok'),
            handle_query_results(NewCursor, Bookmark, Rows, JObjs, props:get_value('limit', ViewOptions))
    end.

handle_db_not_found(Cursor, Bookmark, Rows) ->
    case kz_view_cursor:is_last_db(Cursor) of
        'false' ->
            %% lets query the next db in hope that it exists and has some result.
            ?MAYBE_LOG("last db returned error but we have hopes, querying next db...", []),
            fetch_more(Cursor, Bookmark, Rows);
        'true' ->
            LastError = kz_view_cursor:last_db_error(Cursor),
            case other_dbs_have_results(Cursor) of
                'true' ->
                    %% soft ignoring missing db or view, useful for ignoring missing or buggy modb/yodb.
                    ?MAYBE_LOG("databases exhausted with some results from other dbs, ignoring errors and returning results", []),
                    handle_ret(Cursor#{'is_exhausted' => 'true'}, Bookmark, Rows);
                'false' ->
                    %% Returning error if all dbs return error.
                    %% This mostly applies for querying a system or an account db, when we always expect that db or view
                    %% exists, returning error here will lets us handle the error better.
                    ?MAYBE_LOG("no result from any database, returning the last error: ~p", [LastError]),
                    {'error', LastError}
            end
    end.

other_dbs_have_results(Cursor) ->
    kz_term:is_not_empty(
      [Db || {Db, MaybeOkay} <- kz_view_cursor:get_db_errors(Cursor),
             MaybeOkay =:= 'ok'
      ]
     ).

db_or_view_not_found(Server, Db, View) ->
    case kz_couch_db:db_exists(Server, Db) of
        'true' ->
            ?MAYBE_LOG("view ~s does not exists in db ~s", [View, Db]),
            'invalid_view_name';
        'false' ->
            ?MAYBE_LOG("db ~s does not exists", [Db]),
            'invalid_db_name'
    end.

update_db_errors(#{'db_errors' := DbErrors}=Cursor, Db, Error) ->
    Cursor#{'db_errors' => [{Db, Error} | DbErrors]}.

-spec next_view_options(kz_view_cursor:cursor(), map()) -> view_options().
next_view_options(#{'direction' := Direction
                   ,'databases' := [_Db|_]
                   ,'driver_params' := #{'design_view' := _View
                                        ,'view_options' := ViewOptions
                                        }
                   ,'other_options' := OtherOptions
                   }
                 ,#{'batch_size' := BatchSize
                   ,'size' := Size
                   ,'startkey' := StartKey
                   ,'startkey_docid' := StartDocId
                   ,'next_startkey' := NextStartKey
                   ,'next_startkey_docid' := NextStartDocId
                   }) ->
    LimitWithLast = add_limit(BatchSize, Size),
    {NextKey, NextId} = case NextStartKey of
                            'undefined' -> {StartKey, StartDocId};
                            N -> {N, NextStartDocId}
                        end,
    Prop = props:filter_undefined(
             [{'limit', LimitWithLast}
             ,{'startkey', NextKey}
             ,{'startkey_docid', NextId}
             ]),
    Options = props:set_values(Prop, ViewOptions),

    %% FIXME: What will happend if ViewOptions has key/keys in it?
    %% If they have key/keys and we set startkey here it is invalid options. If they have key and we remove keys, the
    %% view options potentialy loses its ending condition and will return everything in view.
    %%
    %% In other words, if you're making a query with key/keys, DO NOT EVER DO pagination or batching!!!
    case {props:get_value('startkey', Options)
         ,props:get_value('endkey', Options)
         }
    of
        {'undefined', 'undefined'} -> Options;
        {_, _}=StartEnd ->
            KeyMinLength = props:get_value('key_min_length', OtherOptions),
            maybe_expand_keys(KeyMinLength, StartEnd, props:delete_keys(['key', 'keys'], Options), Direction)
    end.

%%------------------------------------------------------------------------------
%% @doc When reduce and group level is involved, key length returned by CouchDB
%% can be shorter then actual key length of the view. Because of how
%% view collation works, this would cause one-off error in which the row with
%% those keys won't matched and not included in the result.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_expand_keys(kz_term:api_non_neg_integer(), {kazoo_data:key_range(), kazoo_data:key_range()}, view_options(), kz_view:direction()) ->
          view_options().
maybe_expand_keys('undefined', _, Options, _) ->
    Options;
maybe_expand_keys(KeyMinLength, StartEnd, Options, Direction) ->
    {Start, End} = expand_min_max_keys(StartEnd, Direction, KeyMinLength),
    props:set_values([{'startkey', Start}
                     ,{'endkey', End}
                     ], Options).

expand_min_max_keys({StartKey, EndKey}, Direction, KeyMinLength) ->
    {expand_min_max_keys2('start', StartKey, Direction, KeyMinLength)
    ,expand_min_max_keys2('end', EndKey, Direction, KeyMinLength)
    }.

expand_min_max_keys2(KeyType, RangeKey, Direction, KeyMinLength) when is_list(RangeKey) ->
    RangeKeyPadded = maybe_min_max_pad(KeyMinLength, RangeKey),
    lists:map(fun(Elem) -> min_max_key(KeyType, Elem, Direction) end, RangeKeyPadded);
expand_min_max_keys2(_, RangeKey, _, _) -> RangeKey.

maybe_min_max_pad('undefined', RangeKey) -> RangeKey;
maybe_min_max_pad(KeyMinLength, RangeKey) ->
    lists:reverse(min_max_pad(KeyMinLength - length(RangeKey), lists:reverse(RangeKey))).

min_max_pad(0, RangeKey) -> RangeKey;
min_max_pad(N, RangeKey) ->
    ?MAYBE_LOG("padding composite key", []),
    min_max_pad(N-1, ['min_max' | RangeKey]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec add_limit(kz_view:limit(), non_neg_integer()) -> kz_term:api_pos_integer().
add_limit('infinity', _TotalQueried) -> 'undefined';
add_limit(BatchSize, TotalQueried) -> 1 + BatchSize - TotalQueried.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_query_results(kz_view_cursor:cursor(), map(), kz_json:objects(), kz_json:objects(), kz_term:api_pos_integer()) ->
          kz_view_cursor:result().
handle_query_results(#{'memory_limit' := MemLimit}=Cursor, Bookmark, Rows, JObjs, LimitWithLast)
  when not is_integer(MemLimit) ->
    process_query_results(Cursor, Bookmark, Rows, JObjs, LimitWithLast);
handle_query_results(#{'memory_limit' := MemoryLimit}=Cursor, Bookmark, Rows, JObjs, LimitWithLast) ->
    case process_info(self(), ['memory']) of
        [{'memory', MemoryUsed}] when MemoryUsed =< MemoryLimit ->
            ?MAYBE_LOG("under memory cap of ~p: ~p used", [MemoryLimit, MemoryUsed]),
            process_query_results(Cursor, Bookmark, Rows, JObjs, LimitWithLast);
        [{'memory', MemoryUsed}] ->
            lager:warning("memory used ~p exceeds limit ~p", [MemoryUsed, MemoryLimit]),
            {'error', 'memory_exceeded'}
    end.

process_query_results(Cursor, Bookmark, Rows, JObjs0, LimitWithLast) ->
    #{'size' := TotalQueried
     ,'next_startkey' := OldLastKey
     ,'next_startkey_docid' := OldStartDocId
     } = Bookmark,
    {NewLastKey, NewLastDocId, JObjs} = get_rows_and_next_key(Bookmark, JObjs0, LimitWithLast, length(JObjs0)),
    try kz_view:apply_filtermap(Cursor, JObjs) of
        {'error', _Reason}=Error ->
            lager:debug("filtermap returned error: ~p", [_Reason]),
            Error;
        FilteredJObjs when is_list(FilteredJObjs) ->
            FilteredLength = length(FilteredJObjs),
            ?MAYBE_LOG("db_returned: ~b, after_limit: ~b, filtermap_returned: ~p, next_startkey: ~1000p next_startkey_docid: ~1000p"
                      ,[length(JObjs0), length(JObjs), FilteredLength, NewLastKey, NewLastDocId]
                      ),
            NewBookmark = Bookmark#{'size' => TotalQueried + FilteredLength
                                   ,'next_startkey' => NewLastKey
                                   ,'next_startkey_docid' => NewLastDocId
                                   },
            maybe_next_batch(Cursor, NewBookmark, Rows ++ FilteredJObjs, OldLastKey, OldStartDocId)
    catch
        _E:_T:ST ->
            kz_log:log_stacktrace(ST, "exception during applying filtermap: ~p:~p", [_E, _T]),
            {'error', 'exception'}
    end.

get_rows_and_next_key(#{'next_startkey' := StartKey
                       ,'next_startkey_docid' := StartDocId
                       }, JObjs, 'undefined', _ReturnedLength) ->
    %% ?MAYBE_LOG("unlimit query, re-using previously found next_startkey", []),
    {StartKey, StartDocId, JObjs};
get_rows_and_next_key(#{'next_startkey' := StartKey
                       ,'next_startkey_docid' := StartDocId
                       }, [], _Limit, _ReturnedLength) ->
    %% ?MAYBE_LOG("no result from db, re-using previously found next_startkey", []),
    {StartKey, StartDocId, []};
get_rows_and_next_key(_, JObjs, BatchSize, BatchSize) ->
    Last = lists:last(JObjs),
    %% ?MAYBE_LOG("got all request rows, calculating next_startkey", []),
    {kz_json:get_value(<<"key">>, Last), kz_json:get_value(<<"id">>, Last), lists:droplast(JObjs)};
get_rows_and_next_key(_, JObjs, _Limit, _ReturnedLength) ->
    %% ?MAYBE_LOG("returned rows is lower than limit, no next_startkey for this db", []),
    {'undefined', 'undefined', JObjs}.

maybe_next_batch(#{'databases' := [_|Dbs]}=Cursor, Bookmark, Rows, OldLastKey, OldStartDocId) ->
    case maybe_next_db(Bookmark) of
        'batch_exhausted' ->
            handle_ret(Cursor, Bookmark, Rows);
        'next_db' ->
            fetch_more(Cursor#{'databases' => Dbs}, Bookmark, Rows);
        'same_db' ->
            maybe_same_db(Cursor, Bookmark, OldLastKey, OldStartDocId, Rows)
    end.



-spec maybe_next_db(map()) -> 'batch_exhausted' | 'next_db' | 'same_db'.
maybe_next_db(#{'batch_size' := 'infinity'}) ->
    'next_db';
maybe_next_db(#{'batch_size' := BatchSize, 'size' := Size, 'next_startkey' := StartKey})
  when StartKey =/= 'undefined'
       andalso BatchSize =:= Size ->
    ?MAYBE_LOG("batch size ~b exhausted", [BatchSize]),
    'batch_exhausted';
maybe_next_db(#{'next_startkey' := 'undefined'}) ->
    ?MAYBE_LOG("no more result from this db, going to next db", []),
    'next_db';
maybe_next_db(#{}) ->
    'same_db'.



maybe_same_db(Cursor, #{'next_startkey' := NextStartKey
                       ,'next_startkey_docid' := NextStartDocId
                       }=Bookmark, NextStartKey, NextStartDocId, Rows) ->
    %% This may not happening at all. But to prove it we stop and be loud about it.
    %% The only way I can imagine this may happen is when we're reducing. With reduce there is no start_docid
    %% and the keys _may_ be repeating. But how does this works? In reduce rows with same keys merge or sum
    %% into one row.
    %% Even in interaction CDRs with group_level 2, if the keys are same, result is doc with lower doc._id.
    #{'databases' := [Db|_]
     ,'driver_params' := #{'design_view' := View}
     } = Cursor,
    lager:error("(pagination) INCONCLUSIVE result set in db ~s and view ~s, old startkey '~1000p' and startkey_docid '~1000p' are repeating"
               ,[Db, View, NextStartKey, NextStartDocId]
               ),
    NewBookmark = Bookmark#{'next_startkey' := 'undefined'
                           ,'next_startkey_docid' := 'undefined'
                           },
    fetch_more(Cursor#{'is_exhausted' := 'true'}, NewBookmark, Rows);

maybe_same_db(Cursor ,#{'next_startkey' := NextStartKey
                       ,'next_startkey_docid' := NextStartDocId
                       }=Bookmark, OldNextStartKey, OldNextStartDocId, Rows)
  when NextStartKey =:= OldNextStartKey
       andalso NextStartDocId =/= OldNextStartDocId ->
    ?MAYBE_LOG("current db has more result to give, querying it again", []),
    fetch_more(Cursor, Bookmark, Rows);

maybe_same_db(Cursor ,#{'next_startkey' := NextStartKey}=Bookmark, OldNextStartKey, _, Rows)
  when NextStartKey =/= OldNextStartKey ->
    ?MAYBE_LOG("current db has more result to give, querying it again", []),
    fetch_more(Cursor, Bookmark, Rows).
