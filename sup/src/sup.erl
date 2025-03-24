%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc A really simple escript to accept RPC request and push them
%%% into a running kazoo virtual machine.
%%%
%%% @author Karl Anderson
%%% @author Pierre Fenoll
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(sup).

-export([main/1]).
-export([in_kazoo/4]).

%% just for testing in the shell
%% -export([nearest/2
%%         ,print_invalid_module/1
%%         ,print_invalid_function/3
%%         ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").

-elvis([{elvis_style, no_debug_call, disable}]).

-define(MAX_CHARS, round(math:pow(2012, 80))).

%%% API

-spec main(string()) -> no_return().
main(CommandLineArgs) ->
    main(CommandLineArgs, 0).

main(CommandLineArgs, Loops) ->
    _ = os:cmd("epmd -daemon"),
    _ = net_kernel:stop(),

    {'ok', Options, Args} = parse_args(CommandLineArgs),

    SUPName = my_name(use_short(Options)),

    case net_kernel:start([SUPName, long_or_short_name(use_short(Options))]) of
        {'error', _E} when Loops < 3 ->
            stderr("Unable to start command bridge network kernel (~p), try again", [_E]),
            halt(1);
        {'error', _E} ->
            io:format("failed to start command bridge network kernel (~p), trying again (~p)~n", [_E, Loops]),
            main(CommandLineArgs, Loops + 1);
        {'ok', _} ->
            lists:member('help', Options)
                andalso print_help(),
            IsVerbose = props:get_value('verbose', Options) =/= 'undefined',
            Target = get_target(Options, IsVerbose),
            Module =
                case props:get_value('module', Options) of
                    'undefined' -> print_invalid_cli_args('undefined', 'undefined', 0);
                    M -> list_to_atom(M)
                end,
            IsMaintenanceCommand = lists:suffix("_maintenance", props:get_value('module', Options)),
            Function =
                case props:get_value('function', Options) of
                    'undefined' -> print_invalid_cli_args(Module, 'undefined', 0);
                    F -> list_to_atom(F)
                end,

            %% If erl_term_args is set then parse the args as erlang terms, else just convert to binary
            Arguments = case erl_term_args(Options) of
                            'true' -> parse_erl_terms_from_args(Args);
                            'false' -> [list_to_binary(Arg) || Arg <- Args]
                        end,
            Timeout = case props:get_value('timeout', Options) of 0 -> 'infinity'; T -> T * 1000 end,
            IsVerbose
                andalso stdout("Running ~s:~s(~s)", [Module, Function, string:join(Args, ", ")]),

            case rpc:call(Target, ?MODULE, 'in_kazoo', [SUPName, Module, Function, Arguments], Timeout) of
                {'badrpc', {'EXIT',{'undef', _}}} ->
                    print_invalid_cli_args(Module, Function, length(Arguments));
                {'badrpc', {'EXIT', {'timeout_value',[{Module,Function,_,_}|_]}}} ->
                    stderr("Command failed: timeout~n", []),
                    halt(4);
                {'badrpc', Reason} ->
                    String = io_lib:print(Reason, 1, ?MAX_CHARS, -1),
                    stderr("Command failed: ~s~n", [String]),
                    halt(3);
                {'no_return', Code} ->
                    halt(Code);
                'no_return' when IsMaintenanceCommand ->
                    halt(0);
                Result when IsMaintenanceCommand ->
                    print_result(Result, IsVerbose),
                    Code = case 'ok' =:= Result of
                               'true' -> 0;
                               'false' -> 2
                           end,
                    halt(Code);
                'no_return' ->
                    halt(0);
                Result ->
                    print_result(Result, IsVerbose),
                    halt(0)
            end
    end.

%%% Internals

%%------------------------------------------------------------------------------
%% @doc Parse script args into erlang terms or halt and print help if fails to parse an arg.
%% @end
%%------------------------------------------------------------------------------
-spec parse_erl_terms_from_args(list(list())) -> term() | no_return().
parse_erl_terms_from_args(Args) ->
    [parse_erl_terms_from_arg(Arg) || Arg <- Args].

-spec parse_erl_terms_from_arg(list()) -> term() | no_return().
parse_erl_terms_from_arg(Arg) ->
    {'ok', Tokens, _} = erl_scan:string(Arg++"."),
    case erl_parse:parse_term(Tokens) of
        {'ok', ParsedArg} ->
            ParsedArg;
        Failed ->
            stderr("Failed to parse term ~p, error ~p", [Arg, Failed]),
            print_erl_term_args_help()
    end.

-spec in_kazoo(atom(), module(), atom(), kz_term:binaries()) -> no_return().
in_kazoo(SUPName, M, F, As) ->
    kz_log:put_callid(SUPName),
    erlang:put('is_sup_call', 'true'),
    lager:notice("~s: ~s ~s ~s", [?MODULE, M, F, kz_term:iolist_join($,, As)]),
    R = apply(M, F, As),
    lager:notice("~s result: ~p", [?MODULE, R]),
    R.

-spec print_result(any(), boolean()) -> 'ok'.
print_result(Result, 'true') ->
    String = io_lib:print(Result, 1, ?MAX_CHARS, -1),
    try stdout("Result: ~s", [String])
    catch
        'error':'badarg' -> stdout("Result: ~p", [String])
    end;
print_result(Result, 'false') ->
    String = io_lib:print(Result, 1, ?MAX_CHARS, -1),
    try stdout("~s", [String])
    catch
        'error':'badarg' -> stdout("~p", [String])
    end.

-spec get_target(kz_term:proplist(), boolean()) -> atom().
get_target(Options, Verbose) ->
    Cookie = get_cookie(Options, list_to_atom(props:get_value('node', Options))),
    Target = get_target(Options),
    case net_adm:ping(Target) of
        'pong' ->
            Verbose
                andalso stdout("Connected to service ~s with cookie ~s", [Target, Cookie]),
            Target;
        'pang' ->
            stderr("Connection to service failed!", []),
            print_ping_failed(Target, Cookie)
    end.

-spec get_target(kz_term:proplist()) -> atom().
get_target(Options) ->
    build_target(Options, use_short(Options)).

-spec build_target(kz_term:proplist(), kz_term:api_boolean()) -> atom().
build_target(Options, 'true') ->
    Node = props:get_value('node', Options),
    [First | _] = string:tokens(get_host(), "."),

    kz_term:to_atom(Node ++ [$@ | First], 'true');
build_target(Options, _) ->
    Node = props:get_value('node', Options),
    Host = get_host(),
    list_to_atom(Node ++ "@" ++ Host).

-spec get_cookie(kz_term:proplist(), atom()) -> atom().
get_cookie(Options, Node) ->
    CookieStr =
        case {props:get_value('cookie', Options, "")
             ,kazoo_config_init:read_cookie(Node)
             }
        of
            {C, []} when C =/= "" -> C;
            {_, [C]} -> C;
            {"", []} -> print_no_setcookie()
        end,
    Cookie = kz_term:to_atom(CookieStr, 'true'),
    'true' = erlang:set_cookie(node(), Cookie),
    Cookie.

-spec get_host() -> nonempty_string().
get_host() ->
    Host = localhost(),
    case inet:gethostbyname(Host) of
        {'ok', _} -> Host;
        {'error', 'nxdomain'} ->
            stderr("Unable to resolve host '~s'", [Host]),
            print_unresolvable_host(Host);
        {'error', Reason} ->
            stderr("Unable to resolve host '~s': ~p", [Host, Reason]),
            print_unresolvable_host(Host)
    end.

-spec my_name(kz_term:api_boolean()) -> node().
my_name('true') ->
    kz_term:to_atom(iolist_to_binary(["sup_", kz_binary:rand_hex(2)]), 'true');
my_name(_) ->
    Name = iolist_to_binary(["sup_", kz_binary:rand_hex(2), $@, localhost()]),
    kz_term:to_atom(Name, 'true').

-spec localhost() -> nonempty_string().
localhost() ->
    net_adm:localhost().

-spec long_or_short_name(kz_term:api_boolean()) -> 'longnames' | 'shortnames'.
long_or_short_name('true') ->
    'shortnames';
long_or_short_name(_) ->
    IsDot = fun ($.) -> 'true'; (_) -> 'false' end,
    case lists:any(IsDot, localhost()) of
        'true' -> 'longnames';
        'false' -> 'shortnames'
    end.

-spec print_invalid_cli_args(module() | 'undefined', function() | 'undefined', arity()) -> no_return().
print_invalid_cli_args('undefined', _Function, _Arity) ->
    stderr("No module supplied, invalid invocation of SUP", []),
    halt(1);
print_invalid_cli_args(Module, 'undefined', _Arity) ->
    stderr("No function for module ~s supplied, invalid invocation of SUP", [Module]),
    halt(1);
print_invalid_cli_args(Module, Function, Arity) ->
    case kz_module:ensure_loaded(Module) of
        Module -> print_invalid_function(Module, Function, Arity);
        'false' -> print_invalid_module(Module)
    end,
    halt(1).

-spec print_invalid_module(module()) -> 'ok'.
print_invalid_module(Module) ->
    Modules = [kz_term:to_binary(Mod) || {Mod, _} <- code:all_loaded()],
    case nearest_module(kz_term:to_binary(Module), Modules) of
        [] -> stderr("Invalid module ~s, no close candidates found", [Module]);
        [Nearest | _] -> stderr("Invalid module ~s, maybe you meant ~s", [Module, Nearest])
    end.

nearest_module(Module, Ms) ->
    nearest_module(Module, [{M, M} || M <- Ms], []).

nearest_module(<<>>, _, Nearest) -> [M || {M, _} <- Nearest];
nearest_module(<<C, Rest/binary>>, Ms, Nearest) ->
    case [{M, MRest} || {M, <<MC, MRest/binary>>} <- Ms, MC =:= C] of
        [] -> [M || {M, _} <- Nearest];
        NearerStill ->
            nearest_module(Rest, NearerStill, NearerStill)
    end.

-spec print_invalid_function(atom(), atom(), non_neg_integer()) -> 'ok'.
print_invalid_function(Module, Function, Arity) ->
    Exports = [{kz_term:to_binary(F), A} || {F, A} <- Module:module_info('exports')],

    NearestFuns = nearest(kz_term:to_binary(Function), Exports),
    {Nearest, FA} = case [{F, FA} || {F, FA} <- NearestFuns, FA =:= Arity] of
                        [] -> hd(NearestFuns);
                        [{N, A} | _] -> {N, A}
                    end,
    stderr("Invalid function ~s:~s/~p, maybe you meant ~s/~p"
          ,[Module, Function, Arity, Nearest, FA]
          ).

%% lame matching to find "close"
-spec nearest(kz_term:ne_binary(), [{kz_term:ne_binary(), arity()}]) -> [{kz_term:ne_binary(), arity()}].
nearest(Function, Exports) ->
    Exs = [{Fun, Fun, Arity} || {Fun, Arity} <- Exports],
    nearest(Function, Exs, []).

nearest(<<>>, _Exports, Nearest) ->
    [{Fun, Arity} || {_G, Fun, Arity} <- Nearest];
nearest(<<F:1/binary, Rest/binary>>, Exports, Nearest) ->
    case [{GRest, Fun, Arity} || {<<G:1/binary, GRest/binary>>, Fun, Arity} <- Exports,
                                 G =:= F
         ]
    of
        [] ->
            [{Fun, Arity} || {_G, Fun, Arity} <- Nearest];
        NearerStill ->
            nearest(Rest, NearerStill, NearerStill)
    end.

-spec parse_args(string()) -> {'ok', kz_term:proplist(), list()}.
parse_args(CommandLineArgs) ->
    case getopt:parse(option_spec_list(), CommandLineArgs) of
        {'ok', {Options, Args}} when is_list(Options) ->
            {'ok', Options, Args};
        {'error', {_, _}} ->
            print_help()
    end.

-spec print_no_setcookie() -> no_return().
print_no_setcookie() ->
    stdout("Unable to automatically determine cookie", []),
    stdout("Please provide the cookie of the node you are connecting to", []),
    stdout("`sup -c <cookie>`", []),
    halt(1).

-spec print_ping_failed(string(), atom()) -> no_return().
print_ping_failed(Target, Cookie) ->
    stdout("Failed to connect to service ~s with cookie ~s", [Target, Cookie]),
    stdout("  Possible fixes:", []),
    stdout("    * Ensure the Kazoo service you are trying to connect to is running on the host", []),
    stdout("    * Ensure that you are using the same cookie as the Kazoo node, `sup -c <cookie>`", []),
    stdout("    * Verify that the hostname being used is a Kazoo node", []),
    halt(1).

-spec print_unresolvable_host(string()) -> no_return().
print_unresolvable_host(Host) ->
    stdout("If you cannot run `ping ~s` then this program will not be able to connect.", [Host]),
    stdout("  Possible fixes:", []),
    stdout("    * Add \"{IP_OF_KAZOO_NODE}  ~s\" to your /etc/hosts file", [Host]),
    stdout("    * Create a DNS record for \"~s\"", [Host]),
    halt(1).

-spec print_help() -> no_return().
print_help() ->
    getopt:usage(option_spec_list(), "sup", "[args ...]"),
    halt(1).

%%------------------------------------------------------------------------------
%% @doc Print help for erl_term_args flag and halt.
%% @end
%%------------------------------------------------------------------------------
-spec print_erl_term_args_help() -> no_return().
print_erl_term_args_help() ->
    stdout("Erlang term arguments must be correctly wrapped / formatted as below:", []),
    stdout("  * Atom: atom", []),
    stdout("  * String: \"this is a string\"", []),
    stdout("  * Binary: \"<<\\\"Etc/UTC\\\">>\"", []),
    stdout("  * Tuple: \"{{2020, 01, 01}, {01, 20, 30}}\"", []),
    stdout("  * List: \"[1,2,3,4]\"", []),
    halt(1).

-spec stdout(string(), list()) -> 'ok'.
stdout(Format, Things) ->
    io:format('standard_io', Format++"\n", Things).

-spec stderr(string(), list()) -> 'ok'.
stderr(Format, Things) ->
    io:format('standard_error', Format++"\n", Things).

-spec option_spec_list() -> list().
option_spec_list() ->
    [{'help', $?, "help", 'undefined', "Show the program options"}
    ,{'node', $n, "node", {'string', from_env("KAZOO_NODE", "kazoo_apps")}, "Node name"}
    ,{'cookie', $c, "cookie", {'string', from_env("KAZOO_COOKIE", "change_me")}, "Erlang cookie"}
    ,{'timeout', $t, "timeout", {'integer', 0}, "Command timeout"}
    ,{'verbose', $v, "verbose", 'undefined', "Be verbose"}
    ,{'module', 'undefined', 'undefined', 'string', "The name of the remote module"}
    ,{'function', 'undefined', 'undefined', 'string', "The name of the remote module's function"}
    ,{'use_short', $s, "use_short", {'boolean', 'undefined'}, "Force using shortnames"}
    ,{'erl_term_args', $e, "erl_term_args", {'boolean', 'false'}, "Parse function args to erlang terms"}
    ].

-spec from_env(list(), list()) -> list().
from_env(Name, Default) ->
    case os:getenv(Name) of
        'false' -> Default;
        Value -> Value
    end.

-spec use_short(kz_term:proplist()) -> kz_term:api_boolean().
use_short(Options) ->
    props:get_value('use_short', Options).

%%------------------------------------------------------------------------------
%% @doc Return 'true' if the erl_term_args flag is passed by the user, else false
%% @end
%%------------------------------------------------------------------------------
-spec erl_term_args(kz_term:proplist()) -> kz_term:api_boolean().
erl_term_args(Options) ->
    props:get_value('erl_term_args', Options).

%%% End of Module
