%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2018-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzdb_account).

-export([create/2
        ,delete/1, delete/2
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-export_type([delete_error/0
             ,delete_errors/0
             ]).

-define(ACCOUNTS_CONFIG_CAT, <<"crossbar.accounts">>).

-define(AGG_VIEW_NAME, <<"accounts/listing_by_name">>).

-type delete_error() :: {atom(), kz_term:ne_binary()}.
-type delete_errors() :: [delete_error()].

-spec delete(kz_term:api_ne_binary()) ->
          {'ok', kzd_accounts:doc() | 'undefined'} |
          kz_datamgr:data_error() |
          {'error', delete_errors()}.
delete(AccountId) ->
    delete(AccountId, maps:new()).

-spec delete(kz_term:api_ne_binary(), map()) ->
          {'ok', kzd_accounts:doc() | 'undefined'} |
          kz_datamgr:data_error() |
          {'error', delete_errors()}.
delete(undefined, _Options) -> {ok, undefined};
delete(AccountId, Options) ->
    case is_not_master_account(AccountId)
        andalso kzd_accounts:fetch(AccountId)
    of
        false ->
            lager:error("deleting master account is forbidden"),
            {'error', 'unauthorized'};
        {'error', _}=Error ->
            maybe_cleanup_accounts(AccountId, Error);
        {'ok', AccountJObj} ->
            lager:info("attempting to delete ~s(~s)", [AccountId, kz_doc:revision(AccountJObj)]),
            Context = delete_context(AccountId, AccountJObj, Options),
            delete_account(Context)
    end.

delete_context(AccountId, AccountJObj, Options) ->
    #{account_id => AccountId
     ,account => AccountJObj
     ,options => Options
     }.

is_not_master_account(AccountId) ->
    kapps_util:get_master_account_id() =/= AccountId.

maybe_cleanup_accounts(AccountId, Error) ->
    case kzd_accounts:fetch(AccountId, 'accounts') of
        {'ok', AccountJObj} ->
            case kz_doc:is_deleted(AccountJObj) of
                'true' -> {'ok', AccountJObj};
                'false' -> delete(AccountId, AccountJObj)
            end;
        {'error', _} -> Error
    end.

-spec delete_account(map()) -> {ok, kzd_accounts:doc()} | {error, delete_errors()}.
delete_account(Context) ->
    Routines = [{fun delete_remove_services/1, "remove account services"}
               ,{fun delete_free_numbers/1, "release account numbers"}
               ,{fun delete_remove_sip_aggregates/1, "delete sip aggregation"}
               ,{fun delete_aux_services/1, "delete auxiliary services"}
               ,{fun delete_account_dbs/1, "delete account related databases"}
               ,{fun delete_account_db/1, "delete account database"}
               ,{fun delete_from_accounts/1, "unregistering account"}
               ],
    case lists:foldl(fun delete_account_exec_routine/2, Context, Routines) of
        #{errors := Errors} -> {error, Errors};
        #{account := Account} ->   {ok, Account}
    end.

log_delete(#{options := #{progress_callback := CB}}, Msg) ->
    CB(Msg),
    lager:debug(Msg);
log_delete(_Context, Msg) ->
    lager:debug(Msg).

delete_account_exec_routine({Routine, Msg}, Context) ->
    try
        log_delete(Context, Msg),
        Routine(Context)
    catch
        _Class:_Exception:ST ->
            kz_log:log_stacktrace(ST),
            Context
    end.


-type delete_acc() :: map().

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec delete_remove_services(delete_acc()) -> delete_acc().
delete_remove_services(#{account_id := AccountId} = Context) ->
    try kz_services:delete(AccountId) of
        _S ->
            lager:info("deleted account's services"),
            Context
    catch
        _E:_R ->
            lager:error("failed to delete services: ~s: ~p", [_E, _R]),
            Error = {'services_error', <<"unable to cancel services">>},
            maps:put(errors, [Error | maps:get(errors, Context, [])], Context)
    end.

-spec delete_free_numbers(delete_acc()) -> delete_acc().
delete_free_numbers(#{account_id := AccountId} = Context) ->
    _Freed = knm_numbers:free(AccountId),
    Context.

-spec delete_remove_sip_aggregates(delete_acc()) -> delete_acc().
delete_remove_sip_aggregates(#{account_id := AccountId} = Context) ->
    ViewOptions = ['include_docs'
                  ,{'key', AccountId}
                  ],
    case kz_datamgr:get_results(?KZ_SIP_DB, <<"credentials/lookup_by_account">>, ViewOptions) of
        {'error', _R} ->
            lager:debug("unable to clean sip_auth: ~p", [_R]);
        {'ok', JObjs} ->
            Docs = [kz_json:get_json_value(<<"doc">>, JObj) || JObj <- JObjs],
            _ = kz_datamgr:del_docs(?KZ_SIP_DB, Docs),
            lager:debug("deleted ~p docs from ~s", [length(Docs), ?KZ_SIP_DB])
    end,
    Context.

delete_aux_services(#{} = Context) ->
    Context.

-spec delete_account_db(delete_acc()) -> delete_acc().
delete_account_db(#{account_id := AccountId} = Context) ->
    case kz_datamgr:db_delete(AccountId) of
        'true' ->
            lager:debug("deleted account ~s db", [AccountId]),
            Context;
        'false' ->
            lager:debug("failed to remove account ~s database", [AccountId]),
            Error = {'datastore_fault', <<"unable to remove account database">>},
            maps:put(errors, [Error | maps:get(errors, Context, [])], Context)
    end.

-spec delete_account_dbs(delete_acc()) -> delete_acc().
delete_account_dbs(#{account_id := AccountId} = Context) ->
    DBs = kapps_util:get_account_dbs(AccountId),
    _ = [kz_datamgr:db_delete(DB) || DB <- DBs],
    Context.

-spec delete_from_accounts(delete_acc()) -> delete_acc().
delete_from_accounts(#{retry := Retry} = Context) when Retry > 5 ->
    Context;
delete_from_accounts(#{account_id := AccountId} = Context) ->
    case kz_datamgr:open_doc(?KZ_ACCOUNTS_DB, AccountId) of
        {ok, _JObj} ->
            ensure_deleted_from_accounts(Context, kz_datamgr:del_doc(?KZ_ACCOUNTS_DB, AccountId));
        {'error', 'not_found'} ->
            lager:info("account ~s not found in 'accounts' db", [AccountId]),
            Context;
        {'error', _R} ->
            lager:info("failed to open ~s account doc from 'accounts' db: ~p", [AccountId, _R]),
            Error = {'datastore_fault', <<"unable to remove account definition">>},
            maps:put(errors, [Error | maps:get(errors, Context, [])], Context)
    end.

ensure_deleted_from_accounts(#{account_id := AccountId} = Context, {'ok', DeleteJObj}) ->
    case kz_json:get_ne_binary_value(<<"error">>, DeleteJObj) of
        undefined ->
            Context;
        Error ->
            Reason = kz_json:get_ne_binary_value(<<"reason">>, DeleteJObj),
            lager:error("error deleting ~s from 'accounts' db: ~s: ~s", [AccountId, Error, Reason]),
            delete_from_accounts(Context#{retry => maps:get(retry, Context, 0) + 1})
    end;
ensure_deleted_from_accounts(#{account_id := AccountId} = Context, Error) ->
    lager:error("unexpected error deleting ~s from 'accounts' db: ~p", [AccountId, Error]),
    delete_from_accounts(Context#{retry => maps:get(retry, Context, 0) + 1}).

-spec create(kz_term:ne_binary(), kz_json:object()) -> kzd_accounts:doc() | 'undefined'.
create(AccountId, ReqJObj) ->
    AccountDb = kzs_util:format_account_db(AccountId),
    case kzs_util:is_account_db(AccountDb)
        andalso kz_datamgr:db_create(AccountDb)
    of
        'false' ->
            lager:info("failed to create database: ~s", [AccountDb]),
            'undefined';
        'true' ->
            lager:info("created account database: ~s", [AccountDb]),

            Doc = lists:foldl(fun({F, V}, J) -> F(J, V) end
                             ,ReqJObj
                             ,[{fun kz_doc:set_id/2, AccountId}
                              ,{fun kz_doc:set_account_id/2, AccountId}
                              ,{fun kz_doc:update_pvt_parameters/2, AccountDb}
                              ,{fun kz_doc:set_type/2, kzd_accounts:type()}
                              ]
                             ),
            create(Doc)
    end.

-spec create(kz_json:object()) -> kzd_accounts:doc().
create(ReqJObj) ->
    lists:foldl(fun(F, Req) -> F(Req) end
               ,ReqJObj
               ,[fun create_account_definition/1
                ,fun load_initial_views/1
                ,fun create_account_mod/1
                ,fun reconcile/1
                ,fun create_first_transaction/1
                ,fun set_notification_preference/1
                ,fun add_apps_store_doc/1
                ]
               ).

-spec create_account_definition(kz_json:object()) -> kz_json:object().
create_account_definition(ReqJObj) ->
    JObj = maybe_set_trial_expires(ReqJObj),
    case kzd_accounts:save(JObj) of
        {'ok', AccountDef} -> AccountDef;
        {'error', _R} ->
            lager:info("unable to create account definition: ~p", [_R]),
            throw('datastore_fault')
    end.

-spec load_initial_views(kzd_accounts:doc()) -> kzd_accounts:doc().
load_initial_views(AccountDoc) ->
    _ = kz_datamgr:refresh_views(kz_doc:account_db(AccountDoc)),
    lager:info("loaded initial views"),
    AccountDoc.

-spec create_account_mod(kzd_accounts:doc()) -> kzd_accounts:doc().
create_account_mod(AccountDoc) ->
    Db = kzs_util:format_account_mod_id(kz_doc:account_id(AccountDoc)),
    case kazoo_modb:create(Db) of
        'true' ->
            lager:info("created this month's MODb for account"),
            AccountDoc;
        'false' ->
            lager:error("failed to create modb for account"),
            throw('datastore_fault')
    end.

-spec reconcile(kzd_accounts:doc()) -> kzd_accounts:doc().
reconcile(AccountDoc) ->
    _Services = kz_services:reconcile(kz_doc:account_db(AccountDoc)),
    lager:info("performed initial services reconcile"),
    AccountDoc.

-spec create_first_transaction(kzd_accounts:doc()) -> kzd_accounts:doc().
create_first_transaction(AccountDoc) ->
    {Year, Month, _} = erlang:date(),
    AccountId = kz_doc:account_id(AccountDoc),
    {'ok', _} = kz_currency:rollover(AccountId, Year, Month, 0),
    lager:info("created first transaction for account"),
    AccountDoc.

-spec set_notification_preference(kzd_accounts:doc()) -> kzd_accounts:doc().
set_notification_preference(AccountDoc) ->
    lager:info("set notification preference"),
    AccountId = kz_doc:account_id(AccountDoc),
    ResellerId = kz_services_reseller:find_id(AccountId),
    case kzd_accounts:fetch(ResellerId) of
        {'error', _E} ->
            lager:error("failed to open reseller '~s': ~p", [ResellerId, _E]),
            AccountDoc;
        {'ok', AccountJObj} ->
            case kzd_accounts:notification_preference(AccountJObj) of
                'undefined' ->
                    lager:info("notification preference not set on reseller '~s'", [ResellerId]),
                    AccountDoc;
                Preference ->
                    set_notification_preference(AccountDoc, Preference)
            end
    end.

-spec set_notification_preference(kzd_accounts:doc(), kz_term:ne_binary()) -> kzd_accounts:doc().
set_notification_preference(AccountDoc, Preference) ->
    AccountDefinition = kzd_accounts:set_notification_preference(AccountDoc, Preference),
    case kzd_accounts:save(AccountDefinition) of
        {'error', _R} ->
            lager:error("failed to update account definition: ~p", [_R]),
            AccountDoc;
        {'ok', UpdatedAccountDoc} ->
            lager:info("notification_preference set to '~s'", [Preference]),
            UpdatedAccountDoc
    end.

-spec maybe_set_trial_expires(kz_json:object()) -> kz_json:object().
maybe_set_trial_expires(JObj) ->
    case kzd_accounts:is_trial_account(JObj) of
        'false' -> JObj;
        'true' -> set_trial_expires(JObj)
    end.

-spec set_trial_expires(kz_json:object()) -> kz_json:object().
set_trial_expires(JObj) ->
    TrialTime = kapps_config:get_integer(?ACCOUNTS_CONFIG_CAT, <<"trial_time">>, ?SECONDS_IN_DAY * 14),
    Expires = kz_time:now_s() + TrialTime,
    kzd_accounts:set_trial_expiration(kzd_accounts:set_pvt_is_trial(JObj, 'true'), Expires).

-spec add_apps_store_doc(kzd_accounts:doc()) -> kzd_accounts:doc().
add_apps_store_doc(AccountJObj) ->
    AppsStoreDoc = kzd_apps_store:new(kz_doc:id(AccountJObj)),
    {'ok', _} = kz_datamgr:save_doc(kz_doc:account_db(AccountJObj), AppsStoreDoc),
    lager:info("created initial apps store doc"),
    AccountJObj.
