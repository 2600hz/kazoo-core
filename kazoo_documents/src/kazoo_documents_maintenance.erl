%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2022, 2600Hz
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_documents_maintenance).

-export([init_apps/1, init_apps/2
        ,init_app/1, init_app/2, init_app/3
        ,refresh_apps/1, refresh_apps/2
        ,refresh_app/1, refresh_app/2
        ,rename_and_refresh_app/2, rename_and_refresh_app/3
        ,rename_app/4 %% Please read the note inside the function before using it.
        ,apps/0
        ,app/1
        ,set_app_field/3
        ,set_app_label/2
        ,set_app_description/2
        ,set_app_extended_description/2
        ,set_app_features/2
        ,set_app_icon/2
        ,set_app_screenshots/2

        ,fix_apps_store_SUPP_212/1, fix_apps_store_SUPP_212/2, fix_apps_store_SUPP_212/3
        ]).

-define(DEFAULT_REFRESH_APP_KEYS, [<<"name">>
                                  ,<<"i18n">>
                                  ,<<"tags">>
                                  ,<<"author">>
                                  ,<<"version">>
                                  ,<<"license">>
                                  ,<<"price">>
                                  ,<<"icon">>
                                  ,<<"screenshots">>
                                  ,<<"api_url">>
                                  ,<<"phase">>
                                  ,<<"source_url">>
                                  ]
       ).

-define(REFRESH_APP_KEYS
       ,kapps_config:get_ne_binaries(<<"crossbar">>, <<"refresh_app_keys">>, ?DEFAULT_REFRESH_APP_KEYS)
       ).

-define(CB_APPS_STORE_LIST, <<"apps_store/crossbar_listing">>).

-include("kz_documents.hrl").

-spec init_apps(file:name()) -> 'ok'.
init_apps(AppsPath) ->
    init_apps(AppsPath, 'undefined').

-spec init_apps(file:name(), kz_term:api_binary()) -> 'ok'.
init_apps(AppsPath, ApiUrl) ->
    Apps = find_apps(AppsPath),
    InitApp = fun(App) -> init_app(App, ApiUrl) end,
    lists:foreach(InitApp, Apps).

-spec init_app(file:filename_all()) -> 'ok'.
init_app(AppPath) ->
    init_app(AppPath, 'undefined').

-spec init_app(file:filename_all(), kz_term:api_binary()) -> 'ok'.
init_app(AppPath, ApiUrl) ->
    Keys = [<<"api_url">>],
    init_app(AppPath, ApiUrl, Keys).

-spec init_app(file:filename_all(), kz_term:api_binary(), kz_term:ne_binaries()) -> 'ok'.
init_app(AppPath, ApiUrl, Keys) ->
    ?SUP_LOG_INFO("trying to init app from ~s~n", [AppPath]),
    maybe_update_app(AppPath, ApiUrl, Keys).

-spec refresh_apps(file:name()) -> 'ok'.
refresh_apps(AppsPath) ->
    refresh_apps(AppsPath, 'undefined').

-spec refresh_apps(file:name(), kz_term:api_binary()) -> 'ok'.
refresh_apps(AppsPath, ApiUrl) ->
    Apps = find_apps(AppsPath),
    InitApp = fun(App) -> refresh_app(App, ApiUrl) end,
    lists:foreach(InitApp, Apps).

-spec refresh_app(file:filename_all()) -> 'ok'.
refresh_app(AppPath) ->
    refresh_app(AppPath, 'undefined').

-spec refresh_app(file:filename_all(), kz_term:api_binary()) -> 'ok'.
refresh_app(AppPath, ApiUrl) ->
    ?SUP_LOG_INFO("trying to refresh app from ~s~n", [AppPath]),
    maybe_update_app(AppPath, ApiUrl, ?REFRESH_APP_KEYS).

