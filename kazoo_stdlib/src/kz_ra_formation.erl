%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2025, 2600Hz
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_ra_formation).

-behaviour(gen_server).

-export([reset/1]).
-export([check/1]).
-export([startup_time/1]).


%% API
-export([start_link/1]).

%% gen_server
-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(TICK_INTERVAL, 20 * ?MILLISECONDS_IN_SECOND).
-define(RESTART_SLEEP_MS, ?MILLISECONDS_IN_SECOND * 5).
-define(RETRY_SLEEP_MS, ?MILLISECONDS_IN_SECOND * 30).
-define(MAX_RESTART_COUNT, 5).

-type state() :: map().

-type context() :: map().
-type start_link_options() :: map().

-spec start_link(start_link_options()) -> kz_types:startlink_ret().
start_link(Options)
  when is_map(Options) ->
    gen_server:start_link({'local', server_name(Options)}, ?MODULE, Options, []).

-spec init(start_link_options()) -> {'ok', state()}.
init(Options) ->
    process_flag('trap_exit', 'true'),
    kz_log:put_callid(ra_name(Options)),
    gen_server:cast(self(), 'start'),
    {'ok', init_state(Options)}.

init_state(Options) ->
    maps:merge(init_state_defaults(Options), Options).

init_state_defaults(#{ra_machine := Module}) ->
    {'ok', Application} = application:get_application(Module),
    #{max_restart_count => kz_app_config:get_integer(Application
                                                    ,['ra', 'pg', 'max_restart_count']
                                                    ,?MAX_RESTART_COUNT
                                                    )
     ,restart_sleep_ms => kz_app_config:get_integer(Application
                                                   ,['ra', 'pg', 'restart_sleep_ms']
                                                   ,?RESTART_SLEEP_MS
                                                   )
     ,startup_time => kz_time:now_us()
     }.

-spec handle_call(any(), kz_term:pid_ref(), state()) -> {'reply', any(), state()}.
handle_call('startup_time', _From, #{startup_time := StartupTime} = State) ->
    {'reply', StartupTime, State};
handle_call(_Request, _From, State) ->
    lager:info("unhandled call from ~p : ~p", [_From, _Request]),
    {'reply', 'not_implemented', State}.

-spec handle_cast(any(), state()) -> {'noreply', state()}.
handle_cast('start', State) ->
    {'noreply', start(State)};
handle_cast('reset', State) ->
    {'noreply', do_reset(State)};
handle_cast('check', State) ->
    {'noreply', do_check(State)};
handle_cast(_Msg, State) ->
    lager:info("unhandled cast : ~p", [_Msg]),
    {'noreply', State}.

-spec handle_info(any(), state()) -> {'noreply', state()}.
handle_info(_Msg, State) ->
    lager:debug("unhandled info: ~p", [_Msg]),
    {'noreply', State}.

-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, Context) ->
    lager:debug("stopping pg monitoring: ~s / ~p", [ra_name(Context), _Reason]),
    _ = do_terminate(Context),
    'ok'.

do_terminate(Context) ->
    Routines = [fun pg_leave/1
               ,fun ra_stop/1
               ,fun ra_leave/1
               ],
    kz_maps:exec(Routines, Context).

