#!/usr/bin/env escript
%%! +A0
%% -*- coding: utf-8 -*-

-mode(compile).

-export([main/1]).

main(_) ->
    ScriptsDir = filename:dirname(escript:script_name()),
    'ok' = file:set_cwd(filename:absname(ScriptsDir ++ "/..")),
    Files = filelib:wildcard("priv/dbs/*/view-index.csv"),
    lists:foreach(fun process_view_index/1, Files).

process_view_index(File) ->
    {'ok', Bin} = file:read_file(File),
    Db = kz_term:to_binary(filename:basename(filename:dirname(File))),
    case binary:split(Bin, <<"\n">>, ['global', 'trim_all']) of
        [] -> 'ok';
        [_Header] -> 'ok';
        [_Header|Lines] ->
            'ok' = file:delete(File),
            process_index_rows(Db, Lines)
    end.

process_index_rows(_Db, []) ->
    'ok';
process_index_rows(Db, [Line|Lines]) ->
    process_index_row(Db, Line),
    process_index_rows(Db, Lines).

process_index_row(Db, Line) ->
    %% extract first column as view name
    {'match', [Design]} = re:run(Line, <<"^([^,]+),">>, [{'capture', [1], 'binary'}]),
    %% capture second column as view options.
    {'match', [OptionsStr]} = re:run(Line, <<"^[^,]+,\s*(.*), [-_.+a-z0-9]+$">>, [{'capture', [1], 'list'}]),
    {'ok', OptTokens, _} = erl_scan:string(OptionsStr++"."),
    {'ok', Options} = erl_parse:parse_term(OptTokens),

    {'match', [OldFile]} = re:run(Line, <<"], ([-_.+a-z0-9]+)$">>, [{capture, [1], binary}]),

    {'ok', UpdatedRow} = kz_fixturedb_util:add_view_to_index(Db, Design, Options),
    {'match', [NewFile]} = re:run(UpdatedRow, <<"], ([-_.+a-z0-9]+)$">>, [{capture, [1], binary}]),

    io:format("updating view file from ~ts to ~ts~n", [OldFile, NewFile]),
    'ok' = file:rename(view_path(Db, OldFile), view_path(Db, NewFile)).

view_path(Db, File) ->
    <<"priv/dbs/", Db/binary, "/views/", File/binary>>.
