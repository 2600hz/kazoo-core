%%%-----------------------------------------------------------------------------
%%% @doc Often times it is useful to try a bunch of operations on a list of
%%% data, some of which whill fail and some which will succeed. This module
%%% helps formalize that pattern.
%%%
%%% Use this if:
%%% * successes and failures do not depend or effect each other
%%% * the list of data is (relatively) proper; ie, it contains only one type.
%%% * order of success and failures does not matter.
%%%
%%% For times where one is checking multiple sources using a single input list,
%%% and those sources may differ on what is a success or error, use an okko of
%%% type `okko({KeyType, ErrorType}, {KeyType, SuccessType})' for each source,
%%% then make use of the `merge_keyed/2' function.
%%% @end
%%%-----------------------------------------------------------------------------

-module(kz_okko).

-type okko(Err, Ok) :: #{ 'ok' := [ Ok ], 'ko' := [ Err ]}.
-type conflict_resolver(Key, Err, Ok) :: fun((Key, kz_result:result(Err, Ok), kz_result:result(Err, Ok)) -> kz_result:result(Err, Ok)).
-type filtermap(Input, Output) :: fun((Input) -> boolean() | {'true', Output}).

-export_type(
   [okko/2
   ,conflict_resolver/3
   ,filtermap/2
   ]).

-export(
   [foldl/2
   ,foldl_async/2
   ,merge/1
   ,merge_keyed/2
   ,build_conflict_resolver/1
   ,empty_okko/0
   ,filtermap_oks/2
   ,filtermap_kos/2
   ,filtermap_both/3
   ,to_results/1
   ,from_results/1
   ]).

