%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
%%% @doc HTTP client for the app exchange
%%% 1. Fetches the listing of available apps for the cluster
%%% 2. Loads the app when requested via kapps_controller
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_client_client).
-behaviour(gen_server).

%% start the reader
-export([start_link/0
        ,refresh_listing/0

        ,listings/0
        ,loaded/0
        ,running/0

        ,add_running/2
        ,stop_running/1

        ,link_cluster/1
        ,unlink_cluster/0
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
-export([controller_fetch_app/2
        ,post_config_to_exchange/0
        ,fetch_license/2
        ]).

-include("appex_client.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").

-type external_app() :: atom() | {atom(), atom()}.

-record(fetch, {app :: atom()
               ,from :: kz_term:pid_ref()
               ,fetch :: kz_term:pid_ref()
               }
       ).
-type fetch() :: #fetch{}.
-type fetches() :: [fetch()].
-type apps() :: #{atom() => #{pid => pid()
                             ,ref => reference()
                             }
                 }.
-type running_pid_ref() :: #{{pid(), reference()} => atom()}.
-record(state, {list_fetch_timer :: kz_term:api_reference()
               ,list_fetch_pid_ref :: kz_term:api_pid_ref()
               ,fetchings = [] :: fetches()
               ,listed = [] :: kz_json:objects()
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

-spec listings() -> kz_json:objects().
listings() ->
    gen_server:call(?MODULE, 'listings').

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

-spec controller_fetch_app(pid(), external_app()) -> boolean().
controller_fetch_app(Pid, App) ->
    is_process_alive(Pid)
        andalso gen_server:call(Pid, {'fetch_app', App}, ?HTTP_FETCH_TIMEOUT).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec init(list()) -> {'ok', state()}.
init(_Args) ->
    process_flag('trap_exit', 'true'),
    _Binding = kapps_controller:binding_fetch_app(?MODULE, 'controller_fetch_app', self()),
    post_config_to_exchange(),
    {'ok', #state{list_fetch_timer=start_fetch_timer(0)}}.

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) ->
          {'reply', boolean() | kz_json:object() | kz_term:atoms(), state()} |
          {'noreply', state()}.
handle_call('listings', _From, #state{listed=Listing}=State) ->
    {'reply', Listing, State};
handle_call('loaded', _From, #state{loaded=Loaded}=State) ->
    {'reply', Loaded, State};
handle_call('running', _From, #state{running_pid_ref=PidRefs}=State) ->
    {'reply', maps:values(PidRefs), State};
handle_call({'fetch_app', App}, From, State) ->
    handle_fetch_app(App, From, State);
handle_call(_Req, _From, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> {'noreply', state()}.
handle_cast('refresh_listing', State) ->
    {'noreply', start_fetch_listing(State)};
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
handle_info({'timeout', FetchRef, 'fetch_listing'}
           ,#state{list_fetch_timer=FetchRef
                  ,list_fetch_pid_ref='undefined'
                  }=State
           ) ->
    {'noreply', start_fetch_listing(State)};
handle_info({'timeout', FetchRef, 'fetch_listing'}
           ,#state{list_fetch_timer=FetchRef
                  ,list_fetch_pid_ref=_FetchPidRef
                  }=State
           ) ->
    lager:info("fetch already in progress: ~p", [_FetchPidRef]),
    {'noreply', State#state{list_fetch_timer=start_fetch_timer()}};
handle_info({'DOWN', Ref, 'process', Pid, 'normal'}
           ,#state{list_fetch_pid_ref={Pid, Ref}}=State
           ) ->
    lager:info("fetch pid ~p(~p) finished", [Pid, Ref]),
    {'noreply', reset_state(State)};
handle_info({'DOWN', Ref, 'process', Pid, _Reason}
           ,#state{list_fetch_pid_ref={Pid, Ref}}=State
           ) ->
    lager:info("fetch pid ~p(~p) finished abnormally: ~p", [Pid, Ref, _Reason]),
    {'noreply', reset_state(State)};
handle_info({'DOWN', _Ref, 'process', _Pid, _Reason}=Req, State) ->
    case handle_fetch_finish(Req, State) of
        'false' ->
            case handle_app_stop(Req, State) of
                'false' ->
                    {'noreply', State};
                NewState ->
                    {'noreply', NewState}
            end;
        NewState ->
            {'noreply', NewState}
    end;
handle_info({'listing', {'ok', Listing}}, State) ->
    %% TODO: do we want preload all apps?
    %% kz_process:spawn(fun fetch_archives/1, [Listing]),
    {'noreply', State#state{listed=Listing}};
handle_info({'listing', {'error', _Reason}}, State) ->
    %% FIXME: bug handle_received_listing, set better timing,
    %% %% handle the error and make sure we are fetching the list on startup
    %% also every hour
    {'noreply', reset_state(State, 10000)}; %% 10seconds
handle_info(_Msg, State) ->
    lager:info("unhandled message: ~p", [_Msg]),
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
    _ = kapps_controller:unbinding_fetch_app(?MODULE, 'controller_fetch_app', self()),
    lager:info("terminating: ~p", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

-spec start_fetch_timer() -> reference().
start_fetch_timer() ->
    start_fetch_timer(appex_client_config:fetch_timer_s()).

-spec start_fetch_timer(non_neg_integer()) -> reference().
start_fetch_timer(FetchS) ->
    erlang:start_timer(FetchS * ?MILLISECONDS_IN_SECOND, self(), 'fetch_listing').

-spec start_fetch_listing(state()) -> state().
start_fetch_listing(State) ->
    PidRef = spawn_monitor(fun() -> fetch_listing(self()) end),
    State#state{list_fetch_pid_ref=PidRef}.

-spec reset_state(state()) -> state().
reset_state(#state{list_fetch_timer=OldRef}=State) ->
    maybe_cancel_timer(OldRef),
    State#state{list_fetch_timer=start_fetch_timer()
               ,list_fetch_pid_ref='undefined'
               }.

-spec reset_state(state(), non_neg_integer()) -> state().
reset_state(#state{list_fetch_timer=OldRef}=State, FetchSeconds) ->
    maybe_cancel_timer(OldRef),
    State#state{list_fetch_timer=start_fetch_timer(FetchSeconds)
               ,list_fetch_pid_ref='undefined'
               }.

-spec maybe_cancel_timer(kz_term:api_reference()) -> 'ok'.
maybe_cancel_timer(Ref) when is_reference(Ref) ->
    erlang:cancel_timer(Ref);
maybe_cancel_timer(_) -> 'ok'.

-spec handle_fetch_finish(any(), state()) -> 'false' | state().
handle_fetch_finish({'DOWN', Ref, 'process', Pid, 'normal'}
                   ,#state{fetchings=Fetches
                          ,loaded=Loaded
                          }=State
                   ) ->
    case lists:keytake({Pid, Ref}, #fetch.fetch, Fetches) of
        'false' ->
            'false';
        {'value', #fetch{app=App, from=_From}, Fetches1} ->
            lager:info("fetch app ~s with pid ~p(~p) finished normally", [App, Pid, Ref]),
            State#state{fetchings=Fetches1
                       ,loaded=[App | Loaded]
                       }
    end;
handle_fetch_finish({'DOWN', Ref, 'process', Pid, _Reason}
                   ,#state{fetchings=Fetches
                          }=State
                   ) ->
    case lists:keytake({Pid, Ref}, #fetch.fetch, Fetches) of
        'false' -> 'false';
        {'value', #fetch{from=From, app=App}, Fetches1} ->
            lager:info("fetch app ~s with pid ~p(~p) finished abnormally: ~p", [App, Pid, Ref, _Reason]),
            gen_server:reply(From, 'false'),
            State#state{fetchings=Fetches1}
    end.

-spec handle_app_stop(any(), state()) -> 'false' | state().
handle_app_stop({'DOWN', Ref, 'process', Pid, _Reason}
               ,#state{running=Running
                      ,running_pid_ref=PidRefs
                      ,loaded=Loaded
                      }=State
               ) ->
    case maps:take({Pid, Ref}, PidRefs) of
        'error' ->
            'false';
        {App, NewPidRefs} ->
            State#state{running=maps:remove(App, Running)
                       ,running_pid_ref=NewPidRefs
                       ,loaded=lists:delete(App, Loaded)
                       }
    end.

-type listing_resp() :: {'ok', kz_json:objects()} |
                        {'error', any()}.

-spec refresh_listing() -> 'ok'.
refresh_listing() ->
    gen_server:cast(?MODULE, 'refresh_listing').

-spec fetch_listing(pid()) -> listing_resp() | {'listing', listing_resp()}.
fetch_listing(ReplyTo) ->
    %% ClusterId = appex_client_config:cluster_id(),
    %% URL = appex_server_url(
    %%         kz_binary:join(
    %%           [<<"api/appex/client">>, ClusterId, <<"packages?core_version=5.2.0">>], <<"/">>
    %%          )
    %%        ),
    %% Headers = appex_server_authorization_header(),
    %% case kz_http:async_req(self(), 'get', URL, Headers, <<>>, []) of
    %%     {'http_req_id', ReqId} ->
    %%         ListingResp = receive_listing(ReqId, #{cluster_id => ClusterId
    %%                                               ,resp_body => <<>>
    %%                                               }),
    %%         reply_to(ReplyTo, ListingResp);
    %%     {'error', _Reason}=Error ->
    %%         lager:error("failed to query ~s: ~p", [URL, _Reason]),
    %%         reply_to(ReplyTo, Error)
    %% end.

    reply_to(ReplyTo, {'ok', []}).

appex_server_authorization_header() ->
    Secret = appex_client_config:cluster_secret(),
    [{<<"authorization">>, <<"APPEX ", Secret/binary>>}].

appex_server_url(Path) ->
    uri_string:resolve(kz_term:to_binary(Path), appex_client_config:app_exchange_url()).

-spec reply_to(pid(), listing_resp()) -> listing_resp() | {'listing', listing_resp()}.
reply_to(Pid, Resp) -> Pid ! {'listing', Resp}.

%% -spec receive_listing(reference(), map()) ->
%%           {'ok', kz_json:objects()} |
%%           {'error', any()}.
%% receive_listing(ReqId, Listing) ->
%%     case receive_response(ReqId, Listing) of
%%         {'continue', Listing1} -> receive_listing(ReqId, Listing1);
%%         {'finished', Listing1} -> handle_received_listing(Listing1);
%%         {'error', _E}=Error -> Error
%%     end.
%%
%% -spec handle_received_listing(map()) ->
%%           {'ok', kz_json:objects()} |
%%           {'error', any()}.
%% handle_received_listing(#{resp_headers:=RespHeaders}=Response) ->
%%     note_request_id(RespHeaders),
%%     handle_received_listing(Response, props:get_value("content-type", RespHeaders)).
%%
%% -spec handle_received_listing(map(), string()) ->
%%           {'ok', kz_json:objects()} |
%%           {'error', any()}.
%% handle_received_listing(#{resp_body:=RespBody
%%                          ,cluster_id:=ClusterId
%%                          }
%%                        ,"application/json"++_
%%                        ) ->
%%     handle_listing_json(ClusterId, kz_json:decode(RespBody));
%% handle_received_listing(Response, _ContentType) ->
%%     lager:warning("unexpected content type ~s", [_ContentType]),
%%     lager:debug("resp: ~p", [Response]),
%%     {'error', 'unknown_content_type'}.
%%
%% -spec handle_listing_json(kz_term:ne_binary(), kz_json:object()) ->
%%           {'ok', kz_json:object()} |
%%           {'error', kz_json:object()}.
%% handle_listing_json(ClusterId, ListingJObj) ->
%%     case {kz_json:get_json_value(<<"error">>, ListingJObj)
%%          ,kz_json:get_list_value(<<"data">>, ListingJObj)
%%          }
%%     of
%%         {'undefined', []} ->
%%             lager:info("no apps, go buy some some!"),
%%             {'ok', []};
%%         {'undefined', Apps} ->
%%             lager:info("found app listing for ~s", [ClusterId]),
%%             {'ok', Apps};
%%         {Status, _Data} ->
%%             lager:info("got error ~p"
%%                       ,[Status]
%%                       ),
%%             {'error', []}
%%     end.

-spec handle_error(any()) -> {'error', 'failed_to_connect' | 'failure'}.
handle_error({'failed_connect',[{'to_address',{_Host,_Port}}
                               ,{'inet',['inet'],_Error}
                               ]
             }) ->
    lager:error("failed to connect to ~s:~b: ~p", [_Host, _Port, _Error]),
    {'error', 'failed_to_connect'};
handle_error(_E) ->
    lager:error("error: ~p", [_E]),
    {'error', 'failure'}.

-spec receive_response(reference(), map()) ->
          {'continue', map()} |
          {'finished', map()} |
          {'redirect', kz_term:api_string()} |
          {'error', any()}.
receive_response(ReqId, #{resp_body := Body}=Listing) ->
    Timeout = ?HTTP_FETCH_TIMEOUT,
    receive
        {'error', Error} ->
            handle_error(Error);
        {'http', {ReqId, {{_HTTP, 404, _RespMsg}
                         ,RespHeaders
                         ,_RespBody
                         }}} ->
            note_request_id(RespHeaders),
            lager:info("failed to find requested app/version"),
            {'error', 'not_found'};
        {'http', {ReqId, {{_HTTP, RespCode, _RespMsg}
                         ,RespHeaders
                         ,_RespBody
                         }}} when RespCode >= 400 ->
            note_request_id(RespHeaders),
            lager:error("failure fetching app: ~p: ~s", [RespCode, _RespBody]),
            {'error', RespCode};
        {'http', {ReqId, {{_HTTP, RespCode, _RespMsg}
                         ,RespHeaders
                         ,_RespBody
                         }}} when 300 =< RespCode
                                  andalso RespCode < 400 ->
            note_request_id(RespHeaders),
            lager:debug("got redirect url for app"),
            {'redirect', kz_http_util:get_resp_header("location", RespHeaders)};
        {'http', {ReqId, {'error', E}}} ->
            handle_error(E);
        {'http', {ReqId, _Msg}} ->
            {'continue', Listing};
        {'http', {ReqId, 'stream_start', RespHeaders}} ->
            note_request_id(RespHeaders),
            receive_response(ReqId, Listing#{resp_headers=>RespHeaders});
        {'http',{ReqId, 'stream', RespBody}} ->
            receive_response(ReqId, Listing#{resp_body=> <<Body/binary, RespBody/binary>>});
        {'http',{ReqId, 'stream_end', _RespHeaders}} ->
            {'finished', Listing};
        _Msg ->
            lager:info("ignoring ~p", [_Msg]),
            receive_response(ReqId, Listing)
    after
        Timeout ->
            lager:error("timed out waiting for http response"),
            {'error', 'timeout'}
    end.

-spec receive_app(reference(), map()) ->
          {'ok', atom()} |
          {'error', any()} |
          {'redirect', kz_term:api_string()}.
receive_app(ReqId, Fetch) ->
    case receive_response(ReqId, Fetch) of
        {'continue', Fetch1} -> receive_response(ReqId, Fetch1);
        {'finished', Fetch1} -> handle_received_app(Fetch1);
        {'redirect', _}=Redirect -> Redirect;
        {'error', _E}=Error -> Error
    end.

-spec handle_received_app(map()) -> {'ok', atom()} | {'error', any()}.
handle_received_app(#{resp_body := Archive
                     ,resp_headers := RespHeaders
                     ,app_name := AppName
                     ,parent_app := ParentApp
                     }) ->
    note_request_id(RespHeaders),
    CT = props:get_value("content-type", RespHeaders),
    try appex_bluepak:load_app(ParentApp, AppName, Archive, CT) of
        {'ok', App} -> {'ok', App};
        {'error', _}=Error -> Error
    catch
        'error':{'badmatch',{'error',{'running',_App}}} ->
            lager:info("~s is already running", [_App]),
            {'error',{'running',_App}};
        _E:_R:ST ->
            lager:error("failed to extract app archive: ~s: ~p", [_E, _R]),
            kz_log:log_stacktrace(ST),
            {'error', 'failed_to_load'}
    end.

-spec handle_fetch_app(external_app(), kz_term:pid_ref(), state()) ->
          {'reply', boolean(), state()} |
          {'noreply', state()}.
handle_fetch_app(ExternalApp, From, #state{loaded=LoadedApps}=State) ->
    App = external_app(ExternalApp),
    case lists:member(App, LoadedApps)
        andalso application:load(App)
    of
        'ok' ->
            lager:debug("app ~s was fetched before, loading it", [App]),
            {'reply', 'true', State};
        {'error', {'already_loaded', App}} ->
            lager:debug("app ~s is already fetched and loaded", [App]),
            {'reply', 'true', State};
        {'error', _Reason} ->
            lager:debug("app ~s is listed but not loaded: ~p", [App, _Reason]),
            handle_load_app(ExternalApp, From, State);
        'false' ->
            lager:debug("app ~s not loaded, checking listing", [App]),
            handle_load_app(ExternalApp, From, State)
    end.

-spec handle_load_app(external_app(), kz_term:pid_ref(), state()) ->
          {'reply', 'false', state()} |
          {'noreply', state()}.
handle_load_app(ExternalApp, From, #state{listed=_ListedApps
                                         ,fetchings=Fetches
                                         }=State) ->
    %% App = external_app(ExternalApp),
    %% AppName = kz_term:to_binary(App),
    %% case [AppMeta
    %%       || AppMeta <- ListedApps,
    %%          AppName =:= kz_json:get_ne_binary_value(<<"name">>, AppMeta)
    %%      ]
    %% of
    %%     [] ->
    %%         lager:info("app ~s is not available in listings", [App]),
    %%         {'reply', 'false', State};
    %%     [AppMeta] ->
    %%         PidRef = start_fetch_app(ExternalApp, AppMeta),
    %%         lager:info("starting fetch app for app ~s in ~p", [AppName, PidRef]),
    %%         {'noreply', State#state{fetches=[#fetch{app=App
    %%                                                ,fetch=PidRef
    %%                                                ,from=From
    %%                                                }
    %%                                         | Fetches
    %%                                         ]}};
    %%     [_|_]=MoreApps ->
    %%         lager:error("FIXME: there are more than one with name ~s: ~p", [AppName, MoreApps]),
    %%         {'noreply', 'false', State}
    %% end.
    App = external_app(ExternalApp),
    AppName = kz_term:to_binary(App),
    PidRef = start_fetch_app(ExternalApp, From, kz_json:new()),
    lager:info("starting fetch app for app ~s in ~p", [AppName, PidRef]),
    {'noreply', State#state{fetchings=[#fetch{app=App
                                             ,fetch=PidRef
                                             ,from=From
                                             }
                                      | Fetches
                                      ]}}.

-spec external_app(external_app()) -> atom().
external_app({_ParentApp, Dep}) -> Dep;
external_app(App) -> App.

-spec external_parent_app(external_app()) -> atom().
external_parent_app({ParentApp, _Dep}) -> ParentApp;
external_parent_app(App) -> App.

-spec start_fetch_app(external_app(), kz_term:pid_ref(), kz_json:object()) -> kz_term:pid_ref().
start_fetch_app(ExternalApp, From, AppMeta) ->
    spawn_monitor(
      fun() ->
              internal_fetch_app_result(fetch_app(ExternalApp, AppMeta), external_app(ExternalApp), From)
      end
     ).

-spec fetch_app(external_app(), kz_json:object()) ->
          {'ok', atom()} |
          {'error', any()}.
fetch_app(ExternalApp, AppMeta) ->
    ClusterId = appex_client_config:cluster_id(),
    Headers = fetch_app_headers(),

    App = external_app(ExternalApp),
    ParentApp = external_parent_app(ExternalApp),

    %% Link = kz_json:get_ne_binary_value(<<"link">>, AppMeta),
    AppLink = app_link(ClusterId, ExternalApp),

    not kz_term:is_ne_binary(AppLink)
        andalso throw({'error', 'no_app_link'}),

    Url = appex_server_url([<<"api/">>, AppLink]),

    lager:debug("fetching app ~s (as dependency for ~s)", [App, ParentApp]),
    case kz_http:async_req(self(), 'get', Url, Headers, <<>>, fetch_app_options()) of
        {'http_req_id', ReqId} ->
            FetchParams = #{cluster_id => ClusterId
                           ,resp_body => <<>>
                           ,start => kz_time:now()
                           ,app_name => external_app(ExternalApp)
                           ,app_meta => AppMeta
                           ,parent_app => ParentApp
                           },
            maybe_redirect(receive_app(ReqId, FetchParams), FetchParams);
        {'error', _Reason}=Error ->
            lager:error("failed to query for ~s: ~p", [AppLink, _Reason]),
            Error
    end.

