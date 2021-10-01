-module(kz_events_tests).

-export([do_test/0]).

-spec do_test() -> 'ok'.
do_test() ->
    {'ok', _} = application:ensure_all_started('kazoo_events'),

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
    ?assert('true');
wait_for_events({CallId, {CPid, CRef}=PidRefCallIds, CallCount}=C
               ,{PresenceId, {PPid, PRef}=PidRefPresenceIds, PresCount}=P
               ) ->
    receive
        {'DOWN', CRef, 'process', CPid, _Reason} ->
            io:format(user, "call-id publisher down: ~p~n", [_Reason]),
            wait_for_events(C, P);
        {'DOWN', PRef, 'process', PPid, _Reason} ->
            io:format(user, "presence-id publisher down: ~p~n", [_Reason]),
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
            io:format(user, "event recv: ~p~n", [_Evt]),
            wait_for_events(C, P)
    after 1000 ->
            io:format(user, "timed out:~n~p~n~p~n", [C, P]),
            ?assert('false')
    end.

handle_call_event(CallId, PidRef, Count, Event) ->
    case kz_call_event:call_id(Event) of
        CallId ->
            ?assertEqual(Count, kz_term:to_integer(kz_api:app_version(Event))),
            {CallId, PidRef, Count-1};
        _OtherCallId ->
            {CallId, PidRef, Count}
    end.

handle_presence_event(PresenceId, PidRef, Count, Event) ->
    case kz_json:get_ne_binary_value(<<"Presence-ID">>, Event) of
        PresenceId ->
            ?assertEqual(Count, kz_term:to_integer(kz_api:app_version(Event))),
            {PresenceId, PidRef, Count-1};
        _OtherPresenceId ->
            {PresenceId, PidRef, Count}
    end.

publish_call_ids(_CallIds, 0) -> 'ok';
publish_call_ids(CallIds, PublishCount) ->
    [publish_call_id(CallId, PublishCount) || CallId <- CallIds],
    timer:sleep(100),
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
    [publish_presence_id(PresenceId, PublishCount) || PresenceId <- PresenceIds],
    timer:sleep(100),
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