%%------------------------------------------------------------------------------
%% @doc Take an okko and turn it into a list of results.
%% @end
%%------------------------------------------------------------------------------
-spec to_results(okko(Err, Ok)) -> [ kz_result:result(Err, Ok) ].
to_results(#{'ok' := Oks, 'ko' := Kos}) ->
    ResultOks = lists:map(fun(E) -> {'ok', E} end, Oks),
    ResultErrs = lists:map(fun(E) -> {'error', E} end, Kos),
    ResultOks ++ ResultErrs.

%%------------------------------------------------------------------------------
%% @doc Take a list of results and turn it into an okko.
%% @end
%%------------------------------------------------------------------------------
-spec from_results([kz_result:result(Err, Ok)]) -> okko(Err, Ok).
from_results(Results) ->
    FoldFun = fun(Result) -> Result end,
    foldl(FoldFun, Results).

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
%% @doc Makes the fold fun for the lists:foldl/3 above.
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
            #{'ko' := Kos} = Okko,
            Okko#{'ko' => [{'crashed', Crash} | Kos]}
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
            Okko#{'ok' => [ Result | Oks]};
        {'$okko_result', Child, {'error', Result}} ->
            Okko#{'kos' => [ {'finished', Result} | Kos ]}
    after
        0 ->
            Okko#{'kos' => [ {'crashed', 'no_response'} | Kos] }
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
    #{'ok' := AOks, 'ko' := AKos} = OkkoA,
    #{'ok' := BOks, 'ko' := BKos} = OkkoB,
    #{'ok' => AOks ++ BOks, 'ko' => AKos ++ BKos}.

%%------------------------------------------------------------------------------
%% @doc Creates an empty okko, rather than needing to type out and remmeber the
%% structure. Using this also means if the internal structure is changed someday,
%% code updates are easier.
%% @end
%%------------------------------------------------------------------------------
-spec empty_okko() -> okko(_, _).
empty_okko() ->
    #{'ok' => [], 'ko' => []}.

%%------------------------------------------------------------------------------
%% @doc Filter and update the ok values for the okko based on the given function.
%% Essentially this is the same as destructuring the okko, do `lists:filtermap/2'
%% on just the 'ok' property, and building it back up. But why do all that when
%% you can have this function do it for you?
%% @end
%%------------------------------------------------------------------------------
-spec filtermap_oks(okko(Err, Ok), filtermap(Ok, NewOk)) -> okko(Err, NewOk).
filtermap_oks(#{'ok' := Oks, 'ko' := Kos}, Filtermap) ->
    #{'ok' => lists:filtermap(Filtermap, Oks), 'ko' => Kos}.

%%------------------------------------------------------------------------------
%% @doc Filter and update the kos values for the okko based on the given function.
%% @end
%%------------------------------------------------------------------------------
-spec filtermap_kos(okko(Err, Ok), filtermap(Err, NewErr)) -> okko(NewErr, Ok).
filtermap_kos(#{ 'ok' := Oks, 'ko' := Kos}, Filtermap) ->
    #{'ok' => Oks, 'ko' => lists:filtermap(Filtermap, Kos)}.

%%------------------------------------------------------------------------------
%% @doc Filter and update both the kos and oks for the okko based on the given
%% functions. Because the types of the 'oks' and 'kos' can differ, we do not
%% assume you can use the same function for both. Nothing is stopping you from
%% doing so, of couse.
%%
%% Note: the error filtermap is first, just like the type definitions have the
%% error first.
%% @end
%%------------------------------------------------------------------------------
-spec filtermap_both(okko(Err, Ok), filtermap(Err, NewErr), filtermap(Ok, NewOk)) -> okko(NewErr, NewOk).
filtermap_both(#{ 'ok' := Oks, 'ko' := Kos}, ErrFiltermap, OkFiltermap) ->
    #{'ok' => lists:filtermap(OkFiltermap, Oks), 'ko' => lists:filtermap(ErrFiltermap, Kos)}.

%%------------------------------------------------------------------------------
%% @doc Take many okko's that have keyed values and merge them down into one.
%% The second argument is a function that determines what to do on key
%% collisions.
%%
%% The ok and ko lists are not checked for duplicates, they are simply sorted
%% to make the check for key collisions easier. While the default conflict
%% resolver will catch duplicates between okko's, it will not catch them if the
%% duplicates are within the same okko.
%%
%% This is useful if we're doing checks on a set of data against multiple
%% systems, and each system may report a different set of successes for a given
%% input.
%%
%% For an easy way to build up a conflict resolver, use
%% `build_conflict_resolver/1'.
%% @end
%%------------------------------------------------------------------------------
-spec merge_keyed([ okko({Key, Error}, {Key, Ok}) ], conflict_resolver(Key, Error, Ok)) -> okko({Key, Error}, {Key, Ok}).
merge_keyed(Okkos, MergeFun) ->
    lists:foldl(fun(NewOkko, OldOkko) ->
                        merge_keyed(OldOkko, NewOkko, MergeFun)
                end, empty_okko(), Okkos).


%%------------------------------------------------------------------------------
%% @doc What actually does the mergeing. The code is kinda dense, but here it is
%% in a nut-shell:
%% * Turn both okko's into a proplist. The value is a result based on if the
%%   value was on the ok or ko side of the okko.
%% * Sort the proplists to make comparisons easier.
%% * Using the conflict resolver function to break ties, merge both sorted key
%%   lists down into a single sorted keylist.
%% * Turn that sorted keylist back into an okko.
%% @end.
%%------------------------------------------------------------------------------
-spec merge_keyed(okko({Key, Error}, {Key, Ok}), okko({Key, Error}, {Key, Ok}), conflict_resolver(Key, Error, Ok)) -> okko({Key, Error}, {Key, Ok}).
merge_keyed(OldOkko, NewOkko, ConflictResolver) ->
    TagOks = fun({Key, Value}) ->
                     {'true', {Key, {'ok', Value}}}
             end,
    TagErrors = fun({Key, Error}) ->
                        {'true', {Key, {'error', Error}}}
                end,
    OldOkkoTagged = filtermap_both(OldOkko, TagErrors, TagOks),
    NewOkkoTagged = filtermap_both(NewOkko, TagErrors, TagOks),
    #{'ok' := OldOks, 'ko' := OldKos} = OldOkkoTagged,
    #{'ok' := NewOks, 'ko' := NewKos} = NewOkkoTagged,
    OldValues = lists:sort(OldOks ++ OldKos),
    NewValues = lists:sort(NewOks ++ NewKos),
    MergedList = perform_merge(OldValues, NewValues, ConflictResolver),
    foldl(fun({Key, {ResultTag, Value}}) -> {ResultTag, {Key, Value}} end, MergedList).

%%------------------------------------------------------------------------------
%% @doc Given two proplists and a conflict resolver, merge the proplists to one
%% avoiding duplicate keys between the two lists. Duplicate keys within the
%% same list will end up getting kept one way or the other.
%% @end.
%%------------------------------------------------------------------------------
-spec perform_merge([ {Key, kz_result:result(Err, Ok)} ], [ {Key, kz_result:result(Err, Ok)} ], conflict_resolver(Key, Err, Ok)) -> [{Key, kz_result:result(Err, Ok)}].
perform_merge(OldValues, NewValues, MergeFun) ->
    perform_merge(OldValues, NewValues, MergeFun, []).


%%------------------------------------------------------------------------------
%% @doc We're using a recursive function because we don't know when we'll be
%% able to stop based on a singluar list.
%% @end
%%------------------------------------------------------------------------------
-spec perform_merge([{Key, kz_result:result(Err, Ok)}], [{Key, kz_result:result(Err, Ok)}], conflict_resolver(Key, Err, Ok), [ {Key, kz_result:result(Err, Ok)}]) -> [{Key, kz_result:result(Err, Ok)}].
perform_merge(OldValues, NewValues, _MergeFun, Accumulator) when OldValues =:= []; NewValues =:= [] ->
    OldValues ++ NewValues ++ Accumulator;
perform_merge([Head | OldTail], [Head | NewTail], MergeFun, Accumulator) ->
    perform_merge(OldTail, NewTail, MergeFun, [Head | Accumulator]);
perform_merge([{Key, {OldResultTag, OldValue}} | OldTail], [{Key, {NewResultTag, NewValue}} | NewTail], MergeFun, Accumulator) ->
    KeepResult = MergeFun(Key, {OldResultTag, OldValue}, {NewResultTag, NewValue}),
    Keep = {Key, KeepResult},
    NewAccumulator = [Keep | Accumulator],
    perform_merge(OldTail, NewTail, MergeFun, NewAccumulator);
perform_merge([{OldKey, _} = Keep | OldTail], [{NewKey, _} | _] = NewTail, MergeFun, Accumulator) when OldKey < NewKey ->
    perform_merge(OldTail, NewTail, MergeFun, [Keep | Accumulator]);
perform_merge([{OldKey, _} | _] = OldTail, [{NewKey, _} = Keep | NewTail], MergeFun, Accumulator) when NewKey < OldKey ->
    perform_merge(OldTail, NewTail, MergeFun, [Keep | Accumulator]).


%%------------------------------------------------------------------------------
%% @doc Rather than needing to write a function for merge_keyed/2 everytime, you
%% can have this function make it for you.
%%
%% * {both_ok, keep | update} : if the key is okay for both okkos, `keep' the
%%   existing value, or `update' to the new one.
%% * {both_error, keep | update} If the key is an error for both okkos, `keep'
%%   the existing error, or `update' to the new one.
%% * {differ, promote | demote | keep | update} : IF the key is okay for one
%%    okko, but an error for the other, either `promote' the ok side discarding
%%   the error;, `demote' the ok side, keeping the error; `keep' the existing
%%   result be it ok or error; `udpate' to the new result, be it ok or error.
%%
%% The default is to always update.
%% @end
%%------------------------------------------------------------------------------
-type both_ok_action() :: {'both_ok', 'keep' | 'update'}.
-type both_error_action() :: {'both_error', 'keep' | 'update'}.
-type differ_action() :: {'differ', 'promote' | 'demote' | 'keep' | 'update'}.
-type action() :: both_ok_action() | both_error_action() | differ_action().
-spec build_conflict_resolver([ action() ]) -> fun((_, kz_result:result(Error, Ok), kz_result:result(Error, Ok)) -> kz_result:result(Error, Ok)).
build_conflict_resolver(GivenOptionsList) ->
    DefaultActions = #{'both_ok' => 'update', 'both_error' => 'update', 'differ' => 'update'},
    GivenOptions = maps:from_list(GivenOptionsList),
    Options = maps:merge(DefaultActions, GivenOptions),
    fun(_Key, OldResult, NewResult) ->
            resolve_conflict(OldResult, NewResult, Options)
    end.

%%------------------------------------------------------------------------------
%% @doc Resolve a conflict between two results based on a map of options.
%% @end.
%%------------------------------------------------------------------------------
-type resolver_map() ::
        #{'both_ok' := 'keep' | 'update'
         ,'both_error' := 'keep' | 'update'
         ,'differ' := 'keep' | 'update' | 'promote' | 'demote'
         }.
-spec resolve_conflict(kz_result:result(Err, Ok), kz_result:result(Err, Ok), resolver_map()) -> kz_result:result(Err, Ok).
resolve_conflict({'ok', _} = Keep, {'ok', _}, #{'both_ok' := 'keep'}) ->
    Keep;
resolve_conflict({'ok', _}, {'ok', _} = Keep, #{'both_ok' := 'update'}) ->
    Keep;
resolve_conflict({'error', _} = Keep, {'error', _}, #{'both_error' := 'keep'}) ->
    Keep;
resolve_conflict({'error', _}, {'error', _} = Keep, #{'both_error' := 'update'}) ->
    Keep;
resolve_conflict(Keep, _, #{'differ' := 'keep'}) ->
    Keep;
resolve_conflict(_, Keep, #{'differ' := 'update'}) ->
    Keep;
resolve_conflict({'ok', _} = Keep, {'error', _}, #{'differ' := 'promote'}) ->
    Keep;
resolve_conflict({'ok', _}, {'error', _} = Keep, #{'differ' := 'demote'}) ->
    Keep;
resolve_conflict({'error', _}, {'ok', _} = Keep, #{'differ' := 'promote'}) ->
    Keep;
resolve_conflict({'error', _} = Keep, {'ok', _}, #{'differ' := 'demote'}) ->
    Keep.
