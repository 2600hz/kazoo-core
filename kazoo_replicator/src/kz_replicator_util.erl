%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_replicator_util).

-include("kz_replicator.hrl").

-export([start_job/1
        ,stop_replication/1
        ]).

-spec get_all_dbs(kz_json:object()) -> kz_term:ne_binaries().
get_all_dbs(JObj) ->
    {Host, Opts} = get_from_opts(JObj),
    Url = kz_term:to_binary([Host, "/_all_dbs"]),
    {'ok', 200, _Headers, Body} = kz_http:get(Url, [], Opts),
    kz_json:decode(Body).

-spec process_dbs(kz_term:ne_binary(), kz_term:ne_binaries(), kz_term:proplist(), kz_json:object()) -> 'ok'.
process_dbs(_, [], _, _) -> 'ok';
process_dbs(Url, [Db|Dbs], Opts, JObj) ->
    _ = maybe_listed_db(Url, Db, Opts, JObj, should_process_accounts(JObj)),
    process_dbs(Url, Dbs, Opts, JObj).

maybe_listed_db(Url, Db, Opts, JObj, 'true') ->
    maybe_replicate_account(Url, Db, Opts, JObj, kzs_util:is_account_db(Db));
maybe_listed_db(Url, Db, Opts, JObj, 'false') ->
    case kzs_util:is_account_db(Db) of
        'true' ->
            Dbs = kz_json:get_value(<<"accounts">>, JObj),
            case is_listed_db(Db, Dbs) of
                'true' ->
                    maybe_replicate_account(Url, Db, Opts, JObj, 'true');
                'false' -> 'ok'
            end;
        'false' -> maybe_system_db(Url, Db, Opts, JObj, is_system_db(Db))
    end.

maybe_replicate_account(Url, Db, Opts, JObj, 'true') ->
    process_data(Url, kzs_util:format_account_db(Db), Opts, JObj);
maybe_replicate_account(Url, Db, Opts, JObj, 'false') ->
    maybe_system_db(Url, Db, Opts, JObj, is_system_db(Db)).

maybe_system_db(Url, Db, Opts, JObj, 'true') ->
    process_data(Url, Db, Opts, JObj);
maybe_system_db(_, _, _, _, _) -> 'ok'.

process_data(_, ?KZ_REPLICATOR_DB, _, _) -> 'ok';
process_data(_, <<?KZ_REPLICATOR_DB_MATCH, _/binary>>, _, _) -> 'ok';
process_data(Url, Db, Opts, JObj) ->
    lager:debug("replicating db ~s", [Db]),
    Doc = kz_json:from_list([{<<"_id">>, Db}
                            ,{<<"source">>, url_section(get_from_section(Db, JObj))}
                            ,{<<"target">>, url_section(get_to_section(Db, JObj))}
                            ,{<<"continuous">>, kz_json:get_boolean_value(<<"continuous">>, JObj, 'true')}
                            ,{<<"create_target">>, 'true'}
                            ]),
    save_doc(Url, Db, Opts, Doc).

save_doc(Url, Db, Opts, Doc) ->
    DocUrl = kz_term:to_binary([Url, <<"/">>, Db]),
    _ = kz_http:put(DocUrl, [], kz_json:encode(Doc), Opts).

get_from_section(Db, JObj) ->
    Host = kz_json:get_binary_value(<<"from_host">>, JObj),
    Username = kz_json:get_binary_value(<<"from_username">>, JObj),
    Password = kz_json:get_binary_value(<<"from_password">>, JObj),
    Port = kz_json:get_binary_value(<<"from_port">>, JObj, <<"5984">>),
    Url = kz_term:to_binary([<<"http://">>, Host, ":", Port, "/", Db]),
    {Url, Username, Password}.

get_to_section(Db, JObj) ->
    Host = kz_json:get_binary_value(<<"to_host">>, JObj),
    Username = kz_json:get_binary_value(<<"to_username">>, JObj),
    Password = kz_json:get_binary_value(<<"to_password">>, JObj),
    Port = kz_json:get_binary_value(<<"to_port">>, JObj, <<"5984">>),
    Url = kz_term:to_binary([<<"http://">>, Host, ":", Port, "/", Db]),
    {Url, Username, Password}.

