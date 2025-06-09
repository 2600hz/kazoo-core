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

-include("kz_replicator.hrl").

-export([create/0
        ,create/1
        ,create/2
        ,set/3
        ,add/2
        ,status/0
        ,status/1
        ,start/1
        ,stop/1
        ,update/1
        ,stop_all/0
        ,delete/1
        ,delete_all/0
        ]).

-spec create() -> 'ok'.
create() ->
    Id = kz_datamgr:get_uuid(),
    create(Id, Id).

-spec create(kz_term:ne_binary()) -> 'ok'.
create(Name) ->
    Id = kz_datamgr:get_uuid(),
    create(Id, Name).

-spec create(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
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
    {'ok', _} = kz_datamgr:save_doc(?KZ_REPLICATOR_DB, Doc),
    lager:info("created job ~s with name ~s",[Id, Name]).

-spec set(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
set(JobId, Key, Value) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, JobId) of
        {'ok', JObj} ->
            case kz_datamgr:save_doc(?KZ_REPLICATOR_DB, kz_json:set_value(Key, Value, JObj)) of
                {'ok', _} ->
                    lager:debug("saved ~s value ~s for job ~s",[Key, Value, JobId]);
                {'error', _} ->
                    lager:error("unable to save ~s value ~s for job ~s",[Key, Value, JobId])
            end;
        {'error', _} ->
            lager:debug("unable to update value check if job exists")
    end.

-spec add(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
add(JobId, AccountId) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, JobId) of
        {'ok', JObj} ->
            Accounts = lists:merge(kz_json:get_value(<<"accounts">>, JObj, []), [AccountId]),
            JObj1 = kz_json:set_value(<<"accounts">>, Accounts, JObj),
            case kz_datamgr:save_doc(?KZ_REPLICATOR_DB, JObj1) of
                {'ok', _} ->
                    lager:debug("saved ~s for job ~s",[AccountId, JobId]);
                {'error', _} ->
                    lager:debug("unable to save ~s for job ~s",[AccountId, JobId])
            end;
        {'error', _} ->
            lager:debug("unable to update value check if job exists")
    end.

-spec status() -> 'ok'.
status() ->
    print_status(get_all_docs()).

get_all_docs() ->
    {'ok', Docs} = kz_datamgr:all_docs(?KZ_REPLICATOR_DB, ['include_docs']),
    Docs.

print_status([]) -> 'ok';
print_status([Doc | Docs]) ->
    Id = kz_doc:id(Doc),
    JObj = kz_json:get_json_value(<<"doc">>, Doc),
    Name = kz_json:get_value(<<"name">>, JObj),
    Status = kz_json:get_value(<<"status">>, JObj),
    lager:debug("status of ~s(~s) is ~s", [Name, Id, Status]),
    print_status(Docs).

-spec status(kz_term:ne_binary()) -> 'ok'.
status(Id) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            lager:debug("status of ~s is ~s",[Id, kz_json:get_value(<<"status">>, JObj)]);
        {'error', _} ->
            lager:debug("unable to check status, check if job ~s exists",[Id])
    end.

-spec start(kz_term:ne_binary()) -> 'ok'.
start(Id) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            lager:debug("trying to start replication job ~s", [Id]),
            maybe_start(JObj);
        {'error', _} ->
            lager:debug("unable to start replication, check if job ~s exists",[Id])
    end.

maybe_start(JObj) ->
    case kz_json:get_atom_value(<<"status">>, JObj) of
        'replicating' ->
            lager:debug("already replicating not starting");
        'new' ->
            kz_replicator_util:start_job(JObj);
        'stopped' ->
            kz_replicator_util:start_job(JObj)
    end.

-spec stop(kz_term:ne_binary()) -> 'ok'.
stop(Id) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            maybe_stop(Id, JObj);
        {'error', _} ->
            lager:debug("unable to stop replication, check if job ~s exists",[Id])
    end.

maybe_stop(Id, JObj) ->
    case kz_json:get_atom_value(<<"status">>, JObj) of
        'replicating' ->
            lager:debug("stoping replication job ~s ", [Id]),
            kz_replicator_util:stop_replication(JObj);
        _ ->
            lager:debug("replication already stopped not stopping")
    end.

-spec update(kz_term:ne_binary()) -> 'ok'.
update(Id) ->
    stop(Id),
    start(Id).

-spec stop_all() -> 'ok'.
stop_all() ->
    lager:debug("stopping all jobs"),
    Docs = get_all_docs(),
    stop_all(Docs).

stop_all([]) -> 'ok';
stop_all([Doc|Docs]) ->
    Id = kz_doc:id(Doc),
    stop(Id),
    stop_all(Docs).

-spec delete(kz_term:ne_binary()) -> 'ok'.
delete(Id) ->
    stop(Id),
    {'ok', Doc} = kz_datamgr:open_doc(?KZ_REPLICATOR_DB, Id),
    _ = kz_datamgr:del_doc(?KZ_REPLICATOR_DB, Doc),
    lager:debug("deleting job ~s", [Id]).

-spec delete_all() -> 'ok'.
delete_all() ->
    Docs = get_all_docs(),
    delete_all(Docs),
    lager:debug("deleted all jobs").

delete_all([]) ->
    _ = kz_datamgr:db_delete(?KZ_REPLICATOR_DB),
    lager:debug("deleted replication db");
delete_all([Doc|Docs]) ->
    Id = kz_doc:id(Doc),
    delete(Id),
    delete_all(Docs).
