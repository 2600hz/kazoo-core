%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc kapps_controller-esque controller for appex :)
%%% 1. Fetches the listing of available apps for the cluster
%%% 2. Loads the app when requested via kapps_controller
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kappex_controller).
-behaviour(gen_server).

%% start the reader
-export([start_link/0

        ,loaded/0
        ,running/0

        ,add_running/2
        ,stop_running/1

        ,kapp_heartbeat/1
        ]).

%% gen_server callbacks
-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

%% internal usage
-export([load_app/2, unload_app/2]).

-include("appex_client.hrl").

-type external_app() :: atom().

-record(fetch, {app :: atom()
               ,fetch :: kz_term:pid_ref()
               ,froms :: [kz_term:pid_ref()]
               }
       ).
-type fetch() :: #fetch{}.
-type fetches() :: [fetch()].
-type apps() :: #{atom() => #{pid => pid()
                             ,ref => reference()
                             }
                 }.
-type running_pid_ref() :: #{{pid(), reference()} => atom()}.
-record(state, {fetchings = [] :: fetches()
               ,loaded = [] :: kz_term:atoms()
               ,running = #{} :: apps()
               ,running_pid_ref = #{} :: running_pid_ref()
               }).
-type state() :: #state{}.

-define(HTTP_FETCH_TIMEOUT, appex_client_config:http_timeout_s() * ?MILLISECONDS_IN_SECOND).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?MODULE}, ?MODULE, [], []).

-spec loaded() -> kz_term:atoms().
loaded() ->
    gen_server:call(?MODULE, 'loaded').

-spec running() -> kz_term:atoms().
running() ->
    gen_server:call(?MODULE, 'running').

-spec add_running(App::atom(), AppPid::pid()) -> 'ok'.
add_running(App, AppPid) ->
    gen_server:cast(?MODULE, {'add_running', {App, AppPid}}).

-spec stop_running(App::atom()) -> 'ok'.
stop_running(App) ->
    gen_server:cast(?MODULE, {'stop_running', App}).

%% @doc this is run by kapps_controller:load_external_app/1. If this
%% returns 'true', the app is then ensure_started as a
%% locally-installed app would be.
-spec load_app(pid(), external_app()) -> boolean().
load_app(Pid, App) ->
    %% FIXME: maybe remove timeout from here and use timer?
    case appex_client_config:is_enabled()
        andalso appex_client_config:is_configured()
    of
        'true' ->
            gen_server:call(Pid, {'load_app', App}, ?HTTP_FETCH_TIMEOUT);
        'false' ->
            lager:warning("~s is not enabled or configured properly, unable to proceed with app fetch request"
                         ,[?APP_NAME]
                         ),
            'false'
    end.

-spec unload_app(pid(), external_app()) -> 'ok'.
unload_app(Pid, App) ->
    case application:get_env(App, 'kappex_app_mod') of
        {'ok', AppCallback} ->
            _ = appex_app_master:stop_app(App, {AppCallback, []}),
            gen_server:cast(Pid, {'unload_app', App});
        _ ->
            appex_app_master:force_cleanse_app(App),
            gen_server:cast(Pid, {'unload_app', App})
    end.

