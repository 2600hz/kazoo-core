%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_log).

-export([change_console_log_level/1
        ,change_error_log_level/1
        ,change_syslog_log_level/1
        ,change_file_log_level/2

        ,change_sink_level/2

        ,log_stacktrace/0, log_stacktrace/1, log_stacktrace/2, log_stacktrace/3
        ,put_callid/1, put_callid/2, get_callid/0, find_callid/1
        ,kz_log_md_clear/0, kz_log_md_put/2
        ,format/2, format/3

        ,print_table/1, print_table/2
        ]).
-export([redactor/1]).

-elvis([{elvis_style, no_debug_call, disable}]).

-ifdef(TEST).
-export([restart_check/0]).
-endif.

-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_amqp/include/kz_api_literals.hrl").

%% From erlang:get_stacktrace()
-type location() :: {'file', file:filename_all()} |
                    {'line', pos_integer()}.
-type stack_item() :: {module(), atom(), arity() | [term()], [location()]}.
-type stacktrace() :: [stack_item()].

-export_type([log_level/0
             ,stack_item/0
             ,stacktrace/0
             ]).

-deprecated({'log_stacktrace', 0, 'next_major_release'}).
-deprecated({'log_stacktrace', 2, 'next_major_release'}).

-define(LOG_LEVELS, ['emergency'
                    ,'alert'
                    ,'critical'
                    ,'error'
                    ,'warning'
                    ,'notice'
                    ,'info'
                    ,'debug'
                    ]).
-type log_level() :: 'emergency'
                   | 'alert'
                   | 'critical'
                   | 'error'
                   | 'warning'
                   | 'notice'
                   | 'info'
                   | 'debug'
                   | kz_term:ne_binary().

-define(LOG(Fmt), begin lager:info(Fmt), io:format(Fmt ++ "~n") end).
-define(LOG(Fmt, Args), begin lager:info(Fmt, Args), io:format(Fmt ++ "~n", Args) end).
-define(REDACTED_REPLACEMENT, "***REDACTED***").

%% @doc Usage: kz_log:change_sink_level(amqp, debug)
%% or sup kz_log change_sink_level amqp debug
-spec change_sink_level(kz_term:text(), log_level()) -> 'ok'.
change_sink_level(<<SinkHandler/binary>>, Level) ->
    Sink = kz_term:to_atom(<<SinkHandler/binary, "_lager_event">>, 'true'),

    Handlers = lager_config:global_get('handlers', []),

    %% [{Backend, Pid, Sink}]
    case lists:keyfind(Sink, 3, Handlers) of
        'false' ->
            io:format("no sink ~s (~s) with configuration~n", [SinkHandler, Sink]);
        {Handler, _Pid, Sink} ->
            case lager:get_loglevel(Sink, Handler) of
                {'error', 'bad_module'} -> 'ok';
                Level ->
                    ?LOG("~s handler ~p already logging at ~p", [Sink, Handler, Level]);
                _OldLevel ->
                    ?LOG("~s handler ~p now logging at ~p (was ~p)", [Sink, Handler, Level, _OldLevel]),
                    lager:set_loglevel(Sink, Handler, 'undefined', Level)
            end
    end;
change_sink_level(Sink, Level) ->
    change_sink_level(kz_term:to_binary(Sink), Level).

-spec change_console_log_level(log_level()) -> 'ok'.
change_console_log_level(L) when is_atom(L) ->
    Handlers = ['lager_console_backend'
               ,{'lager_file_backend', "log/console.log"}
               ],
    update_log_level(Handlers, L);
change_console_log_level(L) ->
    change_console_log_level(kz_term:to_atom(L)).

-spec change_error_log_level(log_level()) -> 'ok'.
change_error_log_level(L) when is_atom(L) ->
    update_log_level([{'lager_file_backend', "log/error.log"}], L);
change_error_log_level(L) ->
    change_error_log_level(kz_term:to_atom(L)).

