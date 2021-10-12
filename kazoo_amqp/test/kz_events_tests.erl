-module(kz_events_tests).

-export([check_events/0]).

-export([check_events_genl/0
        ,genl/1
        ,init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,handle_event/2
        ,code_change/3
        ,terminate/2
        ]).

-spec check_events() -> boolean().
check_events() ->
    {'ok', _} = application:ensure_all_started('kazoo_amqp'),

    CallId = kz_binary:rand_hex(6),
    OtherCallId = kz_binary:rand_hex(6),

    PresenceId = list_to_binary([kz_binary:rand_hex(6), "@", kz_binary:rand_hex(6)]),
    OtherPresenceId = list_to_binary([kz_binary:rand_hex(6), "@", kz_binary:rand_hex(6)]),

    PublishCount = 10,

    'ok' = kz_events:bind_call_id(CallId),
    'ok' = kz_events:bind_presence_id(PresenceId),

    PidRefCallIds = kz_process:spawn_monitor(fun publish_call_ids/2
                                            ,[[CallId, OtherCallId], PublishCount]
                                            ),
    PidRefPresenceIds = kz_process:spawn_monitor(fun publish_presence_ids/2
                                                ,[[PresenceId, OtherPresenceId], PublishCount]
                                                ),

    wait_for_events({CallId, PidRefCallIds, PublishCount}
                   ,{PresenceId, PidRefPresenceIds, PublishCount}
                   ).

wait_for_events({CallId, _, 0}
               ,{PresenceId, _, 0}
               ) ->
    io:format(user, "done for call ~s and presence ~s~n", [CallId, PresenceId]),
    'true';
wait_for_events({CallId, {CPid, CRef}=PidRefCallIds, CallCount}=C
               ,{PresenceId, {PPid, PRef}=PidRefPresenceIds, PresCount}=P
               ) ->
    receive
        {'DOWN', CRef, 'process', CPid, _Reason} ->
            lager:info("call-id publisher down: ~p~n", [_Reason]),
            wait_for_events(C, P);
        {'DOWN', PRef, 'process', PPid, _Reason} ->
            lager:info("presence-id publisher down: ~p~n", [_Reason]),
            wait_for_events(C, P);
        {'kapi', {{_Exchange, _RoutingKey, _BasicDeliver}
                 ,{'call_event', 'CHANNEL_CREATE'}
                 ,CallEventJObj
                 }
        } ->
            wait_for_events(handle_call_event(CallId, PidRefCallIds, CallCount, CallEventJObj)
                           ,P
                           );
        {'kapi', {{_Exchange, _RoutingKey, _BasicDeliver}
                 ,{'presence', 'update'}
                 ,PresenceEventJObj
                 }
        } ->
            wait_for_events(C
                           ,handle_presence_event(PresenceId, PidRefPresenceIds, PresCount, PresenceEventJObj)
                           );
        _Evt ->
            lager:info("event recv: ~p~n", [_Evt]),
            wait_for_events(C, P)
    after 1000 ->
            lager:info("timed out:~n~p~n~p~n", [C, P]),
            'false'
    end.

handle_call_event(CallId, PidRef, Count, Event) ->
    case kz_call_event:call_id(Event) of
        CallId ->
            Count = kz_term:to_integer(kz_api:app_version(Event)),
            {CallId, PidRef, Count-1};
        _OtherCallId ->
            {CallId, PidRef, Count}
    end.

handle_presence_event(PresenceId, PidRef, Count, Event) ->
    case kz_json:get_ne_binary_value(<<"Presence-ID">>, Event) of
        PresenceId ->
            Count = kz_term:to_integer(kz_api:app_version(Event)),
            {PresenceId, PidRef, Count-1};
        _OtherPresenceId ->
            {PresenceId, PidRef, Count}
    end.

publish_call_ids(_CallIds, 0) -> 'ok';
publish_call_ids(CallIds, PublishCount) ->
    timer:sleep(100),
    _ = [publish_call_id(CallId, PublishCount) || CallId <- CallIds],
    lager:info("published call events ~p: ~p~n", [CallIds, PublishCount]),
    publish_call_ids(CallIds, PublishCount-1).

