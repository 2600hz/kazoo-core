%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(replicator).

-include("kazoo_replicator.hrl").

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
    io:format("created job ~s with name ~s\n",[Id, Name]).

-spec set(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
set(JobId, Key, Value) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, JobId) of
        {'ok', JObj} ->
            case kz_datamgr:save_doc(?KZ_REPLICATOR_DB, kz_json:set_value(Key, Value, JObj)) of
                {'ok', _} ->
                    io:format("saved ~s value ~s for job ~s\n",[Key, Value, JobId]);
                {'error', _} ->
                    io:format("unable to save ~s value ~s for job ~s\n",[Key, Value, JobId])
            end;
        {'error', _} ->
            io:format("unable to update value check if job exists\n")
    end.

-spec add(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
add(JobId, AccountId) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, JobId) of
        {'ok', JObj} ->
            Accounts = lists:merge(kz_json:get_value(<<"accounts">>, JObj, []), [AccountId]),
            JObj1 = kz_json:set_value(<<"accounts">>, Accounts, JObj),
            case kz_datamgr:save_doc(?KZ_REPLICATOR_DB, JObj1) of
                {'ok', _} ->
                    io:format("saved ~s for job ~s\n",[AccountId, JobId]);
                {'error', _} ->
                    io:format("unable to save ~s for job ~s\n",[AccountId, JobId])
            end;
        {'error', _} ->
            io:format("unable to update value check if job exists\n")
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
    JObj = kz_json:get_value(<<"doc">>, Doc),
    Name = kz_json:get_value(<<"name">>, JObj),
    Status = kz_json:get_value(<<"status">>, JObj),
    io:format("status of ~s(~s) is ~s\n", [Name, Id, Status]),
    print_status(Docs).

-spec status(kz_term:ne_binary()) -> 'ok'.
status(Id) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            io:format("status of ~s is ~s\n",[Id, kz_json:get_value(<<"status">>, JObj)]);
        {'error', _} ->
            io:format("unable to check status, check if job ~s exists\n",[Id])
    end.

-spec start(kz_term:ne_binary()) -> 'ok'.
start(Id) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            io:format("trying to start job ~s \n", [Id]),
            maybe_start(JObj);
        {'error', _} ->
            io:format("unable to start, check if job ~s exists\n",[Id])
    end.

maybe_start(JObj) ->
    case kz_json:get_atom_value(<<"status">>, JObj) of
        'replicating' ->
            io:format("already replicating not starting ...\n");
        'new' ->
            replicator_util:start_job(JObj);
        'stopped' ->
            replicator_util:start_job(JObj)
    end.

-spec stop(kz_term:ne_binary()) -> 'ok'.
stop(Id) ->
    case kz_datamgr:open_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            maybe_stop(Id, JObj);
        {'error', _} ->
            io:format("unable to stop, check if job ~s exists\n",[Id])
    end.

maybe_stop(Id, JObj) ->
    case kz_json:get_atom_value(<<"status">>, JObj) of
        'replicating' ->
            io:format("stoping job ~s \n", [Id]),
            replicator_util:stop_replication(JObj);
        _ ->
            io:format("already stopped not stopping ...\n")
    end.

-spec update(kz_term:ne_binary()) -> 'ok'.
update(Id) ->
    stop(Id),
    start(Id).

-spec stop_all() -> 'ok'.
stop_all() ->
    io:format("stopping all jobs"),
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
    io:format("deleting job ~s\n", [Id]).

-spec delete_all() -> 'ok'.
delete_all() ->
    Docs = get_all_docs(),
    delete_all(Docs),
    io:format("deleted all jobs\n").

delete_all([]) ->
    _ = kz_datamgr:db_delete(?KZ_REPLICATOR_DB),
    io:format("deleted replication db\n");
delete_all([Doc|Docs]) ->
    Id = kz_doc:id(Doc),
    delete(Id),
    delete_all(Docs).