-spec change_syslog_log_level(log_level()) -> 'ok'.
change_syslog_log_level(L) when is_atom(L) ->
    update_log_level([{'lager_syslog_backend',{"2600hz",'local0'}}], L);
change_syslog_log_level(L) ->
    change_syslog_log_level(kz_term:to_atom(L)).

-spec change_file_log_level(kz_term:text(), log_level()) -> 'ok'.
change_file_log_level(File, Level) ->
    update_log_level([{'lager_file_backend', kz_term:to_list(File)}], Level).

update_log_level([], _Level) -> 'ok';
update_log_level([Backend|Backends], Level) ->
    case lager:get_loglevel(Backend) of
        {'error', 'bad_module'} -> 'ok';
        Level ->
            ?LOG("handler ~p already logging at ~p", [Backend, Level]);
        _OldLevel ->
            ?LOG("handler ~p now logging at ~p (was ~p)", [Backend, Level, _OldLevel]),
            lager:set_loglevel(Backend, Level)
    end,
    update_log_level(Backends, Level).

%%------------------------------------------------------------------------------
%% @doc Standardized way of logging the stack-trace.
%% @deprecated `erlang:get_stacktrace/0' used by this function is deprecated
%% in OTP 21, please use the new try/catch syntax and pass stacktrace to
%% {@link kz_log:log_stacktrace/1} instead.
%% @end
%%------------------------------------------------------------------------------
-spec log_stacktrace() -> 'ok'.
log_stacktrace() ->
    try throw('get_stacktrace')
    catch
        ?STACKTRACE(_E, _R, ST)
        log_stacktrace(ST, "log_stacktrace/0 is deprecated: ", [])
        end.

%%------------------------------------------------------------------------------
%% @doc Standardized way of logging the stack-trace.
%% @end
%%------------------------------------------------------------------------------
-spec log_stacktrace(list()) -> 'ok'.
log_stacktrace(ST) ->
    log_stacktrace(ST, "", []).

%%------------------------------------------------------------------------------
%% @doc Standardized way of logging the stack-trace.
%% @deprecated `erlang:get_stacktrace/0' used by this function is deprecated
%% in OTP 21, please use the new try/catch syntax and pass stacktrace to
%% {@link kz_log:log_stacktrace/3} instead.
%% @end
%%------------------------------------------------------------------------------
-spec log_stacktrace(string(), list()) -> 'ok'.
log_stacktrace(Fmt, Args) ->
    try throw('get_stacktrace')
    catch
        ?STACKTRACE(_E, _R, ST)
        log_stacktrace(ST, "log_stacktrace/2 is deprecated: " ++ Fmt, Args)
        end.

%%------------------------------------------------------------------------------
%% @doc Standardized way of logging the stack-trace.
%% @end
%%------------------------------------------------------------------------------
-spec log_stacktrace(list(), string(), list()) -> 'ok'.
log_stacktrace(ST, Fmt, Args) ->
    ?LOG_ERROR("stacktrace: " ++ Fmt, Args),
    _ = [log_stacktrace_mfa(M, F, A, Info)
         || {M, F, A, Info} <- ST
        ],
    'ok'.

log_stacktrace_mfa(M, F, Arity, Info) when is_integer(Arity) ->
    ?LOG_ERROR("st: ~s:~s/~b at (~b)", [M, F, Arity, props:get_value('line', Info, 0)]);
log_stacktrace_mfa(M, F, Args, Info) ->
    ?LOG_ERROR("st: ~s:~s at ~p", [M, F, props:get_value('line', Info, 0)]),
    lists:foreach(fun (Arg) -> ?LOG_ERROR("args: ~p", [Arg]) end, Args).

