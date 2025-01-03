%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_json_generators).

-export([test_object/0
        ,deep_object/0, deep_object/1
        ,valid_flat_proplist/0
        ,path/1

        ,max_depth/1
        ]).

-include_lib("kazoo_stdlib/include/kazoo_json.hrl").
-include_lib("proper/include/proper.hrl").

test_object() ->
    ?LET(JObj, object(), remove_duplicate_keys(JObj)).

remove_duplicate_keys(?JSON_WRAPPER(_)=JObj) ->
    kz_json:expand(kz_json:from_map(kz_json:to_map(kz_json:flatten(JObj)))).

deep_object() ->
    ?SIZED(Nesting, deep_object(Nesting)).

deep_object(Nesting) ->
    ?LET(DeepObject
        ,deep_object(Nesting, {'$call', 'kz_json', 'new', []})
        ,DeepObject
        ).

deep_object(0, JObj) ->
    JObj;
deep_object(Depth, JObj) ->
    deep_object(Depth-1
               ,{'$call', 'kz_json', 'set_value', [path(Depth), freq_value(Depth), JObj]}
               ).

%%------------------------------------------------------------------------------
%% @doc Generate flat proplists that have only binaries for the first key of
%% each path - this is to ensure that the proplist is valid for
%% `kz_json:from_list/1'. Otherwise, the proplist seemingly represents a
%% top-level JSON array, which is unhandled.
%% @end
%%------------------------------------------------------------------------------
-spec valid_flat_proplist() -> proper_types:type().
valid_flat_proplist() ->
    ?LET(Proplist
        ,flat_proplist()
        ,ensure_consistent_path_types(Proplist)
        ).

path(0) ->
    utf8_json_string();
path(Depth) ->
    ?LET(Path
        ,resize(Depth, utf8_json_string())
        ,Path
        ).

freq_value(0) ->
    utf8_non_object_json_term();
freq_value(Depth) ->
    frequency([{90, utf8_non_object_json_term()}
              ,{10, ?LET(JObj, deep_object(Depth-1), JObj)}
              ]).

max_depth(JObj) ->
    Depth = kz_json:foldl(fun(Path, _, Max) ->
                                  case length(Path) of
                                      NewMax when NewMax > Max -> NewMax;
                                      _Len -> Max
                                  end
                          end
                         ,0
                         ,kz_json:flatten(JObj)
                         ),
    Depth.

%%------------------------------------------------------------------------------
%% @doc Generate non-object JSON terms that do not contain invalid UTF-8
%% strings.
%% @end
%%------------------------------------------------------------------------------
-spec utf8_non_object_json_term() -> proper_types:type().
utf8_non_object_json_term() ->
    ?LET(Term, non_object_json_term(), ensure_utf8(Term)).

%%------------------------------------------------------------------------------
%% @doc Generate valid UTF-8 JSON strings.
%% @end
%%------------------------------------------------------------------------------
-spec utf8_json_string() -> proper_types:type().
utf8_json_string() -> proper_unicode:utf8().

%%------------------------------------------------------------------------------
%% @doc Replace invalid UTF-8 strings with valid UTF-8 strings in a JSON term.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_utf8(kz_json:json_term()) -> kz_json:json_term() | proper_types:type().
ensure_utf8(Bin) when is_binary(Bin) ->
    case unicode:characters_to_binary(Bin) of
        Bin -> Bin;
        _ -> utf8_json_string()
    end;
ensure_utf8(List) when is_list(List) ->
    lists:map(fun ensure_utf8/1, List);
ensure_utf8(Term) ->
    case kz_json:is_json_object(Term) of
        'true' -> ensure_jobj_utf8(Term);
        'false' -> Term
    end.

%%------------------------------------------------------------------------------
%% @doc Replace invalid UTF-8 strings with valid UTF-8 strings in a JSON object.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_jobj_utf8(kz_json:object()) -> kz_json:object().
ensure_jobj_utf8(JObj) ->
    kz_json:map(fun(Key, Value) ->
                        {ensure_utf8(Key), ensure_utf8(Value)}
                end
               ,JObj
               ).

%%------------------------------------------------------------------------------
%% @doc Ensure that the paths in a flat proplist are valid for assignment to the
%% object generated from earlier paths in the proplist. This is to ensure that
%% the proplist is valid for `kz_json:from_list/1'. The goal is to restrict the
%% input generation to avoid attempting to get a key from a non-object term or
%% get an index from a non-array term.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_consistent_path_types(flat_proplist()) -> flat_proplist().
ensure_consistent_path_types(Proplist) ->
    {_JObj, Proplist1} = lists:foldl(fun ensure_consistent_path_types/2
                                    ,{kz_json:new(), []}
                                    ,Proplist
                                    ),
    lists:reverse(Proplist1).

-spec ensure_consistent_path_types({path(), flat_json_term()}
                                  ,{object(), flat_proplist()}
                                  ) -> {object(), flat_proplist()}.
ensure_consistent_path_types({Path, Value}, {JObj, Proplist}) ->
    try ensure_types_along_path(Path, JObj) of
        Path1 ->
            JObj1 = kz_json:set_value(Path1, Value, JObj),
            {JObj1, [{Path1, Value} | Proplist]}
    catch
        {'invalid_path', _InvalidPath, _Term} ->
            %% Discard invalid paths
            {JObj, Proplist}
    end.

%%------------------------------------------------------------------------------
%% @doc Ensure that the types along a path are valid for assignment to the
%% provided object. Integer and binary types are coerced when appropriate.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_types_along_path(path(), object()) -> path().
ensure_types_along_path(Path, JObj) ->
    ensure_types_along_path(Path, JObj, []).

-spec ensure_types_along_path(path(), api_json_term(), path()) -> path().
ensure_types_along_path([], _JObj, NewPath) -> NewPath;
ensure_types_along_path(Path, 'undefined', NewPath) ->
    %% Nothing at the target - safe to replace target's value
    NewPath ++ Path;
ensure_types_along_path([Key|KVs], List, NewPath)
  when is_list(List), not is_integer(Key) ->
    %% Replace object key with array index
    Key1 = try kz_term:to_integer(Key) of
               I -> I
           catch
               %% Make up a new index for generated input
               'error':'badarg' -> 1
           end,
    ensure_types_along_path([Key1 | KVs], List, NewPath);
ensure_types_along_path([Key|_KVs]=Path, List, NewPath)
  when is_list(List), Key > length(List) ->
    %% Key is after list end - will append value
    ensure_types_along_path(Path, 'undefined', NewPath);
ensure_types_along_path([Key|KVs], List, NewPath) when is_list(List) ->
    %% Recurse into list
    ensure_types_along_path(KVs, lists:nth(Key, List), NewPath ++ [Key]);
ensure_types_along_path([Key|KVs]=Path, Term, NewPath) ->
    case kz_json:is_json_object(Term) of
        'true' when is_integer(Key) ->
            %% Replace array index with object key
            ensure_types_along_path([kz_term:to_binary(Key) | KVs], Term, NewPath);
        'true' ->
            %% Recurse into object
            V = kz_json:get_value(Key, Term),
            ensure_types_along_path(KVs, V, NewPath ++ [Key]);
        'false' ->
            %% Invalid attempt to "subscript" a non-array/object term
            throw({'invalid_path', Path, Term})
    end.
