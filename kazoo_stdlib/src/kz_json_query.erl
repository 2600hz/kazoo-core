%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc json query
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_json_query).

-export([query/1
        ,eval/2
        ]).

%% ====================================================================
%% API functions
%% ====================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec query(map()) -> {ok | error, any()}.
query(Query)
  when is_map(Query) ->
    Funs = [fun lexer/1
           ,fun parser/1
           ,fun collect/1
           ,fun filter/1
           ,fun scope/1
           ,fun transformer/1
           ,fun transform/1
           ,fun run/1
           ,fun patch/1
           ,fun action/1
           ,fun output/1
           ],
    query_exec(Funs, Query).

-spec eval(kz_json:object(), undefined | tuple()) -> boolean().
eval(_JObj, undefined) ->
    true;
eval(JObj, {'query', Condition}) ->
    eval(JObj, Condition);
eval(JObj, {'cond', 'not', Expr}) ->
    not eval(JObj, Expr);
eval(JObj, {'cond', 'path', Key, Cond}) ->
    Items = kz_json:get_list_value(Key, JObj, []),
    lists:any(fun(Item) -> eval(Item, Cond) end, Items);
eval(JObj, {'cond', 'any', Conditions}) ->
    lists:any(fun(Condition) -> eval(JObj, Condition) end, Conditions);
eval(JObj, {'cond', 'all', Conditions}) ->
    lists:all(fun(Condition) -> eval(JObj, Condition) end, Conditions);
eval(JObj, {'cond', 'exists', {key, Key}}) ->
    kz_json:is_defined(Key, JObj);
eval(JObj, {'cond', Operator, {key, Key}, {_Type, Value}}) ->
    operator(Operator, kz_json:get_value(Key, JObj, null), Value).

