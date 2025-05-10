%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% @author James Aimonetti
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_data_maintenance).

-export([flush/0]).
-export([flush_data_plans/0]).
-export([flush_docs/0
        ,flush_docs/1
        ,flush_docs/2
        ]).
-export([trace_module/1
        ,trace_function/1, trace_function/2
        ,trace_pid/1
        ,stop_trace/1
        ]).
-export([open_document/2, open_document/3
        ,open_document_cached/2, open_document_cached/3
        ]).

-export([load_doc_from_file/2]).

-export([cache_strategy/0, set_cache_strategy/1]).

-export([dataplan_reload/0, dataplan_reload/1]).

-export([move_recordings_to_external_storage/0
        ,move_recordings_to_external_storage/1
        ,move_recordings_to_external_storage/2
        ,move_recordings_to_external_storage/3
        ]).

-include("kz_data.hrl").

-elvis([{elvis_style, no_debug_call, disable}]).

-define(CB_LIST_BY_ATTACHMENT, <<"recordings/list_by_attachment">>).

-spec flush() -> 'ok'.
flush() ->
    _ = kz_datamgr:flush_cache_docs(),
    _ = dataplan_reload(),
    io:format("flushed all data manager caches~n").

-spec flush_data_plans() -> 'ok'.
flush_data_plans() ->
    dataplan_reload().

-spec flush_docs() -> 'ok'.
flush_docs() ->
    _ = kz_datamgr:flush_cache_docs(),
    io:format("flushed all cached docs~n").

-spec flush_docs(kz_term:ne_binary()) -> 'ok'.
flush_docs(Account) ->
    _ = kz_datamgr:flush_cache_docs(kzs_util:format_account_db(Account)),
    io:format("flushed all docs cached for account ~s~n", [Account]).