publish_call_id(CallId, PublishCount) ->
    Event = [{<<"Call-ID">>, CallId}
            ,{<<"Event-Name">>, <<"CHANNEL_CREATE">>}
            ,{<<"Event-Category">>, <<"call_event">>}
            ,{<<"From">>, list_to_binary([pid_to_list(self()), "@", net_adm:localhost()])}
            ,{<<"To">>, list_to_binary([integer_to_list(PublishCount), "@", net_adm:localhost()])}
            | kz_api:default_headers(<<?MODULE_STRING>>, integer_to_binary(PublishCount))
            ],
    kz_amqp_worker:cast(Event, fun kapi_call:publish_event/1).

publish_presence_ids(_PresenceIds, 0) -> 'ok';
publish_presence_ids(PresenceIds, PublishCount) ->
    _ = [publish_presence_id(PresenceId, PublishCount) || PresenceId <- PresenceIds],
    timer:sleep(100),
    lager:info("published presence events ~p: ~p~n", [PresenceIds, PublishCount]),
    publish_presence_ids(PresenceIds, PublishCount-1).

publish_presence_id(PresenceId, PublishCount) ->
    Event = [{<<"Presence-ID">>, PresenceId}
            ,{<<"Event-Name">>, <<"update">>}
            ,{<<"Event-Category">>, <<"presence">>}
            ,{<<"State">>, <<"trying">>}
            ,{<<"Call-ID">>, list_to_binary([integer_to_list(PublishCount), "@", net_adm:localhost()])}
            | kz_api:default_headers(<<?MODULE_STRING>>, integer_to_binary(PublishCount))
            ],
    kz_amqp_worker:cast(Event, fun kapi_presence:publish_update/1).

-spec check_events_genl() -> 'ok'.
check_events_genl() ->
    PidRef = proc_lib:spawn_opt(?MODULE, 'genl', [self()], ['monitor']),
    wait_for_pid(PidRef).

wait_for_pid({Pid, Ref}) ->
    receive
        {'DOWN', Ref, 'process', Pid, Reason} ->
            lager:info("genl ~p finished: ~p~n", [Pid, Reason])
    after 15000 ->
            lager:info("genl ~p timed out~n", [Pid]),
            exit(Pid, 'normal')
    end.

-spec genl(pid()) -> no_return().
genl(Parent) ->
    {'ok', _} = application:ensure_all_started('kazoo_amqp'),

    CallId = kz_binary:rand_hex(6),
    PresenceId = list_to_binary([kz_binary:rand_hex(6), "@", kz_binary:rand_hex(6)]),
    PublishCount = 10,

    proc_lib:init_ack(Parent, {'ok', self()}),

    gen_listener:enter_loop(?MODULE, [{'bindings', [{'call', [{'callid', CallId}
                                                             ,'pooled'
                                                             ]
                                                    }
                                                   ,{'presence', [{'presence-id', PresenceId}
                                                                 ,'pooled'
                                                                 ]
                                                    }
                                                   ]}
                                     ,{'responders', []}
                                     ,{'queue_name', <<>>}
                                     ]
                           ,#{calls => {CallId, 'undefined', PublishCount}
                             ,presence => {PresenceId, 'undefined', PublishCount}
                             }
                           ).

-spec init(map()) -> {'ok', map()}.
init(Map) ->
    {'ok', Map}.

-spec handle_call(any(), any(), map()) -> {'noreply', map()}.
handle_call(_Call, _From, State) ->
    {'noreply', State}.

