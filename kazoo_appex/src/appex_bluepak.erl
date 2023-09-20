%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
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

-include("appex_client.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").

-record(load_app, {app_metadata :: kz_term:api_object()
                  ,app_name :: kz_term:api_ne_binary()
                  ,app_spec :: {'application', atom(), kz_term:proplist()} | 'undefined'
                  ,app_type :: app_type()
                  ,app :: atom()
                  ,app_vsn :: kz_term:api_ne_binary()
                  ,app_dir :: kz_term:api_ne_binary()
                  ,base_path :: kz_term:api_ne_binary()
                  ,writeable = [] :: [{file:filename_all(), binary()}] %% [{Filename, Contents}]
                  ,api_url :: kz_term:api_ne_binary()
                  ,loaded_mods = [] :: [atom()]
                  ,app_beams = #{} :: #{File::file:filename_all() => binary()}
                  }).
-type load_app() :: #load_app{}.

-type loaded() :: #{app := atom()
                   ,app_name := kz_term:ne_binary()
                   ,app_spec := {'application', atom(), kz_term:proplist()}
                   ,app_type := kz_term:ne_binary()
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
                {'ok', #load_app{app_metadata='undefined'}} ->
                    lager:error("invalid acrhive file, no metadata"),
                    {'error', 'no_metadata'};
                {'ok', #load_app{app_spec='undefined'}} ->
                    lager:error("invalid erlang app, acrhive contained no .app"),
                    {'error', 'no_app_spec'};
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

-spec set_load_params(load_app()) -> {'ok', load_app()} | {'error', 'no_api_url'}.
set_load_params(#load_app{app_type='kazoo'}=LoadApp) ->
    {'ok', update_load_app(LoadApp)};
set_load_params(#load_app{}=LoadApp) ->
    set_load_params(LoadApp, api_url()).

set_load_params(_LoadApp, {'error', _}=Error) ->
    Error;
set_load_params(LoadApp, {'ok', APIUrl}) ->
    NewLoad = update_load_app(LoadApp),
    {'ok', NewLoad#load_app{api_url=APIUrl}}.

update_load_app(#load_app{app_metadata=AppMeta
                         ,app=App
                         }=LoadApp
               ) ->
    AppVsn = kz_json:get_ne_binary_value(<<"version">>, AppMeta, <<"0.1.0">>),
    AppName = kz_term:to_binary(App),

    LoadApp#load_app{app_vsn=AppVsn
                    ,app_dir=kz_term:to_binary([AppName, "-", AppVsn])
                    ,base_path=base_path()
                    }.

-spec prior_cleanup(App::atom()) -> 'ok'.
prior_cleanup(App) ->
    AppDir = lists:concat([App, "-*"]),
    BasePath = code:lib_dir(),
    case filelib:wildcard(AppDir, BasePath) of
        [] -> 'ok';
        DirList ->
            _ = [file:del_dir_r(filename:join(BasePath, Dir))
                 || Dir <- DirList
                ],
            lager:warning("before loading ~p app; ~s old directory(s) is/are deleted from ~s path"
                         ,[App, string:join(DirList, ", "), BasePath]
                         )
    end.

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

fail_cleanup(#load_app{loaded_mods=Loaded
                      ,app=App
                      }=LoadApp) ->
    _ = [begin
             _Purged = code:purge(Module),
             code:delete(Module)
         end
         || Module <- Loaded
        ],
    _Unload = application:unload(App),
    Ebin = ebin_path(LoadApp),
    _ = file:del_dir_r(filename:dirname(Ebin)),
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
    NewEnv = props:set_values([{'app_mod', AppMod}
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
finish_loading_app(#load_app{app_type='monster'
                            ,app_dir=AppDir
                            ,base_path=BasePath
                            ,api_url=ApiUrl
                            ,app=App
                            }=LoadApp) ->
    AssetsDir = appex_cb_router:assets_dir(BasePath, AppDir),
    kazoo_documents_maintenance:refresh_app(AssetsDir, ApiUrl),
    lager:info("initialized ~s app", [App]),
    {'ok', LoadApp};
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
write_file({Filename, Contents}, #load_app{app_type='kazoo'}=LoadApp) ->
    do_the_write_thing({Filename, Contents}, LoadApp);
write_file({Filename, Contents}
          ,#load_app{app_dir=AppDir, api_url=ApiUrl}=LoadApp
          ) ->
    case {filename:dirname(Filename), filename:basename(Filename)} of
        {"priv/assets/metadata", "app.json"} ->
            SourceURL = appex_cb_router:source_url(ApiUrl, AppDir),
            AppJObj = kz_doc:setters(kz_json:decode(Contents)
                                    ,[{fun kzd_app:set_source_url/2, SourceURL}]
                                    ),
            do_the_write_thing({Filename, kz_json:encode(AppJObj)}, LoadApp);
        _ ->
            do_the_write_thing({Filename, Contents}, LoadApp)
    end.

-spec do_the_write_thing({file:filename_all(), binary()}, load_app()) -> 'ok' | {'error', term()}.
do_the_write_thing({Filename, Contents}, LoadApp) ->
    AbsPath = write_path(Filename, LoadApp),
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

write_path(Filename, #load_app{app_type='kazoo'
                              ,app_dir=AppDir
                              ,base_path=BasePath
                              }) ->
    filename:join([BasePath, AppDir, Filename]);
write_path(Filename, #load_app{app_dir=AppDir
                              ,base_path=BasePath
                              }) ->
    appex_cb_router:asset_path(BasePath, AppDir, Filename).

-spec api_url() -> {'ok', kz_term:ne_binary()} | {'error', 'no_api_url'}.
api_url() ->
    case appex_client_config:api_url() of
        'undefined' ->
            try kz_network_utils:resolve(kz_term:to_binary(kz_network_utils:get_hostname())
                                        ,get_resolve_options()
                                        )
            of
                [] ->
                    lager:error("unable to detect localhost api_url, please configure api_url in appex_client"),
                    {'error', 'no_api_url'};
                [IP|_] ->
                    lager:info("using current hostmachine address ~s as api_url", [IP]),
                    {'ok', IP}
            catch
                _E:_T:_ST ->
                    lager:error("unable to detect localhost api_url, please configure api_url in appex_client"),
                    {'error', 'no_api_url'}
            end;
        ApiUrl ->
            {'ok', ApiUrl}
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
      lists:foldl(fun extract_file/2
                 ,#load_app{app_type = AppType
                           ,app = App
                           }
                 ,ArchiveFiles
                 )
     );