-spec flush_docs(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
flush_docs(Account, DocId) ->
    _ = kz_datamgr:flush_cache_doc(kzs_util:format_account_db(Account), DocId),
    io:format("flushed cached doc ~s for account ~s~n", [DocId, Account]).

-spec trace_module(kz_term:ne_binary()) -> 'ok'.
trace_module(Module) ->
    start_trace([{'module', kz_term:to_atom(Module)}]).

-spec trace_function(kz_term:ne_binary()) -> 'ok'.
trace_function(Function) ->
    start_trace([{'function', kz_term:to_atom(Function)}]).

-spec trace_function(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
trace_function(Module, Function) ->
    start_trace([{'module', kz_term:to_atom(Module)}
                ,{'function', kz_term:to_atom(Function)}
                ]).

-spec trace_pid(kz_term:ne_binary()) -> 'ok'.
trace_pid(Pid) ->
    start_trace([{'pid', kz_term:to_list(Pid)}]).

-spec start_trace(kz_data_tracing:filters()) -> 'ok'.
start_trace(Filters) ->
    {'ok', Ref} = kz_data_tracing:trace_file(Filters),
    io:format("trace started, stop with 'sup kazoo_data_maintenance stop_trace ~s'~n", [Ref]).

-spec stop_trace(kz_term:ne_binary()) -> 'ok'.
stop_trace(Ref) ->
    {'ok', Filename} = kz_data_tracing:stop_trace(Ref),
    io:format("trace stopped, see log at ~s~n", [Filename]).


-spec open_document(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
open_document(Db, Id) ->
    open_document(Db, Id, 'false').

-spec open_document(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary() | boolean()) -> 'no_return'.
open_document(Db, Id, PP) ->
    print(kz_datamgr:open_doc(Db, Id), kz_term:is_true(PP)).

-spec open_document_cached(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
open_document_cached(Db, Id) ->
    open_document_cached(Db, Id, 'false').

-spec open_document_cached(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary() | boolean()) -> 'no_return'.
open_document_cached(Db, Id, PP) ->
    print(kz_datamgr:open_cache_doc(Db, Id), kz_term:is_true(PP)).

print({'ok', JObj}, 'true') ->
    io:format("~s\n", [kz_json:encode(JObj, ['pretty'])]),
    'no_return';
print({'ok', JObj}, 'false') ->
    io:format("~s\n", [kz_json:encode(JObj)]),
    'no_return';
print({'error', R}, _PP) ->
    io:format("ERROR: ~p\n", [R]),
    'no_return'.

-spec load_doc_from_file(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          data_error().
load_doc_from_file(Db, _FilePath) when size(Db) == 0 ->
    {'error', 'invalid_db_name'};
load_doc_from_file(Db, FilePath) ->
    lager:debug("update db ~s from CouchDB file: ~s", [Db, FilePath]),
    try
        {'ok', Bin} = file:read_file(FilePath),
        JObj = kz_datamgr:maybe_adapt_multilines(kz_json:decode(Bin)),
        kz_datamgr:maybe_update_doc(Db, JObj)
    catch
        _Type:{'badmatch',{'error',Reason}} ->
            lager:debug("bad match: ~p", [Reason]),
            {'error', Reason};
        _Type:Reason ->
            lager:debug("exception: ~p", [Reason]),
            {'error', Reason}
    end.

-spec set_cache_strategy(kz_term:text()) -> 'ok'.
set_cache_strategy(?NE_BINARY = StrategyBin) ->
    set_cache_strategy(kz_term:to_atom(StrategyBin));
set_cache_strategy(Strategy) when is_atom(Strategy) ->
    application:set_env('kazoo_data', 'cache_strategy', Strategy),
    cache_strategy().

-spec cache_strategy() -> 'ok'.
cache_strategy() ->
    Strategy = kzs_cache:cache_strategy(),
    io:format("             strategy: ~s~n", [Strategy]),
    print_strategy_details(Strategy).

-define(STRATEGY_DETAILS(Mitigate, Async)
       ,io:format("  stampede mitigation: ~s~n          async store: ~s~n", [Mitigate, Async])
       ).

print_strategy_details('none') ->
    ?STRATEGY_DETAILS('false', 'false');
print_strategy_details('stampede') ->
    ?STRATEGY_DETAILS('true', 'false');
print_strategy_details('async') ->
    ?STRATEGY_DETAILS('false', 'true');
print_strategy_details('stampede_async') ->
    ?STRATEGY_DETAILS('true', 'true').

-spec dataplan_reload() -> 'ok'.
dataplan_reload() ->
    _ = kzs_plan:reload(),
    io:format("dataplans reloaded~n").

-spec dataplan_reload(kz_term:ne_binary()) -> 'ok'.
dataplan_reload(AccountId) ->
    _ = kzs_plan:reload(AccountId),
    io:format("dataplan for account ~s reloaded~n", [AccountId]).

%% @doc resaves attachments in MODBs for the given year, typically
%% moving them to external storage after a storage plan is in place.
-spec move_recordings_to_external_storage() -> 'ok' | data_error().
move_recordings_to_external_storage() ->
    {Year, _, _} = erlang:date(),
    move_recordings_to_external_storage(Year).

-spec move_recordings_to_external_storage(kz_time:year()) -> 'ok' | data_error().
move_recordings_to_external_storage(Year) ->
    case fetch_accounts() of
        {'error', _Reason} = E ->
            lager:debug("failed to query accounts listing: ~p", [_Reason]),
            E;
        {'ok', []} ->
            lager:debug("no accounts found"),
            {'error', 'no_accounts'};
        {'ok', AccountIds} ->
            _ = move_all_recordings(AccountIds, Year),
            lager:debug("finished moving all recordings to external storage")
    end.

fetch_accounts() ->
    kz_datamgr:get_result_ids(?KZ_ACCOUNTS_DB, <<"accounts/listing_by_id">>).

move_all_recordings(AccountIds, Year) ->
    [move_recordings_to_external_storage(AccountId, Year) || AccountId <- AccountIds].

-spec move_recordings_to_external_storage(kz_term:ne_binary(), kz_time:year()) -> 'ok'.
move_recordings_to_external_storage(AccountId, Year) ->
    _ = [move_recordings_to_external_storage(AccountId, Year, Month) || Month <- lists:seq(1, 12)],
    'ok'.

-spec move_recordings_to_external_storage(kz_term:ne_binary(), kz_time:year(), kz_time:month()) -> 'ok'.
move_recordings_to_external_storage(AccountId, Year, Month) ->
    MODB = kzs_util:format_account_mod_id(AccountId, Year, Month),
    case fetch_recordings(MODB) of
        {'ok', []} ->
            lager:debug("no call recording attachments found for ~s ~p-~p"
                       ,[AccountId, Year, Month]
                       );
        {'ok', JObjs} ->
            _ = [move_recording(MODB, JObj) || JObj <- JObjs],
            'ok';
        {'error', _Reason} ->
            lager:warning("failed to list call recording attachments for ~s ~p-~p: ~p"
                         ,[AccountId, Year, Month, _Reason]
                         )
    end.

fetch_recordings(MODB) ->
    kazoo_modb:get_results(MODB, ?CB_LIST_BY_ATTACHMENT, [{'result_key', <<"value">>}]).

move_recording(MODB, JObj) ->
    DocId = kz_doc:id(JObj),
    AName = kzd_call_recordings:name(JObj),
    case kz_datamgr:fetch_attachment(MODB, DocId, AName) of
        {'ok', Bin} ->
            store_attachment(MODB, DocId, AName, Bin, kzd_call_recordings:content_type(JObj));
        {'error', _Error} ->
            lager:warning("failed to fetch the recording attachment ~s from ~s. Reason: ~p"
                         ,[AName, MODB, _Error]
                         )
    end.

store_attachment(MODB, DocId, AName, Bin, ContentType) ->
    Options = [{'content_type', ContentType}],
    case kz_datamgr:put_attachment(MODB, DocId, AName, Bin, Options) of
        {'ok', _, _} ->
            verify_move(MODB, DocId, AName);
        {'ok', _} ->
            verify_move(MODB, DocId, AName);
        {'error', _Error} ->
            lager:warning("failed to re-save the recording attachment ~s to ~s. Reason: ~p"
                         ,[AName, MODB, _Error]
                         )
    end.

verify_move(MODB, DocId, AName) ->
    {'ok', Doc} = kz_datamgr:open_doc(MODB, DocId),
    case kz_doc:external_attachments(Doc) of
        'undefined' ->
            lager:warning("failed to move call recording ~s from ~s in MODB ~s to external storage"
                         ,[AName, DocId, MODB]
                         );
        _Handler ->
            finalize_move(MODB, DocId, AName, Doc)
    end.

finalize_move(MODB, DocId, AName, Doc) ->
    Options = [{'doc_type', kz_doc:type(Doc)}],
    Dataplan = kzs_plan:plan(MODB, props:set_value('rev', kz_doc:revision(Doc), Options)),
    {'ok', _} = kzs_attachments:delete_attachment(Dataplan, MODB, DocId, AName, Options),
    lager:debug("call recording ~s from ~s in MODB ~s has been successfully moved to external storage"
               ,[AName, DocId, MODB]
               ).
