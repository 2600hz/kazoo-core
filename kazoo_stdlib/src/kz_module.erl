%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2018-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_module).

-export([is_exported/3]).
-export([ensure_loaded/1]).
-export([application_integrations/1]).
-export([hotload/1]).
-export([behaviours/1, has_behaviour/2]).

-type integration() :: {kz_term:ne_binary() | module(), module(), atom()} |
                       {kz_term:ne_binary() | module(), module(), atom(), boolean()} |
                       module().
-type integrations() :: [integration()].
-export_type([integration/0
             ,integrations/0
             ]).

-elvis([{'elvis_style', 'no_debug_call', 'disable'}]).

%% @doc lifted from erlang ML
%% http://erlang.2086793.n4.nabble.com/What-is-the-fastest-way-to-check-if-a-function-is-defined-in-a-module-tp4723096p4723108.html
-spec is_exported(module() | kz_term:text(), kz_term:text(), arity()) -> boolean().
is_exported(Module, Function, Arity)
  when is_atom(Module),
       is_atom(Function),
       is_integer(Arity),
       Arity >= 0 ->
    case ensure_loaded(Module) of
        'false' -> 'false';
        Module -> erlang:function_exported(Module, Function, Arity)
    end;
is_exported(Module, Function, Arity) ->
    try is_exported(kz_term:to_atom(Module)
                   ,kz_term:to_atom(Function)
                   ,kz_term:to_integer(Arity)
                   )
    catch
        'error':'badarg' -> 'false';
        'error':'system_limit' -> 'false'
    end.

%%------------------------------------------------------------------------------
%% @doc Given a module name try to verify its existence, loading it into the
%% the Erlang VM if possible.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_loaded(kz_term:text()) -> module() | 'false'.
ensure_loaded('undefined') -> 'false';
ensure_loaded("undefined") -> 'false';
ensure_loaded(<<"undefined">>) -> 'false';
ensure_loaded(Mod) ->
    Module = kz_term:to_atom(Mod, 'true'),
    case erlang:module_loaded(Module) of
        'true' -> Module;
        'false' ->
            case code:ensure_loaded(Module) of
                {'module', Module} -> Module;
                {'error', _Why} ->
                    lager:debug("module ~s not found: ~p", [Module, _Why]),
                    'false'
            end
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec application_integrations(integrations()) -> 'ok'.
application_integrations(Integrations) ->
    lists:foreach(fun load_integration/1, Integrations).

-spec load_integration(integration()) -> 'ok'.
load_integration({Q, M, F, 'true'}) ->
    _Result = M:F(Q),
    lager:debug("application integration loading ~p:~p(~p), result: ~p", [M, F, Q, _Result]);
load_integration({Q, M, F, 'false'}) ->
    try load_integration({Q, M, F, 'true'}) of
        Result -> Result
    catch
        _E:_R ->
            lager:debug("application integration loading ~p:~p(~p), died: ~p:~p", [M, F, Q, _E, _R])
    end;
load_integration({Q, M, F}) ->
    load_integration({Q, M, F, 'false'});
load_integration(H)
  when is_atom(H) ->
    Loaded = code:ensure_loaded(H),
    lager:debug("application integration loading ~p, result: ~p", [H, Loaded]).

-spec hotload(kz_term:text() | atom()) -> 'ok' | 'no_return'.
hotload(Module)
  when is_atom(Module) ->
    _ = code:soft_purge(Module),
    handle_load_module_return(Module, code:load_file(Module));
hotload(Module) ->
    hotload(kz_term:to_atom(Module, 'true')).

%%------------------------------------------------------------------------------
%% @doc Clarify the error returned when a module could not be loaded.
%% @end
%%------------------------------------------------------------------------------
-spec handle_load_module_return(module(), code:load_ret()) -> 'ok'.
handle_load_module_return(Module, {'error', 'nofile'}) ->
    Filename = kz_term:to_list(Module) ++ code:objfile_extension(),
    case code:where_is_file(Filename) of
        'non_existing' ->
            io:format("ERROR: unable to hotload ~s: nofile~n", [Module]);
        AbsName ->
            io:format("ERROR: unable to hotload ~s: check ~s for permission issues~n", [Module, AbsName])
    end;
handle_load_module_return(_Module, {'error', _E}) ->
    io:format("ERROR: unable to hotload ~s: ~p~n", [_Module, _E]);
handle_load_module_return(Module, {'module', Module}) ->
    'ok'.

-spec behaviours(atom()) -> [atom()].
behaviours(Module)
  when is_atom(Module) ->
    props:get_value('behaviour', Module:module_info('attributes'), []).

-spec has_behaviour(atom(), atom()) -> boolean().
has_behaviour(Module, Behaviour)
  when is_atom(Module) ->
    case ensure_loaded(Module) of
        'false' -> 'false';
        Module -> lists:member(Behaviour, behaviours(Module))
    end.