-spec handle_cast(any(), map()) -> {'noreply', map()}.
handle_cast({'gen_listener', {'pooled_binding', 'call'}}
           ,#{calls := {CallId, _, PublishCount}}=State
           ) ->
    OtherCallId = kz_binary:rand_hex(6),

    PidRefCallIds = kz_process:spawn_monitor(fun publish_call_ids/2
                                            ,[[CallId, OtherCallId], PublishCount]
                                            ),
    {'noreply', State#{calls => {CallId, PidRefCallIds, PublishCount}}};
handle_cast({'gen_listener', {'pooled_binding', 'presence'}}
           ,#{presence := {PresenceId, _, PublishCount}}=State
           ) ->
    OtherPresenceId = list_to_binary([kz_binary:rand_hex(6), "@", kz_binary:rand_hex(6)]),
    PidRefPresenceIds = kz_process:spawn_monitor(fun publish_presence_ids/2
                                                ,[[PresenceId, OtherPresenceId], PublishCount]
                                                ),
    {'noreply', State#{presence => {PresenceId, PidRefPresenceIds, PublishCount}}};
handle_cast(_Cast, State) ->
    lager:info("cast: ~p", [_Cast]),
    {'noreply', State}.

-spec handle_info(any(), map()) -> {'noreply', map()}.
handle_info('stop', #{calls := {_, _, 0}
                     ,presence := {_, _, 0}
                     }=State) ->
    {'stop', 'normal', State};
handle_info('stop', State) ->
    {'stop', 'failure', State};
handle_info({'DOWN', Ref, 'process', Pid, 'normal'}
           ,#{calls := {CallId, {Pid, Ref}, PublishCount}}=State
           ) ->
    lager:info("call events ~p is down, we got ~p left for ~s~n", [Pid, PublishCount, CallId]),
    {'noreply', State};
handle_info({'DOWN', Ref, 'process', Pid, 'normal'}
           ,#{presence := {PresenceId, {Pid, Ref}, PublishCount}}=State
           ) ->
    lager:info("presence events ~p is down, we got ~p left for ~s~n", [Pid, PublishCount, PresenceId]),
    {'noreply', State};
handle_info(_Info, State) ->
    lager:info("recv message ~p~n ~p~n", [_Info, State]),
    {'noreply', State}.

-spec handle_event(kz_json:object(), map()) -> {'ignore', map()}.
handle_event(Evt, State) ->
    lager:info("recv event ~p~n", [Evt]),
    {'ignore', note_event(Evt, State)}.

note_event(Evt, State) ->
    note_event(Evt, State, kz_api:event_category(Evt)).

note_event(Evt
          ,#{calls := {CallId, PidRefCallIds, PublishCount}
            ,presence := {_, _, PPublishCount}
            }=State
          ,<<"call_event">>
          ) ->
    case kz_api:call_id(Evt) of
        CallId when PublishCount =:= 1, PPublishCount =:= 0 ->
            lager:info("recv all call events for ~s~n", [CallId]),
            self() ! 'stop',
            State#{calls := {CallId, PidRefCallIds, 0}};
        CallId ->
            lager:info("call: ~p~n", [PublishCount]),
            State#{calls => {CallId, PidRefCallIds, PublishCount-1}};
        _CallId ->
            lager:info("ignoring call event for ~s~n", [_CallId]),
            State
    end;
note_event(Evt
          ,#{presence := {PresenceId, PidRefPresenceIds, PublishCount}
            ,calls := {_, _, CPublishCount}
            }=State
          ,<<"presence">>
          ) ->
    case kz_json:get_ne_binary_value(<<"Presence-ID">>, Evt) of
        PresenceId when PublishCount =:= 1, CPublishCount =:= 0 ->
            lager:info("recv all presence events for ~s~n", [PresenceId]),
            self() ! 'stop',
            State#{presence := {PresenceId, PidRefPresenceIds, 0}};
        PresenceId ->
            lager:info("presence: ~p~n", [PublishCount]),
            State#{presence => {PresenceId, PidRefPresenceIds, PublishCount-1}};
        _PresenceId ->
            lager:info("ignoring presence event for ~s~n", [_PresenceId]),
            State
    end.

-spec code_change(any(), map(), any()) -> {'ok', map()}.
code_change(_OldVersion, State, _Extra) ->
    {'ok', State}.

-spec terminate(any(), map()) -> 'ok'.
terminate(_Reason, _State) -> lager:info("terminated at ~p~n", [_State]).
