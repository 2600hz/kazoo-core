%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc json patch
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_json_patch).

-export([patch/4
        ,patch_lexer/1
        ,patch_parser/1
        ]).

-type op() :: 'add' | 'replace' | 'remove'.

%% ====================================================================
%% API functions
%% ====================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec patch_lexer(binary()) -> undefined | list().
patch_lexer(Expr) ->
    case kz_json_query_lexer:string(kz_term:to_list(Expr)) of
        {ok, Tokens, _} -> Tokens;
        _ -> undefined
    end.

-spec patch_parser(list()) -> undefined | tuple().
patch_parser(Tokens) ->
    case kz_json_patch_parser:parse(Tokens) of
        {ok, Patch} -> Patch;
        _ -> undefined
    end.

-spec patch(kz_json:object(), op(), any(), any()) -> kz_json:object().
patch(JObj, _Op, undefined, _Value) -> JObj;
patch(JObj, Op, Expr, Value)
  when is_binary(Expr);
       is_list(Expr) ->
    case patch_lexer(Expr) of
        undefined -> JObj;
        Tokens ->
            case patch_parser(Tokens) of
                undefined -> JObj;
                Patch -> patch(JObj, Op, Patch, Value)
            end
    end;
patch(JObj, Op, {'patch', Condition}, Value) ->
    {_, Keys} = keys(JObj, Condition, {[], []}),
    apply_patch(JObj, Op, Keys, Value).

%% ====================================================================
%% Internal functions
%% ====================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
apply_patch(JObj, add, Keys, Value)
  when is_list(Keys) ->
    lists:foldl(fun(K, J) -> patch_add(K, J, Value) end, JObj, Keys);

apply_patch(JObj, replace, Keys, Value)
  when is_list(Keys) ->
    lists:foldl(fun(K, J) -> kz_json:set_value(K, Value, J, #{deep => true}) end, JObj, Keys);

apply_patch(JObj, remove, Keys, _Value)
  when is_list(Keys) ->
    kz_json:delete_keys(Keys, JObj).


patch_add(K, JObj, Value) ->
    case  kz_json:get_value(K, JObj, null) of
        null ->
            kz_json:set_value(K, Value, JObj, #{deep => true});
        List when is_list(List);
                  is_list(Value) ->
            kz_json:set_value(K, List ++ Value, JObj, #{deep => true});
        List when is_list(List) ->
            kz_json:set_value(K, List ++ [Value], JObj, #{deep => true});
        Value ->
            JObj;
        _Else ->
            lager:notice("not adding ~p to ~s because of existing value ~p", [Value, create_path(K), _Else]),
            JObj
    end.

keys(_JObj, {'key', Key}, {KCurrent, Keys}) ->
    ToAdd = KCurrent ++ Key,
    {KCurrent, Keys ++ [ToAdd]};

keys(JObj, {'path', {key, Key}, Cond}, {KCurrent, Keys}) ->
    Items = kz_json:get_list_value(KCurrent ++ Key, JObj, []),
    Size = length(Items),
    NewKeys = [NKeys || {_, NKeys} <- [ keys(lists:nth(Idx, Items), Cond, {KCurrent ++ Key ++ [Idx], []}) || Idx <- lists:seq(1, Size)]],
    {KCurrent, Keys ++ NewKeys};

keys(JObj, {'path', {path, _, _} = Step, {key, _} = Key}, {KCurrent, Keys}) ->
    {_, NewKeys} = keys(JObj, Step, {KCurrent, []}),
    PKeys1 = [PKey || {_, PKeys} <- [keys(JObj, Key, {NewKey, []}) || NewKey <- NewKeys],
                     PKey <- PKeys
            ],
    {KCurrent,  Keys ++ PKeys1};
keys(JObj, {'cond', _, _} = Cond, {KCurrent, Keys} = Acc) ->
    case kz_json_query:eval(JObj, Cond) of
        true ->
            {KCurrent, Keys ++ KCurrent};
        false -> Acc
    end;
keys(JObj, {'cond', _, _, _} = Cond, {KCurrent, Keys} = Acc) ->
    case kz_json_query:eval(JObj, Cond) of
        true ->
            {KCurrent, Keys ++ KCurrent};
        false -> Acc
    end;
keys(JObj, _Expr, _Value) -> JObj.


create_path(Key)
  when is_binary(Key) ->
    Key;
create_path(Keys)
  when is_list(Keys) ->
    kz_binary:join([Bin || Key <- Keys, Bin <- [kz_term:to_binary(Key)]], <<".">>).
