%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% Fetches config values from the Erlang application's environment
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_app_config).

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

-compile({no_auto_import, [get/1]}).

-type app() :: atom().
-type app_key() :: binary() | kz_term:binaries().

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
        {'ok', Value} -> kz_term:to_atom(Value, true)
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

-spec get(app(), app_key()) -> 'undefined' | {'ok', any()}.
get(App, <<_/binary>>=Key) ->
    get(App, binary:split(Key, <<".">>, ['global']));
get(App, Keys) ->
    case kz_term:is_ne_binaries(Keys) of
        'true' -> fetch_value(App, Keys);
        'false' -> 'undefined'
    end.

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

-spec fetch_value(app(), app_key()) -> 'undefined' | {'ok', term()}.
fetch_value(App, Key) ->
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

get_env(App, [Key | Keys]) ->
    AppAtom = kz_term:to_atom(App),
    case application:get_env(AppAtom, kz_term:to_atom(Key, 'true')) of
        'undefined' -> 'undefined';
        {'ok', Value} -> get_value(Value, Keys)
    end.

get_value(Value, []) -> {'ok', Value};
get_value([{_, _} | _] = Value, [Key | Keys]) ->
    case props:get_value(Key, Value) of
        'undefined' -> 'undefined';
        V -> get_value(V, Keys)
    end;
get_value(_NotList, _) -> 'undefined'.
