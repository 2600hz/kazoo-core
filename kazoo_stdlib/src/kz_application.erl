%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_application).

-export([calling_app/0]).
-export([calling_app_version/0]).
-export([calling_process/0]).
-export([get_app/1]).
-export([hotload/1]).
-export([running_apps/0, loaded_apps/0, is_kapp/1]).
-export([version/1]).
-export([application_version/1]).
-export([application_version_with_otp_release/1, otp_release/0]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-elvis([{'elvis_style', 'no_debug_call', 'disable'}]).

-spec process_fold([tuple()], atom()) -> tuple() | atom().
process_fold([], App) -> App;
process_fold([{M, _, _, _}=Mod | Others], App) ->
    ModApp = case application:get_application(M) of
                 {'ok', KModApp} -> KModApp;
                 'undefined' -> M
             end,
    process_fold(ModApp, App, Mod, Others).

-spec process_fold(atom(), atom(), tuple(), [tuple()]) -> tuple() | atom().
process_fold(App, App, _, Others) ->
    process_fold(Others, App);
process_fold(App, _, M, _) -> {App, M}.

-spec calling_app_stacktrace() -> any().
calling_app_stacktrace() ->
    try throw('get_stacktrace')
    catch
        _E:_R:ST ->
            [_Me | Others] = ST,
            Others
    end.

%%------------------------------------------------------------------------------
%% @doc For core applications that want to know which app is calling.
%% @end
%%------------------------------------------------------------------------------
-spec calling_app() -> kz_term:ne_binary().
calling_app() ->
    Modules = calling_app_stacktrace(),
    [_Me, {Module, _, _, _} | Start] = Modules,
    {'ok', App} = application:get_application(Module),
    case process_fold(Start, App) of
        App -> kz_term:to_binary(App);
        {Parent, _MFA} -> kz_term:to_binary(Parent)
    end.

-spec calling_app(pid()) -> kz_term:ne_binary().
calling_app(Pid) when is_pid(Pid) ->
    case application:get_application(Pid) of
        {'ok', App} -> App;
        _Other -> calling_app()
    end.

-spec calling_app_version() -> {kz_term:ne_binary(), kz_term:ne_binary()}.
calling_app_version() ->
    App = calling_app(self()),
    {NewApp, _, Version} = get_app(App),
    {kz_term:to_binary(NewApp), kz_term:to_binary(Version)}.

-spec calling_process() -> map().
calling_process() ->
    Modules = calling_app_stacktrace(),
    [_Me, {Module, _, _, _}=M | Start] = Modules,
    App = case application:get_application(Module) of
              {'ok', KApp} -> KApp;
              'undefined' -> Module
          end,
    {NewApp, {Mod, Function, Arity, [{'file', Filename}, {'line', Line}]}} =
        case process_fold(Start, App) of
            App -> {App, M};
            {Parent, MFA } -> {Parent, MFA}
        end,
    #{app => NewApp
     ,module => Mod
     ,function => Function
     ,arity => Arity
     ,file => Filename
     ,line => Line
     }.

-spec get_app(atom() | kz_term:ne_binary()) -> {atom(), string(), string()} | 'undefined'.
get_app(<<AppName/binary>>) ->
    get_app(kz_term:to_atom(AppName));
get_app(AppName) when is_atom(AppName) ->
    case [App || {Name, _, _}=App <- application:loaded_applications(), Name =:= AppName] of
        [] -> 'undefined';
        [Ret | _] -> Ret
    end.

-spec application_version(atom()) -> kz_term:ne_binary().
application_version(Application) when is_atom(Application) ->
    case application:get_key(Application, 'vsn') of
        {'ok', Vsn} -> kz_term:to_binary(Vsn);
        'undefined' -> <<"unknown">>
    end.

-spec hotload(kz_term:text() | atom()) -> 'ok'.
hotload(App) when is_atom(App) ->
    case application:get_key(App, 'modules') of
        {'ok', Modules} ->
            io:format("found ~b modules to reload for ~s~n", [length(Modules), App]),
            lists:foreach(fun kz_module:hotload/1, Modules),
            io:format("app ~s modules reloaded~n", [App]);
        'undefined' ->
            io:format("app ~s not found (is it running? typo?)~n", [App])
    end;
hotload(App) ->
    hotload(kz_term:to_atom(App, 'true')).

-spec is_kapp(atom()) -> boolean().
is_kapp(App) when is_atom(App) ->
    {'ok', 'true'} =:= application:get_env(App, 'is_kazoo_app').

-spec running_apps() -> [{atom(), string(), _}].
running_apps() ->
    [AppData
     || {App, _Desc, _Vsn}=AppData <- application:which_applications(),
        is_kapp(App)
    ].

-spec loaded_apps() -> [kz_types:kapp_version()].
loaded_apps() ->
    lists:foldl(fun loaded_app_from_path/2
               ,[]
               ,code:get_path()
               ).

loaded_app_from_path(Filepath, Acc) ->
    case "ebin" =:= filename:basename(Filepath) of % rule out "." and the like
        'false' -> Acc;
        'true' ->
            AppDir = filename:basename(filename:dirname(Filepath)),
            [AppName, AppVersion] = binary:split(kz_term:to_binary(AppDir), <<"-">>),
            DotAppPath = filename:join([Filepath, <<AppName/binary, ".app">>]),

            AppConfig = load_app_config(AppName, DotAppPath),
            Env = props:get_value('env', AppConfig, []),
            case props:is_true('is_kazoo_app', Env, 'false') of
                'false' ->
                    Acc;
                'true' ->
                    [kapp_version({AppName
                                  ,props:get_value('description', AppConfig)
                                  ,props:get_value('vsn', AppConfig, AppVersion)
                                  }
                                 )
                    | Acc
                    ]
            end

    end.

load_app_config(AppName, DotAppPath) ->
    case file:consult(DotAppPath) of
        {'ok', [{'application', _App, AppConfig}]} ->
            AppConfig;
        _Error ->
            try application:get_all_key(kz_term:to_atom(AppName)) of
                {'ok', AppConfig} ->
                    AppConfig;
                _ ->
                    []
            catch
                _:_ ->
                    []
            end
    end.

kapp_version({Name, Desc, Vsn}) ->
    #kapp_version{
       name = kz_term:to_binary(Name),
       description = kz_term:to_binary(Desc),
       version = kz_term:to_binary(Vsn)
      }.

-spec version(atom()) -> kz_term:api_ne_binary().
version(Application) when is_atom(Application) ->
    case application:get_key(Application, 'vsn') of
        {'ok', Version} -> kz_term:to_binary(Version);
        _Else -> 'undefined'
    end.

-spec application_version_with_otp_release(atom()) -> kz_term:ne_binary().
application_version_with_otp_release(App) ->
    list_to_binary([application_version(App), " - ", otp_release()]).

-spec otp_release() -> kz_term:ne_binary().
otp_release() ->
    kz_term:to_binary(erlang:system_info('otp_release')).