%%------------------------------------------------------------------------------
%% @doc Given an JSON Object extracts the `Call-ID' into the processes
%% dictionary, failing that the `Msg-ID' and finally a generic.
%% @end
%%------------------------------------------------------------------------------
-spec put_callid(kz_json:object() | kz_term:proplist() | kz_term:ne_binary() | atom()) -> 'ok'.
put_callid(?NE_BINARY = CallId) ->
    _ = kz_log_md_put('callid', CallId),
    _ = erlang:put('callid', CallId),
    'ok';
put_callid(Atom) when is_atom(Atom) ->
    _ = kz_log_md_put('callid', Atom),
    _ = erlang:put('callid', Atom),
    'ok';
put_callid(APITerm) ->
    put_callid(find_callid(APITerm)).

-spec put_callid(kz_term:ne_binary() | atom(), kz_json:object() | kz_term:proplist() | kz_term:ne_binary() | atom()) -> 'ok'.
put_callid(Prefix, CallId) ->
    put_callid(list_to_binary([kz_term:to_binary(Prefix), "|", logid(CallId)])).

-spec logid(kz_json:object() | kz_term:proplist() | kz_term:ne_binary() | atom()) -> kz_term:ne_binary() | atom().
logid(?NE_BINARY = Id) -> Id;
logid(Atom) when is_atom(Atom) -> Atom;
logid(APITerm) -> find_callid(APITerm).

-spec get_callid() -> kz_term:api_ne_binary().
get_callid() -> erlang:get('callid').

-spec find_callid(kz_term:api_terms()) -> kz_term:api_binary().
find_callid(APITerm) when is_list(APITerm) ->
    find_callid(APITerm, fun props:get_first_defined/3);
find_callid(APITerm) ->
    find_callid(APITerm, fun kz_json:get_first_defined/3).

-spec find_callid(kz_term:api_terms(), fun()) -> kz_term:api_binary().
find_callid(APITerm, GetFun) ->
    GetFun([?KEY_LOG_ID, ?KEY_API_CALL_ID, ?KEY_MSG_ID]
          ,APITerm
          ,?DEFAULT_LOG_SYSTEM_ID
          ).

-spec kz_log_md_put(atom(), any()) -> any().
kz_log_md_put(K, V) ->
    lager:md(lists:usort(fun is_kz_log_md_equal/2, [{K, V} | lager:md()])).

is_kz_log_md_equal({K1, _}, {K2, _}) -> K1 =< K2;
is_kz_log_md_equal(K1, K2) -> K1 =< K2.

-define(LAGER_MD_KEY, '__lager_metadata').

