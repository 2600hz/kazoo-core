%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023, 2600Hz
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_ui_apps_maintenance).

-export([init_apps/1, init_apps/2
        ,init_app/1, init_app/2
        ,refresh_apps/1, refresh_apps/2
        ,refresh_app/1, refresh_app/2
        ]).

-include("kz_documents.hrl").

-spec init_apps(file:filename_all()) -> 'ok'.
init_apps(AppsPath) ->
    init_apps(AppsPath, 'undefined').

-spec init_apps(file:filename_all(), kz_term:api_ne_binary()) -> 'ok'.
init_apps(AppsPath, ApiUrl) ->
    refresh_apps(AppsPath, ApiUrl).

-spec init_app(file:filename_all()) -> 'ok'.
init_app(AppPath) ->
    init_app(AppPath, 'undefined').

-spec init_app(file:filename_all(), kz_term:api_ne_binary()) -> 'ok'.
init_app(AppPath, ApiUrl) ->
    refresh_app(AppPath, ApiUrl).

-spec refresh_apps(file:filename_all()) -> 'ok'.
refresh_apps(AppsPath) ->
    refresh_apps(AppsPath, 'undefined').

-spec refresh_apps(file:filename_all(), kz_term:api_ne_binary()) -> 'ok'.
refresh_apps(AppsPath, ApiUrl) ->
    Apps = search_apps_folder(AppsPath),
    InitApp = fun(App) -> refresh_app(App, ApiUrl) end,
    lists:foreach(InitApp, Apps).

-spec refresh_app(file:filename_all()) -> 'ok'.
refresh_app(AppPath) ->
    refresh_app(AppPath, 'undefined').

-spec refresh_app(file:filename_all(), kz_term:api_ne_binary()) -> 'ok'.
refresh_app(AppPath, ApiUrl) ->
    ?SUP_LOG_INFO("trying to refresh app from ~ts~n", [AppPath]),
    maybe_update_from_path(AppPath, ApiUrl).

-spec search_apps_folder(file:filename_all()) -> [file:filename_all()].
search_apps_folder(AppsPath) ->
    AccFun =
        fun(AppJSONPath, Acc) ->
                try
                    ?SUP_LOG_DEBUG("find... ~ts", [AppJSONPath]),
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

-spec maybe_update_from_path(file:filename_all(), kz_term:api_ne_binary()) -> 'ok'.
maybe_update_from_path(AppPath, ApiUrl) ->
    try find_metadata(AppPath) of
        {'ok', MetaData} ->
            maybe_create_app(AppPath, maybe_set_api_url(ApiUrl, MetaData));
        {'invalid_data', _E} ->
            ?SUP_LOG_INFO("  failed to validate app data ~ts: ~p~n", [AppPath, _E])
    catch
        'error':{'badmatch', {'error', 'enoent'}} ->
            ?SUP_LOG_INFO("  failed to incorporate app because there was no app.json in ~ts~n"
                         ,[filename:join([AppPath, <<"metadata">>])]
                         );
        'error':_E ->
            ?SUP_LOG_INFO("  failed to find metadata in ~ts: ~p~n", [AppPath, _E])
    end.

-spec maybe_set_api_url(kz_term:api_ne_binary(), kz_json:object()) -> kz_json:object().
maybe_set_api_url('undefined', MetaData) ->
    kz_json:delete_key(<<"api_url">>, MetaData);
maybe_set_api_url(ApiUrl, MetaData) ->
    kz_json:set_value(<<"api_url">>, ApiUrl, MetaData).

-spec maybe_create_app(file:filename_all(), kz_json:object()) -> 'ok'.
maybe_create_app(AppPath, MetaData) ->
    maybe_create_app(AppPath, MetaData, kz_term:is_rfc4122_uuid(kz_doc:id(MetaData))).

-spec maybe_create_app(file:filename_all(), kz_json:object(), boolean()) -> 'ok'.
maybe_create_app(_AppPath, MetaData, 'false') ->
    ?SUP_LOG_ERROR(" required 'uuid' field is missing or not valid from app ~ts metadata, skipping the app~n"
                  ,[kzd_applications:name(MetaData)]
                  );
maybe_create_app(AppPath, MetaData, 'true') ->
    {'ok', MasterAccountDb} = kapps_util:get_master_account_db(),
    AppId = kz_doc:id(MetaData),
    AppName = kzd_applications:name(MetaData),
    case kz_datamgr:open_doc(MasterAccountDb, AppId) of
        {'ok', AppJObj} ->
            ?SUP_LOG_INFO(" application ~ts (~ts) already loaded in system~n", [AppId, AppName]),
            maybe_update_app(AppPath, MetaData, MasterAccountDb, AppJObj);
        {'error', 'not_found'} ->
            create_app(AppPath, MetaData, MasterAccountDb)
    end.

-spec create_app(file:filename_all(), kz_json:object(), kz_term:ne_binary()) -> 'ok'.
create_app(AppPath, MetaData, MasterAccountDb) ->
    case kz_datamgr:save_doc(MasterAccountDb, set_pvt_params(MetaData, MasterAccountDb)) of
        {'ok', AppJObj} ->
            AppId = kz_doc:id(AppJObj),
            ?SUP_LOG_INFO(" saved application ~ts as doc ~ts~n", [kzd_applications:name(AppJObj), AppId]),
            maybe_add_images(AppPath, AppId, MetaData, MasterAccountDb);
        {'error', E} ->
            ?SUP_LOG_INFO(" failed to save app ~ts to ~ts: ~p~n"
                         ,[kzd_applications:name(MetaData), MasterAccountDb, E]
                         )
    end.

