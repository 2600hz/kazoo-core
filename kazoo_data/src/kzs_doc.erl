%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc data adapter behaviour
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzs_doc).

%% Doc related
-export([open_doc/4
        ,lookup_doc_rev/3
        ,save_doc/4
        ,save_docs/4
        ,del_doc/4
        ,del_docs/4
        ,ensure_saved/4
        ,copy_doc/4
        ,move_doc/4
        ]).

%% internal exports
-export([do_save_doc/4
        ,do_save_docs/4
        ,do_delete_doc/4
        ,do_delete_docs/4

        ,add_conn_rev/3
        ]).

-include("kz_data.hrl").

-type copy_function() :: fun((map(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) ->
                                    {'ok', kz_json:object()} | data_error()).
-export_type([copy_function/0]).
-define(COPY_DOC_OVERRIDE_PROPERTY, 'override_existing_document').
-define(COPY_TRANSFORM, 'transform').

%% Document related functions --------------------------------------------------

-spec open_doc(map(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> data_return().
open_doc(#{server := {_App, _Conn}}=Map, DbName, DocId, Options) ->
    OpenResult = do_open_doc(Map, DbName, DocId, Options),
    handle_opened_doc(OpenResult, Options).

do_open_doc(#{server := {App, Conn}}, DbName, DocId, Options) ->
    App:open_doc(Conn, DbName, DocId, Options).

-spec handle_opened_doc({'ok', kz_json:object()}|data_error(), kz_term:proplist()) ->
          data_return().
handle_opened_doc({'error', _}=Error, _Options) -> Error;
handle_opened_doc({'ok', Doc}, Options) ->
    handle_opened_doc(Doc, kz_doc:is_soft_deleted(Doc), props:get_is_true('deleted', Options, 'false')).

-spec handle_opened_doc(kz_json:object(), boolean(), boolean()) ->
          {'ok', kz_json:object()} |
          {'error', 'not_found'}.
handle_opened_doc(Doc, 'false',  _ReturnDeleted) -> {'ok', Doc};
handle_opened_doc(Doc, 'true', 'true') -> {'ok', Doc};
handle_opened_doc(Doc, 'true', 'false') ->
    lager:info("denying access to soft deleted doc: ~s", [kz_doc:id(Doc)]),
    {'error', 'not_found'}.

-spec save_doc(map(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) ->
          data_return().
save_doc(#{server := {_App, _Conn}}=Map, DbName, Doc, Options) ->
    {PreparedDoc, PublishDoc} = prepare_doc_for_save(DbName, Doc),
    try do_save_doc(Map, DbName, PreparedDoc, Options) of
        {'ok', JObj}=Ok ->
            update_cache(DbName, kz_doc:id(JObj), JObj, kz_doc:is_deleted(JObj)),
            kzs_publish:maybe_publish_doc(DbName, PublishDoc, JObj),
            maybe_spawn_secondary({DbName, remove_rev(JObj), Options}
                                 ,'do_save_doc'
                                 ,maps:get('secondary', Map, [])
                                 ),
            Ok;
        {'error', 'conflict'}=Error ->
            kzs_cache:flush_cache_doc(DbName, kz_doc:id(PreparedDoc)),
            Error;
        Else -> Else
    catch
        Ex:Er ->
            ?LOG_DEBUG("exception ~p : ~p", [Ex, Er]),
            {'error', 'failed'}
    end.

-spec do_save_doc(map(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) ->
          data_return().
do_save_doc(#{server := {App, Conn}}, DbName, Doc, Options) ->
    App:save_doc(Conn, DbName, Doc, Options).

update_cache(DbName, DocId, _JObj, 'true') ->
    kzs_cache:flush_cache_doc(DbName, DocId);
update_cache(DbName, DocId, JObj, 'false') ->
    %% Some save operations will return "rev" and not a full doc
    case kz_json:get_value(kz_doc:path_revision(), JObj) of
        'undefined' ->
            kzs_cache:flush_cache_doc(DbName, DocId);
        _Rev ->
            kzs_cache:add_to_doc_cache(DbName, DocId, JObj)
    end.

-spec save_docs(map(), kz_term:ne_binary(), kz_json:objects(), kz_term:proplist()) ->
          {'ok', kz_json:objects()} |
          data_error().
save_docs(#{server := {_App, _Conn}}=Map, DbName, Docs, Options) ->
    {PreparedDocs, PublishDocs} = lists:unzip([prepare_doc_for_save(DbName, D) || D <- Docs]),
    try do_save_docs(Map, DbName, PreparedDocs, Options) of
        {'ok', JObjs}=Ok ->
            kzs_publish:maybe_publish_docs(DbName, PublishDocs, JObjs),
            maybe_spawn_secondary({DbName, remove_rev(JObjs), Options}
                                 ,'do_save_docs'
                                 ,maps:get('secondary', Map, [])
                                 ),
            _ = [update_cache(DbName, kz_doc:id(JObj), JObj, 'true') || JObj <- JObjs],
            Ok;
        Else -> Else
    catch
        _Ex:Er -> {'error', {_Ex, Er}}
    end.

-spec do_save_docs(map(), kz_term:ne_binary(), kz_json:objects(), kz_term:proplist()) ->
          {'ok', kz_json:objects()} | data_error().
do_save_docs(#{server := {App, Conn}}, DbName, Docs, Options) ->
    App:save_docs(Conn, DbName, Docs, Options).

-spec lookup_doc_rev(map(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_term:ne_binary()} |
          data_error().
lookup_doc_rev(#{server := {App, Conn}}, DbName, DocId) ->
    App:lookup_doc_rev(Conn, DbName, DocId).

-spec ensure_saved(map(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) ->
          data_return().
ensure_saved(#{server := {App, Conn}}=Map, DbName, Doc, Options) ->
    {PreparedDoc, PublishDoc} = prepare_doc_for_save(DbName, Doc),
    try App:ensure_saved(Conn, DbName, PreparedDoc, Options) of
        {'ok', JObj}=Ok ->
            kzs_publish:maybe_publish_doc(DbName, PublishDoc, JObj),
            kzs_cache:add_to_doc_cache(DbName, kz_doc:id(JObj), JObj),
            _ = maybe_ensure_saved_others(kz_doc:id(Doc), Map, DbName, Doc, Options),
            Ok;
        Else -> Else
    catch
        Ex:Er ->
            lager:error("exception ~p : ~p", [Ex, Er]),
            'failed'
    end.

maybe_ensure_saved_others(<<"_design", _/binary>>, Map, DbName, Doc, Options) ->
    Others = maps:get('others', Map, []),
    lists:all(fun({_Tag, M1}) ->
                      case ensure_saved(#{server => M1}, DbName, Doc, Options) of
                          {'ok', _} -> 'true';
                          _ -> 'false'
                      end
              end, Others),
    'ok';
maybe_ensure_saved_others(_, _, _, _, _) -> 'ok'.


-spec del_doc(map(), kz_term:ne_binary(), kz_json:object() | kz_term:ne_binary(), kz_term:proplist()) ->
          data_return().
del_doc(Server, DbName, ?NE_BINARY=DocId, Options) ->
    case open_doc(Server, DbName, DocId, Options) of
        {'error', _}=Err -> Err;
        {'ok', JObj} -> del_doc(Server, DbName, JObj, Options)
    end;
del_doc(#{server := {_App, _Conn}}=Map, DbName, Doc, Options) ->
    DelDoc = prepare_doc_for_del(Map, DbName, Doc),
    {PreparedDoc, PublishDoc} = prepare_doc_for_save(DbName, DelDoc),
    try do_delete_doc(Map, DbName, PreparedDoc, Options) of
        {'ok', [JObj]} ->
            handle_del_doc_result(Map, DbName, PublishDoc, JObj, Options);
        {'ok', JObj} ->
            handle_del_doc_result(Map, DbName, PublishDoc, JObj, Options);
        Else -> Else
    catch
        Ex:Er ->
            lager:error("exception ~p: ~p", [Ex, Er]),
            'failed'
    end.

handle_del_doc_result(Map, DbName, PublishDoc, JObj, Options) ->
    kzs_publish:maybe_publish_doc(DbName, PublishDoc, JObj),
    maybe_spawn_secondary({DbName, remove_rev(JObj), Options}
                         ,'do_delete_doc'
                         ,maps:get('secondary', Map, [])
                         ),
    kzs_cache:flush_cache_doc(DbName, kz_doc:id(JObj)),
    {'ok', JObj}.

-spec do_delete_doc(map(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) ->
          data_return() | {'ok', kz_json:objects()}.
do_delete_doc(#{server := {App, Conn}}, DbName, Doc, Options) ->
    App:del_doc(Conn, DbName, Doc, Options).

-spec del_docs(map(), kz_term:ne_binary(), kz_json:objects() | kz_term:ne_binaries(), kz_term:proplist()) ->
          {'ok', kz_json:objects()} |
          data_error().
del_docs(Server, DbName, Docs, Options) ->
    delete_docs(Server, DbName, prepare_docs_for_deletion(Server, DbName, Docs), Options).

delete_docs(_Server, _DbName, [], _Options) -> {'ok', []};
delete_docs(#{server := {_App, _Conn}}=Map, DbName, DelDocs, Options) ->
    {PreparedDocs, PublishDocs} = lists:unzip([prepare_doc_for_save(DbName, D) || D <- DelDocs]),
    try do_delete_docs(Map, DbName, PreparedDocs, Options) of
        {'ok', JObjs}=Ok ->
            kzs_publish:maybe_publish_docs(DbName, PublishDocs, JObjs),
            maybe_spawn_secondary({DbName, remove_rev(JObjs), Options}
                                 ,'do_delete_docs'
                                 ,maps:get('secondary', Map, [])
                                 ),
            _ = [kzs_cache:flush_cache_doc(DbName, kz_doc:id(JObj)) || JObj <- JObjs],
            Ok;
        Else -> Else
    catch
        _Ex:Er -> {'error', {_Ex, Er}}
    end.

-spec do_delete_docs(map(), kz_term:ne_binary(), kz_json:objects(), kz_term:proplist()) ->
          {'ok', kz_json:objects()} |
          data_error().
do_delete_docs(#{server := {App, Conn}}, DbName, DelDocs, Options) ->
    App:del_docs(Conn, DbName, DelDocs, Options).

-spec prepare_docs_for_deletion(map(), kz_term:ne_binary(), [kz_json:object() | kz_term:ne_binary()]) ->
          kz_json:objects().
prepare_docs_for_deletion(Server, DbName, Docs) ->
    {NeedsRev, HasRev} = lists:partition(fun needs_rev/1, Docs),

    NeededRevDocs = [prepare_doc_for_del(Server, DbName, D) || D <- get_revisions(Server, DbName, NeedsRev)],
    HasRevDeletionDocs = [prepare_doc_for_del(Server, DbName, D) || D <- HasRev],

    HasRevDeletionDocs ++ NeededRevDocs.

get_revisions(Server, DbName, NeedsRev) ->
    IDs = lists:foldl(fun get_ids/2, [], NeedsRev),
    case kzs_view:all_docs(Server, DbName, [{'keys', IDs}]) of
        {'ok', Docs} ->
            lists:foldl(fun get_revision_from_all_docs_result/2, [], Docs);
        {'error', 'not_found'} -> [];
        {'error', _E} ->
            lager:debug("all_docs error: ~p", [_E]),
            []
    end.

get_revision_from_all_docs_result(Result, Acc) ->
    IsDeleted = kz_json:get_boolean_value([<<"value">>, <<"deleted">>], Result, 'false'),
    get_revision_from_all_docs_result(Result, Acc, kz_doc:id(Result), IsDeleted).

get_revision_from_all_docs_result(_Result, Acc, 'undefined', _IsDeleted) -> Acc;
get_revision_from_all_docs_result(_Result, Acc, _, 'true') ->
    %% Docs that are deleted, but still have tombstones, are treated like docs that have never been
    %% created and for which deletion is being attempted -> doc is ignored
    Acc;
get_revision_from_all_docs_result(Result, Acc, DocId, 'false') ->
    Doc = kz_doc:setters([{fun kz_doc:set_id/2, DocId}
                         ,{fun kz_doc:set_revision/2, kz_json:get_value([<<"value">>, <<"rev">>], Result)}
                         ]),
    [Doc | Acc].

get_ids(<<DocID/binary>>, Acc) -> [DocID | Acc];
get_ids(JObj, Acc) -> [kz_doc:id(JObj) | Acc].

-spec needs_rev(kz_term:ne_binary() | kz_json:object()) -> boolean().
needs_rev(<<_DocId/binary>>) -> 'true';
needs_rev(Doc) -> kz_doc:revision(Doc) =:= 'undefined'.

-spec prepare_doc_for_del(map(), kz_term:ne_binary(), kz_json:object() | kz_term:ne_binary()) ->
          kz_json:object().
prepare_doc_for_del(Server, Db, ?NE_BINARY=DocId) ->
    prepare_doc_for_del(Server, Db, kz_json:from_list([{<<"_id">>, DocId}]));
prepare_doc_for_del(Server, DbName, Doc) ->
    Id = kz_doc:id(Doc),
    Rev0 = kz_doc:revision(Doc),
    DocRev = case Rev0 =:= 'undefined'
                 andalso lookup_doc_rev(Server, DbName, Id)
             of
                 'false' -> Rev0;
                 {'ok', Rev} -> Rev;
                 {'error', 'not_found'} -> 'undefined'
             end,
    kz_json:from_list(
      [{<<"_id">>, Id}
      ,{<<"_rev">>, DocRev}
      ,{<<"_deleted">>, 'true'}
      | kzs_publish:publish_fields(Doc)
      ]).

%%------------------------------------------------------------------------------
%% @doc Prepare / convert a doc for save or delete.
%% If the doc has the key `id' set,it will be deleted and a new `id' will be
%% generated.
%% @returns {PreparedDoc, PublishDoc} where:
%% PreparedDoc is a JObj containing all the necessary key values and in the
%% correct format for the save or delete operation.
%% PublishDoc is a JObj containing a defined set of key value pairs (?PUBLISH_FIELDS + doc rev).
%% @end
%%------------------------------------------------------------------------------
-spec prepare_doc_for_save(kz_term:ne_binary(), kz_json:object()) ->
          {kz_json:object(), kz_json:object()}.
prepare_doc_for_save(Db, JObj) ->
    Doc = kz_json:delete_key(<<"id">>, JObj),
    prepare_doc_for_save(Db, Doc, kz_term:is_empty(kz_doc:id(Doc))).

-spec prepare_doc_for_save(kz_term:ne_binary(), kz_json:object(), boolean()) ->
          {kz_json:object(), kz_json:object()}.
prepare_doc_for_save(_Db, JObj, 'true') ->
    prepare_publish(maybe_set_docid(JObj));
prepare_doc_for_save(Db, JObj, 'false') ->
    kzs_cache:flush_cache_doc(Db, JObj),
    prepare_publish(JObj).

-spec prepare_publish(kz_json:object()) -> {kz_json:object(), kz_json:object()}.
prepare_publish(JObj) ->
    PublishDoc = kz_json:from_list(
                   [{<<"_rev">>, kz_doc:revision(JObj)}
                   | kzs_publish:publish_fields(JObj)
                   ]),
    {maybe_tombstone(JObj), PublishDoc}.

-spec maybe_tombstone(kz_json:object()) -> kz_json:object().
maybe_tombstone(JObj) ->
    maybe_tombstone(JObj, kz_doc:is_deleted(JObj)).

-spec maybe_tombstone(kz_json:object(), boolean()) -> kz_json:object().
maybe_tombstone(JObj, 'true') ->
    kz_json:from_list(
      [{<<"_id">>, kz_doc:id(JObj)}
      ,{<<"_rev">>, kz_doc:revision(JObj)}
      ,{<<"_deleted">>, 'true'}
      ]);
maybe_tombstone(JObj, 'false') -> JObj.

-spec maybe_set_docid(kz_json:object()) -> kz_json:object().
maybe_set_docid(Doc) ->
    case kz_doc:id(Doc) of
        'undefined' -> kz_doc:set_id(Doc, kz_datamgr:get_uuid());
        _ -> Doc
    end.

-spec default_copy_function(boolean()) -> copy_function().
default_copy_function('true') -> fun ensure_saved/4;
default_copy_function('false') -> fun save_doc/4.

-spec copy_doc(map(), map(), copy_doc(), kz_term:proplist()) ->
          data_return().
copy_doc(Src, Dst, CopySpec, Options) ->
    SaveFun = default_copy_function(props:is_defined(?COPY_DOC_OVERRIDE_PROPERTY, Options)),
    copy_doc(Src, Dst, CopySpec, SaveFun, props:delete(?COPY_DOC_OVERRIDE_PROPERTY, Options)).

-spec copy_doc(map(), map(), copy_doc(), copy_function(), kz_term:proplist()) ->
          data_return().
copy_doc(Src, Dst, CopySpec, CopyFun, Opts) ->
    #copy_doc{source_dbname = SourceDbName
             ,source_doc_id = SourceDocId
             ,dest_dbname = DestDbName
             ,dest_doc_id = DestDocId
             } = CopySpec,
    Transform = props:get_value(?COPY_TRANSFORM, Opts),
    Options = props:delete(?COPY_TRANSFORM, Opts),
    case open_doc(Src, SourceDbName, SourceDocId, Options) of
        {'ok', SourceDoc} ->
            Props = [{<<"_id">>, DestDocId}
                    ,{<<"pvt_account_db">>, DestDbName}
                    | [{Key, 'null'} || Key <- ?DELETE_KEYS]
                    ],
            DestinationDoc = kz_json:set_values(Props, SourceDoc),
            Doc = kz_json:delete_key(<<"_attachments">>, copy_transform(Transform, SourceDoc, DestinationDoc)),
            case CopyFun(Dst, DestDbName, Doc, Options) of
                {'ok', JObj} ->
                    Attachments = kz_doc:attachments(SourceDoc, kz_json:new()),
                    copy_attachments(Src, Dst, CopySpec, kz_json:get_values(Attachments), kz_doc:revision(JObj));
                Error -> Error
            end;
        Error -> Error
    end.

-spec copy_transform('undefined' | transform_fun(), kz_json:object(), kz_json:object()) -> kz_json:object().
copy_transform('undefined', _SourceDoc, DestinationDoc) ->
    DestinationDoc;
copy_transform(Fun, SourceDoc, DestinationDoc) ->
    Fun(SourceDoc, DestinationDoc).

-spec copy_attachments(map(), map(), copy_doc(), {kz_json:json_terms(), kz_json:path()}, kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
copy_attachments(_Src, Dst, CopySpec, {[], []}, _) ->
    #copy_doc{dest_dbname = DestDbName
             ,dest_doc_id = DestDocId
             } = CopySpec,
    open_doc(Dst, DestDbName, DestDocId, []);
copy_attachments(Src, Dst, CopySpec, {[JObj | JObjs], [Key | Keys]}, Rev) ->
    #copy_doc{source_dbname = SourceDbName
             ,source_doc_id = SourceDocId
             ,dest_dbname = DestDbName
             ,dest_doc_id = DestDocId
             } = CopySpec,
    case kzs_attachments:fetch_attachment(Src, SourceDbName, SourceDocId, Key) of
        {'ok', Contents} ->
            ContentType = kz_json:get_value([<<"content_type">>], JObj),
            Opts = [{'content_type', kz_term:to_list(ContentType)}
                   ,{'rev', Rev}
                   ],
            case kzs_attachments:put_attachment(Dst, DestDbName, DestDocId, Key, Contents, Opts) of
                {'ok', AttachmentDoc} ->
                    copy_attachments(Src, Dst, CopySpec, {JObjs, Keys}, kz_doc:revision(AttachmentDoc));
                {'ok', AttachmentDoc, _Headers} ->
                    copy_attachments(Src, Dst, CopySpec, {JObjs, Keys}, kz_doc:revision(AttachmentDoc));
                {'error', 'conflict'} ->
                    handle_copy_conflict(Src, Dst, CopySpec, Key, {JObjs, Keys});
                Error ->
                    Error
            end;
        Error -> Error
    end.

handle_copy_conflict(Src, Dst
                    ,#copy_doc{dest_dbname = DestDbName
                              ,dest_doc_id = DestDocId
                              }=CopySpec
                    ,Key
                    ,{JObjs, Keys}
                    ) ->
    case kzs_attachments:fetch_attachment(Dst, DestDbName, DestDocId, Key) of
        {'ok', _Contents} ->
            case kz_datamgr:lookup_doc_rev(DestDbName, DestDocId) of
                {'ok', NewRev} ->
                    copy_attachments(Src, Dst, CopySpec, {JObjs, Keys}, NewRev);
                _Else -> {'error', 'conflict'}
            end;
        _Else -> {'error', 'conflict'}
    end.

-spec move_doc(map(), map(), copy_doc(), kz_term:proplist()) -> data_return().
move_doc(Src, Dst, CopySpec, Options) ->
    #copy_doc{source_dbname = SourceDbName
             ,source_doc_id = SourceDocId
             } = CopySpec,
    case copy_doc(Src, Dst, CopySpec, Options) of
        {'ok', JObj} ->
            _ = del_doc(Src, SourceDbName, SourceDocId, []),
            {'ok', JObj};
        Error -> Error
    end.

maybe_spawn_secondary(_RestArgs, _Fun, []) -> 'ok';
maybe_spawn_secondary({DbName, Doc, Options}=Args, Fun, [{Tag, Conn} | Rest]) ->
    _Pid = kz_process:spawn(fun handle_remote/4
                           ,[self(), Tag, Fun, {Conn, DbName, Doc, Options}]
                           ),
    maybe_spawn_secondary(Args, Fun, Rest).

handle_remote(Parent
             ,RemoteTag
             ,Fun
             ,{Conn, DbName, Doc, Options}=Opts
             ) ->
    RemoteDoc = add_conn_rev(Conn, DbName, Doc), %
    lager:debug("applying fun ~s/4 for ~p to conn ~s", [Fun, Parent, RemoteTag]),
    case apply(?MODULE, Fun, [Conn, DbName, RemoteDoc, Options]) of
        {'error', E} ->
            lager:info("error ~p", [E]),
            handle_remote_error(RemoteTag, Fun, Opts, E);
        _OK -> 'ok'
    end.

%% if we're trying to save a doc and it fails with not_found, let's
%% try creating the db and saving again
handle_remote_error(RemoteTag, 'do_save_docs', {Conn, DbName, [_|_]=Docs, Options}, 'not_found') ->
    case kzs_db:db_create(Conn, DbName) of
        'false' ->
            lager:debug("failed to create db ~s on conn ~s for docs, adding to retries", [DbName, RemoteTag]),
            [add_to_secondary_retry(RemoteTag, 'do_save_doc', DbName, kz_doc:id(Doc)) || Doc <- Docs];
        'true' ->
            lager:debug("created db ~s on remote ~s, retrying do_save_docs", [DbName, RemoteTag]),
            apply(?MODULE, 'do_save_docs', [Conn, DbName, Docs, Options])
    end;
handle_remote_error(RemoteTag, 'do_save_doc', {Conn, DbName, Doc, Options}, 'not_found') ->
    case kzs_db:db_create(Conn, DbName) of
        'false' ->
            lager:debug("failed to create db ~s on conn ~s for doc, adding to retries", [DbName, RemoteTag]),
            add_to_secondary_retry(RemoteTag, 'do_save_doc', DbName, kz_doc:id(Doc));
        'true' ->
            lager:debug("created db ~s on remote ~s, retrying do_save_doc", [DbName, RemoteTag]),
            apply(?MODULE, 'do_save_doc', [Conn, DbName, Doc, Options])
    end;
%% if we tried to delete a doc and it failed with not_found, well, no
%% harm no foul, problem took care of itself
handle_remote_error(_RemoteTag, DeleteFun, {_Conn, _DbName, _Doc, _Options}, 'not_found')
  when DeleteFun =:= 'do_delete_doc'
       orelse DeleteFun =:= 'do_delete_docs'
       ->
    'ok';
%% otherwise, let's queue the operation up for a retry at some future time
handle_remote_error(RemoteTag, 'do_delete_docs', {_Conn, DbName, [_|_]=Docs, _Options}, _Error) ->
    lager:debug("error on conn ~s running fun do_delete_docs with ~s docs: ~p"
               ,[RemoteTag, DbName, _Error]
               ),
    [add_to_secondary_retry(RemoteTag, 'do_delete_doc', DbName, kz_doc:id(Doc)) || Doc <- Docs];
handle_remote_error(RemoteTag, 'do_delete_doc', {_Conn, DbName, Doc, _Options}, _Error) ->
    lager:debug("error on conn ~s running fun do_delete_doc with ~s / ~s: ~p"
               ,[RemoteTag, DbName, kz_doc:id(Doc), _Error]
               ),
    add_to_secondary_retry(RemoteTag, 'do_delete_doc', DbName, kz_doc:id(Doc));
handle_remote_error(RemoteTag, Fun, {_Conn, DbName, Doc, _Options}, _Error) ->
    lager:debug("error on conn ~s running fun ~s with ~s / ~s: ~p"
               ,[RemoteTag, Fun, DbName, kz_doc:id(Doc), _Error]
               ),
    add_to_secondary_retry(RemoteTag, Fun, DbName, kz_doc:id(Doc)).

%% if no ID was set (relying on Couch to set one), we can't retry it anyway
add_to_secondary_retry(_RemoteTag, _Fun, _DbName, 'undefined') -> 'ok';
add_to_secondary_retry(RemoteTag, Fun, DbName, DocId) ->
    kz_datamgr:save_doc(?KZ_STORAGE_RETRY
                       ,kz_doc:update_pvt_parameters(
                          kz_json:from_list([{<<"remote_tag">>, RemoteTag}
                                            ,{<<"fun">>, kz_term:to_binary(Fun)}
                                            ,{<<"db_name">>, DbName}
                                            ,{<<"doc_id">>, DocId}
                                            ])
                         ,?KZ_STORAGE_RETRY
                         ,[{'type', <<"storage_retry">>}]
                         )
                       ).

-spec add_conn_rev(map(), kz_term:ne_binary(), kz_json:object() | kz_json:objects()) ->
          kz_json:object() | kz_json:objects().
add_conn_rev(Conn, DbName, [_|_]=Docs) ->
    [add_conn_rev(Conn, DbName, Doc) || Doc <- Docs];
add_conn_rev(Conn, DbName, Doc) ->
    case lookup_doc_rev(Conn, DbName, kz_doc:id(Doc)) of
        {'ok', RemoteRev} ->
            lager:debug("adding remote rev ~s to ~s/~s", [RemoteRev, DbName, kz_doc:id(Doc)]),
            kz_doc:set_revision(Doc, RemoteRev);
        _Else -> Doc
    end.

remove_rev([_|_]=JObjs) ->
    [kz_doc:delete_revision(JObj) || JObj <- JObjs];
remove_rev(JObj) ->
    kz_doc:delete_revision(JObj).
