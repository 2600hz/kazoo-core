%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
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
    ?LET(Proplist, flat_proplist(), ensure_first_keys_are_binary(Proplist)).

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
utf8_json_string() ->
    ?LET(Bin, json_string(), ensure_utf8(Bin)).

%%------------------------------------------------------------------------------
%% @doc Replace invalid UTF-8 strings with valid UTF-8 strings in a JSON term.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_utf8(kz_json:json_term()) -> kz_json:json_term() | proper_types:type().
ensure_utf8(Bin) when is_binary(Bin) ->
    case unicode:characters_to_binary(Bin) of
        Bin -> Bin;
        _ -> ?LET(Str, string(), unicode:characters_to_binary(Str))
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
%% @doc Ensure that the first key in each proplist path is a binary.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_first_keys_are_binary(flat_proplist()) -> flat_proplist().
ensure_first_keys_are_binary(Proplist) ->
    [{ensure_first_key_is_binary(Path), V} || {Path, V} <- Proplist].

%%------------------------------------------------------------------------------
%% @doc Ensure that the first key in the list is a binary.
%% @end
%%------------------------------------------------------------------------------
-spec ensure_first_key_is_binary(path()) -> path().
ensure_first_key_is_binary([]) ->
    [];
ensure_first_key_is_binary([K|T]) ->
    [kz_term:to_binary(K) | T].
