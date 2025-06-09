%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_replicator_maintenance).

-export([create/0, create/1, create/2
        ,set/3
        ,add/2
        ,status/0, status/1
        ,start/1
        ,stop/1
        ,restart/1
        ,stop_all/0
        ,delete/1
        ,delete_all/0
        ]).

-include("kazoo_replicator.hrl").

-elvis([{elvis_style, no_debug_call, disable}]).

-spec create() -> 'ok'.
create() ->
    handle_create_result(kz_replicator:create()).

-spec create(kz_term:ne_binary()) -> 'ok'.
create(Name) ->
    handle_create_result(kz_replicator:create(Name)).

-spec create(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
create(Id, Name) ->
    handle_create_result(kz_replicator:create(Id, Name)).

handle_create_result({'ok', Job}) ->
    io:format("created job ~s with name ~s~n"
             ,[kz_doc:id(Job), job_name(Job)]
             );
handle_create_result({'error', _E}) ->
    io:format("failed to create a new job: ~p~n", [_E]).

-spec set(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
set(JobId, Key, Value) ->
    case kz_replicator:set(JobId, Key, Value) of
        {'ok', _} ->
            io:format("saved ~s value ~s for job ~s~n", [Key, Value, JobId]);
        {'error', _E} ->
            io:format("failed to update job ~s: ~p~n", [JobId, _E]);
        {'job_error', _JE} ->
            io:format("failed to load job ~s: ~p~n", [JobId, _JE])
    end.

-spec add(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
add(JobId, AccountId) ->
    case replication:add(JobId, AccountId) of
        {'ok', _} ->
            io:format("saved ~s for job ~s~n", [AccountId, JobId]);
        {'error', _E} ->
            io:format("unable to save account ~s to job ~s: ~p~n", [AccountId, JobId, _E]);
        {'job_error', _JE} ->
            io:format("unable to open job ~s: ~p~n", [JobId, _JE])
    end.

-spec status() -> 'ok'.
status() ->
    {'ok', Docs} = kz_datamgr:all_docs(?KZ_REPLICATOR_DB, ['include_docs']),
    Rows = [[<<"Name">>, <<"ID">>, <<"Status">>] |
            [[job_name(JObj), kz_doc:id(JObj), job_status(JObj)]
             || Doc <- Docs,
                JObj <- [kz_json:get_json_value(<<"doc">>, Doc)]
            ]
           ],
    kz_log:print_table(Rows, #{header_divider => $=}).

-spec status(kz_term:ne_binary()) -> 'ok'.
status(Id) ->
    case kz_datamgr:open_cache_doc(?KZ_REPLICATOR_DB, Id) of
        {'ok', JObj} ->
            io:format("status of ~s is ~s\n",[Id, job_status(JObj)]);
        {'error', _} ->
            io:format("unable to check status, check if job ~s exists\n",[Id])
    end.

job_status(JObj) ->
    kz_json:get_ne_binary_value(<<"status">>, JObj).

job_name(JObj) ->
    kz_json:get_ne_binary_value(<<"name">>, JObj).

-spec start(kz_term:ne_binary()) -> 'ok'.
start(JobId) ->
    case kz_replicator:start(JobId) of
        {'ok', _} ->
            io:format("job ~s started~n", [JobId]);
        {'job_error', _JE} ->
            io:format("failed to start job ~s: ~p~n", [JobId, _JE]);
        {'error', 'already_started'} ->
            io:format("job ~s already started~n", [JobId]);
        {'error', _E} ->
            io:format("failed to start job ~s: ~p~n", [JobId, _E])
    end.

-spec stop(kz_term:ne_binary()) -> 'ok'.
stop(JobId) ->
    case kz_replicator:stop(JobId) of
        {'ok', _} ->
            io:format("job ~s stopped~n", [JobId]);
        {'job_error', JobId, _JE} ->
            io:format("failed to stop job ~s: ~p~n", [JobId, _JE]);
        {'error', JobId, 'already_stopped'} ->
            io:format("job ~s already stopped~n", [JobId]);
        {'error', JobId, _E} ->
            io:format("failed to start job ~s: ~p~n", [JobId, _E])
    end.

-spec restart(kz_term:ne_binary()) -> 'ok'.
restart(JobId) ->
    case kz_replicator:restart(JobId) of
        {'ok', _} ->
            io:format("job ~s restarted~n", [JobId]);
        {'job_error', _JE} ->
            io:format("failed to restart job ~s: ~p~n", [JobId, _JE]);
        {'error', _E} ->
            io:format("failed to restart job ~s: ~p~n", [JobId, _E])
    end.

-spec stop_all() -> 'ok'.
stop_all() ->
    Rows = [[<<"Job ID">>, <<"Error Reason">>]
           | [printable_stop_error(Result) || {_, _, _} = Result <- kz_replicator:stop_all()]
           ],
    kz_log:print_table(Rows, #{header_divider => $=}).

printable_stop_error({'error', JobId, E}) ->
    [JobId, io_lib:format("~p", [E])];
printable_stop_error({'job_error', JobId, E}) ->
    [JobId, io_lib:format("~p", [E])].

-spec delete(kz_term:ne_binary()) -> 'ok'.
delete(JobId) ->
    case kz_replicator:delete(JobId) of
        {'ok', _} -> io:format("job ~s stopped and deleted~n", [JobId]);
        {'error', JobId, _E} -> io:format("job ~s failed to be deleted: ~p", [JobId, _E])
    end.

-spec delete_all() -> 'ok'.
delete_all() ->
    Rows = [[<<"Job ID">>, <<"Error Reason">>]
           | [printable_stop_error(Result) || {_, _, _} = Result <- kz_replicator:stop_all()]
           ],
    kz_log:print_table(Rows, #{header_divider => $=}).
