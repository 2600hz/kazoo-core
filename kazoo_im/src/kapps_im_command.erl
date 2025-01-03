%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_im_command).

-export([send_sms/2, send_sms/3, send_sms/4]).

-export([relay_event/2, relay_event/3]).

-export([default_collect_timeout/0
        ,default_message_timeout/0
        ,default_application_timeout/0
        ]).

-include("kapps_im_command.hrl").

-type im() :: kapps_im:im().

-define(CONFIG_CAT, <<"sms_command">>).

-define(DEFAULT_COLLECT_TIMEOUT
       ,kapps_config:get_integer(?CONFIG_CAT, <<"collect_timeout">>, 60 * ?MILLISECONDS_IN_SECOND)
       ).

-define(DEFAULT_MESSAGE_TIMEOUT, kapps_config:get_integer(?CONFIG_CAT, <<"message_timeout">>, 60 * ?MILLISECONDS_IN_SECOND)).

-define(DEFAULT_APPLICATION_TIMEOUT
       ,kapps_config:get_integer(?CONFIG_CAT, <<"application_timeout">>, 500 * ?MILLISECONDS_IN_SECOND)
       ).
-define(DEFAULT_STRATEGY, <<"single">>).

-define(ATOM(X), kz_term:to_atom(X, 'true')).
-define(SMS_POOL(A,B,C), ?ATOM(<<A/binary, "_", B/binary, "_", C/binary>>) ).

-define(SMS_DEFAULT_OUTBOUND_OPTIONS
       ,kz_json:from_list([{<<"delivery_mode">>, 2}
                          ,{<<"mandatory">>, 'true'}
                          ])
       ).
-define(SMS_OUTBOUND_OPTIONS_KEY, [<<"outbound">>, <<"options">>]).
-define(SMS_OUTBOUND_OPTIONS
       ,kapps_config:get_json(<<"sms">>, ?SMS_OUTBOUND_OPTIONS_KEY, ?SMS_DEFAULT_OUTBOUND_OPTIONS)
       ).

-spec default_collect_timeout() -> pos_integer().
default_collect_timeout() ->
    ?DEFAULT_COLLECT_TIMEOUT.

-spec default_message_timeout() -> pos_integer().
default_message_timeout() ->
    ?DEFAULT_MESSAGE_TIMEOUT.

-spec default_application_timeout() -> pos_integer().
default_application_timeout() ->
    ?DEFAULT_APPLICATION_TIMEOUT.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec send_sms(kz_json:objects(), im()) -> kapps_api_std_return().
send_sms(Endpoints, Im) -> send_sms(Endpoints, ?DEFAULT_STRATEGY, Im).

-spec send_sms(kz_json:objects(), binary(), im()) -> kapps_api_std_return().
send_sms(EndpointList, Strategy, Im) ->
    send_sms(EndpointList, Strategy, default_message_timeout(), Im).

-spec send_sms(kz_json:objects(), binary(), integer(), im()) -> kapps_api_std_return().
send_sms(EndpointList, Strategy, Timeout, Im) ->
    Endpoints = create_sms_endpoints(EndpointList, []),
    API = create_sms(Im),
    send(Strategy, API, Endpoints, Timeout).

-spec send(binary(), kz_term:proplist(), kz_json:objects(), integer()) -> kapps_api_std_return().
send(_ , _API, [], _Timeout) ->
    {'error', 'no_endpoints_available'};
send(<<"single">>, API, [Endpoint| Others], Timeout) ->
    case send_and_wait(API, Endpoint, Timeout) of
        {'error', _R}=Err when Others =:= [] ->
            Err;
        {'error', _R} ->
            send(<<"single">>, API, Others, Timeout);
        {_, JObj} = Ret ->
            lager:info("received ~s ~s", [kz_api:event_category(JObj), kz_api:event_name(JObj)]),
            Ret
    end;
send(<<"all">>, API, Endpoints, _Timeout) ->
    lists:foreach(fun(Endpoint) -> send(API, Endpoint) end, Endpoints);
send(_Strategy, _API, _Endpoints, _Timeout) ->
    {'error', 'strategy_not_implemented'}.

-spec send(kz_term:proplist(), kz_json:object()) -> kapps_api_std_return().
send(API, Endpoint) ->
    Payload = create_payload(API, Endpoint),
    send(Payload).

-spec send(kz_term:api_terms()) -> 'ok'.
send(Payload) ->
    kapi_im:publish_outbound(Payload).

-spec send_and_wait(kz_term:proplist(), kz_json:object(), integer()) -> kapps_api_std_return().
send_and_wait(API, Endpoint, Timeout) ->
    Payload = create_payload(API, Endpoint),
    send_and_wait(Payload, Timeout).

-spec send_and_wait(kz_term:api_terms(), integer()) -> kapps_api_std_return().
send_and_wait(Payload, Timeout) ->
    lager:info("sending sms and waiting for response"),
    send(Payload),
    MsgId = props:get_value(<<"Message-ID">>, Payload),
    wait_for_correlated_message(MsgId, <<"delivery">>, <<"message">>, Timeout).

create_payload(API, Endpoint) ->
    Options = kz_json:to_proplist(kz_json:get_value(<<"Endpoint-Options">>, Endpoint, [])),
    props:set_values([{<<"Endpoints">>, [Endpoint]} | Options], API).

