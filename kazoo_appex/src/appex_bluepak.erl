%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_bluepak).

-export([load_app/3
        ,base_path/0
        ]).

-record(load_app, {app_metadata :: kz_term:api_object()
                  ,app_name :: kz_term:api_ne_binary()
                  ,app_spec :: {'application', atom(), kz_term:proplist()} | 'undefined'
                  ,app_type :: app_type()
                  ,app :: atom()
                  ,app_vsn :: kz_term:api_ne_binary()
                  ,app_dir :: kz_term:api_ne_binary()
                  ,base_path :: kz_term:api_ne_binary()
                  ,writeable = [] :: [{file:filename_all(), binary()}] %% [{Filename, Contents}]
                  ,loaded_mods = [] :: [atom()]
                  ,app_beams = #{} :: #{File::file:filename_all() => binary()}
                  }).
-type load_app() :: #load_app{}.

-type loaded() :: #{app := atom()
                   ,app_name := kz_term:ne_binary()
                   ,app_spec := {'application', atom(), kz_term:proplist()}
                   ,app_type := app_type()
                   ,app_vsn := kz_term:ne_binary()
                   }.
-type load_ret() :: {'ok', load_app()} | {'error', any()}.
-type load_resp() :: {'ok', loaded()} | {'error', any()}.
-export_type([loaded/0
             ,load_resp/0
             ]).

-spec load_app(App::atom(), Archive::binary(), ContentType::string() | 'undefined') -> load_resp().
load_app(App, Archive, ContentType) ->
    case app_type(ContentType) of
        'unknown' ->
            lager:error("content-type not supported: ~s", [ContentType]),
            {'error', 'bad_archive'};
        AppType ->
            case extract_files(App, AppType, extract(Archive)) of
                {'ok', #load_app{app_spec={'application', App, _}}=LoadApp} ->
                    prior_cleanup(App),
                    load_app(LoadApp);
                {'ok', #load_app{app_spec={'application', OtherApp, _}}} ->
                    lager:error("invalid app, expected ~s got ~s", [App, OtherApp]),
                    {'error', 'bad_app'};
                {'error', _Reason} ->
                    {'error', 'bad_archive'}
            end
    end.

-spec base_path() -> kz_term:ne_binary().
base_path() ->
    kz_term:to_binary(code:lib_dir()).

-type app_type() :: 'kazoo' | 'monster' | 'commland' | 'unknown'.
-spec app_type(string()) -> app_type().
app_type("application/vnd.bluepak+kazoo") -> 'kazoo';
app_type("application/vnd.bluepak+monster") -> 'monster';
app_type("application/vnd.bluepak+commland") -> 'commland';
app_type(_Other) -> 'unknown'.

-spec set_load_params(load_app()) -> {'ok', load_app()}.
set_load_params(#load_app{app_spec=_AppSpec
                         ,app_metadata=AppMeta
                         ,app=App
                         }=LoadApp) ->
    AppVsn = kz_json:get_ne_binary_value(<<"version">>, AppMeta, <<"0.1.0">>),
    AppName = kz_term:to_binary(App),

    NewLoad = LoadApp#load_app{app_vsn=AppVsn
                              ,app_dir=kz_term:to_binary([AppName, "-", AppVsn])
                              ,base_path=base_path()
                              },
    {'ok', NewLoad}.

-spec prior_cleanup(App::atom()) -> 'ok'.
prior_cleanup(App) ->
    AppDir = lists:concat([App, "-*"]),
    BasePath = code:lib_dir(),
    case filelib:wildcard(AppDir, BasePath) of
        [] -> 'ok';
        DirList ->
            _ = [prior_cleans_path(BasePath, Dir) || Dir <- DirList],
            'ok'
    end.

prior_cleans_path(BasePath, Dir) ->
    Path = kz_term:to_list(filename:join(BasePath, Dir)),
    lager:warning("cleaning old path ~s before fresh load", [Path]),
    _ = file:del_dir_r(Path),
    _ = code:set_path(lists:delete(Path, code:get_path())),
    _ = code:set_path(lists:delete(filename:join([Path, "ebin"]), code:get_path())),
    'ok'.

-spec load_app(load_app()) -> load_resp().
load_app(#load_app{app_spec=_AppSpec, app=App}=LoadApp) ->
    Funs = [fun write_files/1
           ,fun adjust_dot_app/1
           ,fun load_dot_app/1
           ,fun load_beams/1
           ,fun finish_loading_app/1
           ],
    try kz_either:pipe(set_load_params(LoadApp), Funs) of
        {'ok', #load_app{app_spec=NewAppSpec
                        ,app_name=AppName
                        ,app_type=AppType
                        ,app_vsn=AppVsn
                        }} ->
            {'ok', #{app => App
                    ,app_name => AppName
                    ,app_spec => NewAppSpec
                    ,app_type => AppType
                    ,app_vsn => AppVsn
                    }
            };
        {'error', _}=Error ->
            fail_cleanup(LoadApp),
            Error
    catch
        _Class:_Reason:_ST ->
            lager:debug("crashed to load app ~s: {~p, ~p}", [App, _Class, _Reason]),
            kz_log:log_stacktrace(_ST),
            fail_cleanup(LoadApp),
            {'error', 'failed'}
    end.

