%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% Fetches config values from the Erlang application's environment
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_app_config).

-export([set_config_getter/1, set_account_config_getter/1]).

-export([get_binary/2, get_binary/3]).
-export([get_json/2, get_json/3]).
-export([get_jsons/2, get_jsons/3]).
-export([get_atom/2, get_atom/3]).
-export([get_integer/2, get_integer/3]).
-export([get_pos_integer/2, get_pos_integer/3]).
-export([get_non_neg_integer/2, get_non_neg_integer/3]).
-export([get_float/2, get_float/3]).
-export([get_is_false/2, get_is_false/3]).
-export([get_is_true/2, get_is_true/3]).
-export([is_true/2, is_true/3]).
-export([is_false/2, is_false/3]).
-export([get_boolean/2, get_boolean/3]).
-export([get_ne_binary/2, get_ne_binary/3]).
-export([get_ne_binaries/2, get_ne_binaries/3]).
-export([get_timeout/2, get_timeout/3]).

-compile({'no_auto_import', [get/1]}).

-type account_id() :: kz_term:api_ne_binary().
-type app() :: atom() | {atom(), account_id()}.
-type app_key() :: kz_term:ne_binary() | kz_term:ne_binaries().

-type config_getter() :: fun((kz_json:key(), kz_json:get_key()) -> kz_json:api_json_term()).
-type account_config_getter() :: fun((kz_term:api_ne_binary(), kz_json:key(), kz_json:get_key()) -> kz_json:api_json_term()).

-export_type([config_getter/0
             ,account_config_getter/0
             ]).

-spec set_config_getter(config_getter()) -> 'ok'.
set_config_getter(GetterFun) when is_function(GetterFun, 2) ->
    set_config({'kz_config', GetterFun}).

-spec set_account_config_getter(account_config_getter()) -> 'ok'.
set_account_config_getter(GetterFun) when is_function(GetterFun, 3) ->
    set_config({'kz_account_config', GetterFun}).

set_config({Key, Value}) ->
    persistent_term:put(Key, Value).

-spec get_pos_integer(app(), app_key()) -> kz_term:api_pos_integer().
get_pos_integer(App, Key) ->
    get_pos_integer(App, Key, 'undefined').