-spec create_sms(im()) -> kz_term:api_terms().
create_sms(Im) ->
    kapps_im:to_payload(kapps_im:set_direction(<<"outbound">>, Im)).

-spec create_sms_endpoints(kz_json:objects(), kz_json:objects()) -> kz_json:objects().
create_sms_endpoints([], Endpoints) -> Endpoints;
create_sms_endpoints([Endpoint | Others], Endpoints) ->
    case create_sms_endpoint(Endpoint) of
        'undefined' -> create_sms_endpoints(Others, Endpoints);
        NewEndpoint -> create_sms_endpoints(Others, [NewEndpoint | Endpoints])
    end.

-spec create_sms_endpoint(kz_json:object()) -> kz_term:api_object().
create_sms_endpoint(Endpoint) ->
    TokenId = list_to_binary([kzd_endpoint:id(Endpoint), "@", kzd_endpoint:account_id(Endpoint)]),
    case lookup_reg(TokenId) of
        {'ok', Node} ->
            Options = kz_json:get_value(<<"Endpoint-Options">>, Endpoint, []),
            kz_json:set_values(
              [{<<"Route-ID">>, Node}
              ,{<<"Endpoint-Options">>, kz_json:from_list([{<<"Route-ID">>, Node} | Options])}
              ], Endpoint);
        {'error', _E} -> 'undefined'
    end.

-spec lookup_reg(kz_term:ne_binary()) ->
          {'error', any()} |
          {'ok', kz_term:ne_binary()}.
lookup_reg(TokenId) ->
    Req = [{<<"Token-ID">>, TokenId}
          ,{<<"Search-Type">>, <<"token">>}
          | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
          ],
    case kz_amqp_worker:call(Req, fun kapi_registration:publish_search_req/1)
    of
        {'error', _E}=E ->
            lager:debug("error getting registration: ~p", [_E]),
            E;
        {_, JObj} -> {'ok', kz_api:node(JObj)}
    end.

-spec get_correlated_msg_type(kz_json:object()) ->
          {kz_term:api_binary(), kz_term:api_binary(), kz_term:api_binary()}.
get_correlated_msg_type(JObj) ->
    get_correlated_msg_type(<<"Message-ID">>, JObj).

-spec get_correlated_msg_type(kz_term:ne_binary(), kz_json:object()) ->
          {kz_term:api_binary(), kz_term:api_binary(), kz_term:api_binary()}.
get_correlated_msg_type(Key, JObj) ->
    {C, N} = kz_api:event_type(JObj),
    {C, N, kz_json:get_value(Key, JObj)}.

-spec wait_for_correlated_message(kz_term:ne_binary() | im(), kz_term:ne_binary(), kz_term:ne_binary(), timeout()) ->
          kapps_api_std_return().
wait_for_correlated_message(<<MsgId/binary>>, Event, Type, Timeout) ->
    Start = kz_time:start_time(),
    case receive_event(Timeout) of
        {'error', 'timeout'}=E -> E;
        {'ok', JObj}=Ok ->
            case get_correlated_msg_type(JObj) of
                {<<"error">>, _, MsgId} ->
                    lager:debug("message execution error while waiting for ~s", [MsgId]),
                    {'error', JObj};
                {Type, Event, MsgId} ->
                    Ok;
                {_Type, _Event, _MsgId} ->
                    lager:debug("received message (~s , ~s, ~s)",[_Type, _Event, _MsgId]),
                    wait_for_correlated_message(MsgId, Event, Type, kz_time:decr_timeout(Timeout, Start))
            end
    end;
wait_for_correlated_message(Im, Event, Type, Timeout) ->
    MsgId = kapps_im:message_id(Im),
    wait_for_correlated_message(MsgId, Event, Type, Timeout).

-type received_event() :: {'ok', kz_json:object()} |
                          {'error', 'timeout'}.

-spec receive_event(timeout()) -> received_event().
receive_event(Timeout) -> receive_event(Timeout, 'true').

-spec receive_event(timeout(), boolean()) ->
          received_event() |
          {'other', kz_json:object() | any()}.
receive_event(T, _) when T =< 0 -> {'error', 'timeout'};
receive_event(Timeout, IgnoreOthers) ->
    Start = kz_time:start_time(),
    receive
        {'amqp_msg', JObj} -> {'ok', JObj};
        {'kapi',{ _, _, JObj}} -> {'ok', JObj};
        _Msg when IgnoreOthers ->
            lager:debug_unsafe("ignoring received event : ~p", [_Msg]),
            receive_event(kz_time:decr_timeout(Timeout, Start), IgnoreOthers);
        Other ->
            lager:debug_unsafe("received other event : ~p", [Other]),
            {'other', Other}
    after
        Timeout -> {'error', 'timeout'}
    end.

%%------------------------------------------------------------------------------
%% @doc How AMQP messages are sent to the mailboxes of processes waiting
%% for them in the receive blocks below.
%% @end
%%------------------------------------------------------------------------------
-type relay_fun() :: fun((pid() | atom(), any()) -> any()).

-spec relay_event(pid(), kz_json:object()) -> any().
relay_event(Pid, JObj) ->
    relay_event(Pid, JObj, fun erlang:send/2).

-spec relay_event(pid(), kz_json:object(), relay_fun()) -> any().
relay_event(Pid, JObj, RelayFun) ->
    RelayFun(Pid, {'amqp_msg', JObj}).
