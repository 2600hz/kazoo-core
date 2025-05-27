%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_dataconnection).
-behaviour(gen_server).

-export([start_link/1
        ,start_retries_worker/1
        ,stop/1
        ]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-include("kz_data.hrl").

-record(state, {data_connection :: data_connection()
               ,retry_timer_ref :: reference()
               ,retry_pid_ref :: kz_term:api_pid_ref()
               }).
-type state() :: #state{}.

-define(SERVER, ?MODULE).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server.
%% @end
%%------------------------------------------------------------------------------
-spec start_link(data_connection()) -> kz_types:startlink_ret().
start_link(#data_connection{}=Connection) ->
    gen_server:start_link(?SERVER, [Connection], []).

-spec stop(pid()) -> 'ok'.
stop(Pid) ->
    gen_server:stop(Pid).

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server.
%% @end
%%------------------------------------------------------------------------------
-spec init([data_connection()]) -> {'ok', state()}.
init([Connection]) ->
    self() ! 'maintain_connection',
    {'ok', #state{data_connection=Connection#data_connection{pid=self()}
                 ,retry_timer_ref = start_retry_timer()
                 ,retry_pid_ref = 'undefined'
                 }
    }.

start_retry_timer() ->
    erlang:start_timer(?MILLISECONDS_IN_HOUR, self(), 'retry').

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call(_Request, _From, Connection) ->
    {'reply', {'error', 'not_implemented'}, Connection}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast(_Msg, Connection) ->
    {'noreply', Connection}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info({'timeout', TimerRef, 'retry'}
           ,#state{retry_timer_ref=TimerRef
                  ,retry_pid_ref=PidRef
                  ,data_connection=#data_connection{tag=Tag}
                  }=State
           ) ->
    MaybeNewWorker = maybe_start_retries_worker(PidRef, Tag),
    {'noreply', State#state{retry_timer_ref=start_retry_timer()
                           ,retry_pid_ref=MaybeNewWorker
                           }
    };

