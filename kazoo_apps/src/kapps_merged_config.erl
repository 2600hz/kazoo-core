%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2023, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_merged_config).

-export([get_ne_binary/3, get_ne_binary/4
        ,get_ne_binaries/3, get_ne_binaries/4
        ,get_pos_integer/3, get_pos_integer/4
        ,get_atom/3, get_atom/4
        ,get_json/3, get_json/4
        ,get_boolean/3, get_boolean/4
        ]).

-type config_key() :: kz_json:path() | kz_json:key().

-spec get_atom(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key()) -> atom().
get_atom(AccountId, Category, Key) ->
    get_atom(AccountId, Category, Key, 'undefined').

-spec get_atom(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> atom() | Default.
get_atom(AccountId, Category, Key, Default) ->
    kz_term:to_atom(get(AccountId, Category, Key, Default), 'true').

-spec get_boolean(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key()) -> kz_term:api_boolean().
get_boolean(AccountId, Category, Key) ->
    get_boolean(AccountId, Category, Key, 'undefined').

-spec get_boolean(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> boolean() | Default.
get_boolean(AccountId, Category, Key, Default) ->
    case get(AccountId, Category, Key, ?MODULE) of
        ?MODULE -> Default;
        Value -> kz_term:to_boolean(Value)
    end.

-spec get_ne_binary(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key()) -> kz_term:api_ne_binary().
get_ne_binary(AccountId, Category, Path) ->
    get_ne_binary(AccountId, Category, Path, 'undefined').

-spec get_ne_binary(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> kz_term:ne_binary() | Default.
get_ne_binary(AccountId, Category, Path, Default) ->
    Value = get(AccountId, Category, Path, Default),
    case kz_term:is_empty(Value) of
        'true' -> Default;
        'false' -> kz_term:to_binary(Value)
    end.

-spec get_ne_binaries(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key()) -> kz_term:ne_binaries().
get_ne_binaries(AccountId, Category, Path) ->
    get_ne_binaries(AccountId, Category, Path, 'undefined').

-spec get_ne_binaries(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> kz_term:ne_binaries() | Default.
get_ne_binaries(AccountId, Category, Path, Default) ->
    Values = get(AccountId, Category, Path, Default),
    case kz_term:is_ne_binaries(Values) of
        'false' -> Default;
        'true' -> Values
    end.

-spec get_pos_integer(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key()) -> 'undefined' | pos_integer().
get_pos_integer(AccountId, Category, Path) ->
    get_pos_integer(AccountId, Category, Path, 'undefined').

-spec get_pos_integer(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> pos_integer() | Default.
get_pos_integer(AccountId, Category, Path, Default) ->
    to_pos_integer(get(AccountId, Category, Path, Default), Default).

-spec to_pos_integer(any(), Default) -> pos_integer() | Default.
to_pos_integer(Value, Default) ->
    try kz_term:to_integer(Value) of
        PosInteger when is_integer(Value), Value > 0 ->
            PosInteger;
        _ -> Default
    catch
        _:_ -> Default
    end.

-spec get_json(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key()) -> kz_term:api_object().
get_json(AccountId, Category, Key) ->
    get_json(AccountId, Category, Key, 'undefined').

-spec get_json(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> kz_json:object() | Default.
get_json(AccountId, Category, Key, Default) ->
    V = get(AccountId, Category, Key, Default),
    as_json_value(V, Default).

-spec as_json_value(any(), kz_term:api_object()) -> kz_term:api_object().
as_json_value('undefined', Default) -> Default;
as_json_value(V, Default) ->
    case kz_json:is_json_object(V) of
        'true' -> V;
        'false' -> Default
    end.

-spec get(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> kz_json:json_term() | Default.
get(AccountId, Category, Key, Default) ->
    get_merged(AccountId, Category, Key, Default).


-spec load_config(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', kz_json:object()} | kazoo_data:data_error().
load_config(AccountId, Category) ->
    DocId = kapps_config_util:account_doc_id(Category),
    kz_datamgr:open_cache_doc(AccountId, DocId, [{'cache_failures', ['not_found']}]).

%%==============================================================================
%% Internal functions
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec get_merged(kz_term:api_ne_binary(), kz_term:ne_binary(), config_key(), Default) -> Default | kz_json:json_term().
get_merged('undefined', Category, Key, Default) ->
    get_merged_default(Category, key(Key), Default);
get_merged(AccountId, Category, Key, Default) ->
    KeyList = key(Key),
    Value = get_merged_default(Category, KeyList, Default),
    Accounts = [AccountId | lists:reverse(kzd_accounts:tree(AccountId))],
    Keys = [{Account, Category, KeyList} || Account <- Accounts],
    lists:foldr(fun get_merged_fold/2, Value, Keys).

-spec get_merged_default(kz_term:ne_binary(), config_key(), Default) -> Default | kz_json:json_term().
get_merged_default(Category, Key, Default) ->
    case kapps_config:get(Category, Key) of
        'undefined' -> Default;
        Value -> Value
    end.

get_merged_fold({AccountId, Category, Key}, Acc) ->
    case load_config(AccountId, Category) of
        {'ok', JObj} -> get_merged_value(Key, JObj, Acc);
        _ -> Acc
    end.

-define(is_json(J), kz_json:is_json_object(J)).

get_merged_value(Key, JObj, Acc) ->
    case kz_json:get_ne_value(Key, JObj) of
        'undefined' -> Acc;
        Value when Acc =:= 'undefined' -> Value;
        Value -> merged_value(Value, Acc, ?is_json(Value), ?is_json(Acc))
    end.

merged_value(Value, Acc, 'true', 'true') ->
    kz_json:merge(Acc, Value);
merged_value(Value, _Acc, _, _) -> Value.

-spec key(term()) -> [binary()].
key(Key) when is_binary(Key) ->
    case erlang:get('is_sup_call') of
        'true' -> binary:split(kz_term:to_binary(Key), <<".">>, ['global']);
        _ -> [kz_term:to_binary(Key)]
    end;
key(Key) -> Key.
