%%%-----------------------------------------------------------------------------
%%% @doc Often times it is useful to try a bunch of operations on a list of
%%% data, some of which whill fail and some which will succeed. This module
%%% helps formalize that pattern.
%%%
%%% Use this if:
%%% * successes and failures do not depend or effect each other
%%% * the list of data is (relatively) proper; ie, it contains only one type.
%%% * order of success and failures does not matter.
%%% @end
%%%-----------------------------------------------------------------------------

-module(kz_okko).

-type okko(Err, Ok) :: #{ 'ok' := [ Ok ], 'ko' := [ Err ]}.

-export(
   [foldl/2
   ,foldl_async/2
   ,merge/1
   ]).


%%------------------------------------------------------------------------------
%% @doc Given the operation and list, generate an okko. The operations
%% are performed in sequence in the same process, so if there is a crash, you
%% lose everything.
%% @end
%%------------------------------------------------------------------------------
-spec foldl(fun((Elem) -> kz_result:result(Error, OutElem)), [ Elem ]) -> okko(Error, OutElem).
foldl(FoldFun,Elements) ->
    lists:foldl(basic_fold(FoldFun), empty_okko(), Elements).


%%------------------------------------------------------------------------------
%% @doc It does the thing.
%% @end
%%------------------------------------------------------------------------------
-spec basic_fold( fun((Elem) -> kz_result:result(Error, OutElem))) -> fun((Elem, okko(Error, OutElem)) -> okko(Error, OutElem)).
basic_fold(InnerFun) ->
    fun(Element, Okko) ->
            #{ 'ok' := Oks, 'ko' := Kos} = Okko,
            case InnerFun(Element) of
                {'ok', Term} ->
                    Okko#{ 'ok' => [Term | Oks]};
                {'error', Term} ->
                    Okko#{ 'ko' => [Term | Kos]}
            end
    end.

%%------------------------------------------------------------------------------
%% @doc Like `foldl/2', but spawns a new process for each element. This is
%% useful when the work requires significant processing time. This whill only
%% block as long as the longest call. Furthermore, if a process should crash,
%% this does not crash with it, but gets put in the `ko' list.
%%
%% If your processing function does not terminate, neither will this.
%% @end
%%------------------------------------------------------------------------------
-spec foldl_async(fun((Elem) -> kz_result:result(Error, OutElem)), [ Elem ]) -> okko({'finished', Error} | {'crashed', term()}, OutElem).
foldl_async(FoldFun, Elements) ->
    Parent = self(),
    MapFun = fun(Element) ->
                     make_spawn_fun(FoldFun, Element, Parent)
             end,
    Monitors = lists:map(MapFun, Elements),
    lists:foldl(fun foldl_async_accumulator/2, empty_okko(), Monitors).

%%------------------------------------------------------------------------------
%% @doc Wrap the fold in a spawn that tells the parent.
%% @end
%%------------------------------------------------------------------------------
-spec make_spawn_fun(fun((A) -> kz_result:result(_Err, _B)), A, pid()) -> fun(() -> 'ok').
make_spawn_fun(FoldFun, Element, Parent) ->
    fun() ->
            Result = FoldFun(Element),
            Child = self(),
            Parent ! {'$okko_result', Child, Result},
            'ok'
    end.

%%------------------------------------------------------------------------------
%% @doc Gather ye results.
%% @end
%%------------------------------------------------------------------------------
-spec foldl_async_accumulator({pid(), reference()}, okko(Err, Ok)) -> okko(Err, Ok).
foldl_async_accumulator({Pid, Mon}, Okko) ->
    receive
        {'DOWN', Mon, 'process', Pid, 'normal'} ->
            accumulate_async_result(Pid, Okko);
        {'DOWN', Mon, 'process', Pid, Crash} ->
            #{ 'ko' := Kos} = Okko,
            Okko#{ 'ko' => [{'crashed', Crash} | Kos]}
    end.

%%------------------------------------------------------------------------------
%% @doc gather ye successful (we think) results.
%% @end
%%------------------------------------------------------------------------------
-spec accumulate_async_result(pid(), okko(Err, Ok)) -> okko(Err, Ok).
accumulate_async_result(Child, Okko) ->
    #{ 'ok' := Oks, 'ko' := Kos} = Okko,
    receive
        {'$okko_result', Child, {'ok', Result}} ->
            Okko#{ 'ok' => [ Result | Oks]};
        {'$okko_result', Child, {'error', Result}} ->
            Okko#{ 'kos' => [ {'finished', Result} | Kos ]}
    after
        0 ->
            Okko#{ 'kos' => [ {'crashed', 'no_response'} | Kos] }
    end.

%%------------------------------------------------------------------------------
%% @doc Take a list of `okko`'s and mush them all together. This does no
%% de-duplication of the ok, ko, or okkos at large.
%% @end.
%%------------------------------------------------------------------------------
-spec merge([ okko(Error, Ok) ]) -> okko(Error, Ok).
merge(Okkos) ->
    lists:foldl(fun merge/2, empty_okko(), Okkos).

%%------------------------------------------------------------------------------
%% @doc Take two `okko()''s and mush them together. This is no deduplication
%% done.
%% @end
%%------------------------------------------------------------------------------
-spec merge(okko(Err, Ok), okko(Err, Ok)) -> okko(Err, Ok).
merge(OkkoA, OkkoB) ->
    #{ 'ok' := AOks, 'ko' := AKos} = OkkoA,
    #{ 'ok' := BOks, 'ko' := BKos} = OkkoB,
    #{ 'ok' => AOks ++ BOks, 'ko' => AKos ++ BKos}.

%%------------------------------------------------------------------------------
%% @doc Just so I don't have to type out the structure of an empty okko all the
%% time.
%% @end
%%------------------------------------------------------------------------------
-spec empty_okko() -> okko(_, _).
empty_okko() ->
    #{ 'ok' => [], 'ko' => [] }.