handle_info('maintain_connection'
           ,#state{data_connection=#data_connection{connected = 'false'}=Conn}=State
           ) ->
    case try_connection(Conn) of
        {'error', _} ->
            erlang:send_after(?MILLISECONDS_IN_SECOND, self(), 'maintain_connection'),
            {'noreply', State};
        {'ok', C} ->
            self() ! 'maintain_connection',
            {'noreply', State#state{data_connection=connection_established(C)}}
    end;
handle_info('maintain_connection'
           ,#state{data_connection=#data_connection{ready=Ready
                                                   ,server=Server
                                                   ,app=App
                                                   }=Connection
                  }=State
           ) ->
    case App:server_info(Server) of
        {'ok', _} when not Ready ->
            erlang:send_after(5 * ?MILLISECONDS_IN_SECOND, self(), 'maintain_connection'),
            {'noreply', State#state{data_connection=connection_ready(Connection)}};
        {'ok', _} ->
            erlang:send_after(5 * ?MILLISECONDS_IN_SECOND, self(), 'maintain_connection'),
            {'noreply', State};
        _Else ->
            erlang:send_after(?MILLISECONDS_IN_SECOND, self(), 'maintain_connection'),
            {'noreply', State#state{data_connection=reset_connection(Connection)}}
    end;
handle_info(_Info, Connection) ->
    {'noreply', Connection}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_server' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_server' terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _Connection) ->
    lager:debug("couch connection terminating: ~p", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, Connection, _Extra) ->
    {'ok', Connection}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec try_connection(data_connection()) ->  {'ok', data_connection()} | {'error', any()}.
try_connection(#data_connection{app=App, props=Props}=Connection) ->
    try App:new_connection(Props) of
        {'ok', Server} -> {'ok', Connection#data_connection{server=Server}};
        Error -> handle_error(Connection, Error)
    catch
        _:Error -> handle_error(Connection, Error)
    end.

-spec handle_error(data_connection(), tuple()) -> {'error', any()}.
handle_error(#data_connection{app=App, props=Props}, Error) ->
    lager:info("failed to connect with ~s : ~p : ~p", [App, Error, Props]),
    {'error', Error}.

-spec connection_established(data_connection()) -> data_connection().
connection_established(Connection) ->
    Connection#data_connection{connected = 'true'}.

-spec connection_ready(data_connection()) -> data_connection().
connection_ready(Connection) ->
    C = Connection#data_connection{ready = 'true'},
    kz_dataconnections:update(C),
    lager:info("conn ready: ~p", [C]),
    maybe_init(C),
    C.

maybe_init(#data_connection{ready='true', tag = <<"local">>}) ->
    lager:info("trying to create ~s", [?KZ_STORAGE_RETRY]),
    _ = kz_datamgr:db_create(?KZ_STORAGE_RETRY),
    kz_datamgr:revise_views_from_folder(?KZ_STORAGE_RETRY, ?APP);
maybe_init(_) -> 'ok'.

-spec reset_connection(data_connection()) -> data_connection().
reset_connection(Connection) ->
    C = Connection#data_connection{connected = 'false', ready = 'false'},
    %% TODO: this is disabled for the moment to maintain backward
    %% compatibility with couch_mgr which always assumed the connection
    %% was available
    %%    kz_dataconnections:update(C),
    C.

maybe_start_retries_worker('undefined', Tag) ->
    #{others := Others} = kzs_plan:plan(),
    case props:get_value(Tag, Others) of
        'undefined' ->
            lager:warning("no connection found for tag ~s, not retrying", [Tag]),
            'undefined';
        Conn ->
            start_retries_worker(Tag, Conn)
    end;
maybe_start_retries_worker({_Pid, _Ref}=PidRef, _Tag) ->
    lager:debug("retry worker still running in ~p for connection ~s", [_Pid, _Tag]),
    PidRef.

-spec start_retries_worker(kz_term:ne_binary()) -> kz_term:api_pid_ref().
start_retries_worker(Tag) ->
    #{others := Others} = kzs_plan:plan(),
    case props:get_value(Tag, Others) of
        'undefined' ->
            lager:warning("no connection found for tag ~s, not retrying", [Tag]),
            'undefined';
        Conn ->
            start_retries_worker(Tag, Conn)
    end.

start_retries_worker(Tag, Conn) ->
    {_Pid, _Ref}=PidRef = kz_process:spawn_monitor(fun retry_worker/2, [Tag, Conn]),
    lager:debug("started retry worker in ~p", [_Pid]),
    PidRef.

retry_worker(Tag, Conn) ->
    kz_log:put_callid(<<"retry-", Tag/binary>>),
    Node = kz_term:to_binary(node()),
    ViewOptions = [{'startkey', [Node, Tag]}
                  ,{'endkey', [Node, Tag, <<"\ufff0">>]}
                  ,'include_docs'
                  ],

    handle_page(Conn
               ,ViewOptions
               ,kz_datamgr:paginate_results(?KZ_STORAGE_RETRY, <<"storage/retries">>, ViewOptions)
               ).

handle_page(Conn, _ViewOptions, {'ok', Retries, 'undefined'}) ->
    handle_retries(Conn, Retries),
    lager:info("finished handling retries");
handle_page(Conn, ViewOptions, {'ok', Retries, NextStartKey}) ->
    handle_retries(Conn, Retries),
    NewOptions = props:set_value('startkey', NextStartKey, ViewOptions),
    handle_page(Conn
               ,NewOptions
               ,kz_datamgr:paginate_results(?KZ_STORAGE_RETRY, <<"storage/retries">>, NewOptions)
               ).

handle_retries(Conn, Retries) ->
    lists:foreach(fun(Retry) -> handle_retry(Conn, Retry) end
                 ,[kz_json:get_json_value(<<"doc">>, Retry) || Retry <- Retries]
                 ).

handle_retry(Conn, Retry) ->
    DbName = kz_json:get_ne_binary_value(<<"db_name">>, Retry),
    DocId = kz_json:get_ne_binary_value(<<"doc_id">>, Retry),

    case kz_datamgr:open_cache_doc(DbName, DocId) of
        {'error', 'not_found'} -> remove_retry_doc(Retry); % we don't have the data any more, nothing to do
        {'ok', Doc} -> do_retry(Conn, Retry, DbName, kzs_doc:add_conn_rev(Conn, DbName, Doc));
        {'error', _E} -> 'ok'
    end.

do_retry(Conn, Retry, DbName, Doc) ->
    Fun = kz_json:get_atom_value(<<"fun">>, Retry),
    case apply('kzs_doc', Fun, [Conn, DbName, Doc, []]) of
        {'ok', _OK} ->
            remove_retry_doc(Retry),
            lager:debug("successfully retried fun ~s for ~s / ~s: ~p"
                       ,[Fun, DbName, kz_doc:id(Doc), _OK]
                       );
        {'error', 'not_found'}
          when Fun =:= 'do_delete_doc';
               Fun =:= 'do_delete_docs'
               ->
            remove_retry_doc(Retry),
            lager:debug("retry fun ~s failed not_found for ~s / ~s, not retrying"
                       ,[Fun, DbName, kz_doc:id(Doc)]
                       );
        {'error', _E} ->
            lager:debug("retry fun ~s failed ~p for ~s / ~s"
                       ,[Fun, _E, DbName, kz_doc:id(Doc)]
                       )
    end.

remove_retry_doc(Retry) ->
    _Remove = kz_datamgr:del_doc(?KZ_STORAGE_RETRY, kz_doc:id(Retry)),
    lager:debug("removed retry job ~s: ~p", [kz_doc:id(Retry), _Remove]).