fail_cleanup(#load_app{app=App, base_path=BasePath, app_dir=AppDirBin}=LoadApp) ->
    _Unload = application:unload(App),
    AppDir = kz_term:to_list(filename:join([BasePath, AppDirBin])),
    Ebin = kz_term:to_list(ebin_path(LoadApp)),
    _ = file:del_dir_r(filename:dirname(Ebin)),
    _ = code:set_path(lists:delete(AppDir, code:get_path())),
    _ = code:set_path(lists:delete(Ebin, code:get_path())),
    'ok'.

-spec load_beams(load_app()) -> load_ret().
load_beams(#load_app{app_beams=AppBeams}=LoadApp) ->
    maps:fold(fun load_beams/3, {'ok', LoadApp}, AppBeams).

-spec load_beams(file:filename_all(), binary(), load_ret()) -> load_ret().
load_beams(_, _, {'error', _}=Error) ->
    Error;
load_beams(Filename, Bin, {'ok', #load_app{loaded_mods=Loaded}=LoadApp}) ->
    Ebin = ebin_path(LoadApp),
    Path = kz_term:to_list(filename:join([Ebin, filename:basename(Filename)])),
    Module = kz_term:to_atom(filename:basename(Filename, ".beam"), 'true'),
    case code:load_binary(Module, Path, Bin) of
        {'module', Module} ->
            {'ok', LoadApp#load_app{loaded_mods=[Module|Loaded]}};
        {'error', Reason} ->
            lager:error("failed to load module ~s: ~p", [Module, Reason]),
            {'error', {'load_module', {Module, Reason}}}
    end.

-spec adjust_dot_app(load_app()) -> {'ok', load_app()}.
adjust_dot_app(#load_app{app_spec={'application', App, AppConfig}}=LoadApp) ->
    {AppMod, StartArgs} = props:get_value('mod', AppConfig),
    AppEnv = props:get_value('env', AppConfig, []),
    NewEnv = props:set_values([{'kappex_app_mod', AppMod}
                              ,{'from_kappex', 'true'}
                              ]
                             ,AppEnv
                             ),
    %% tabulates tabulars
    AppDeps = props:get_value('applications', AppConfig, []),

    AppProps = [{'applications', lists:usort(AppDeps)}
               ,{'mod', {'appex_client_app_loader', {App, AppMod, StartArgs}}}
               ,{'env', NewEnv}
               ],
    NewConfig = props:set_values(AppProps, AppConfig),
    {'ok', LoadApp#load_app{app_spec={'application', App, NewConfig}}}.

-spec load_dot_app(load_app()) -> load_ret().
load_dot_app(#load_app{app_spec={'application', App, _}=AppSpec}=LoadApp) ->
    case application:load(AppSpec) of
        'ok' ->
            lager:debug("loaded app spec for ~s", [App]),
            {'ok', LoadApp};
        {'error', {'already_loaded', App}} ->
            'ok' = application:unload(App),
            load_dot_app(LoadApp);
        {'error', Reason}->
            lager:error("unable to load app ~s spec: ~p", [App, Reason]),
            {'error', {'load_app', {App, Reason}}}
    end.

-spec finish_loading_app(load_app()) -> load_ret().
finish_loading_app(#load_app{app=App}=LoadApp) ->
    lager:info("initialized ~s app", [App]),
    {'ok', LoadApp}.

-spec write_files(load_app()) -> load_ret().
write_files(LoadApp) ->
    Ebin = ebin_path(LoadApp),
    case loop_expected(
           [{fun create_ebin_dir/1, Ebin, 'ok'}
           ,{fun do_write_files/1, LoadApp, 'ok'}
           ,{fun add_code_path/1, Ebin, 'true'}
           ]
          )
    of
        'ok' ->
            {'ok', LoadApp};
        {'error', _Reason}=Error ->
            Error
    end.

-spec loop_expected([{function(), term(), term()}]) -> 'ok' | {'error', term()}.
loop_expected([]) ->
    'ok';
loop_expected([{Fun, Arg, Expected}|Routins]) ->
    case Fun(Arg) of
        Expected ->
            loop_expected(Routins);
        Other ->
            Other
    end.

-spec create_ebin_dir(file:name_all()) -> 'ok' | {'error', term()}.
create_ebin_dir(Ebin) ->
    filelib:ensure_dir(filename:join(Ebin, ".placeholder")).

-spec do_write_files(load_app()) -> 'ok' | {'error', term()}.
do_write_files(#load_app{writeable=Writeable}=LoadApp) ->
    lists:foldl(fun(File, 'ok') -> write_file(File, LoadApp);
                   (_, {'error', _}=Error) -> Error
                end
               ,'ok'
               ,Writeable
               ).

-spec add_code_path(file:name_all()) -> 'true' | {'error', term()}.
add_code_path(Ebin) ->
    case code:add_patha(kz_term:to_list(Ebin)) of
        'true' -> 'true';
        {'error', Reason} ->
            lager:debug("failed adding app to path: ~p", [Reason]),
            {'error', {'load_app', Reason}}
    end.

ebin_path(#load_app{base_path=BasePath, app_dir=AppDir}) ->
    filename:join([BasePath, AppDir, "ebin"]).

-spec write_file({file:filename_all(), binary()}, load_app()) -> 'ok' | {'error', term()}.
write_file({Filename, Contents}, #load_app{app_dir=AppDir
                                          ,base_path=BasePath
                                          }) ->
    AbsPath = filename:join([BasePath, AppDir, Filename]),
    case filelib:ensure_dir(AbsPath) of
        'ok' ->
            case file:write_file(AbsPath, Contents) of
                'ok' -> 'ok';
                {'error', Reason} ->
                    lager:error("failed to write file ~s: ~p", [AbsPath, Reason]),
                    {'error', {'file_write_failed', {AbsPath, Reason}}}
            end;
        {'error', Reason}->
            lager:error("failed to write file ~s: ~p", [AbsPath, Reason]),
            {'error', {'file_write_failed', {AbsPath, Reason}}}
    end.

%% erl_tar:extract will return 'ok' when extracting to a directory. if dialyzer is complaining ignore it or just add
%% a dummy ok fun header to extract_files to handle it.
-type erl_tar_extract() :: {'ok', [{Path::string(), Content::binary()}]} | {'error', term()}.
-spec extract(binary()) -> erl_tar_extract().
extract(Archive) ->
    try erl_tar:extract({'binary', Archive}, ['compressed', 'memory'])
    catch
        _E:_T:_ST ->
            lager:debug("cannot extract the archive, bad archive?"),
            {'error', 'bad_archive'}
    end.

-spec extract_files(atom(), app_type(), erl_tar_extract()) -> load_ret().
extract_files(App, AppType, {'ok', ArchiveFiles}) ->
    finish_extracting(
      extract_fold(ArchiveFiles
                  ,#load_app{app_type = AppType
                            ,app = App
                            }
                  )
     );
extract_files(_App, _AppType, {'error', _E}) ->
    lager:warning("failed to extract archive: ~p", [_E]),
    {'error', 'bad_archive'}.

-spec extract_fold([{string(), binary()}], load_app()) -> load_ret().
extract_fold([], LoadApp) ->
    {'ok', LoadApp};
extract_fold([{Filename, Bin} | Files], #load_app{app_beams = AppBeams
                                                 ,writeable = Writeable
                                                 }=LoadApp) ->
    %% files in packaging is under {PACKAGE_NAME}-{VERSION}/[...] folder.
    %%
    %% Let's remove AppDir from path, so we add it back
    %% when writing file to fs.
    case {filename:split(Filename)
         ,filename:extension(Filename)
         }
    of
        {[], _} ->
            extract_fold(Files, LoadApp);
        {["metadata.json"], _} ->
            extract_fold(Files, LoadApp#load_app{app_metadata=kz_json:decode(Bin)});
        {[_AppDir], _} ->
            extract_fold(Files, LoadApp);
        {[_AppDir, "ebin"|Rest], ".beam"} ->
            extract_fold(Files, LoadApp#load_app{app_beams=AppBeams#{filename:join(Rest) => Bin}});
        {[_AppDir, "ebin"|_], ".app"} ->
            handle_dot_app_file(Files, Bin, LoadApp);
        {[_AppDir, "ebin"|_], _} ->
            extract_fold(Files, LoadApp);
        {[_AppDir | Rest], _Ext} ->
            extract_fold(Files, LoadApp#load_app{writeable=[{filename:join(Rest), Bin} | Writeable]})
    end.

-spec finish_extracting(load_ret()) -> load_ret().
finish_extracting({'ok', #load_app{app_metadata='undefined'}}) ->
    lager:error("invalid acrhive file, no metadata is included in archive file"),
    {'error', 'no_metadata'};
finish_extracting({'ok', #load_app{app_spec='undefined'}}) ->
    lager:error("invalid erlang app, archive contained no .app"),
    {'error', 'no_app_spec'};
finish_extracting({'ok', _}=OK) ->
    OK;
finish_extracting({'error', _}=Error) ->
    Error.

-spec handle_dot_app_file([{string(), binary()}], binary(), load_app()) -> load_ret().
handle_dot_app_file(Files, Bin, LoadApp) ->
    {'ok', Tokens, _EndLocation} = erl_scan:string(binary_to_list(Bin)),
    %% {'application', Module, ...}
    {'ok', AppFileTerms = {'application', App, AppConfig}} = erl_parse:parse_term(Tokens),
    NewLoad = LoadApp#load_app{app_spec=AppFileTerms
                              ,app_name=kz_term:to_binary(App)
                              },
    case props:get_value('mod', AppConfig) of
        'undefined' ->
            lager:error("invalid erlang app, no application callback module is defined in .app"),
            {'error', 'no_app_mod'};
        _ ->
            extract_fold(Files, NewLoad)
    end.