%% When the local node is building a heartbeat payload, each running
%% kapp is folded over for properties to add to the heartbeat. When
%% kappex loads a kapp, it binds for this kapp heartbeat and will add
%% itself to the properties associated with the kapp.
-spec kapp_heartbeat(kazoo_bindings:fold_results()) -> kazoo_bindings:fold_results().
kapp_heartbeat(Acc) ->
    #whapp_info{roles=Roles}=WhappInfo = props:get_value('info', Acc, #whapp_info{}),
    props:set_value('info', WhappInfo#whapp_info{roles=[<<"kappex">> | Roles]}, Acc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec init(list()) -> {'ok', state()}.
init(_Args) ->
    process_flag('trap_exit', 'true'),
    _LoadBinding = kapps_controller:binding_fetch_app(?MODULE, 'load_app', self()),
    _UnloadBinding = kapps_controller:binding_unload_app(?MODULE, 'unload_app', self()),
    kz_nodes_notify:notify_heartbeat(),
    {'ok', #state{}}.

-spec should_check_node_bindings() -> boolean().
should_check_node_bindings() ->
    appex_client_config:is_configured()
        andalso appex_client_config:is_aio_cluster().

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) ->
          {'reply', any(), state()} |
          {'noreply', state()}.
handle_call('loaded', _From, #state{loaded=Loaded}=State) ->
    {'reply', Loaded, State};
handle_call('running', _From, #state{running_pid_ref=PidRefs}=State) ->
    {'reply', maps:values(PidRefs), State};
handle_call({'load_app', ExternalApp}, From, #state{loaded=LoadedApps}=State) ->
    case fetched_or_fetching(ExternalApp, State) of
        'fetched' ->
            lager:debug("app ~s is already fetched and loaded", [ExternalApp]),
            {'reply', 'true', State};
        'not_fetched' ->
            handle_load_app(ExternalApp, From, State);
        {'fetching', #fetch{fetch=_PidRef, froms=Froms}=Fetch, NewFetchings} ->
            lager:info("app ~s is fetching in ~p", [ExternalApp, _PidRef]),
            {'noreply', State#state{loaded=lists:delete(ExternalApp, LoadedApps)
                                   ,fetchings=[Fetch#fetch{froms=[From|Froms]}|NewFetchings]
                                   }}
    end;
handle_call(_Req, _From, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> {'noreply', state()}.
handle_cast({'add_running', {App, AppPid}}, #state{running=Running
                                                  ,running_pid_ref=PidRefs
                                                  }=State) ->
    _ = kz_nodes_bindings:bind(App, ?MODULE, 'kapp_heartbeat'),
    Ref = erlang:monitor('process', AppPid),
    NewRunning = Running#{App => #{pid => AppPid, ref => Ref}},
    NewPidRefs = PidRefs#{{AppPid, Ref} => App},
    {'noreply', State#state{running=NewRunning, running_pid_ref=NewPidRefs}};
handle_cast({'stop_running', App}, #state{running=Running}=State) ->
    case maps:get(App, Running, 'undefined') of
        'undefined' ->
            'ok';
        #{pid := _Pid, ref := _Ref} ->
            _ = kz_nodes_bindings:unbind(App, ?MODULE, 'kapp_heartbeat'),
            _ = spawn('application', 'stop', [App]),
            {'noreply', State}
    end;
handle_cast({'unload_app', ExternalApp}, #state{loaded=LoadedApps}=State) ->
    {'noreply', State#state{loaded=lists:delete(ExternalApp, LoadedApps)}};
handle_cast({'kz_nodes', {'heartbeat', Node}}, State) ->
    should_check_node_bindings()
        andalso handle_node_heartbeat(Node, node()),
    {'noreply', State};
handle_cast(_Msg, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> {'noreply', state()}.
%% dealing with fetch.app or app stop cleanup
handle_info({'DOWN', _Ref, 'process', _Pid, _Reason}=Req, State) ->
    case handle_fetch_down(Req, State) of
        'no_fetch_app' ->
            case handle_app_stop(Req, State) of
                'no_app_stop' ->
                    {'noreply', State};
                NewState ->
                    {'noreply', NewState}
            end;
        NewState ->
            {'noreply', NewState}
    end;

handle_info(_Msg, State) ->
    lager:debug("unhandled message: ~p", [_Msg]),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_server' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_server' terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, #state{}=_State) ->
    %% FIXME: cancel/kill any fetch/load process
    _ = kapps_controller:unbinding_fetch_app(?MODULE, 'load_app', self()),
    _ = kapps_controller:unbinding_unload_app(?MODULE, 'unload_app', self()),
    lager:debug("terminating: ~p", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.


%%%=============================================================================
%%% Internal Functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec fetched_or_fetching(external_app(), state()) ->
          'fetched' |
          'not_fetched' |
          {'fetching', fetch(), fetches()}.
fetched_or_fetching(ExternalApp, #state{loaded=LoadedApps
                                       ,fetchings=Fetchings
                                       }
                   ) ->
    case lists:keytake(ExternalApp, #fetch.app, Fetchings) of
        'false' ->
            case lists:member(ExternalApp, LoadedApps) of
                'true' ->
                    'fetched';
                'false' ->
                    'not_fetched'
            end;
        {'value', #fetch{}, _NewFetchings}=Fetch ->
            {'fetching', Fetch}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_load_app(external_app(), kz_term:pid_ref(), state()) -> {'noreply', state()}.
handle_load_app(ExternalApp, From, #state{fetchings=Fetchings
                                         ,loaded=Loaded
                                         }=State) ->
    PidRef = start_fetch_process(ExternalApp),
    lager:info("started a fetch process for app ~s in ~p", [ExternalApp, PidRef]),
    Fetch = #fetch{app=ExternalApp, froms=[From], fetch=PidRef},
    {'noreply', State#state{fetchings=lists:usort([Fetch | Fetchings])
                           ,loaded=lists:delete(ExternalApp, Loaded)
                           }}.

-spec start_fetch_process(external_app()) -> kz_term:pid_ref().
start_fetch_process(ExternalApp) ->
    spawn_monitor(
      fun() -> appex_client_client:load_app(ExternalApp) end
     ).

-spec handle_fetch_down(any(), state()) -> 'no_fetch_app' | state().
handle_fetch_down({'DOWN', Ref, 'process', Pid, 'normal'}, #state{fetchings=Fetches
                                                                 ,loaded=Loaded
                                                                 }=State) ->
    case lists:keytake({Pid, Ref}, #fetch.fetch, Fetches) of
        'false' ->
            'no_fetch_app';
        {'value', #fetch{app=App,froms=Froms}, Fetches1} ->
            lager:info("fetch app ~s with pid ~p(~p) finished normally", [App, Pid, Ref]),
            _ = [gen_server:reply(From, 'true') || From <- Froms],
            State#state{fetchings=Fetches1
                       ,loaded=lists:usort([App | Loaded])
                       }
    end;
handle_fetch_down({'DOWN', Ref, 'process', Pid, _Reason}, #state{fetchings=Fetches}=State) ->
    case lists:keytake({Pid, Ref}, #fetch.fetch, Fetches) of
        'false' ->
            'no_fetch_app';
        {'value', #fetch{app=App, froms=Froms}, Fetches1} ->
            lager:info("fetch app ~s with pid ~p(~p) finished abnormally: ~p", [App, Pid, Ref, _Reason]),
            _ = [gen_server:reply(From, 'false') || From <- Froms],
            State#state{fetchings=Fetches1}
    end.

-spec handle_app_stop(any(), state()) -> 'no_app_stop' | state().
handle_app_stop({'DOWN', Ref, 'process', Pid, _Reason}
               ,#state{running=Running
                      ,running_pid_ref=PidRefs
                      ,loaded=Loaded
                      }=State
               ) ->
    case maps:take({Pid, Ref}, PidRefs) of
        'error' ->
            'no_app_stop';
        {App, NewPidRefs} ->
            State#state{running=maps:remove(App, Running)
                       ,running_pid_ref=NewPidRefs
                       ,loaded=lists:delete(App, Loaded)
                       }
    end.

%% don't handle our heartbeat
handle_node_heartbeat(#kz_node{node=Node}, Node) -> 'ok';
handle_node_heartbeat(#kz_node{node=OtherNode
                              ,kapps=OtherKapps
                              }
                     ,_Node
                     ) ->
    OurApps = kapps_controller:running_apps('false'),
    _ = [start_other_app(OtherNode, AppName)
         || {Name, OtherAppInfo} <- OtherKapps,
            AppName <- [kz_term:to_atom(Name, 'true')],
            not lists:member(AppName, OurApps),
            is_kappex_app(OtherAppInfo)
        ],
    'ok'.

is_kappex_app(#whapp_info{roles=Roles}) ->
    lists:member(<<"kappex">>, Roles).

start_other_app(_OtherNode, AppName) ->
    _Pid = kz_process:spawn(fun kapps_controller:start_app/1, [AppName]),
    lager:info("other node ~s running ~s, starting in ~p", [_OtherNode, AppName, _Pid]).