pg_leave(#{joined := 'true'} = Context) ->
    lager:debug("leaving pg ~s / ~s", [pg_scope(Context), ra_name(Context)]),
    pg:leave(pg_scope(Context), ra_name(Context), self()),
    Context;
pg_leave(Context) -> Context.

ra_stop(#{ra_auto_leave := 'true'} = Context) -> Context;
ra_stop(#{running := 'true'} = Context) ->
    lager:debug("stopping ra node ~s / ~s", [ra_system(Context), ra_name(Context)]),
    _ = ra:stop_server(ra_system(Context), ra_node(Context)),
    Context;
ra_stop(Context) -> Context.

ra_leave(#{running := 'true'
          ,ra_auto_leave := 'true'
          } = Context
        ) ->
    lager:debug("leaving cluster ~s / ~s", [ra_system(Context), ra_name(Context)]),
    _ = ra:leave_and_delete_server(ra_system(Context), ra_leader(Context), ra_node(Context)),
    Context;
ra_leave(Context) -> Context.

-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

start(Context) ->
    Routines = [fun ra_system_start/1
               ,fun pg_join/1
               ,fun pg_query_nodes/1
               ,fun ra_restart/1
               ,fun pg_sleep/1
               ,fun ra_join/1
               ,fun ra_start/1
               ,fun ra_election/1
               ,fun ra_retry/1
               ],
    kz_maps:exec(Routines, Context).

ra_election(#{sleeping := 'true'} = Context) -> Context;
ra_election(#{trigger_election := 'true'} = Context) ->
    ra_election(ra_leader(Context), Context);
ra_election(Context) -> Context.

ra_election('undefined', Context) -> Context;
ra_election(Leader, Context) ->
    ra:trigger_election(Leader),
    maps:without(['trigger_election'], Context).

ra_system(#{ra_system := RASystem}) -> RASystem.

ra_system_start(#{ra_started := 'true'} = Context) -> Context;
ra_system_start(Context) ->
    lager:info("checking ra system ~s is running", [ra_system(Context)]),
    case ra:overview(ra_system(Context)) of
        'system_not_started' -> do_ra_system_start(Context);
        _ -> Context#{ra_started => 'true'}
    end.

do_ra_system_start(Context) ->
    lager:info("starting ra system ~s", [ra_system(Context)]),
    RASystemConfig = ra_system_config(Context),
    {'ok', _RaSystemPid} = ra_system:start(RASystemConfig),
    Context#{ra_started => 'true'}.

ra_system_config(Context) ->
    ra_config(Context, ra_system:default_config()).

ra_config(Context, Config) ->
    Config#{name => ra_system(Context)
           ,names => ra_system:derive_names(ra_system(Context))
           }.

pg_join(#{joined := 'true'} = Context) -> Context;
pg_join(Context) ->
    lager:info("joining pg group ~s", [ra_name(Context)]),
    pg:join(pg_scope(Context), ra_name(Context), self()),
    {Ref, _Pids} = pg:monitor(pg_scope(Context), ra_name(Context)),
    Context#{joined => 'true', monitor => Ref}.

pg_query_nodes(#{running := 'true'} = Context) -> Context;
pg_query_nodes(Context) ->
    case pg_nodes(Context) of
        [] -> maps:without(['nodes'], Context);
        Nodes ->
            lager:info("pg group ~s nodes => [~s]"
                      ,[ra_name(Context)
                       ,kz_binary:join([kz_term:to_binary(Node) || Node <- Nodes], <<",">>)
                       ]),
            Context#{nodes => Nodes}
    end.

pg_sleep(#{restarted := 'true'
          ,sleep_count := Count
          ,max_restart_count := Max
          } = Context
        ) when Count > Max ->
    maps:without(['sleeping', 'restarted'], Context);
pg_sleep(#{restarted := 'true', restart_sleep_ms := Sleep} = Context) ->
    kz_process:spawn(fun pg_restart/2, [self(), Sleep]),
    Context#{sleeping => 'true', sleep_count => sleep_count(Context)};
pg_sleep(#{running := 'true'} = Context) -> Context;
pg_sleep(#{nodes := _} = Context) -> maps:without(['sleeping'], Context);
pg_sleep(#{sleep_count := Count
          ,max_restart_count := Max
          } = Context
        ) when Count > Max ->
    lager:info("reached max count for getting other pg group ~s members", [ra_name(Context)]),
    maps:without(['sleeping'], Context);
pg_sleep(#{restart_sleep_ms := Sleep} = Context) ->
    lager:info("restarting fetch for pg group ~s members", [ra_name(Context)]),
    kz_process:spawn(fun pg_restart/2, [self(), Sleep]),
    Context#{sleeping => 'true', sleep_count => sleep_count(Context)}.

sleep_count(Context) ->
    maps:get('sleep_count', Context, 0) + 1.

pg_restart(Pid) ->
    pg_restart(Pid, ?RETRY_SLEEP_MS).

pg_restart(Pid, 0) ->
    gen_server:cast(Pid, 'start');
pg_restart(Pid, Sleep) ->
    timer:sleep(Sleep),
    gen_server:cast(Pid, 'start').

ra_restart(#{restart_checked := 'true'} = Context) -> Context;
ra_restart(#{running := 'true'} = Context) -> Context;
ra_restart(Context0) ->
    Context = maps:put('restart_checked', 'true', Context0),
    RaSystem = ra_system(Context),
    ThisMember = ra_node(Context),
    lager:info("check if a local ra server is running for cluster ~s", [ra_name(Context)]),
    case whereis(ra_name(Context)) of
        'undefined' ->
            lager:info("no local ra server running for cluster ~s, try to restart existing instance", [ra_name(Context)]),
            case ra:restart_server(RaSystem, ThisMember) of
                {'error', Reason}
                  when Reason =:= 'not_started'
                       orelse Reason =:= 'name_not_registered' ->
                    Context;
                'ok' ->
                    lager:info("local ra server for cluster ~s started", [ra_name(Context)]),
                    Context#{running => 'true'
                            ,restarted => 'true'
                            };
                {'error', {'already_started', _}} ->
                    lager:info("local ra server for cluster ~s already started", [ra_name(Context)]),
                    Context#{running => 'true'
                            ,restarted => 'true'
                            };
                _Else ->
                    lager:info("restart server => ~s => ~p", [ra_name(Context), _Else]),
                    Context
            end;
        _ ->
            lager:info("local ra server running, part of cluster ~s", [ra_name(Context)]),
            Context#{running => 'true'
                    ,restarted => 'true'
                    }
    end.

ra_join(#{running := 'true'} = Context) -> Context;
ra_join(#{nodes := []} = Context) -> Context;
ra_join(#{nodes := Nodes} = Context) ->
    case leaders(Context, Nodes) of
        [] -> Context;
        [Leader | _ ] -> do_ra_join(Leader, Context)
    end;
ra_join(Context) -> Context.

do_ra_join(JoinLeader, Context) ->
    Members = [ra_node(Context, JoinLeader)],
    Member = ra_node(Context),
    lager:info("ra cluster not running, try to join it to members => ~p", [Members]),
    case ra:add_member(Members, Member) of
        {'ok', _, Leader} ->
            lager:info("leader ~p confirmed this node has joined ra server cluster ~s", [Leader, ra_name(Context)]),
            RaServerConfig = make_ra_server_config(Context, Member, [Leader]),
            R = ra:start_server(ra_system(Context), RaServerConfig),
            lager:info("server started on cluster ~s with result ~p", [ra_name(Context), R]),
            Context#{running => 'true'};
        {'error', {'no_more_servers_to_try', [{'error', 'already_member'} | _]}} ->
            lager:info("already joined ra server to cluster ~s", [ra_name(Context)]),
            Leader = ra_leaderboard:lookup_leader(ra_name(Context)),
            RaServerConfig = make_ra_server_config(Context, Member, [Leader]),
            R = ra:start_server(ra_system(Context), RaServerConfig),
            lager:info("server started on cluster ~s with result ~p", [ra_name(Context), R]),
            Context#{running => 'true'};
        {'error', {'no_more_servers_to_try', _}} ->
            lager:info("failed to join ~s to cluster ~s", [node(), ra_name(Context)]),
            Context;
        Error ->
            lager:error("failed to add member ~p to ~p for cluster ~s", [Member, Members, ra_name(Context)]),
            throw(Error)
    end.

startup_nodes(Context) ->
    [node() | pg_nodes(Context)].

should_start_ra_cluster(Context) ->
    Nodes = startup_nodes(Context),
    Results = erpc:multicall(Nodes, ?MODULE, 'startup_time', [ra_name(Context)]),
    element(1, hd(lists:keysort(2, lists:zip(Nodes, Results)))) =:= node().

ra_start(#{sleeping := 'true'} = Context) -> Context;
ra_start(#{running := 'true'} = Context) -> Context;
ra_start(Context) ->
    case should_start_ra_cluster(Context) of
        'true' -> do_ra_start(Context);
        'false' -> Context
    end.

do_ra_start(Context) ->
    lager:info("ra cluster ~s not running, try to start it", [ra_name(Context)]),
    Members = [ra_node(Context, node())],
    RaServerConfigs = [make_ra_server_config(Context, Member, Members) || Member <- Members],
    case ra:start_cluster(ra_system(Context), RaServerConfigs) of
        {'ok', Started, _} ->
            lager:debug("started ra server for cluster ~s on ~p", [ra_name(Context), Started]),
            Context#{running => 'true'};
        {'error', 'cluster_not_formed'} ->
            lager:error("failed to start ra server for cluster ~s", [ra_name(Context)]),
            Context
    end.

ra_retry(#{sleeping := 'true'} = Context) -> Context;
ra_retry(#{running := 'true'} = Context) ->
    case is_stable(Context) of
        'true' -> Context;
        'false' -> do_reset(Context)
    end;
ra_retry(Context) ->
    kz_process:spawn(fun pg_restart/1, [self()]),
    maps:without(['sleeping', 'sleep_count'], Context).

is_stable(Context) ->
    case missing_nodes(Context) of
        [] -> 'true';
        Nodes -> check_leader(Context, Nodes)
    end.

filter_leader_fun(Context) ->
    fun({'ok', {_, Node}}) ->
            case ra:members(ra_node(Context, Node), 100) of
                {'ok', Members, {_, LeaderNode}} ->
                    {'true', {Node, LeaderNode, [N || {_, N} <- Members, N =/= node()]}};
                _Other -> 'false'
            end;
       (_) -> 'false'
    end.

leader_nodes(Context, Nodes) ->
    lists:usort(
      lists:filtermap(filter_leader_fun(Context)
                     ,erpc:multicall(Nodes, 'ra_leaderboard', 'lookup_leader', [ra_name(Context)])
                     )
     ).

leader({_Node, LeaderNode, _MemberNodes}) -> LeaderNode.

leaders(Context, Nodes) ->
    lists:usort(lists:map(fun leader/1, leader_nodes(Context, Nodes))).

check_leader(Context, Nodes) ->
    lists:all(check_leader_fun(Context), leader_nodes(Context, Nodes)).

check_leader_fun(Context) ->
    RACount = length(ra_nodes(Context)),
    RALeaderNode = ra_leader_node(Context),
    fun({_Node, LeaderNode, _Members}) when LeaderNode =:= RALeaderNode -> 'true';
       ({_Node, _LeaderNode, Members}) when length(Members) =< RACount -> 'true';
       ({_Node, _LeaderNode, _Members}) ->
            lager:info("node ~s with leader ~s has ~B member while we have ~B, resetting", [_Node, _LeaderNode, length(_Members), RACount]),
            'false'
    end.

ra_leader_node(Context)
  when is_map(Context) ->
    ra_leader_node(ra_leader(Context));
ra_leader_node({_, Node}) -> Node;
ra_leader_node(Node) -> Node.

ra_leader(Context) ->
    ra_leaderboard:lookup_leader(ra_name(Context)).

missing_nodes(Context) ->
    pg_nodes(Context) -- ra_nodes(Context).

ra_nodes(Context) ->
    case ra:members(ra_node(Context)) of
        {'ok', Members, {_, _LeaderNode} = _Leader} ->
            [Node
             || {_, Node} <- Members,
                Node =/= node()
            ];
        _ -> []
    end.

make_ra_server_config(Context, Member, Members) ->
    UId = ra:new_uid(ra_lib:to_binary(ra_name(Context))),
    #{cluster_name => ra_name(Context)
     ,id => Member
     ,uid => UId
     ,initial_members => Members
     ,log_init_args => #{uid => UId}
     ,tick_timeout => tick_timeout(Context)
     ,machine => ra_machine(Context)
     }.

tick_timeout(#{ra_tick_timeout := Tick}) -> Tick;
tick_timeout(_) -> ?TICK_INTERVAL.

ra_machine(#{ra_machine := Machine} = Context) ->
    {'module', Machine, ra_machine_config(Context)}.

ra_machine_config(Context) -> #{store_id => ra_name(Context)}.

server(Name) ->
    erlang:whereis(server_name(Name)).

-spec check(term()) -> 'ok'.
check(Name) ->
    case server(Name) of
        'undefined' -> 'ok';
        Server -> gen_server:cast(Server, 'check')
    end.

do_check(#{sleeping := 'true'} = Context) -> Context;
do_check(#{running := 'true'} = Context) ->
    case is_stable(Context) of
        'true' -> Context;
        'false' -> do_reset(Context)
    end;
do_check(Context) -> Context.

-spec reset(term()) -> 'ok'.
reset(Context) ->
    case server(Context) of
        'undefined' -> 'ok';
        Server -> gen_server:cast(Server, 'reset')
    end.

do_reset(#{running := 'true'} = Context) ->
    _ = ra:stop_server(ra_system(Context), ra_node(Context)),
    _ = ra:force_delete_server(ra_system(Context), ra_node(Context)),
    gen_server:cast(self(), 'start'),
    maps:without(['running'], Context);
do_reset(Context) ->
    _ = ra:force_delete_server(ra_system(Context), ra_node(Context)),
    gen_server:cast(self(), 'start'),
    Context#{trigger_election => 'true'}.

-spec startup_time(term()) -> kz_time:datetime().
startup_time(Name) ->
    gen_server:call(server(Name), 'startup_time').

-spec ra_name(context()) -> atom().
ra_name(#{ra_name := Name}) -> Name;
ra_name(#{name := Name}) -> Name.

-spec ra_node(context()) -> {atom(), node()}.
ra_node(Context) -> ra_node(Context, node()).

-spec ra_node(atom() | context(), node()) -> {atom(), node()}.
ra_node(Context, Node)
  when is_map(Context) ->
    ra_node(ra_name(Context), Node);
ra_node(Name, Node) -> {Name, Node}.

-spec pg_nodes(context()) -> [node()].
pg_nodes(Context) ->
    lists:usort([node(P) || P <- pg_members(Context), node(P) =/= node()]).

pg_members(Context) ->
    pg:get_members(pg_scope(Context), ra_name(Context)).

-spec pg_scope(context()) -> atom().
pg_scope(#{pg_scope := Scope}) -> Scope.

server_name(Context)
  when is_map(Context) ->
    server_name(ra_name(Context));
server_name(Name) ->
    kz_term:to_atom(list_to_binary(["kz_ra_formation_", kz_term:to_binary(Name)]), 'true').
