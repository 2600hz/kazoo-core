%%%-----------------------------------------------------------------------------
%%% @doc We may not have all the coolness monads, but we can emulate some of it.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_result).

-type result(Err, Ok) :: {'ok', Ok} | {'error', Err}.
-export_type([result/2]).

-export([flow/2
        ,and_then/1
        ,on_error/1
        ,map/1
        ,map_error/1
        ,to_maybe/1
        ,from_maybe/2
        ,with_default/2
        ]).


%%------------------------------------------------------------------------------
%% @doc Apply the sequence of result operations to the given result. This is
%% not going to be caught by dialyzer, or if it is, it is wrong. The result
%% flow end type does not need to match the result flow input.
%% @end
%%------------------------------------------------------------------------------
-spec flow(result(Err, Ok), [ fun((result(Err, Ok)) -> result(Err, Ok))]) -> result(Err, Ok).
flow(InitialResult, Operations) ->
    flow_recursive(InitialResult, Operations).

-spec flow_recursive(result(Err, Ok), [ fun((result(Err, Ok)) -> result(Err, Ok))]) -> result(Err, Ok).
flow_recursive(Result, []) ->
    Result;
flow_recursive(Result, [ Operation | Tail]) ->
    NewResult = Operation(Result),
    flow_recursive(NewResult, Tail).

%%------------------------------------------------------------------------------
%% @doc Wrap the given function to accept a result, and only be called if the
%% result is not an error. The inner function is not given the whole result,
%% just the success value if there is one.
%% @end.
%%------------------------------------------------------------------------------
-spec and_then(fun((GoodA) -> result(ErrorB, GoodB))) -> fun((result(ErrorA, GoodA)) -> result(ErrorA, GoodA) | result(ErrorB, GoodB)).
and_then(ToWrap) ->
    fun(Result) ->
            and_then(Result, ToWrap)
    end.

and_then({'error', _} = Result, _WrappedFun) ->
    Result;
and_then({'ok', Success}, WrappedFun) ->
    WrappedFun(Success).

%%------------------------------------------------------------------------------
%% @doc The mirror to `and_then/' for errors.
%% @end.
%%------------------------------------------------------------------------------
-spec on_error(fun((ErrorA) -> result(ErrorB, GoodB))) -> fun((result(ErrorA, GoodA)) -> result(ErrorB, GoodB) | result(ErrorA, GoodA)).
on_error(ToWrap) ->
    fun(Result) ->
            on_error(Result, ToWrap)
    end.

on_error({'ok', _} = Result, _ToWrap) ->
    Result;
on_error({'error', Error}, ToWrap) ->
    ToWrap(Error).

%%------------------------------------------------------------------------------
%% @doc Transform a successful result into another one, otherwise keep the error.
%% @end
%%------------------------------------------------------------------------------
-spec map(fun((GoodA) -> GoodB)) -> fun((result(Error, GoodA)) -> result(Error, GoodB)).
map(MappingFun) ->
    fun(Result) ->
            map(Result, MappingFun)
    end.

map({'ok', Value}, MappingFun) ->
    {'ok', MappingFun(Value)};
map({'error', _} = Result, _MappingFun) ->
    Result.

%%------------------------------------------------------------------------------
%% @doc Transform an error result into another error, otherwise keep the success.
%% @end
%%------------------------------------------------------------------------------
-spec map_error(fun((ErrorA) -> ErrorB)) -> fun((result(ErrorA, GoodA)) -> result(ErrorB, GoodA)).
map_error(MappingFun) ->
    fun(Result) ->
            map_error(Result, MappingFun)
    end.

map_error({'ok', _} = Result, _MappingFun) ->
    Result;
map_error({'error', Error}, MappingFun) ->
    {'error', MappingFun(Error)}.

%%------------------------------------------------------------------------------
%% @doc Take a result and turn it into a 'maybe'.
%% @end
%%------------------------------------------------------------------------------
-spec to_maybe(result(any(), Good)) -> 'undefined' | Good.
to_maybe({'ok', Value}) ->
    Value;
to_maybe({'error', _}) ->
    'undefined'.

%%------------------------------------------------------------------------------
%% @doc Take a 'maybe' and turn it into a result, using the error if the maybe
%% is 'undefined'.
%% @end
%%------------------------------------------------------------------------------
-spec from_maybe(Error, Maybe | 'undefined') -> result(Error, Maybe).
from_maybe('undefined', Error) ->
    {'error', Error};
from_maybe(Value, _Error) ->
    {'ok', Value}.

%%------------------------------------------------------------------------------
%% @doc Sometimes, after all is said and done, you just need a value that is the
%% same type as the good type. This takes a result and the 'default', and does
%% just that. If the result is an error, you get back the default, otherwise it
%% unwraps the ok result.
%% @end
%%------------------------------------------------------------------------------
-spec with_default(result(_, Ok), Ok) -> Ok.
with_default({'ok', Good}, _Default) ->
    Good;
with_default({'error', _Error}, Default) ->
    Default.
