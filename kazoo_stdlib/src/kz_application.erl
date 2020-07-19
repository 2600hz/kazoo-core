%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
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
-export([running_apps/0, is_kapp/1]).

-export([application_version/1]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

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

-spec calling_app_version() -> {kz_term:ne_binary(), kz_term:ne_binary()}.
calling_app_version() ->
    {'ok', App} = application:get_application(self()),
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
get_app(AppName) ->
    case [App || {Name, _, _}=App <- application:loaded_applications(), Name =:= AppName] of
        [] -> 'undefined';
        [Ret | _] -> Ret
    end.

-spec application_version(atom()) -> kz_term:ne_binary().
application_version(Application) ->
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
is_kapp(App) ->
    {'ok', 'true'} =:= application:get_env(App, 'is_kazoo_app').

-spec running_apps() -> [{atom(), string(), _}].
running_apps() ->
    [AppData
     || {App, _Desc, _Vsn}=AppData <- application:which_applications(),
        is_kapp(App)
    ].