extract_files(_App, _AppType, {'error', _E}) ->
    lager:warning("failed to extract archive: ~p", [_E]),
    {'error', 'bad_archive'}.

-spec extract_file({string(), binary()}, load_app()) -> load_app().
extract_file({Filename, Bin}, #load_app{app_type = AppType
                                       ,app_beams = AppBeams
                                       ,writeable = Writeable
                                       }=LoadApp) ->
    %% files in new packaging is under {PACKAGE_NAME}-{VERSION}/[...] folder.
    %%
    %% Let's remove AppDir from path, so we add it back
    %% when writing file to fs.
    case {filename:split(Filename)
         ,filename:extension(Filename)
         }
    of
        {[], _} -> LoadApp;
        {["metadata.json"], _} ->
            LoadApp#load_app{app_metadata=kz_json:decode(Bin)};
        {[_AppDir], _} -> LoadApp;
        {[_AppDir, "ebin"|Rest], ".beam"} when AppType =:= 'kazoo' ->
            LoadApp#load_app{app_beams=AppBeams#{filename:join(Rest) => Bin}};
        {[_AppDir, "ebin"|_], ".app"} when AppType =:= 'kazoo' ->
            handle_dot_app_file(Bin, LoadApp);
        {[_AppDir, "ebin"|_], _} ->
            LoadApp;
        {[_AppDir | Rest], _Ext} ->
            LoadApp#load_app{writeable=[{filename:join(Rest), Bin} | Writeable]}
    end.

-spec finish_extracting(load_app()) -> {'ok', load_app()}.
%% if metadata is missing it is an invalid package
finish_extracting(#load_app{app_metadata='undefined'}=LoadApp) ->
    {'ok', LoadApp};
%% if app has no app_spec, make a fake one, for all app type
finish_extracting(#load_app{app_spec='undefined'
                           ,app_beams=Beams
                           ,app_metadata=AppMeta
                           ,app=App
                           }=LoadApp) ->
    Version = kz_json:get_ne_binary_value(<<"version">>, AppMeta, <<"0.1.0">>),
    Dependencies = [kz_term:to_atom(kz_json:get_ne_binary_value(<<"name">>, Dep), 'true')
                    || Dep <- kz_json:get_list_value(<<"dependencies">>, AppMeta, [])
                   ],
    {'ok', AppMod, AppModBin} = minimal_app_mod(App),
    {'ok', AppSupMod, AppSupModBin} = minimal_app_sup(App),

    Modules = [kz_term:to_atom(filename:basename(Filename, ".beam"), 'true')
               || Filename <- maps:keys(Beams)
              ],

    AppSpec = [{'applications', Dependencies}
              ,{'description', "Asset Application for " ++ kz_term:to_list(App)}
              ,{'vsn', kz_term:to_list(Version)}
              ,{'modules', [AppMod, AppSupMod | Modules]}
              ,{'mod', {AppMod, []}}
              ,{'registered', []}
              ,{'env', [{'is_kazoo_app', 'true'}]}
              ],
    {'ok'
    ,LoadApp#load_app{app_spec={'application', App, AppSpec}
                     ,app_name=kz_term:to_binary(App)
                     ,app_beams=#{io_lib:format("~s.beam", [AppMod]) => AppModBin
                                 ,io_lib:format("~s.beam", [AppSupMod]) => AppSupModBin
                                 }
                     }
    };