-spec get_pos_integer(app(), app_key(), Default) -> pos_integer() | Default.
get_pos_integer(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> as_integer(Value, Default, fun(V) -> V > 0 end)
    end.

-spec get_non_neg_integer(app(), app_key()) -> kz_term:api_pos_integer().
get_non_neg_integer(App, Key) ->
    get_non_neg_integer(App, Key, 'undefined').

-spec get_non_neg_integer(app(), app_key(), Default) -> pos_integer() | Default.
get_non_neg_integer(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> as_integer(Value, Default, fun(V) -> V >= 0 end)
    end.

-spec get_integer(app(), app_key()) -> kz_term:api_pos_integer().
get_integer(App, Key) ->
    get_integer(App, Key, 'undefined').

-spec get_integer(app(), app_key(), Default) -> pos_integer() | Default.
get_integer(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> as_integer(Value, Default)
    end.

-spec get_float(app(), app_key()) -> kz_term:api_pos_integer().
get_float(App, Key) ->
    get_float(App, Key, 'undefined').

-spec get_float(app(), app_key(), Default) -> float() | Default.
get_float(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> kz_term:to_float(Value)
    end.

-spec get_atom(app(), app_key()) -> atom().
get_atom(App, Key) ->
    get_atom(App, Key, 'undefined').

-spec get_atom(app(), app_key(), Default) -> atom() | Default.
get_atom(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> kz_term:to_atom(Value, 'true')
    end.

-spec get_binary(app(), app_key()) -> kz_term:api_binary().
get_binary(App, Key) ->
    get_binary(App, Key, 'undefined').

-spec get_binary(app(), app_key(), Default) -> binary() | Default.
get_binary(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} when is_binary(Value) -> Value;
        _NonBinary -> Default
    end.

-spec get_ne_binary(app(), app_key()) -> kz_term:api_ne_binary().
get_ne_binary(App, Key) ->
    get_ne_binary(App, Key, 'undefined').

-spec get_ne_binary(app(), app_key(), Default) -> kz_term:ne_binary() | Default.
get_ne_binary(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} ->
            case kz_term:is_ne_binary(Value) of
                'true' -> Value;
                'false' -> Default
            end
    end.

-spec get_ne_binaries(app(), app_key()) -> kz_term:api_ne_binaries().
get_ne_binaries(App, Key) ->
    get_ne_binaries(App, Key, 'undefined').

-spec get_ne_binaries(app(), app_key(), Default) -> kz_term:ne_binaries() | Default.
get_ne_binaries(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} ->
            case kz_term:is_ne_binaries(Value) of
                'true' -> Value;
                'false' -> Default
            end
    end.

-spec get_json(app(), app_key()) -> kz_term:api_object().
get_json(App, Key) ->
    get_json(App, Key, 'undefined').

-spec get_json(app(), app_key(), Default) -> kz_json:object() | Default.
get_json(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} ->
            as_json(Value, Default)
    end.

-spec get_jsons(app(), app_key()) -> kz_json:objects().
get_jsons(App, Key) ->
    get_jsons(App, Key, []).

-spec get_jsons(app(), app_key(), Default) -> kz_json:objects() | Default.
get_jsons(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} ->
            as_jsons(Value, Default)
    end.

-spec get_boolean(app(), app_key()) -> boolean().
get_boolean(App, Key) ->
    get_boolean(App, Key, 'false').

-spec get_boolean(app(), app_key(), Default) -> boolean() | Default.
get_boolean(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> as_boolean(Value, Default)
    end.

-spec get_is_true(app(), app_key()) -> boolean().
get_is_true(App, Key) ->
    get_is_true(App, Key, 'false').

-spec get_is_true(app(), app_key(), Default) -> boolean() | Default.
get_is_true(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> kz_term:is_true(Value)
    end.

-spec is_true(app(), app_key()) -> boolean().
is_true(App, Key) ->
    is_true(App, Key, 'false').

-spec is_true(app(), app_key(), Default) -> boolean() | Default.
is_true(App, Key, Default) ->
    get_is_true(App, Key, Default).

-spec get_is_false(app(), app_key()) -> boolean().
get_is_false(App, Key) ->
    get_is_false(App, Key, 'true').

-spec get_is_false(app(), app_key(), Default) -> boolean() | Default.
get_is_false(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', Value} -> kz_term:is_false(Value)
    end.

-spec is_false(app(), app_key()) -> boolean().
is_false(App, Key) ->
    is_false(App, Key, 'false').

-spec is_false(app(), app_key(), Default) -> boolean() | Default.
is_false(App, Key, Default) ->
    get_is_false(App, Key, Default).

-spec get_timeout(app(), app_key()) -> kz_term:api_pos_integer() | 'infinity'.
get_timeout(App, Key) ->
    get_timeout(App, Key, 'undefined').

-spec get_timeout(app(), app_key(), Default) -> pos_integer() | 'infinity' | Default.
get_timeout(App, Key, Default) ->
    case get(App, Key) of
        'undefined' -> Default;
        {'ok', <<"infinity">>} -> 'infinity';
        {'ok', Value} -> as_integer(Value, Default, fun(V) -> V > 0 end)
    end.

-spec get(app(), app_key()) -> 'undefined' | {'ok', any()}.
get(App, <<Key/binary>>) ->
    get(App, binary:split(Key, <<".">>, ['global']));
get(App, Keys) ->
    fetch_value(App, Keys).

-spec as_integer(any(), Default, fun((integer()) -> boolean())) -> integer() | Default.
as_integer(Value, Default, VFun)
  when is_integer(Value) ->
    case VFun(Value) of
        'true' -> Value;
        'false' -> Default
    end;
as_integer(_Value, Default, _VFun) -> Default.

-spec as_integer(any(), Default) -> integer() | Default.
as_integer(Value, _Default)
  when is_integer(Value) -> Value;
as_integer(_Value, Default) -> Default.

-spec as_json(any(), Default) -> kz_json:object() | Default.
as_json(Value, Default) ->
    case kz_json:is_json_object(Value) of
        'true' -> Value;
        'false' -> Default
    end.

-spec as_jsons(kz_json:json_term(), Default) -> kz_json:objects() | Default.
as_jsons(V, Default) when is_list(V) ->
    case lists:all(fun kz_json:is_json_object/1, V) of
        'true' -> V;
        'false' -> Default
    end;
as_jsons(_V, Default) -> Default.

-spec as_boolean(any(), Default) -> boolean() | Default.
as_boolean(Value, _Default)
  when is_boolean(Value) -> Value;
as_boolean(_Value, Default) -> Default.

-spec fetch_account_value(app(), account_id(), app_key()) -> 'undefined' | {'ok', term()}.
fetch_account_value(App, AccountId, Key) ->
    %% default getter is to fetch Key from the app's environment
    Default = persistent_term:get('kz_account_config', fun get_env/3),
    Fun = persistent_term:get({'kz_account_config', App}, Default),
    fetch_account_value(App, AccountId, Key, Fun).

fetch_account_value(App, AccountId, Key, Fun) ->
    case Fun(AccountId, App, Key) of
        'undefined' -> 'undefined';
        {'ok', Value} -> {'ok', Value};
        Value -> {'ok', Value}
    end.

-spec fetch_value(app(), app_key()) -> 'undefined' | {'ok', term()}.
fetch_value({App, 'undefined'}, Key) ->
    fetch_value(App, Key);
fetch_value({App, AccountId}, Key)
  when not is_binary(AccountId) ->
    fetch_value({App, kz_term:to_binary(AccountId)}, Key);
fetch_value({App, AccountId}, Key) when is_atom(App) ->
    fetch_account_value(App, AccountId, Key);
fetch_value(App, Key) when is_atom(App) ->
    %% default getter is to fetch Key from the app's environment
    Default = persistent_term:get('kz_config', fun get_env/2),
    Fun = persistent_term:get({'kz_config', App}, Default),
    fetch_value(App, Key, Fun).

fetch_value(App, Key, Fun) ->
    case Fun(App, Key) of
        'undefined' -> 'undefined';
        {'ok', Value} -> {'ok', Value};
        Value -> {'ok', Value}
    end.

get_env(AccountId, App, Keys) ->
    case get_env(App, [AccountId | Keys]) of
        'undefined' -> get_env(App, Keys);
        Value -> Value
    end.

get_env(App, Keys) ->
    case from_app_env(App, Keys) of
        'undefined' -> from_app_file(App, Keys);
        {'ok', Value} -> get_value(Value, Keys)
    end.

from_app_env(App, [Key | Keys]) ->
    AppAtom = kz_term:to_atom(App),
    case application:get_env(AppAtom, kz_term:to_atom(Key, 'true')) of
        'undefined' -> 'undefined';
        {'ok', Value} -> get_value(Value, Keys)
    end.

current_dir() ->
    case file:get_cwd() of
        {'ok', Dir} ->
            Dir;
        {'error', Reason} ->
            lager:warning("error ~s getting current dir", [kz_term:to_binary(Reason)]),
            <<"/tmp">>
    end.

app_file_base_dir() ->
    case os:getenv("NODE_STARTUP_FILE_PATH", "undefined") of
        "undefined" -> current_dir();
        Dir -> Dir
    end.

app_filename(App) ->
    list_to_binary([kz_term:to_binary(App), ".json"]).

app_full_filename(App) ->
    filename:join([app_file_base_dir(), app_filename(App)]).

app_file(App) ->
    File = app_full_filename(App),
    case filelib:is_regular(File) of
        'true' -> File;
        'false' -> 'undefined'
    end.

persisted_app_file_key(App) ->
    kz_term:to_atom(list_to_binary(["app_settings_", kz_term:to_binary(App)]), 'true').

persisted_app_file(App) ->
    persistent_term:get(persisted_app_file_key(App), 'undefined').

set_persisted_app_file(App, JObj) ->
    persistent_term:put(persisted_app_file_key(App), JObj).

decode_app_file(App, Bin) ->
    JObj = kz_json:decode(Bin, [{'default', 'undefined'}]),
    decode_app_file_result(App, JObj).

decode_app_file_result(_App, 'undefined') -> 'undefined';
decode_app_file_result(App, JObj) ->
    set_persisted_app_file(App, JObj),
    JObj.

load_app_file(_App, 'undefined') -> 'undefined';
load_app_file(App, Filename) ->
    case file:read_file(Filename) of
        {'error', Reason} ->
            lager:warning("error ~s opening file ~s", [kz_term:to_binary(Reason), Filename]),
            'undefined';
        {'ok', Bin} ->
            decode_app_file(App, Bin)
    end.

app_file_json(App) ->
    case persisted_app_file(App) of
        'undefined' -> load_app_file(App, app_file(App));
        JObj -> JObj
    end.

from_app_file(App, Key) ->
    case app_file_json(App) of
        'undefined' -> from_os_env(App, Key);
        JObj -> kz_json:get_value(Key, JObj)
    end.

env_key(App, Keys) ->
    Key = kz_binary:join([kz_term:to_binary(App) | Keys], <<"_">>),
    kz_term:to_list(binary:replace(Key, [<<"-">>, <<".">>], <<"_">>, ['global'])).

from_os_env(App, Keys) ->
    case os:getenv(env_key(App, Keys), "undefined") of
        "undefined" -> 'undefined';
        Value -> {'ok', kz_term:to_binary(Value)}
    end.

get_value(Value, []) -> {'ok', Value};
get_value([{_, _} | _] = Value, [Key | Keys]) ->
    case props:get_value(Key, Value) of
        'undefined' -> 'undefined';
        V -> get_value(V, Keys)
    end;
get_value(_NotList, _) -> 'undefined'.
