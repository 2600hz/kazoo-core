%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_replicator).

-export([add/2
        ,create/0, create/1, create/2
        ,delete/1
        ,delete_all/0
        ,restart/1
        ,set/3
        ,start/1
        ,stop/1
        ,stop_all/0
        ]).

-include("kz_replicator.hrl").

-type job_id() :: kz_term:ne_binary().
-type stop_result() :: {'ok', kz_json:object()} |
                       {'error', job_id(), any()} |
                       {'job_error', job_id(), any()}.

-spec create() ->
          {'ok', kz_json:object()} |
          {'error', any()}.
create() ->
    Id = kz_datamgr:get_uuid(),
    create(Id, Id).

-spec create(kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
create(Name) ->
    Id = kz_datamgr:get_uuid(),
    create(Id, Name).

-spec create(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
create(Id, Name) ->
    _ = kz_datamgr:db_create(?KZ_REPLICATOR_DB),
    timer:sleep(260),
    Doc = kz_json:set_values([{<<"_id">>, Id}
                             ,{<<"name">>, Name}
                             ,{<<"status">>, <<"new">>}
                             ,{<<"pvt_type">>, <<"replicator">>}
                             ]
                            ,kz_json:new()
                            ),
    kz_datamgr:save_doc(?KZ_REPLICATOR_DB, Doc).

-spec set(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()} |
          {'job_error', any()}.
set(JobId, Key, Value) ->
    case kz_datamgr:open_cache_doc(?KZ_REPLICATOR_DB, JobId) of
        {'ok', JObj} ->
            kz_datamgr:save_doc(?KZ_REPLICATOR_DB, kz_json:set_value(Key, Value, JObj));
        {'error', Error} ->
            {'job_error', Error}
    end.

-spec add(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()} |
          {'job_error', any()}.
add(JobId, AccountId) ->
    case kz_datamgr:open_cache_doc(?KZ_REPLICATOR_DB, JobId) of
        {'ok', JObj} ->
            Accounts = lists:merge(kz_json:get_value(<<"accounts">>, JObj, []), [AccountId]),
            JObj1 = kz_json:set_value(<<"accounts">>, Accounts, JObj),
            kz_datamgr:save_doc(?KZ_REPLICATOR_DB, JObj1);
        {'error', JobError} ->
            {'job_error', JobError}
    end.

-spec start(kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()} |
          {'job_error', any()}.
start(Id) ->
    case kz_datamgr:open_cache_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            maybe_start(JObj);
        {'error', E} ->
            {'job_error', E}
    end.

maybe_start(JObj) ->
    case kz_json:get_atom_value(<<"status">>, JObj) of
        'replicating' ->
            {'error', 'already_started'};
        'new' ->
            kz_replicator_util:start_job(JObj);
        'stopped' ->
            kz_replicator_util:start_job(JObj)
    end.

-spec stop(kz_term:ne_binary()) -> stop_result().
stop(Id) ->
    case kz_datamgr:open_cache_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            maybe_stop(Id, JObj);
        {'error', _JE} ->
            {'job_error', Id, _JE}
    end.

maybe_stop(Id, JObj) ->
    case kz_json:get_atom_value(<<"status">>, JObj) of
        'replicating' ->
            case kz_replicator_util:stop_replication(JObj) of
                {'ok', _}=OK -> OK;
                {'error', E} -> {'error', Id, E}
            end;
        _Status ->
            {'error', Id, 'already_stopped'}
    end.

-spec restart(kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'job_error', any()} |
          {'error', any()}.
restart(Id) ->
    _ = stop(Id),
    start(Id).

-spec stop_all() -> [stop_result()].
stop_all() ->
    [stop(kz_doc:id(Doc)) || Doc <- get_all_docs()].

-spec delete(kz_term:ne_binary()) ->
          stop_result().
delete(Id) ->
    case stop(Id) of
        {'ok', Stopped} ->
            kz_datamgr:del_doc(?KZ_REPLICATOR_DB, Stopped);
        Error -> Error
    end.

-spec delete_all() -> [stop_result()].
delete_all() ->
    [delete(kz_doc:id(Doc)) || Doc <- get_all_docs()].

get_all_docs() ->
    {'ok', Docs} = kz_datamgr:all_docs(?KZ_REPLICATOR_DB, ['include_docs']),
    Docs.