%%------------------------------------------------------------------------------
%% @doc Takes care of updating the given (`PrevName') application's metadata
%% after renaming its folder.
%%
%% NOTE: if the desire is just to change the application's label (name) that
%% appears on monster-ui, then modify the `i18n' field information within the
%% metadata.json file of the application and use `refresh_app/[1,2]' instead.
%% @end
%%------------------------------------------------------------------------------
-spec rename_and_refresh_app(file:filename_all(), kz_term:ne_binary()) -> 'ok'.
rename_and_refresh_app(AppPath, PrevName) ->
    rename_and_refresh_app(AppPath, PrevName, 'undefined').

-spec rename_and_refresh_app(file:filename_all(), kz_term:ne_binary(), kz_term:api_binary()) -> 'ok'.
rename_and_refresh_app(AppPath, PrevName, ApiUrl) ->
    ?SUP_LOG_INFO("renaming and refreshing ~s app from ~s~n", [PrevName, AppPath]),
    {'ok', MasterAccountDb} = kapps_util:get_master_account_db(),
    {'ok', MetaData} = find_metadata(AppPath),
    case kzd_app:find_by_name(MasterAccountDb, PrevName) of
        {'ok', AppDoc} ->
            maybe_update_app(AppPath
                            ,maybe_set_api_url(ApiUrl, MetaData)
                            ,?REFRESH_APP_KEYS
                            ,MasterAccountDb
                            ,AppDoc
                            ),
            rename_app(kz_doc:id(AppDoc), PrevName, kzd_app:name(MetaData));
        {'error', Error} ->
            ?SUP_LOG_INFO(" failed to find app ~s: ~p", [PrevName, Error])
    end.

-spec rename_app(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
rename_app(AppId, PrevName, NewName) ->
    {'ok', MA} = kapps_util:get_master_account_id(),
    Accounts = kapps_util:account_descendants(MA),
    case rename_app(AppId, PrevName, NewName, [MA | Accounts]) of
        [] ->
            ?SUP_LOG_DEBUG("~s -> ~s renamed successfully for all the accounts found"
                          ,[PrevName, NewName]
                          );
        Failed ->
            ?SUP_LOG_WARNING("failed to rename ~s for these accounts: ~s"
                            ,[PrevName, kz_binary:join(Failed, <<", ">>)]
                            )
    end.

-spec rename_app(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binaries()) -> kz_term:ne_binaries().
rename_app(AppId, PrevName, NewName, Accounts) ->
    %% NOTE: this function is intended for the particular case when
    %% somehow rename_app functionality fails to update a given
    %% account as part of the `rename_and_refresh_app' process. Or
    %% maybe an application was renamed a few days ago and for a given
    %% customer it has not been renamed yet.  First, make sure the
    %% application was already renamed on its own document
    %% (`kzd_app:find_by_name(MasterAccountDb, NewName)') and the
    %% master account DB apps_store document
    %% ({MASTER_ACCOUNT_DB/apps_store}).
    rename_app(AppId, PrevName, NewName, Accounts, []).

-spec rename_app(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binaries(), kz_term:ne_binaries()) -> kz_term:ne_binaries().
rename_app(_AppId, _PrevName, _NewName, [], Failed) ->
    Failed;
rename_app(AppId, PrevName, NewName, AccountId, Failed) when is_binary(AccountId) ->
    rename_app(AppId, PrevName, NewName, [AccountId], Failed);
rename_app(AppId, PrevName, NewName, [Account | Accounts], Failed) ->
    ?SUP_LOG_DEBUG("renaming application ~s (~s -> ~s) for account ~s. ~p accounts remaining"
                  ,[AppId, PrevName, NewName, Account, length(Accounts)]
                  ),
    NewFailed = rename_app_on_accountdb_apps_store_doc(AppId, PrevName, NewName, Account, Failed),
    %% This function may receive thousands of accounts, so give the DB some rest in between of accounts.
    maybe_sleep_between(200, length(Accounts) + 1, 10),
    rename_app(AppId, PrevName, NewName, Accounts, NewFailed).

%%------------------------------------------------------------------------------
%% @doc Document: {ACCOUNT_DB}/apps_store
%%      Keys to modify:
%%      - apps -> {APP_ID} -> name
%% @end
%%------------------------------------------------------------------------------
-spec rename_app_on_accountdb_apps_store_doc(kz_term:api_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binaries()) -> kz_term:ne_binaries().
rename_app_on_accountdb_apps_store_doc(AppId, PrevName, NewName, Account, Failed) ->
    MaybeAppDoc = kzd_apps_store:fetch(Account),
    rename_app_on_accountdb_apps_store_doc(AppId, PrevName, NewName, Account, MaybeAppDoc, Failed).

-spec rename_app_on_accountdb_apps_store_doc(kz_term:api_binary()
                                            ,kz_term:ne_binary()
                                            ,kz_term:ne_binary()
                                            ,kz_term:ne_binary()
                                            ,{'ok', kz_json:object()} | {'error', 'undefined'} | kz_datamgr:data_error()
                                            ,kz_term:ne_binaries()
                                            ) -> kz_term:ne_binaries().
rename_app_on_accountdb_apps_store_doc(AppId, _PrevName, NewName, Account, {'ok', AppsStoreDoc}, Failed) ->
    case kz_json:get_json_value([<<"apps">>, AppId], AppsStoreDoc) of
        'undefined' ->
            ?SUP_LOG_INFO("app ~s (~s) is not installed in account ~s, ignoring...", [NewName, _PrevName, Account]),
            Failed;
        _AppDoc ->
            Renamed = kz_json:set_value([<<"apps">>, AppId, <<"name">>], NewName, AppsStoreDoc),
            AccountDB = kzs_util:format_account_db(Account),
            case kz_datamgr:save_doc(AccountDB, Renamed) of
                {'ok', _JObj} ->
                    ?SUP_LOG_INFO("renamed ~s -> ~s on ~s/apps_store doc", [_PrevName, NewName, AccountDB]),
                    ?SUP_LOG_INFO("reconciling services for account ~s", [Account]),
                    %% takes care of updating/renaming application within services document for the account.
                    _ = kz_services:reconcile(Account),
                    Failed;
                {'error', _Error} ->
                    ?SUP_LOG_INFO("failed to rename ~s (~s) app on ~s/apps_store doc with error: ~p"
                                 ,[AppId, _PrevName, AccountDB, _Error]
                                 ),
                    [Account | Failed]
            end
    end;
rename_app_on_accountdb_apps_store_doc(_AppId, _PrevName, _NewName, Account, _Err, Failed) ->
    ?SUP_LOG_WARNING("failed to fetch apps_store document for account ~s, skipping. Error: ~p"
                    ,[Account, _Err]
                    ),
    [Account | Failed].

-spec find_apps(file:name()) -> [file:name()].
find_apps(AppsPath) ->
    AccFun =
        fun(AppJSONPath, Acc) ->
                try
                    ?SUP_LOG_DEBUG("find...~p", [AppJSONPath]),
                    App = AppJSONPath, %%filename:absname(AppJSONPath),
                    %% /.../App/metadata/app.json --> App
                    [filename:dirname(filename:dirname(App)) | Acc]
                catch
                    _Ex:_Er:_ST ->
                        kz_log:log_stacktrace(_ST),
                        Acc
                end
        end,
    filelib:fold_files(AppsPath, "app\\.json", 'true', AccFun, []).

-spec maybe_update_app(file:filename_all(), kz_term:api_binary(), kz_term:ne_binaries()) -> 'ok'.
maybe_update_app(AppPath, ApiUrl, Keys) ->
    try find_metadata(AppPath) of
        {'ok', MetaData} ->
            maybe_create_app(AppPath, maybe_set_api_url(ApiUrl, MetaData), Keys);
        {'invalid_data', _E} ->
            ?SUP_LOG_INFO("  failed to validate app data ~s: ~p~n", [AppPath, _E])
    catch
        'error':{'badmatch', {'error', 'enoent'}} ->
            ?SUP_LOG_INFO("  failed to incorporate app because there was no app.json in ~s~n"
                         ,[filename:join([AppPath, <<"metadata">>])]
                         );
        'error':_E ->
            ?SUP_LOG_INFO("  failed to find metadata in ~s: ~p~n", [AppPath, _E])
    end.

-spec maybe_set_api_url(kz_term:api_binary(), kz_json:object()) -> kz_json:object().
maybe_set_api_url('undefined', MetaData) ->
    kz_json:delete_key(<<"api_url">>, MetaData);
maybe_set_api_url(ApiUrl, MetaData) ->
    kz_json:set_value(<<"api_url">>, ApiUrl, MetaData).

-spec maybe_create_app(file:filename_all(), kz_json:object(), kz_term:ne_binaries()) -> 'ok'.
maybe_create_app(AppPath, MetaData, Keys) ->
    {'ok', MasterAccountDb} = kapps_util:get_master_account_db(),
    maybe_create_app(AppPath, MetaData, Keys, MasterAccountDb).

-spec maybe_create_app(file:filename_all(), kz_json:object(), kz_term:ne_binaries(), kz_term:ne_binary()) -> 'ok'.
maybe_create_app(AppPath, MetaData, Keys, MasterAccountDb) ->
    AppName = kzd_app:name(MetaData),
    case kzd_app:find_by_name(MasterAccountDb, AppName) of
        {'ok', AppJObj} ->
            ?SUP_LOG_INFO(" app ~s already loaded in system~n", [AppName]),
            maybe_update_app(AppPath, MetaData, Keys, MasterAccountDb, AppJObj);
        {'error', 'not_found'} -> create_app(AppPath, MetaData, MasterAccountDb);
        {'error', _E} -> ?SUP_LOG_INFO(" failed to find app ~s: ~p", [AppName, _E])
    end.

-spec create_app(file:filename_all(), kz_json:object(), kz_term:ne_binary()) -> 'ok'.
create_app(AppPath, MetaData, MasterAccountDb) ->
    case kzd_app:save(MasterAccountDb, MetaData) of
        {'ok', AppJObj} ->
            AppId = kz_doc:id(AppJObj),
            ?SUP_LOG_INFO(" saved app ~s as doc ~s~n", [kzd_app:name(AppJObj), AppId]),
            maybe_add_images(AppPath, AppId, MetaData, MasterAccountDb);
        {'error', _E} ->
            ?SUP_LOG_INFO(" failed to save app ~s to ~s: ~p~n"
                         ,[kzd_app:name(MetaData), MasterAccountDb, _E]
                         )
    end.

-spec maybe_update_app(file:filename_all(), kz_json:object(), kz_term:ne_binaries(), kz_term:ne_binary(), kz_json:object()) -> 'no_return'.
maybe_update_app(AppPath, MetaData, Keys, MasterAccountDb, AppJObj) ->
    CurrentDocId = kz_doc:id(AppJObj),
    case update_app_updates(Keys, MetaData, AppJObj) of
        [] -> ?SUP_LOG_INFO(" no metadata changes for app ~s~n", [CurrentDocId]);
        Updates -> save_app_updates(MasterAccountDb, CurrentDocId, AppJObj, Updates)
    end,
    'ok' = delete_old_images(CurrentDocId, MetaData, MasterAccountDb),
    maybe_add_images(AppPath, CurrentDocId, MetaData, MasterAccountDb).

-spec save_app_updates(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> 'ok'.
save_app_updates(MasterAccountDb, CurrentDocId, AppJObj, Updates) ->
    case kz_datamgr:save_doc(MasterAccountDb, kz_json:set_values(Updates, AppJObj)) of
        {'ok', NewAppJObj} ->
            AppName = kzd_app:name(NewAppJObj),
            ?SUP_LOG_INFO(" updated ~s app ~s metadata~n", [AppName, CurrentDocId]);
        {'error', Err} ->
            ?SUP_LOG_INFO(" error updating app ~s metadata: ~p~n", [CurrentDocId, Err])
    end.

-spec update_app_updates(kz_term:ne_binaries(), kz_json:object(), kz_json:object()) -> kz_term:proplist().
update_app_updates(Keys, MetaData, AppJObj) ->
    update_app_updates(Keys, MetaData, AppJObj, []).

-spec update_app_updates(kz_term:ne_binaries(), kz_json:object(), kz_json:object(), kz_term:proplist()) -> kz_term:proplist().
update_app_updates([], _, _, Props) -> Props;
update_app_updates([Key|Keys], MetaData, AppJObj, Props) ->
    CurrentValue = kz_json:get_ne_value(Key, AppJObj),
    NewValue = kz_json:get_ne_value(Key, MetaData),
    case update_app_values_differ(CurrentValue, NewValue) of
        'false' ->
            ?SUP_LOG_INFO(" not updating ~s, it is unchanged~n", [Key]),
            update_app_updates(Keys, MetaData, AppJObj, Props);
        'true' ->
            Updates = [{Key, NewValue} | Props],
            ?SUP_LOG_INFO(" preparing to update ~s~n", [Key]),
            update_app_updates(Keys, MetaData, AppJObj, Updates)
    end.

-spec update_app_values_differ(kz_json:json_term(), kz_json:json_term()) -> boolean().
update_app_values_differ(_, 'undefined') -> 'false';
update_app_values_differ('undefined', _) -> 'true';
update_app_values_differ(CurrentValue, NewValue) ->
    case kz_json:are_json_objects([CurrentValue, NewValue]) of
        'true' -> not kz_json:are_equal(CurrentValue, NewValue);
        'false' -> CurrentValue =/= NewValue
    end.

-spec delete_old_images(kz_term:ne_binary(), kz_json:object(), kz_term:ne_binary()) -> 'ok'.
delete_old_images(AppId, MetaData, MasterAccountDb) ->
    F = fun (X) -> safe_delete_image(MasterAccountDb, AppId, X) end,
    lists:foreach(F, [kzd_app:icon(MetaData)]),
    lists:foreach(F, kzd_app:screenshots(MetaData)).

-spec safe_delete_image(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_binary()) -> 'ok'.
safe_delete_image(_AccountDb, _AppId, 'undefined') -> 'ok';
safe_delete_image(AccountDb, AppId, Image) ->
    case kz_datamgr:fetch_attachment(AccountDb, AppId, Image) of
        {'error', _} -> 'ok';
        {'ok', _} ->
            kz_datamgr:delete_attachment(AccountDb, AppId, Image)
    end.

-spec maybe_add_images(file:filename_all(), kz_term:ne_binary(), kz_json:object(), kz_term:ne_binary()) -> 'no_return'.
maybe_add_images(AppPath, ?NE_BINARY=AppId, MetaData, MasterAccountDb) ->
    Icon = kzd_app:icon(MetaData),
    Screenshots = kzd_app:screenshots(MetaData),
    IconPath = {Icon, filename:join([AppPath, <<"metadata">>, <<"icon">>, Icon])},
    SShotPaths = [{SShot, filename:join([AppPath, <<"metadata">>, <<"screenshots">>, SShot])}
                  || SShot <- Screenshots
                 ],
    update_icon(AppId, MasterAccountDb, IconPath),
    update_screenshots(AppId, MasterAccountDb, SShotPaths).

update_icon(AppId, MA, IconPath) ->
    update_images(AppId, MA, [IconPath], <<"icon">>),
    'no_return'.

update_screenshots(AppId, MA, SShotPaths) ->
    update_images(AppId, MA, SShotPaths, <<"screenshots">>),
    'no_return'.

-type image_path() :: {file:filename_all(), file:filename_all()}.
-type image_paths() :: [image_path()].

-spec update_images(kz_term:ne_binary(), kz_term:ne_binary(), image_paths(), kz_term:ne_binary()) -> 'ok'.
update_images(AppId, MasterAccountDb, ImagePaths, Type) ->
    try read_images(ImagePaths) of
        {'ok', Images} -> add_images(AppId, MasterAccountDb, Images)
    catch
        'error':{'badmatch', {'error', 'enoent'}} ->
            ?SUP_LOG_INFO("  failed to find ~s in ~s~n", [Type, AppId]);
        'error':_E ->
            ?SUP_LOG_INFO("  failed to load ~s in ~s: ~p~n", [Type, AppId, _E])
    end.

-spec add_images(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
add_images(AppId, MasterAccountDb, Images) ->
    _ = [add_image(AppId, MasterAccountDb, ImageId, ImageData)
         || {ImageId, ImageData} <- Images
        ],
    'ok'.

-spec add_image(kz_term:ne_binary(), kz_term:ne_binary(), file:filename_all(), binary()) -> 'ok'.
add_image(AppId, MasterAccountDb, ImageId, ImageData) ->
    case kz_datamgr:put_attachment(MasterAccountDb, AppId, ImageId, ImageData) of
        {'ok', _} ->     ?SUP_LOG_INFO("   saved ~s to ~s~n", [ImageId, AppId]);
        {'error', _E} -> ?SUP_LOG_INFO("   failed to save ~s to ~s: ~p~n", [ImageId, AppId, _E])
    end.

-spec read_images(image_paths()) ->
          {'ok', [{file:filename_all(), binary()}]}.
read_images(Images) ->
    {'ok', [{Image, read_image(ImagePath)}
            || {Image, ImagePath} <- Images
           ]}.

-spec read_image(file:filename_all()) -> binary().
read_image(File) ->
    {'ok', ImageData} = file:read_file(File),
    ImageData.

-spec find_metadata(file:filename_all()) ->
          {'ok', kz_json:object()} |
          {'invalid_data', kz_term:proplist()}.
find_metadata(AppPath) ->
    AppFile = filename:join([AppPath, <<"metadata">>, <<"app.json">>]),
    {'ok', Bin} = file:read_file(AppFile),
    JSON = kz_json:decode(Bin),
    case kz_json_schema:validate(<<"app">>, kz_doc:public_fields(JSON)) of
        {'ok', _} -> {'ok', kzd_app:set_app_hash(JSON, kz_binary:rand_hex(16))};
        {'error', Errors} ->
            io:format("validation error on ~s~n", [AppFile]),
            io:format("JSON: ~s~n", [Bin]),
            {'invalid_data', [log_and_return_error(Error) || Error <- Errors]}
    end.

log_and_return_error({'data_invalid', _, Error, _, _}=_E) ->
    io:format("  ~p~n", [_E]),
    Error.

-spec apps() -> 'no_return'.
apps() ->
    {'ok', MA} = kapps_util:get_master_account_db(),
    case kz_datamgr:get_results(MA, ?CB_APPS_STORE_LIST) of
        {'error', _R} -> ?SUP_LOG_DEBUG("failed to read apps in ~s: ~p", [MA, _R]);
        {'ok', JObjs} -> lists:foreach(fun print_app/1, JObjs)
    end,
    'no_return'.

-spec app(kz_term:ne_binary()) -> 'no_return'.
app(AppNameOrId) ->
    {'ok', MA} = kapps_util:get_master_account_db(),
    case kzd_app:find_by_name(MA, AppNameOrId) of
        {'ok', AppJObj} -> print_app(AppJObj);
        {'error', _} ->
            case kz_datamgr:open_doc(MA, AppNameOrId) of
                {'ok', AppJObj} -> print_app(view_app(AppJObj));
                _ -> ?SUP_LOG_INFO("unknown app\n"), 'no_return'
            end
    end.

view_app(AppJObj) ->
    M = maps:with([<<"name">>, <<"id">>, <<"phase">>, <<"i18n">>
                  ,<<"tags">>, <<"api_url">>, <<"source_url">>, <<"published">>
                  ]
                 ,kz_json:to_map(AppJObj)
                 ),
    kz_json:from_list([{<<"key">>, kzd_app:name(AppJObj)}
                      ,{<<"value">>, kz_json:from_map(M)}
                      ]).

-spec print_app(kzd_app:doc()) -> 'no_return'.
print_app(AppJObj) ->
    ?SUP_LOG_INFO("App ~s\n", [kzd_app:name(AppJObj)]),
    _ = put('pp_lvl', 1),
    _ = print_kvs(kz_doc:public_fields(AppJObj)),
    ?SUP_LOG_INFO("\n"),
    'no_return'.

print_kvs(JObj) -> kz_json:foreach(fun print_k_v/1, JObj).

print_k_v({K, V}) ->
    Lvl = get('pp_lvl'),
    Indent = string:copies("  ", Lvl),
    case kz_json:is_json_object(V) of
        'false' -> ?SUP_LOG_INFO("~s~s: ~s\n", [Indent, K, kz_json:encode(V)]);
        'true' ->
            ?SUP_LOG_INFO("~s~s:\n", [Indent, K]),
            _ = put('pp_lvl', Lvl + 1),
            _ = print_kvs(V),
            _ = put('pp_lvl', Lvl)
    end.

update_app(AppId, Path, Value) ->
    case lists:last(Path) of
        <<"_id">> -> 'ok';
        <<"pvt_", _/binary>> -> 'ok';
        ?NE_BINARY ->
            {'ok', MA} = kapps_util:get_master_account_db(),
            Updates = [{Path, Value}],
            UpdateOptions = [{'update', Updates}],
            case kz_datamgr:update_doc(MA, AppId, UpdateOptions) of
                {'ok', _} -> app(AppId);
                {'error', _R} -> ?SUP_LOG_INFO("updating ~s failed: ~p\n", [AppId, _R])
            end
    end,
    'no_return'.

-spec set_app_field(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
set_app_field(AppId, Field, Value) ->
    update_app(AppId, [Field], Value).

-spec set_app_label(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
set_app_label(AppId, Value) ->
    update_app(AppId, [<<"i18n">>, <<"en-US">>, <<"label">>], Value).

-spec set_app_description(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
set_app_description(AppId, Value) ->
    update_app(AppId, [<<"i18n">>, <<"en-US">>, <<"description">>], Value).

-spec set_app_extended_description(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
set_app_extended_description(AppId, Value) ->
    update_app(AppId, [<<"i18n">>, <<"en-US">>, <<"extended_description">>], Value).

-spec set_app_features(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
set_app_features(AppId, Value) ->
    Values = [V || V <- binary:split(Value, <<$@>>, ['global']),
                   V =/= <<>>
             ],
    update_app(AppId, [<<"i18n">>, <<"en-US">>, <<"features">>], Values).

-spec set_app_icon(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
set_app_icon(AppId, PathToPNGIcon) ->
    {'ok', MA} = kapps_util:get_master_account_db(),
    ?SUP_LOG_INFO("Processing...\n"),
    Icon = {filename:basename(PathToPNGIcon), PathToPNGIcon},
    update_icon(AppId, MA, Icon).

-spec set_app_screenshots(kz_term:ne_binary(), kz_term:ne_binary()) -> 'no_return'.
set_app_screenshots(AppId, PathToScreenshotsFolder) ->
    {'ok', MA} = kapps_util:get_master_account_db(),
    ?SUP_LOG_INFO("processing...\n"),
    SShots = [{filename:basename(SShot), SShot}
              || SShot <- filelib:wildcard(kz_term:to_list(PathToScreenshotsFolder) ++ "/*.png")
             ],
    update_screenshots(AppId, MA, SShots).

-spec fix_apps_store_SUPP_212(kz_term:ne_binary() | kz_term:ne_binaries()) -> 'ok'.
fix_apps_store_SUPP_212(AppId) ->
    fix_apps_store_SUPP_212(AppId, 10).

-spec fix_apps_store_SUPP_212(kz_term:ne_binary() | kz_term:ne_binaries(), binary() | non_neg_integer()) -> 'ok'.
fix_apps_store_SUPP_212(AppId, SecondsToRelax) ->
    fix_apps_store_SUPP_212(AppId, SecondsToRelax, 200).

-spec fix_apps_store_SUPP_212(kz_term:ne_binary() | kz_term:ne_binaries(), binary() | non_neg_integer(), binary() | non_neg_integer()) -> 'ok'.
fix_apps_store_SUPP_212(<<AppId/binary>>, SecondsToRelax, WriteLoopLimit) ->
    fix_apps_store_SUPP_212([AppId], SecondsToRelax, WriteLoopLimit);
fix_apps_store_SUPP_212(AppIds, SecondsToRelax, WriteLoopLimit) when is_list(AppIds) ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),
    Accounts = kapps_util:account_descendants(MasterAccountId),

    Acc = #{processed_count => 1
           ,app_ids => AppIds
           ,relax_s => kz_term:to_integer(SecondsToRelax)
           ,loop_limit => kz_term:to_integer(WriteLoopLimit)
           ,total_accounts => length(Accounts)
           },
    io:format("~n"),
    Result = lists:foldl(fun fix_SUP_212_fold/2, Acc, [MasterAccountId | Accounts]),

    LogFile = <<"/tmp/fix_apps_store_SUPP_212_", (kz_binary:rand_hex(4))/binary, ".log">>,
    ?SUP_LOG_INFO("~n>> you can examine fix result at ~s", [LogFile]),
    file:write_file(LogFile, io_lib:format("~p~n", [Result])).

fix_SUP_212_fold(AccountId, #{processed_count := Count
                             ,loop_limit := Limit
                             ,relax_s := SleepSec
                             }=Acc) ->
    NewAcc = process_account_SUP_212(AccountId, Acc),
    maybe_sleep_between(Limit, Count + 1, SleepSec),
    NewAcc.

process_account_SUP_212(AccountId, #{processed_count := Count
                                    ,total_accounts := Total
                                    }=Acc) ->
    NewAcc0 = Acc#{processed_count => Count+1},
    ?SUP_LOG_INFO(":: (~p/~p) processing account ~s apps_store doc", [Count, Total, AccountId]),
    try maybe_apps_store_SUP_212(AccountId, NewAcc0)
    catch
        _E:_T:_ST ->
            ?SUP_LOG_INFO("        crashed during fixing apps_store, moving on...: ~p:~p", [_E, _T]),
            kz_log:log_stacktrace(_ST),
            kz_maps:put(['errors', AccountId], NewAcc0, io_lib:format("crashed during fixing apps_store: ~p:~p", [_E, _T]))
    end.

maybe_apps_store_SUP_212(AccountId, Acc) ->
    case kz_datamgr:open_doc(AccountId, <<"apps_store">>) of
        {'ok', AppsStoreDoc} ->
            maybe_fix_SUPP_212(AccountId, Acc, AppsStoreDoc);
        {'error', 'not_found'} ->
            ?SUP_LOG_INFO("        no apps_store for account, moving on..."),
            kz_maps:put(['no_problems', AccountId, <<"apps_store">>], Acc, "not_found");
        {'error', E} ->
            ?SUP_LOG_INFO("        failed to open apps_store doc:~n        ~p", [E]),
            kz_maps:put(['errors', AccountId], Acc, io_lib:format("failed to open apps_store doc ~p", [E]))
    end.

maybe_fix_SUPP_212(AccountId, #{app_ids := AppIds}=Acc, AppsStoreDoc) ->
    {_AccoutId, _AppsStoreDoc, NewAcc} = lists:foldl(fun maybe_fix_app_SUPP_212/2
                                                    ,{AccountId, AppsStoreDoc, Acc}
                                                    ,AppIds
                                                    ),
    case kz_maps:get(['to_delete', AccountId], NewAcc, 'undefined') of
        'undefined' ->
            ?SUP_LOG_INFO("        apps_store is correct"),
            NewAcc;
        ToDelete ->
            ToDeleteIds = maps:keys(ToDelete),
            NewAppsStoreJObj = kz_json:delete_keys([[<<"apps">>, AppId] || AppId <- ToDeleteIds], AppsStoreDoc),
            case kz_datamgr:save_doc(AccountId, NewAppsStoreJObj) of
                {ok, _Saved} ->
                    ?SUP_LOG_INFO("        removed wrongfully installed apps"),
                    kz_maps:put(['fixed', AccountId], NewAcc, ToDelete);
                {error, E} ->
                    ?SUP_LOG_INFO("        failed to write and fix apps_store:~n        ~p", [E]),
                    kz_maps:put(['errors', AccountId], NewAcc, kz_binary:format("failed to save and fix apps_store ~p", [E]))
            end
    end.

maybe_fix_app_SUPP_212(AppId, {AccountId, AppsStoreDoc, Acc}) ->
    case {kz_json:is_defined([<<"apps">>, AppId], AppsStoreDoc)
         ,kz_json:get_ne_binary_value([<<"apps">>, AppId, <<"allowed_users">>], AppsStoreDoc)
         }
    of
        {'true', 'undefined'} ->
            ?SUP_LOG_INFO("        removing wrongfully installed app ~s", [AppId]),
            {AccountId
            ,AppsStoreDoc
            ,kz_maps:put(['to_delete', AccountId, AppId], Acc, kz_json:get_value([<<"apps">>, AppId], AppsStoreDoc))
            };
        {'true', _Allowed} ->
            ?SUP_LOG_INFO("        app ~p is correct", [AppId]),
            {AccountId
            ,AppsStoreDoc
            ,kz_maps:put(['no_problems', AccountId, AppId], Acc, "app object is correct")
            };
        {'false', _} ->
            ?SUP_LOG_INFO("        app ~s is not defined in apps_store doc, all good", [AppId]),
            {AccountId
            ,AppsStoreDoc
            ,kz_maps:put(['no_problems', AccountId, AppId], Acc, "app is not defined in apps_store")
            }
    end.

maybe_sleep_between(Limit, CurrentCount, SleepSec) ->
    case (CurrentCount + 1) rem Limit of
        0 ->
            io:format("~n==== sleeping for 5s to relax on CouchDB....~n"),
            _ = [begin
                     timer:sleep(1000),
                     io:format("...~b", [SleepCount]),
                     'ok'
                 end || SleepCount <- lists:seq(1, SleepSec)
                ],
            io:format("~n");
        _ ->
            'ok'
    end.