%% ====================================================================
%% Internal functions
%% ====================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
query_exec([], #{error := Error}) -> {error, Error};
query_exec([], #{output := Output}) -> {ok, Output};
query_exec([], #{result := Results}) -> {ok, Results};
query_exec([], #{}) -> {ok, []};
query_exec([Fun | Funs], Query) ->
    case Fun(Query) of
        #{error := Error}  -> {error, Error};
        Next when is_map(Next) -> query_exec(Funs, Next);
        _Next -> {error, unknown}
    end.

lexer(#{query := Query} = Map) ->
    case kz_json_query_lexer:string(kz_term:to_list(Query)) of
        {ok, Tokens, _} -> Map#{lex => Tokens};
        _ -> {error, <<"invalid query">>}
    end;
lexer(Map) -> Map.

parser(#{lex := Tokens} = Map) ->
    case kz_json_query_parser:parse(Tokens) of
        {error, {_, kz_json_query_parser, Error}} -> {error, list_to_binary(Error)};
        {ok, AST} -> Map#{ast => AST}
    end;
parser(Map) -> Map#{ast => undefined}.

collect(#{collection := _} = Map) -> Map;
collect(#{collector := #{'fun' := Fun, params := Params}} = Map) ->
    try erlang:apply(Fun, Params) of
        {error, Error} -> Map#{error => Error};
        {ok, Collection} -> Map#{collection => Collection}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
collect(#{collector := #{'fun' := _Fun} = Collector} = Map) ->
    collect(Map#{collector => Collector#{params => []}});
collect(Map) ->
    Map#{error => no_collection_or_collector}.

filter(#{filter := #{'fun' := Fun, params := Params}
        ,collection := Collection
        } = Map) ->
    try erlang:apply(Fun, [Collection | Params]) of
        {error, Error} -> Map#{error => Error};
        {ok, Collection} -> Map#{collection => Collection}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
filter(#{filter := #{'fun' := Fun}
        ,collection := Collection
        } = Map) ->
    try erlang:apply(Fun, [Collection]) of
        {error, Error} -> Map#{error => Error};
        {ok, Collection} -> Map#{collection => Collection}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
filter(Map) -> Map.

transformer(#{transformer := #{'fun' := Fun, params := Params}
             ,collection := Collection
             } = Map) ->
    try erlang:apply(Fun, [Collection | Params]) of
        {error, Error} -> Map#{error => Error};
        {ok, Collection} -> Map#{collection => Collection}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
transformer(#{transformer := #{'fun' := Fun}
             ,collection := Collection
             } = Map) ->
    try erlang:apply(Fun, [Collection]) of
        {error, Error} -> Map#{error => Error};
        {ok, Collection} -> Map#{collection => Collection}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
transformer(Map) -> Map.

transform(#{transform := #{'fun' := Fun, params := Params}
           ,collection := Collection
           } = Map) ->
    try
        Map#{collection => [erlang:apply(Fun, [JObj | Params]) || JObj <- Collection]}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
transform(#{transform := #{'fun' := Fun}
           ,collection := Collection
           } = Map) ->
    try
        Map#{collection => [Fun(JObj) || JObj <- Collection]}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
transform(Map) -> Map.

scope(#{scope := []} = Map) -> Map;
scope(#{scope := Scope
       ,collection := Collection
       } = Map) ->
    Map#{collection => [Scoped || JObj <- Collection, (Scoped = kz_json:get_json_value(Scope, JObj)) =/= undefined]};
scope(Map) -> Map.

run(#{collection := Collection, ast := AST} = Map) ->
    Map#{result => [JObj || JObj <- Collection, eval(JObj, AST)]};
run(Map) ->
    Map#{result => []}.

patch(#{patch := #{op := Op, path := Path} = Patch
       ,result := Collection
       } = Map) ->
    Value = maps:get(value, Patch, null),
    Scope = case maps:get(scope, Patch, undefined) of
                undefined -> undefined;
                Binary
                  when is_binary(Binary) ->
                    binary:split(Binary,<<".">>, ['global']);
                [Binary | _] = Binaries
                  when is_binary(Binary) ->
                    Binaries;
                [String | _] = Strings
                  when is_list(String) ->
                    [list_to_binary(S) || S <- Strings];
                String
                  when is_list(String) ->
                    binary:split(list_to_binary(String),<<".">>, ['global']);
                _Else -> undefined
            end,
    try
        Results = [begin
                       case Scope of
                           undefined ->
                               case kz_json_patch:patch(JObj, Op, Path, Value) of
                                   JObj -> undefined;
                                   Changed -> Changed
                               end;
                           Scope ->
                               case kz_json:get_json_value(Scope, JObj) of
                                   undefined -> undefined;
                                   Scoped ->
                                       case kz_json_patch:patch(Scoped, Op, Path, Value) of
                                           Scoped -> undefined;
                                           Changed -> kz_json:set_value(Scope, Changed, JObj)
                                       end
                               end
                       end
                   end  || JObj <- Collection],
        Map#{result => [Result || Result <- Results, Result =/= undefined]}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
patch(Map) -> Map.


action(#{action := #{'fun' := Fun, params := Params}
        ,result := Collection
        } = Map) ->
    try
        Map#{result => [erlang:apply(Fun, [JObj | Params]) || JObj <- Collection]}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
action(#{action := #{'fun' := Fun}
        ,result := Collection
        } = Map) ->
    try
        Map#{result => [Fun(JObj) || JObj <- Collection]}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
action(Map) -> Map.

output(#{output := #{'fun' := Fun, params := Params}
        ,result := Collection
        } = Map) ->
    try
        Map#{output => [erlang:apply(Fun, [JObj | Params]) || JObj <- Collection]}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
output(#{output := #{'fun' := Fun}
        ,result := Collection
        } = Map) ->
    try
        Map#{output => [Fun(JObj) || JObj <- Collection]}
    catch
        _Exc:_Err:_ST ->
            Map#{error => _Err}
    end;
output(Map) -> Map.

operator('equal', V1, V2) ->
    V1 =:= V2;
operator('not_equal', V1, V2) ->
    V1 =/= V2;
operator('contains', V1, V2) ->
    binary:match(kz_term:to_binary(V1), kz_term:to_binary(V2)) =/= 'nomatch';
operator('starts_with', V1, V2) ->
    V1 =/= V2;
operator('ends_with', V1, V2) ->
    V1 =/= V2;
operator('greater_than', V1, V2) ->
    V1 > V2;
operator('greater_than_or_equal', V1, V2) ->
    V1 >= V2;
operator('less_than', V1, V2) ->
    V1 < V2;
operator('less_than_or_equal', V1, V2) ->
    V1 =< V2.