finish_extracting(#load_app{}=LoadApp) ->
    {'ok', LoadApp}.

-spec minimal_app_mod(module()) ->
          {'ok', module(), binary() | term()} |
          {'error', term(), term()}.
minimal_app_mod(App) ->
    Mod = kz_term:to_atom(io_lib:format("~s_app", [App]), 'true'),
    SupMod = kz_term:to_atom(io_lib:format("~s_sup", [App]), 'true'),
    compile:forms(
      [{'attribute',erl_anno:new(1),'file',{io_lib:format("~s.erl", [Mod]),1}}
      ,{'attribute',erl_anno:new(1),'module',Mod}
      ,{'attribute',erl_anno:new(2),'behaviour','application'}
      ,{'attribute',erl_anno:new(3),'export',[{'start',2},{'stop',1}]}
      ,{'function',erl_anno:new(4),'start',2
       ,[{'clause',erl_anno:new(4), [{'var',erl_anno:new(4),'_'},{'var',erl_anno:new(4),'_'}], []
         ,[{'call',erl_anno:new(4),{'remote',erl_anno:new(4),{'atom',erl_anno:new(4),SupMod},{'atom',erl_anno:new(4),'start_link'}},[]}]
         }
        ]
       }
      ,{'function',erl_anno:new(5),'stop',1,[{'clause',erl_anno:new(5),[{'var',erl_anno:new(5),'_'}],[],[{'atom',erl_anno:new(5),'ok'}]}]}
      ]
     ).

-spec minimal_app_sup(atom()) ->
          {'ok', module(), binary() | term()} |
          {'error', term(), term()}.
minimal_app_sup(App) ->
    Mod = kz_term:to_atom(io_lib:format("~s_sup", [App]), 'true'),
    compile:forms(
      [{'attribute',erl_anno:new(1),'file',{io_lib:format("~s.erl", [Mod]),1}}
      ,{'attribute',erl_anno:new(1),'module',Mod}
      ,{'attribute',erl_anno:new(2),'behaviour','supervisor'}
      ,{'attribute',erl_anno:new(3),'export',[{'start_link',0},{'init',1}]}
      ,{'function',erl_anno:new(4),'start_link',0
       ,[{'clause',erl_anno:new(4),[],[]
         ,[{'call',erl_anno:new(4),{'remote',erl_anno:new(4),{'atom',erl_anno:new(4),'supervisor'},{'atom',erl_anno:new(4),'start_link'}}
           ,[{'tuple',erl_anno:new(4),[{'atom',erl_anno:new(4),'local'},{'atom',erl_anno:new(4),Mod}]},{'atom',erl_anno:new(4),Mod},{'nil',erl_anno:new(4)}]
           }]}]
       }
      ,{'function',erl_anno:new(5),'init',1
       ,[{'clause',erl_anno:new(5),[{'nil',erl_anno:new(5)}],[]
         ,[{'tuple',erl_anno:new(5),[{'atom',erl_anno:new(5),'ok'},{'tuple',erl_anno:new(5),[{'tuple',erl_anno:new(5),[{'atom',erl_anno:new(5),'one_for_one'},{'integer',erl_anno:new(5),25},{'integer',erl_anno:new(5),1}]},{'nil',erl_anno:new(5)}]}]}
          ]}]
       }
      ]
     ).

-spec handle_dot_app_file(binary(), load_app()) -> load_app().
handle_dot_app_file(Bin, LoadApp) ->
    {'ok', Tokens, _EndLocation} = erl_scan:string(binary_to_list(Bin)),
    %% {'application', Module, ...}
    {'ok', AppFileTerms = {'application', App, AppConfig}} = erl_parse:parse_term(Tokens),
    NewLoad = LoadApp#load_app{app_spec=AppFileTerms
                              ,app_name=kz_term:to_binary(App)
                              },
    case props:get_value('mod', AppConfig) of
        'undefined' ->
            create_minimal_modules(NewLoad);
        _ ->
            NewLoad
    end.

-spec create_minimal_modules(load_app()) -> load_app().
create_minimal_modules(#load_app{app_spec={'application', App, AppConfig}
                                ,app_beams=AppBeams
                                }=LoadApp) ->
    Modules = props:get_value('modules', AppConfig, []),
    {'ok', AppMod, AppModBin} = minimal_app_mod(App),
    {'ok', AppSupMod, AppSupModBin} = minimal_app_sup(App),
    NewAppConfig = props:set_values([{'mod', {AppMod, []}}
                                    ,{'modules', lists:usort([AppMod, AppSupMod | Modules])}
                                    ]
                                   ,AppConfig
                                   ),
    LoadApp#load_app{app_spec={'application', App, NewAppConfig}
                    ,app_beams=AppBeams#{io_lib:format("~s.beam", [AppMod]) => AppModBin
                                        ,io_lib:format("~s.beam", [AppSupMod]) => AppSupModBin
                                        }

                    }.

-spec get_resolve_options() -> kz_term:proplist().
get_resolve_options() ->
    case kapps_config:is_true(?CONFIG_CAT, <<"use_tcp">>, 'false') of
        'true' -> kz_network_utils:default_options();
        'false' -> props:set_value('usevc', 'false', kz_network_utils:default_options())
    end.