-spec maybe_update_app(file:filename_all(), kz_json:object(), kz_term:ne_binary(), kz_json:object()) -> 'no_return'.
maybe_update_app(AppPath, MetaData, MasterAccountDb, ApplicationJObj) ->
    CurrentDocId = kz_doc:id(ApplicationJObj),
    case update_app_updates(MetaData, ApplicationJObj) of
        {'false', _} ->
            AppName = kzd_applications:name(ApplicationJObj),
            ?SUP_LOG_INFO(" no metadata changes for application ~ts (~ts) ~n", [CurrentDocId, AppName]);
        {'true', Merged} ->
            save_app_updates(MasterAccountDb, CurrentDocId, Merged)
    end,
    'ok' = delete_old_images(CurrentDocId, MetaData, MasterAccountDb),
    maybe_add_images(AppPath, CurrentDocId, MetaData, MasterAccountDb).

-spec save_app_updates(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> 'ok'.
save_app_updates(MasterAccountDb, CurrentDocId, AppJObj) ->
    case kz_datamgr:save_doc(MasterAccountDb, set_pvt_params(AppJObj, MasterAccountDb)) of
        {'ok', NewAppJObj} ->
            AppName = kzd_applications:name(NewAppJObj),
            ?SUP_LOG_INFO(" updated ~ts app ~ts metadata~n", [AppName, CurrentDocId]);
        {'error', Err} ->
            AppName = kzd_applications:name(AppJObj),
            ?SUP_LOG_INFO(" error updating app ~ts (~ts) metadata: ~p~n", [CurrentDocId, AppName, Err])
    end.

-spec update_app_updates(kz_json:object(), kz_json:object()) -> {boolean(), kz_json:object()}.
update_app_updates(MetaData, AppJObj) ->
    Merged = kz_json:merge(AppJObj, kz_doc:public_fields(MetaData, 'false')),
    MergedHash = kz_doc:calculate_document_hash(Merged),
    %% recalculate current app doc in case sysadmin edited the doc directly in db
    %% without updating document hash.
    case kz_doc:calculate_document_hash(AppJObj) of
        MergedHash ->
            {'false', Merged};
        _ ->
            {'true', Merged}
    end.

-spec delete_old_images(kz_term:ne_binary(), kz_json:object(), kz_term:ne_binary()) -> 'ok'.
delete_old_images(AppId, MetaData, MasterAccountDb) ->
    F = fun (X) -> safe_delete_image(MasterAccountDb, AppId, X) end,
    lists:foreach(F, [kzd_applications:icon(MetaData)]),
    lists:foreach(F, kzd_applications:screenshots(MetaData)).

-spec safe_delete_image(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_ne_binary()) -> 'ok'.
safe_delete_image(_AccountDb, _AppId, 'undefined') -> 'ok';
safe_delete_image(AccountDb, AppId, Image) ->
    case kz_datamgr:fetch_attachment(AccountDb, AppId, Image) of
        {'error', _} -> 'ok';
        {'ok', _} ->
            kz_datamgr:delete_attachment(AccountDb, AppId, Image)
    end.

-spec maybe_add_images(file:filename_all(), kz_term:ne_binary(), kz_json:object(), kz_term:ne_binary()) -> 'no_return'.
maybe_add_images(AppPath, ?NE_BINARY=AppId, MetaData, MasterAccountDb) ->
    Icon = kzd_applications:icon(MetaData),
    Screenshots = kzd_applications:screenshots(MetaData),
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
            ?SUP_LOG_INFO("  failed to find ~ts in ~st~n", [Type, AppId]);
        'error':_E ->
            ?SUP_LOG_INFO("  failed to load ~ts in ~ts: ~p~n", [Type, AppId, _E])
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
        {'ok', _} ->     ?SUP_LOG_INFO("   saved ~ts to ~ts~n", [ImageId, AppId]);
        {'error', _E} -> ?SUP_LOG_INFO("   failed to save ~ts to ~ts: ~p~n", [ImageId, AppId, _E])
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

    case kz_json_schema:validate(kzd_applications:schema(), kz_doc:public_fields(JSON, 'false')) of
        {'ok', ValidatedJObj} ->
            case kz_json:is_defined(<<"uuid">>, JSON) of
                'false' ->
                    {'ok', kz_doc:set_type(ValidatedJObj, kzd_applications:pvt_type())};
                'true' ->
                    Setters = [{fun kz_doc:set_type/2, kzd_applications:pvt_type()}
                              ,{fun kz_doc:set_id/2, kz_json:get_ne_binary_value(<<"uuid">>, JSON)}
                              ],
                    {'ok', kz_doc:setters(ValidatedJObj, Setters)}
            end;
        {'error', Errors} ->
            ?SUP_LOG_ERROR("validation error on ~ts~n", [AppFile]),
            ?SUP_LOG_ERROR("JSON: ~ts~n", [Bin]),
            {'invalid_data', [log_and_return_error(Error) || Error <- Errors]}
    end.

log_and_return_error({'data_invalid', _, Error, _, _}=_E) ->
    ?SUP_LOG_ERROR("  ~tp~n", [_E]),
    Error.

set_pvt_params(JObj, MasterAccountDb) ->
    Options = [{'type', kzd_applications:pvt_type()}
              ,{'account_id', kzs_util:format_account_id(MasterAccountDb)}
              ],
    kz_doc:update_pvt_parameters(JObj, MasterAccountDb, Options).
