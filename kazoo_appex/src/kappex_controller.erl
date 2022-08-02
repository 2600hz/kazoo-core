%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
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
-export([load_app/2]).

-include("appex_client.hrl").

-type external_app() :: atom() | {atom(), atom()}.

-record(fetch, {app :: atom()
               ,fetch :: kz_term:pid_ref()
               ,from :: kz_term:pid_ref()
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

-spec load_app(pid(), external_app()) -> boolean().
load_app(Pid, App) ->
    %% FIXME: maybe remove timeout from here and use timer?
    is_process_alive(Pid)
        andalso gen_server:call(Pid, {'load_app', App}, ?HTTP_FETCH_TIMEOUT).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec init(list()) -> {'ok', state()}.
init(_Args) ->
    process_flag('trap_exit', 'true'),
    _Binding = kapps_controller:binding_fetch_app(?MODULE, 'load_app', self()),
    {'ok', #state{}}.

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
    App = external_app(ExternalApp),
    %% FIXME: just like ensure_all_started, ensure the app and all of its deps and deps of dep are fully loaded so when
    %% kapps_controller calls ensure_all_started eveything is loaded up and it won't call appex again.
    %%
    %% The goal here that we ensure the app and all of its deps are recursively resolved and loaded so kapps_controller
    %% won't get an error from erlang that some deps are not loaded. That wass the original error that we are trying to
    %% solve here, because if erlang ssys something s not loaded, erlang would stop eveything that is loaded and
    %% started, and will cause an app cleanup in appex which causing a race condition to stop and fetch/load the app and
    %% its deps.
    %%
    %% - check if app is loading
    %%   - maybe previously someone called load_app??
    %%   - if yes no_reply and add from to loading and let it handle it there
    %%     - make sure we are tracking and have timeout set properly so we don't deadlock
    %%   - maybe even better return loading as error to caller to indicate appex recieved
    %%     duplicated request to start the app?
    %% - check if app is fetching
    %%   - if yes that means the app is already fetching as part of dep resolving for another app
    %%   - add to loadings
    %%     - make sure we don't have deadlock
    %% - check if app itself is loaded
    %%   - if fully loaded:
    %%     - call ensure_all_loaded
    %%   - if not loaded:
    %%     - try to fetch it from appex
    %%     - fetch_resp
    %%     - after fetch call ensure_all_loaded
    %% - ensure_all_loaded: fold over app's applications recursively and check all deps are loaded
    %%   - fetch all not loaded apps one-by-one, fetch_resp and call ensure_all_loaded on them?
    %%   - fetch_resp after each fetch, and before spawning a new fetch check if it is loaded
    case lists:member(App, LoadedApps)
        andalso application:load(App)
    of
        'ok' ->
            lager:debug("app ~s was fetched before, loading it", [App]),
            {'reply', 'true', State#state{loaded=lists:usort([App | LoadedApps])}};
        {'error', {'already_loaded', App}} ->
            lager:debug("app ~s is already fetched and loaded", [App]),
            {'reply', 'true', State#state{loaded=lists:usort([App | LoadedApps])}};
        {'error', _Reason} ->
            lager:debug("app ~s is listed but not loaded: ~p", [App, _Reason]),
            handle_load_app(ExternalApp, From, State);
        'false' ->
            lager:debug("app ~s not loaded, checking listing", [App]),
            handle_load_app(ExternalApp, From, State)
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
    Ref = erlang:monitor('process', AppPid),
    NewRunning = Running#{App => #{pid => AppPid, ref => Ref}},
    NewPidRefs = PidRefs#{{AppPid, Ref} => App},
    {'noreply', State#state{running=NewRunning, running_pid_ref=NewPidRefs}};
handle_cast({'stop_running', App}, #state{running=Running}=State) ->
    case maps:get(App, Running, 'undefined') of
        'undefined' ->
            'ok';
        #{pid := _Pid, ref := _Ref} ->
            _ = spawn('application', 'stop', [App]),
            {'noreply', State}
    end;
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
-spec external_app(external_app()) -> atom().
external_app({_ParentApp, Dep}) -> Dep;
external_app(App) -> App.

-spec external_parent_app(external_app()) -> atom().
external_parent_app({ParentApp, _Dep}) -> ParentApp;
external_parent_app(App) -> App.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_load_app(external_app(), kz_term:pid_ref(), state()) -> {'noreply', state()}.
handle_load_app(ExternalApp, From, #state{fetchings=Fetchings}=State) ->
    App = external_app(ExternalApp),
    ParentApp = external_parent_app(ExternalApp),
    AppName = kz_term:to_binary(App),
    PidRef = start_fetch_process(ExternalApp, From),
    lager:info("starting a fetch process for app ~s (parent: ~s) in ~p", [AppName, ParentApp, PidRef]),
    {'noreply', State#state{fetchings=[#fetch{app=App
                                             ,from=From
                                             ,fetch=PidRef
                                             }
                                       | Fetchings]
                           }}.

-spec start_fetch_process(external_app(), kz_term:pid_ref()) -> kz_term:pid_ref().
start_fetch_process(ExternalApp, From) ->
    ParentApp = external_parent_app(ExternalApp),
    App = external_app(ExternalApp),
    spawn_monitor(
      fun() ->
              case appex_client_client:load_app(ParentApp, App) of
                  {'ok', _Loaded} ->
                      gen_server:reply(From, 'true');
                  {'error', _Reason} ->
                      lager:error("failed to fetch and extract app ~s: ~p", [App, _Reason]),
                      gen_server:reply(From, 'false')
              end
      end
     ).

-spec handle_fetch_down(any(), state()) -> 'no_fetch_app' | state().
handle_fetch_down({'DOWN', Ref, 'process', Pid, 'normal'}, #state{fetchings=Fetches}=State) ->
    case lists:keytake({Pid, Ref}, #fetch.fetch, Fetches) of
        'false' ->
            'no_fetch_app';
        {'value', #fetch{app=App}, Fetches1} ->
            lager:info("fetch app ~s with pid ~p(~p) finished normally", [App, Pid, Ref]),
            State#state{fetchings=Fetches1}
    end;
handle_fetch_down({'DOWN', Ref, 'process', Pid, _Reason}
                   ,#state{fetchings=Fetches
                          ,loaded=Loaded
                          }=State
                   ) ->
    case lists:keytake({Pid, Ref}, #fetch.fetch, Fetches) of
        'false' -> 'no_fetch_app';
        {'value', #fetch{app=App, from=From}, Fetches1} ->
            lager:info("fetch app ~s with pid ~p(~p) finished abnormally: ~p", [App, Pid, Ref, _Reason]),
            gen_server:reply(From, 'false'),
            State#state{fetchings=Fetches1
                       ,loaded=lists:usort([App | Loaded])
                       }
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