url_section({Url, Username, Password}) ->
    Auth = kz_json:from_list([{<<"basic">>
                              ,kz_json:from_list([{<<"username">>, Username}
                                                 ,{<<"password">>, Password}
                                                 ])
                              }]),
    kz_json:from_list([{<<"url">>, Url}
                      ,{<<"auth">>, Auth}
                      ]).

-spec stop_replication(kz_json:object()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
stop_replication(JObj) ->
    Worker = kz_json:get_atom_value(<<"worker_node">>, JObj, 'to'),
    _ = stop_replication(JObj, Worker),
    change_status(JObj, <<"stopped">>).

stop_replication(JObj, 'to') ->
    {Host, Opts} = get_to_opts(JObj),
    stop_replication(Host, Opts, JObj);
stop_replication(JObj, _) ->
    {Host, Opts} = get_from_opts(JObj),
    stop_replication(Host, Opts, JObj).

stop_replication(Host, Opts, JObj) ->
    Id = kz_doc:id(JObj),
    Url = kz_term:to_binary([Host
                            ,?KZ_REPLICATOR_DB
                            ,<<"%2F">>
                            ,Id
                            ,"%2F_replicator"
                            ]),
    {'ok', _, _, _} = kz_http:delete(Url, [], [], Opts).

-spec start_job(kz_json:object()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
start_job(JObj) ->
    {Url, Opts} = create_replication_db(JObj),
    Dbs = get_all_dbs(JObj),
    process_dbs(Url, Dbs, Opts, JObj),
    change_status(JObj, <<"replicating">>).

change_status(JObj, Status) ->
    Doc = kz_json:set_value(<<"status">>, Status, JObj),
    kz_datamgr:save_doc(?KZ_REPLICATOR_DB, Doc).

-spec create_replication_db(kz_json:object()) ->
          {kz_http:url(), kz_term:proplist()}.
create_replication_db(JObj) ->
    Worker = kz_json:get_atom_value(<<"worker_node">>, JObj, 'to'),
    create_replication_db(JObj, Worker).

create_replication_db(JObj, 'to') ->
    {Host, Opts} = get_to_opts(JObj),
    create_replication_db(Host, Opts, JObj);
create_replication_db(JObj, _) ->
    {Host, Opts} = get_from_opts(JObj),
    create_replication_db(Host, Opts, JObj).

create_replication_db(Host, Opts, JObj) ->
    Id = kz_doc:id(JObj),
    Url = kz_term:to_binary([Host, ?KZ_REPLICATOR_DB, <<"%2F">>, Id, <<"%2F_replicator">>]),
    {'ok', 201, _, _} = kz_http:put(Url, [], [], Opts),
    {Url, Opts}.

-spec get_from_opts(kz_json:object()) -> {kz_http:url(), kz_term:proplist()}.
get_from_opts(JObj) ->
    Host = kz_json:get_binary_value(<<"from_host">>, JObj),
    Port = kz_json:get_binary_value(<<"from_port">>, JObj, <<"5984">>),
    Username = kz_json:get_binary_value(<<"from_username">>, JObj),
    Password = kz_json:get_binary_value(<<"from_password">>, JObj),
    Options = [{'basic_auth', {Username, Password}}],
    Url = kz_term:to_binary([<<"http://">>, Host, <<":">>, Port, "/"]),
    {Url, Options}.

-spec get_to_opts(kz_json:object()) -> {kz_http:url(), kz_term:proplist()}.
get_to_opts(JObj) ->
    Host = kz_json:get_binary_value(<<"to_host">>, JObj),
    Port = kz_json:get_binary_value(<<"to_port">>, JObj, <<"5984">>),
    Username = kz_json:get_binary_value(<<"to_username">>, JObj),
    Password = kz_json:get_binary_value(<<"to_password">>, JObj),
    Options = [{'basic_auth', {Username, Password}}],
    Url = kz_term:to_binary([<<"http://">>, Host, <<":">>, Port, "/"]),
    {Url, Options}.

-spec is_system_db(kz_term:ne_binary()) -> boolean().
is_system_db(Db) ->
    lists:member(Db, ?KZ_SYSTEM_DBS).

is_listed_db(Db, Dbs) ->
    lists:member(Db, Dbs).

should_process_accounts(JObj) ->
    case kz_json:get_value(<<"accounts">>, JObj) of
        'undefined' -> 'true';
        [] -> 'true';
        _ -> 'false'
    end.