-spec kz_log_md_clear() -> 'ok'.
kz_log_md_clear() ->
    %% `lager:md([])' causing dialyzer to complain:
    %% warn_failing_call
    %% `kz_util.erl:408: The call lager:md([]) breaks the contract ([{atom(),any()},...]) -> ok`'
    %% lager:md([]).
    _ = erlang:put(?LAGER_MD_KEY, []),
    'ok'.

-spec redactor(kz_term:text()) -> kz_term:text().
redactor(Line) ->
    Routines = [fun redact_json_password/1
               ,fun redact_json_credit_card_number/1
               ,fun redact_basic_auth/1
               ],
    lists:foldl(fun apply_redactor/2, Line, Routines).

apply_redactor(F, L) when is_function(F, 1) -> F(L).

-spec redact_json_password(kz_term:text()) -> kz_term:ne_binary().
redact_json_password(Line) ->
    re:replace(Line, <<"(([\'\"])password\\2\\s*:\\s*\\2)((?:.(?!(?<![\\\\])\\2))*.?)\\2">>, "\\1" ++ ?REDACTED_REPLACEMENT ++ "\\2", [{'return', 'binary'}]).

-spec redact_json_credit_card_number(kz_term:text()) -> kz_term:ne_binary().
redact_json_credit_card_number(Line) ->
    re:replace(Line, <<"(([\'\"])credit_card\\2\\s*:\\s*{\\s*\\2number\\2\\s*:\\s*\\2)((?:.(?!(?<![\\\\])\\2))*.?)\\2">>, "\\1" ++ ?REDACTED_REPLACEMENT ++ "\\2", [{'return', 'binary'}]).

-spec redact_basic_auth(kz_term:text()) -> kz_term:ne_binary().
redact_basic_auth(Line) ->
    case re:run(Line
               ,<<"((?:amqp|http)s?://)([^:]+:[^@]+@)(.+)">>
               ,[{'capture', 'all_but_first', 'binary'}]
               )
    of
        {'match', [Scheme, _Creds, URL]} ->
            <<Scheme/binary, URL/binary>>;
        _ -> Line
    end.

-spec format(lager_msg:lager_msg(), list(), list()) -> any().
format(Message, Config, Colors) ->
    lager_default_formatter:format(Message, lists:foldr(fun log_format/2, [], Config), Colors).

-spec format(lager_msg:lager_msg(),list()) -> any().
format(Msg, Config) ->
    format(Msg, Config, []).

log_format('rfc3339', Acc) ->
    Now = os:system_time('nanosecond'),
    RFC3339Options = [{'unit', 'nanosecond'}
                     ,{'offset', "Z"}
                     ],
    RFC3339 = calendar:system_time_to_rfc3339(Now, RFC3339Options),
    [RFC3339 | Acc];
log_format(Term, Acc) ->
    [Term | Acc].

-spec print_table([[any()]]) -> 'ok'.
print_table(Rows) ->
    print_table(Rows, #{}).

-type cell_spacing() :: #{field_width => pos_integer() | 'undefined' % will be calculated if not defined
                         ,justification => 'left' | 'right' % defaults right per-cell
                         ,precision => 'undefined' % unused as of yet
                         ,pad_char => char() % padding character to use to fill the cell, if needed, default: $\s
                         ,control_sequence_modifier => 'unicode' | 'unprintable'
                         ,control_sequence => $s | $p % how to print the data
                         }.
-type table_options() :: #{row_spacing => [cell_spacing() | 'left' | 'right'] | 'undefined'
                          ,cell_divider => char() | 'undefined'
                          ,header_divider => char() | 'undefined'
                          }.

-spec print_table(list(list()), table_options()) -> 'ok'.
print_table([], _) -> 'ok';
print_table([MaybeHeader | Rows], Options) ->
    RowSpacing = lists:foldl(fun format_row/2
                            ,maps:get('row_spacing', Options, [])
                            ,[MaybeHeader | Rows]
                            ),
    Fmt = spacing_fmt(RowSpacing, Options),
    %% io:format("using fmt: ~p~n", [Fmt]),

    case opt_header_divider(Options) of
        'undefined' -> print_rows(Fmt, [MaybeHeader | Rows]);
        HeaderDivider ->
            DividerRow = spacing_fmt_pad(RowSpacing, HeaderDivider),
            print_rows(Fmt, [MaybeHeader]),
            print_rows(Fmt, [DividerRow]),
            print_rows(Fmt, Rows)
    end.

spacing_fmt_pad(RowSpacing, HeaderDivider) ->
    [[HeaderDivider || _ <- lists:seq(1, FieldWidth+2)] ||
        #{field_width := FieldWidth} <- RowSpacing
    ].

print_rows(Fmt, Rows) ->
    lists:foreach(fun(R) -> io:format(Fmt, lists:map(fun pad_cell_value/1, R)) end
                 ,Rows
                 ).

pad_cell_value(Cell) ->
    kz_term:to_binary(Cell).
%% <<" ", Bin/binary, " ">>.

spacing_fmt(RowSpacing, Options) ->
    CellDivider = opt_cell_divider(Options),
    iolist_to_binary([CellDivider
                     ,kz_binary:join([cell_spacing_fmt(CellSpacing) || CellSpacing <- RowSpacing], <<CellDivider>>)
                     ,CellDivider
                     ,"~n"
                     ]).

opt_cell_divider(#{cell_divider := Char}) when is_integer(Char) ->
    Char;
opt_cell_divider(_) -> $|.

opt_header_divider(#{header_divider := Char}) when is_integer(Char) ->
    Char;
opt_header_divider(_) -> 'undefined'.

%% ~F.P.PadModC
%% F = field_width
%% P = precision (unused)
%% Pad = padding char
%% Mod = control sequence modifier
-spec cell_spacing_fmt(cell_spacing()) -> iodata().
cell_spacing_fmt(#{control_sequence := ControlSeq
                  ,field_width := CellSize
                  ,justification := Justification
                  ,pad_char := PadChar
                  }
                ) ->
    [justification(Justification)
    ,kz_term:to_list(CellSize), ".."
    ,PadChar, ControlSeq
    ].

justification('right') ->
    "~";
justification('left') ->
    "~-".

format_row(Row, RowSpacing) ->
    row_spacing(Row, RowSpacing, []).

row_spacing([], [], CalcdSpacing) ->
    lists:reverse(CalcdSpacing);
row_spacing([Cell | Cells], [], CalcdSpacing) ->
    CellSpacing = cell_spacing(Cell),
    row_spacing(Cells, [], [CellSpacing | CalcdSpacing]);
row_spacing([Cell | Cells], [CellSpacing | CellSpacings], CalcdSpacings) ->
    CellSize = cell_field_width(CellSpacing),

    case cell_spacing(Cell) of
        #{field_width:=Size}=Settings when Size > CellSize ->
            Merged = maps:merge(Settings, ensure_map(CellSpacing)),
            row_spacing(Cells, CellSpacings, [Merged#{field_width=>Size} | CalcdSpacings]);
        Settings ->
            Merged = maps:merge(Settings, CellSpacing),
            row_spacing(Cells, CellSpacings, [Merged | CalcdSpacings])
    end.

ensure_map('left') ->
    #{justification => 'left'};
ensure_map('right') ->
    #{justification => 'right'};
ensure_map(#{}=Map) -> Map.

-spec cell_spacing(any()) -> cell_spacing().
cell_spacing(Cell) ->
    Bin = kz_term:to_binary(Cell),
    #{field_width => byte_size(Bin) % will be calculated if not defined
     ,justification => 'right' % defaults right
     ,pad_char => $\s % padding character to use to fill the cell, if needed, default: $\s
     ,control_sequence => $s
     }.

cell_field_width(#{field_width:=FieldWidth}) -> FieldWidth;
cell_field_width(_) -> 0.

-ifdef(TEST).

%% to be run in a running KAZOO VM (dev env obviously)

%% sometimes the syslog driver will crash (typically around a wonky
%% UTF-8 character) and be restarted, but it reverts back to the
%% sys.config defined value (default 'debug'). If syslog was running
%% in a different priority level (info, notice, etc), that runtime
%% change will be lost.

%% KAZOO should monitor the syslog process and at least re-read
%% KAZOO's config.ini setting for the log level
-spec restart_check() -> boolean().
restart_check() ->
    SyslogBackend = {'lager_syslog_backend',{"2600hz",'local0'}},
    [{'syslog', SyslogPid, 'worker', ['syslog']}] = supervisor:which_children('syslog_sup'),

    CurrentLevel = lager:get_loglevel(SyslogBackend),
    change_syslog_log_level('notice'),

    'notice' = lager:get_loglevel(SyslogBackend),

    exit(SyslogPid, 'restart'),

    timer:sleep(100),
    RestartLevel = lager:get_loglevel(SyslogBackend),
    io:format("start level: ~p~nchanged to notice and killed syslog gen_server ~p~nrestart level: ~p~n"
             ,[CurrentLevel, SyslogPid, RestartLevel]
             ),
    RestartLevel =:= 'notice'.
-endif.
