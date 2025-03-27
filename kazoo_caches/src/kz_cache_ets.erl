%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc Simple ETS-backed cache. Handles ETS operations
%%% @author James Aimonetti
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_cache_ets).
-behaviour(gen_server).

%%------------------------------------------------------------------------------
%% @doc API functions
%% @end
%%------------------------------------------------------------------------------
-export([start_link/2
        ,pointer_tab/1
        ,monitor_tab/1

        ,store/4
        ,store_async/4

        ,peek/2
        ,fetch/2

        ,erase/2
        ,flush/1

        ,count/5

        ,wait_for_key/3
        ,wait_for_stampede/3
        ,mitigate_stampede/3

        ,mitigating_keys/1
        ]).

-export([expire_objects/1]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-include("kz_caches.hrl").

-define(MONITOR_EXPIRE_MSG, 'monitor_cleanup').

-type state() :: atom().

-spec start_link(atom(), kz_cache:start_options()) -> kz_types:startlink_ret().
start_link(Name, Options) ->
    gen_server:start_link({'local', Name}, ?MODULE, [Name, Options], []).

-spec pointer_tab(atom()) -> atom().
pointer_tab(Name) ->
    to_tab(Name, "_pointers").

-spec monitor_tab(atom()) -> atom().
monitor_tab(Name) ->
    to_tab(Name, "_monitors").

-spec store_options(atom(), kz_cache:start_options()) -> 'ok'.
store_options(Name, Options) ->
    persistent_term:put(to_tab(Name, "_options"), Options).

-spec fetch_options(atom()) -> kz_cache:start_options().
fetch_options(Name) ->
    persistent_term:get(to_tab(Name, "_options"), []).

-spec to_tab(atom(), string()) -> atom().
to_tab(Name, Suffix) ->
    kz_term:to_atom(kz_term:to_list(Name) ++ Suffix, 'true').

-spec store(kz_types:server_ref(), any(), any(), kz_cache:store_options()) -> 'ok' | 'error'.
store(Srv, K, V, Props)  ->
    gen_server:call(Srv, {'store', cache_obj(K, V, Props)}).

-spec store_async(kz_types:server_ref(), any(), any(), kz_term:proplist()) -> 'ok'.
store_async(Srv, K, V, Props) ->
    handle_store(cache_obj(K, V, Props), Srv).
%% gen_server:cast(Srv, {'store', cache_obj(K, V, Props)}).

-spec peek(atom(), any()) ->
          {'ok', any()} |
          {?MITIGATION, pid()} |
          {'error', 'not_found'}.
peek(Srv, Key) ->
    %% since OTP 26, lookup_element/4 is available
    case ets:lookup_element(Srv, Key, #cache_obj.value, 'undefined') of
        'undefined' -> {'error', 'not_found'};
        {?MITIGATION, _Pid}=Mitigation -> Mitigation;
        Value -> {'ok', Value}
    end.

-spec peek_cache_obj(atom(), any()) ->
          {'ok', cache_obj()} |
          {?MITIGATION, pid()} |
          {'error', 'not_found'}.
peek_cache_obj(Srv, Key) ->
    try ets:lookup(Srv, Key) of
        [] -> {'error', 'not_found'};
        [#cache_obj{value={?MITIGATION, _Pid}=Mitigation}] -> Mitigation;
        [#cache_obj{}=CacheObj] -> {'ok', CacheObj}
    catch
        'error':'badarg' ->
            {'error', 'not_found'}
    end.

-spec fetch(atom(), any()) -> {'ok', any()} |
          {'error', 'not_found'} |
          {?MITIGATION, pid()}.
fetch(Srv, Key) ->
    case peek_cache_obj(Srv, Key) of
        {'error', 'not_found'}=E -> E;
        {?MITIGATION, _Pid}=Stampede -> Stampede;
        {'ok', #cache_obj{expires_s='infinity', value=Value}} ->
            {'ok', Value};
        {'ok', #cache_obj{value=Value}=CacheObj} ->
            maybe_bump_timestamp(Srv, Key, CacheObj),
            {'ok', Value}
    end.

maybe_bump_timestamp(Srv, Key, #cache_obj{expires_s=ExpiresS, timestamp_ms=TimestampMs}) ->
    %% if the cache object is not half-way to expiration, don't bump the timestamp
    %% for instance:
    %%   cache_obj{expires_s=10, timestamp_ms=5000}
    %%    - last updated timstamp at 5,000, expires 10s later (so 15,000)
    %%   if fetch() is called anytime before 10,000, don't bump timestamp_ms
    %% for a key being frequently accessed, this cuts down significantly on ETS actions
    NowMs = kz_time:now_ms(),
    ElapsedMs = NowMs - TimestampMs,

    HalfExpiresMs = ExpiresS * ?MILLISECONDS_IN_SECOND / 2,

    case ElapsedMs < HalfExpiresMs of
        'true' -> 'ok';
        'false' ->
            _ = ets:update_element(Srv, Key, {#cache_obj.timestamp_ms, NowMs}),
            'ok'
    end.

-spec erase(atom(), any()) -> 'ok'.
erase(Srv, Key) ->
    case peek(Srv, Key) of
        {'error', 'not_found'} -> 'ok';
        {?MITIGATION, _Pid} -> kz_cache_callbacks:erased_mitigation(Srv, Key);
        {'ok', _} -> kz_cache_callbacks:erased(Srv, Key)
    end.

-spec flush(atom()) -> 'ok'.
flush(Name) ->
    kz_cache_callbacks:flushed(Name, pointer_tab(Name), monitor_tab(Name), fetch_options(Name)).

-spec cache_obj(any(), any(), kz_cache:store_options()) -> cache_obj().
cache_obj(K, V, Props) ->
    #cache_obj{key=K
              ,value=V
              ,expires_s=get_props_expires(Props)
              ,callback=get_props_callback(Props)
              ,origin=get_props_origin(Props)
              ,monitor_pids=get_monitor_pids(Props)
              }.

-spec get_monitor_pids(kz_cache:store_options()) -> [pid()].
get_monitor_pids(Props) ->
    case props:get_value('monitor', Props, 'false') of
        'false' -> [];
        'true' -> [self()];
        Pids when is_list(Pids) ->
            'true' = lists:all(fun is_pid/1, Pids),
            Pids
    end.

-spec count(atom(), any(), any(), any(), any()) -> non_neg_integer().
count(Srv, KeyMatchHead, KeyMatchCondition, ValMatchHead, ValMatchCondition) ->
    MS = lists:foldl(fun update_match_spec/2
                    ,{#cache_obj{_='_'}, [], ['true']}
                    ,[{#cache_obj.key, KeyMatchHead, KeyMatchCondition}
                     ,{#cache_obj.value, ValMatchHead, ValMatchCondition}
                     ]
                    ),
    ets:select_count(Srv, [MS]).

update_match_spec({Index, 'undefined', Condition}, {MatchHead, MatchConditions, MatchBody}) ->
    update_match_spec({Index, '_', Condition}, {MatchHead, MatchConditions, MatchBody});
update_match_spec({Index, Head, 'undefined'}, {MatchHead, MatchConditions, MatchBody}) ->
    {setelement(Index, MatchHead, Head)
    ,MatchConditions
    ,MatchBody
    };
update_match_spec({Index, Head, Condition}, {MatchHead, MatchConditions, MatchBody}) ->
    {setelement(Index, MatchHead, Head)
    ,[Condition | MatchConditions]
    ,MatchBody
    }.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec get_props_expires(kz_cache:store_options()) -> timeout().
get_props_expires(Props) ->
    case props:get_value('expires', Props) of
        'undefined' -> ?EXPIRES;
        'infinity' -> 'infinity';
        Expires when is_integer(Expires)
                     andalso Expires > 0 ->
            Expires
    end.

-spec get_props_callback(kz_cache:store_options()) -> 'undefined' | callback_fun().
get_props_callback(Props) ->
    case props:get_value('callback', Props) of
        'undefined' -> 'undefined';
        Fun when is_function(Fun, 3) -> Fun
    end.

-spec get_props_origin(kz_cache:store_options()) -> 'undefined' | origin_tuple() | origin_tuples().
get_props_origin(Props) -> props:get_value('origin', Props).

-spec wait_for_key(kz_types:server_ref(), any(), pos_integer()) ->
          {'ok', any()} |
          {'error', 'timeout'}.
wait_for_key(Srv, Key, Timeout) when is_integer(Timeout) ->
    WaitFor = Timeout + 100,

    case handle_wait_for_key(Srv, monitor_tab(Srv), Key, Timeout) of
        {'exists', Value} -> {'ok', Value};
        {'ok', Ref} -> wait_for_response(Ref, WaitFor)
    end.

-spec wait_for_stampede(kz_types:server_ref(), any(), pos_integer()) ->
          {'ok', any()} |
          {'error', 'timeout'}.
wait_for_stampede(Srv, Key, Timeout) when is_integer(Timeout) ->
    wait_for_key(Srv, Key, Timeout).

-spec wait_for_response(reference(), timeout()) -> {'ok', any()} |
          {'error', 'timeout'}.
wait_for_response(Ref, WaitFor) ->
    receive
        {'exists', Ref, {'error', _Reason}=Error} ->
            Error;
        {'exists', Ref, Value} ->
            {'ok', Value};
        {'store', Ref, {'error', _Reason}=Error} ->
            Error;
        {'store', Ref, Value} ->
            {'ok', Value};
        {_, Ref, _}=_Other ->
            {'error', 'timeout'}
    after WaitFor ->
            {'error', 'timeout'}
    end.

-spec mitigate_stampede(atom(), any(), kz_cache:store_options()) -> 'ok' | 'error'.
mitigate_stampede(Srv, Key, Options) ->
    CacheObj = cache_obj(Key, {?MITIGATION, self()}, Options),
    case ets:insert_new(Srv, CacheObj) of
        'true' ->
            %% link caller to the cache gen_server in case caller dies
            link(whereis(Srv)),
            'ok';
        'false' -> 'error'
    end.

-spec expire_objects(atom()) -> non_neg_integer().
expire_objects(Name) ->
    kz_cache_callbacks:expire_objects(Name, [pointer_tab(Name), monitor_tab(Name)]).

ets_options() ->
    [{'write_concurrency', 'true'}
    ,{'read_concurrency', 'true'}
    ,{'decentralized_counters', 'true'}
    ].

-spec init([atom() | kz_cache:start_options()]) -> {'ok', state()}.
init([Name, Options]) ->
    process_flag('trap_exit', 'true'),
    _Name = ets:new(Name
                   ,['set', 'public', 'named_table', {'keypos', #cache_obj.key} | ets_options()]
                   ),

    _PointerName = ets:new(pointer_tab(Name)
                          ,['bag', 'public', 'named_table', {'keypos', #cache_obj.key} | ets_options()]
                          ),

    %% the monitor table is only needed rarely, and is the only table
    %% we call ets:info(Tab, size) on. Since we don't really need the
    %% perf boost, don't set `decentralized_counters` to true for this
    %% table. See https://www.erlang.org/docs/26/man/ets#info-2 note
    %% about perf impact on ets:info(Tab, size).
    _MonitorName = ets:new(monitor_tab(Name)
                          ,['bag', 'public', 'named_table', {'keypos', #cache_obj.key}]
                          ),
    store_options(Name, Options),
    {'ok', Name}.

-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call({'store', CacheObj}, _From, Name) ->
    {'reply', handle_store(CacheObj, Name), Name};
handle_call(_Request, _From, Name) ->
    {'noreply', Name}.

-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'store', CacheObj}, Name) ->
    _ = handle_store(CacheObj, Name),
    {'noreply', Name};

handle_cast(_Msg, Name) ->
    {'noreply', Name}.

-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info({'timeout', _Ref, {?MONITOR_EXPIRE_MSG, MonitorRef}}
           ,Name
           ) ->
    _ = kz_process:spawn(fun kz_cache_callbacks:timed_out/2
                        ,[monitor_tab(Name), MonitorRef]
                        ),
    {'noreply', Name};
handle_info({'EXIT', Pid, _Reason}, Name) ->
    kz_process:spawn(fun() -> handle_dead_pid(Name, Pid) end),
    {'noreply', Name};
handle_info(_Info, Name) ->
    ?LOG_INFO("unhandled msg: ~p", [_Info]),
    {'noreply', Name}.

-spec terminate(any(), state()) -> any().
terminate(_Reason, Name) ->
    ets:delete(Name),
    ets:delete(pointer_tab(Name)),
    ets:delete(monitor_tab(Name)),
    lager:debug("terminating ~p", [Name]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

-spec handle_store(cache_obj(), state()) -> 'ok' | 'error'.
handle_store(#cache_obj{key=Key
                       ,value={?MITIGATION, _Pid}
                       }=CacheObj
            ,Name
            ) ->
    case peek(Name, Key) of
        {'error', 'not_found'} ->
            store_cache_obj(CacheObj, Name);
        _Else ->
            'error'
    end;
handle_store(CacheObj, Name) ->
    store_cache_obj(CacheObj, Name).

store_cache_obj(#cache_obj{key=Key
                          ,value=Value
                          ,origin=Origins
                          ,expires_s=Expires
                          ,monitor_pids=Pids
                          }=CacheObj
               ,Name
               ) ->
    kz_cache_callbacks:maybe_log_unlock(Key, "store", peek(Name, Key)),
    'true' = ets:insert(Name, CacheObj#cache_obj{origin='undefined'}),
    kz_cache_listener:add_origin_pointers(Name, CacheObj, Origins),
    kz_process:spawn('kz_cache_callbacks', 'stored', [Name, Key, Value]),
    'ok' = kz_cache_processes:monitor_processes(Name, Key, Pids),

    'ok' = kz_cache_lru:update_expire_period(Name, Expires).

-spec handle_wait_for_key(atom(), atom(), any(), pos_integer()) ->
          {'ok', reference()} |
          {'exists', any()}.
handle_wait_for_key(Name, MonitorName, Key, Timeout) ->
    case peek(Name, Key) of
        {'ok', Value} ->
            {'exists', Value};
        _Else ->
            Ref = add_monitor(Name, MonitorName, Key, Timeout, self()),
            {'ok', Ref}
    end.

add_monitor(Name, MonitorName, Key, Timeout, FromPid) ->
    Ref = make_ref(),
    CacheObj = #cache_obj{key=Key
                         ,value=Ref
                         ,expires_s=Timeout
                         ,callback=monitor_response_fun(FromPid, Ref)
                         },
    'true' = ets:insert(MonitorName, CacheObj),

    _TRef = start_monitor_expire_timer(Name, Timeout, Ref),
    Ref.

-spec monitor_response_fun(pid(), reference()) -> fun().
monitor_response_fun(Pid, Ref) ->
    fun(_, Value, Reason) -> Pid ! {Reason, Ref, Value} end.

-spec start_monitor_expire_timer(kz_types:server_ref(), pos_integer(), reference()) -> reference().
start_monitor_expire_timer(Cache, Timeout, Ref) ->
    erlang:start_timer(Timeout, whereis(Cache), {?MONITOR_EXPIRE_MSG, Ref}).

-spec handle_dead_pid(atom(), pid()) -> non_neg_integer().
handle_dead_pid(Name, Pid) ->
    MatchSpec =
        [{#cache_obj{key='$1', value='$2', _='_'}
         ,[{'=:=', '$2', {'const', {?MITIGATION, Pid}}}]
         ,[{{'$1', '$2'}}]
         }],
    Erased = [erase(Name, Key)
              || {Key, {?MITIGATION, P}} <- ets:select(Name, MatchSpec),
                 not is_process_alive(P)
             ],
    length(Erased).

-spec mitigating_keys(atom()) -> [{any(), pid()}].
mitigating_keys(Name) ->
    MatchSpec =
        [{#cache_obj{key='$1', value='$2', _='_'}
         ,[{'is_record', '$2', ?MITIGATION, 2}]
         ,[{{'$1', '$2'}}]
         }],
    [{Key, Pid} || {Key, {?MITIGATION, Pid}} <- ets:select(Name, MatchSpec)].