-spec fetch_app_options() -> kz_term:proplist().
fetch_app_options() ->
    %% SSLOptions = lists:foldl(fun(F, Acc) -> F(Acc) end
    %%                         ,[]
    %%                         ,[fun cacert/1]
    %%                         ),
    %% [{'ssl', SSLOptions}
    [{'timeout', ?HTTP_FETCH_TIMEOUT}
    ,{'connect_timeout', 30 * ?MILLISECONDS_IN_SECOND}
    ,{'autoredirect', 'false'}
    ].

%% -spec cacert(kz_term:proplist()) -> kz_term:proplist().
%% cacert(Acc) ->
%%     case application:get_env('appex_client', 'cacert') of
%%         'undefined' -> Acc;
%%         CACert ->
%%             lager:debug("including server cert from .app"),
%%             [{'cacerts', [CACert]} | Acc]
%%     end.

-spec maybe_redirect({'ok', atom()} | {'error', any()} | {'redirect', kz_term:api_string()}, map()) ->
          {'ok', atom()} |
          {'error', any()}.
maybe_redirect({'redirect', 'undefined'}, _) ->
    lager:error("redirect has no location url"),
    {'error', "bad_redirect"};
maybe_redirect({'redirect', LocationUrl}, #{app_name := AppName}=FetchParams) ->
    case kz_http:async_req(self(), 'get', LocationUrl) of
        {'http_req_id', ReqId} ->
            receive_app(ReqId, FetchParams);
        {'error', _Reason}=Error ->
            lager:error("failed to query for ~s: ~p", [AppName, _Reason]),
            Error
    end;
maybe_redirect(Other, _) ->
    Other.

-spec fetch_app_headers() -> kz_term:proplist().
fetch_app_headers() ->
    props:filter_undefined(
      [{<<"x-appex-kz-version">>, get_node_version(fun kapps_util:kazoo_version/0)}
      ,{<<"x-appex-mui-version">>, get_node_version(fun kapps_util:monsterui_version/0)}
      ,{<<"x-appex-commland-version">>, get_node_version(fun kapps_util:commland_version/0)}
      ,{<<"x-appex-meta-kazoo-version">>, get_node_version(fun kapps_util:meta_kazoo_version/0)}
      ,{<<"accept">>, kz_binary:join(
                        [<<"application/vnd.appex+", Suffix/binary>>
                             || Suffix <- [<<"kazoo">>, <<"monster">>, <<"commland">>]
                        ]
                       ,<<", ">>
                       )
       }
      | appex_server_authorization_header()
      ]
     ).

-spec get_node_version(function()) -> kz_term:api_ne_binary().
get_node_version(Fun) ->
    try Fun()
    catch
        _:_:_ ->
            'undefined'
    end.

app_link(ClusterId, {ParentApp, App}) ->
    kz_binary:join([<<"appex/client">>, ClusterId, <<"packages">>, ParentApp, App], <<"/">>);
app_link(ClusterId, App) ->
    kz_binary:join([<<"appex/client">>, ClusterId, <<"packages">>, App], <<"/">>).

internal_fetch_app_result({'error', _Reason}, App, From) ->
    lager:error("failed to fetch and extract app ~s: ~p", [App, _Reason]),
    gen_server:reply(From, 'false');
internal_fetch_app_result({'ok', _App}, _, From) ->
    gen_server:reply(From, 'true').

-spec note_request_id(kz_term:proplist()) -> 'ok'.
note_request_id(RespHeaders) ->
    RequestId = kz_http_util:get_resp_header("x-request-id", RespHeaders),
    kz_log:put_callid(kz_term:to_binary(RequestId)).

-spec post_config_to_exchange() -> 'ok'.
post_config_to_exchange() ->
    %% ClusterId = appex_client_config:cluster_id(),
    %% URL = kz_binary:join([appex_client_config:app_exchange_url(), <<"client">>, <<"config">>], <<"/">>),

    %% Headers = [{"Authorization", authorization(ClusterId, <<"client/config">>)}],
    %% case kz_http:post(URL, Headers, config_body(), req_options()) of
    %%     {'ok', 200, _RespHeaders, RespBody} ->
    %%         lager:info("posted client config: ~s", [RespBody]);
    %%     _Resp ->
    %%         lager:info("client config error: ~p", [_Resp])
    %% end.
    lager:info("appex client is pretending is uploading config to server").

%% -spec config_body() -> iodata().
%% config_body() ->
%%     ConfigJObj = configs(),
%%     kz_json:encode(ConfigJObj).
%%
%% -spec configs() -> kz_json:object().
%% configs() ->
%%     appex_client_config:system_configs('true').

-spec fetch_license(atom(), atom()) ->
          {'ok', kz_json:object()} |
          {'error', kz_term:ne_binary() | kz_json:object()}.
fetch_license(_, 'undefined') ->
    {'error', <<"no app name">>};
fetch_license(ParentApp, App) ->
    AppName = kz_term:to_binary(App),
    Headers = appex_server_authorization_header(),
    ClusterId = appex_client_config:cluster_id(),
    URL = fetch_license_url(ClusterId, kz_term:to_binary(ParentApp), AppName),
    case kz_http:get(URL, Headers) of
        {'ok', Code, _RespHeaders, RespBody} when Code =< 400 ->
            JObj = kz_json:decode(RespBody, decode_error(Code)),
            case kz_json:get_value(<<"error">>, JObj) of
                'undefined' ->
                    case kz_json:get_value(<<"data">>, JObj) of
                        'null' -> {'error', <<"no license">>};
                        'undefined' -> {'error', <<"no license">>};
                        Data -> {'ok', kz_json:get_json_value(AppName, Data, Data)}
                    end;
                _Error ->
                    lager:info("can not get license for app ~p: ", [AppName, _Error]),
                    {'error', <<"error to get license">>}
            end;
        {'ok', _Code, _RespHeaders, RespBody} ->
            Err = kz_json:get_value(<<"error">>, RespBody, "InternalServerError"),
            lager:debug("unexpected code ~b when getting license for app ~s: ~p", [_Code, AppName, Err]),
            {'error', <<"error to get license">>};
        {'error', _} ->
            {'error', <<"can not connect to server">>}
    end.

fetch_license_url(ClusterId, AppName, AppName) ->
    appex_server_url([kz_binary:join([<<"api/appex/license">>, ClusterId, <<"packages">>, AppName], <<"/">>)]);
fetch_license_url(ClusterId, ParentApp, AppName) ->
    appex_server_url([kz_binary:join([<<"api/appex/license">>, ClusterId, <<"packages">>, ParentApp, AppName], <<"/">>)]).

-spec link_cluster(kz_json:object()) ->
          {'ok' | 'error', kz_json:object()}.
link_cluster(ReqData) ->
    Secret = kz_json:get_ne_binary_value(<<"access_code">>, ReqData, <<>>),
    Headers = [{<<"authorization">>, <<"APPEX-LINK ", Secret/binary>>}
              ,{<<"content-type">>, <<"application/json">>}
              ],
    Payload = link_payload(ReqData),
    URL = appex_server_url([<<"api/appex/cluster">>]),
    case kz_http:post(URL, Headers, kz_json:encode(Payload)) of
        {'ok', Code, _RespHeaders, RespBody} ->
            Body = kz_json:decode(RespBody, decode_error(Code)),
            case kz_json:get_value(<<"error">>, Body) of
                'undefined' ->
                    process_link_cluster(ReqData, Body);
                Error ->
                    {'error', Error}
            end;
        {'error', _Reason} ->
            lager:debug("failed to connect to appex server: ~p", [_Reason]),
            {'error', kz_json:from_list(
                        [{<<"name">>, <<"NetworkError">>}
                        ,{<<"message">>, <<"Can not connect to server">>}
                        ]
                       )
            }
    end.

process_link_cluster(ReqData, Body) ->
    ShouldRestart = kz_json:is_true(<<"restart_appex_client">>, ReqData),
    case kz_json:get_ne_json_value([<<"data">>, <<"attributes">>], Body) of
        'undefined' ->
            lager:debug("git bad response data from appex server: undefined"),
            internal_server_error();
        Data ->
            Secret = kz_json:get_ne_binary_value(<<"cluster_secret">>, Data),
            _ = appex_client_config:set_cluster_secret(Secret),
            maybe_restart_appex_client(ShouldRestart),
            {'ok', kz_json:delete_key(<<"cluster_secret">>, Data)}
    end.

maybe_restart_appex_client('true') ->
    Restart = fun() ->
                      _ = application:stop(?APP),
                      application:start(?APP)
              end,
    _ = spawn(Restart),
    'ok';
maybe_restart_appex_client('false') ->
    'ok'.

internal_server_error() ->
    {'error', kz_json:from_list(
                [{<<"status">>, 500}
                ,{<<"name">>, <<"InternalServerError">>}
                ]
               )}.

link_payload(JObj) ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),
    {'ok', MasterDoc} = kzd_accounts:fetch(MasterAccountId),
    DefaultName = kz_binary:join([kzd_accounts:name(MasterDoc), <<"'s Cluster">>], <<" ">>),
    ClusterName = kz_json:get_ne_binary_value(<<"name">>, JObj, DefaultName),
    Data = kz_json:from_list(
             [{<<"cluster_id">>, kzd_cluster:id()}
             ,{<<"name">>, ClusterName}
             ,{<<"master_account_id">>, MasterAccountId}
             ,{<<"master_account_name">>, kzd_accounts:name(MasterDoc)}
             ,{<<"kazooVersion">>, kapps_util:meta_kazoo_version()}
             ]
            ),
    kz_json:from_list([{<<"data">>, Data}]).

-spec unlink_cluster() ->
          {'ok', kz_json:object()} |
          {'ok' | 'error', kz_json:object()}.
unlink_cluster() ->
    Headers = appex_server_authorization_header(),
    ClusterId = appex_client_config:cluster_id(),
    URL = appex_server_url(
            [kz_binary:join(
               [<<"api/appex/cluster">>, ClusterId], <<"/">>
              )
            ]
           ),
    case kz_http:delete(URL, Headers) of
        {'ok', 401, _RespHeaders, _RespBody} ->
            %% in case you unlinked the cluster directly from marketplace portal and want to re-link the cluster again
            %% using mui
            lager:debug("got 401 when unlinking cluster, considering the cluster is already unlinked from marketplace"),
            %% don't stop kazoo_appex to let it clean out apps when they stop
            _ = appex_client_config:set_cluster_secret('null'),
            {'ok', kz_json:new()};
        {'ok', Code, _RespHeaders, RespBody} ->
            Body = kz_json:decode(RespBody, decode_error(Code)),
            case kz_json:get_value(<<"error">>, Body) of
                'undefined' ->
                    process_unlink_cluster(Body);
                Error ->
                    {'error', Error}
            end;
        {'error', _Reason} ->
            lager:debug("failed to connect to appex server: ~p", [_Reason]),
            {'error', kz_json:from_list(
                        [{<<"name">>, <<"NetworkError">>}
                        ,{<<"message">>, <<"Can not connect to server">>}
                        ]
                       )
            }
    end.

process_unlink_cluster(Body) ->
    case kz_json:get_ne_json_value([<<"data">>, <<"attributes">>], Body) of
        'undefined' ->
            lager:debug("git bad response data from appex server: undefined"),
            internal_server_error();
        Data ->
            %% don't stop kazoo_appex to let it clean out apps when they stop
            _ = appex_client_config:set_cluster_secret('null'),
            {'ok', kz_json:delete_key(<<"cluster_secret">>, Data)}
    end.

decode_error(Code) ->
    [{'default'
     ,kz_json:from_list(
        [{<<"status">>, Code}
        ,{<<"name">>, <<"InternalServerError">>}
        ]
       )
     }
    ].
