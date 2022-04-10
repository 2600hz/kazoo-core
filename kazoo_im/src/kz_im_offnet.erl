%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_im_offnet).
-behaviour(gen_listener).

-export([start_link/1]).

-export([route/1, route/2]).

-export([handle_message/2]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,handle_event/2
        ,terminate/2
        ,code_change/3
        ]).

-include("kazoo_im.hrl").

-define(SERVER, ?MODULE).

-record(state, {connection :: amqp_listener_connection()
               ,confirms = #{count => 1, pids => #{}} :: map()
               ,registered = false :: boolean()
               }).
-type state() :: #state{}.

-define(BINDINGS(Ex), [{'im', [{'exchange', Ex}
                              ,{'restrict_to', ['inbound']}
                              ]}
                      ]).
-define(RESPONDERS, [{{?MODULE, 'handle_message'}
                     ,[{<<"*">>, <<"inbound">>}]
                     }
                    ]).

-define(QUEUE_OPTIONS, [{'exclusive', 'false'}
                       ,{'durable', 'true'}
                       ,{'auto_delete', 'false'}
                       ,{'arguments', [{<<"x-message-ttl">>, 'infinity'}
                                      ,{<<"x-max-length">>, 'infinity'}
                                      ]}
                       ]).
-define(CONSUME_OPTIONS, [{'exclusive', 'false'}
                         ,{'no_ack', 'false'}
                         ]).

-define(AMQP_PUBLISH_OPTIONS, [{'mandatory', 'true'}
                              ,{'delivery_mode', 2}
                              ]).

-define(ROUTE_TIMEOUT, 'infinity').

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server.
%% @end
%%------------------------------------------------------------------------------
-spec start_link(amqp_listener_connection()) -> kz_types:startlink_ret().
start_link(#amqp_listener_connection{broker=Broker
                                    ,exchange=Exchange
                                    ,type=Type
                                    ,queue=Queue
                                    ,options=Options
                                    }=C) ->
    Exchanges = [{Exchange, Type, Options}],
    gen_listener:start_link(?SERVER
                           ,[{'bindings', ?BINDINGS(Exchange)}
                            ,{'responders', ?RESPONDERS}
                            ,{'queue_name', Queue}       % optional to include
                            ,{'queue_options', ?QUEUE_OPTIONS} % optional to include
                            ,{'consume_options', ?CONSUME_OPTIONS} % optional to include
                            ,{'declare_exchanges', Exchanges}
                            ,{'broker', Broker}
                            ,{'server_confirms', 'true'}
                            ]
                           ,[C]
                           ,[]
                           ).

-spec handle_message(kz_json:object(), kz_term:proplist()) -> 'ok'.
handle_message(JObj, Props) ->
    Srv = props:get_value('server', Props),
    Deliver = props:get_value('deliver', Props),
    case kapi_im:inbound_v(JObj) of
        'true' ->
            handle_inbound(JObj, Srv, Deliver);
        'false' ->
            lager:debug("error validating inbound message : ~p", [JObj]),
            gen_listener:ack(Srv, Deliver)
    end.

-spec route(kz_term:api_terms()) -> 'ok' | {'error', 'no_connections'}.
route(Payload) ->
    case kz_im_offnet_sup:worker() of
        {'error', 'no_connections'} = E -> E;
        Pid -> route(Pid, Payload)
    end.

-spec route(pid(), kz_term:api_terms()) -> 'ok'.
route(Pid, Payload) ->
    gen_listener:call(Pid, {'route', Payload}, ?ROUTE_TIMEOUT).

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server.
%% @end
%%------------------------------------------------------------------------------
-spec init([amqp_listener_connection()]) -> {'ok', state()}.
init([#amqp_listener_connection{}=Connection]) ->
    {'ok', #state{connection=Connection}}.

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call({'route', Payload}, From, #state{connection = Connection, confirms = Confirms} = State) ->
    #amqp_listener_connection{exchange = Exchange} = Connection,
    Values = [{<<"Exchange-ID">>, Exchange}],
    JObj = kz_json:set_values(Values, Payload),
    kapi_im:publish_outbound(JObj, ?AMQP_PUBLISH_OPTIONS),
    #{count := Count, pids := Pids} = Confirms,
    Info = #{payload => kz_json:delete_key(<<"Body">>, Payload), from => From},
    {'noreply', State#state{confirms = Confirms#{count => Count + 1, pids => Pids#{Count => Info}}}};
handle_call(_Request, _From, State) ->
    {'reply', {'error', 'not_implemented'}, State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'gen_listener', {'created_queue', _QueueNAme}}, State) ->
    {'noreply', State};
handle_cast({'gen_listener', {'is_consuming', 'false'}}, #state{registered = true} = State) ->
    lager:debug("deactivating offnet worker"),
    _ = gproc:unreg({'p', 'l', 'im_offnet'}),
    {'noreply', State#state{registered = false}};
handle_cast({'gen_listener', {'is_consuming', 'false'}}, #state{registered = false} = State) ->
    {'noreply', State};
handle_cast({'gen_listener', {'is_consuming', 'true'}}, State) ->
    {'noreply', State};
handle_cast({'gen_listener',{'server_confirms', 'true'}}, #state{registered = false} = State) ->
    lager:debug("broker can confirm deliveries, activating offnet worker"),
    'true' = gproc:reg({'p', 'l', 'im_offnet'}),
    {'noreply', State#state{registered = true}};
handle_cast({'gen_listener',{'server_confirms', 'true'}}, #state{registered = true} = State) ->
    {'noreply', State};
handle_cast({'gen_listener',{'server_confirms', 'false'}}, State) ->
    lager:warning("broker can't confirm deliveries"),
    {'stop', {'shutdown', 'no_confirms'}, State};
handle_cast({'gen_listener', {'confirm', Confirm}}, State) ->
    {'noreply', handle_confirm(Confirm, State)};
handle_cast(_Msg, State) ->
    lager:debug("external listener unhandled cast: ~p", [_Msg]),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info(_Info, State) ->
    lager:debug("external listener unhandled info: ~p", [_Info]),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Allows listener to pass options to handlers.
%% @end
%%------------------------------------------------------------------------------
-spec handle_event(kz_json:object(), kz_term:proplist()) -> gen_listener:handle_event_return().
handle_event(_JObj, _State) ->
    {'reply', []}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_server' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_server' terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:debug("external listener terminating : ~s", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_inbound(kz_json:object(), pid(), gen_listener:basic_deliver()) -> 'ok'.
handle_inbound(JObj, Srv, Deliver) ->
    case maybe_relay_request(JObj) of
        'ack' -> gen_listener:ack(Srv, Deliver);
        'nack' -> gen_listener:ack(Srv, Deliver)
    end.

-spec maybe_relay_request(kz_json:object()) -> 'ack' | 'nack'.
maybe_relay_request(JObj) ->
    Numbers = [{knm_converters:normalize(Number), #{}} || Number <- kz_im:to_numbers(JObj)],
    IM = kapps_im:from_payload(JObj),
    Map = #{accounts => #{}
           ,resellers => #{}
           ,numbers => maps:from_list(Numbers)
           ,inception => <<"offnet">>
           ,request => JObj
           ,route_id => kz_im:route_id(JObj)
           ,route_type => kz_im:route_type(JObj)
           ,im => IM
           },
    Routines = [fun lookup_numbers/1
               ,fun numbers_have_im_enabled/1
               ,fun accounts_from_numbers/1
               ,fun accounts/1
               ,fun resellers/1
               ,fun accounts_fetch/1
               ,fun resellers_fetch/1
               ,fun accounts_enabled/1
               ,fun resellers_enabled/1
               ,fun accounts_have_im_enabled/1
               ,fun resellers_have_im_enabled/1
               ,fun accounts_standing_are_acceptable/1
               ,fun resellers_standing_are_acceptable/1
               ,fun set_accounts_rate/1
               ,fun set_errors_from_resellers/1
               ,fun set_errors_from_accounts/1
               ,fun log_errors/1
               ,fun route_onnet/1
               ],
    try
        case route_errors(kz_maps:exec(Routines, Map)) of
            true -> 'nack';
            false -> 'ack'
        end
    catch
        _Exception:_Reason:_Stack ->
            lager:warning("exception ~p / ~p handling inbound request", [_Exception, _Reason]),
            kz_log:log_stacktrace(_Stack),
            nack
    end.

lookup_numbers(#{numbers := Numbers} = Map) ->
    Map#{numbers => maps:map(fun lookup_number/2, Numbers)}.

lookup_number(Number, Map) ->
    case knm_phone_number:fetch(Number) of
        {'error', Error} -> Map#{error => io_lib:format("number not found : ~s", [kz_term:to_binary(Error)])};
        {'ok', KNumber} -> Map#{phone_number => KNumber}
    end.

numbers_have_im_enabled(#{numbers := Numbers, im := IM} = Map) ->
    Map#{numbers => maps:map(fun(K,V) -> number_has_im_enabled(K, V, kapps_im:type(IM)) end, Numbers)}.

number_has_im_enabled(_Number, #{error := _} = Map, _) -> Map;
number_has_im_enabled(_Number, #{phone_number := PN} = Map, Type) ->
    case knm_im:enabled(PN, Type) of
        'true' -> Map;
        'false' -> Map#{error => io_lib:format("number does not have ~s enabled", [Type])}
    end.

accounts_from_numbers(#{numbers := Numbers} = Map) ->
    Map#{numbers => maps:map(fun account_from_number/2, Numbers)}.

account_from_number(_Number, #{error := _} = Map) -> Map;
account_from_number(_Number, #{phone_number := PN} = Map) ->
    case knm_phone_number:assigned_to(PN) of
        'undefined' -> Map#{error => <<"number not assigned to an account">>};
        AccountId -> Map#{account_id => AccountId
                         ,reseller_id => kz_services_reseller:get_id(AccountId)
                         }
    end.

accounts(#{numbers := Numbers} = Map) ->
    Map#{accounts => maps:fold(fun account/3, #{}, Numbers)}.

account(_Number, #{error := _}, Acc) -> Acc;
account(Number, #{account_id := AccountId, reseller_id := ResellerId}, Acc) ->
    case maps:get(AccountId, Acc, undefined) of
        undefined -> maps:put(AccountId, #{numbers => [Number], reseller_id => ResellerId}, Acc);
        #{numbers := Numbers} = V -> maps:put(AccountId, V#{numbers => [Number | Numbers]}, Acc)
    end.

resellers(#{numbers := Numbers} = Map) ->
    Map#{resellers => maps:fold(fun reseller/3, #{}, Numbers)}.

reseller(_Number, #{error := _}, Acc) -> Acc;
reseller(Number, #{reseller_id := ResellerId, account_id := AccountId}, Acc) ->
    case maps:get(ResellerId, Acc, undefined) of
        undefined -> maps:put(ResellerId, #{numbers => [Number], accounts => [AccountId]}, Acc);
        #{numbers := Numbers, accounts := Accounts} = V -> maps:put(ResellerId, V#{numbers => [Number | Numbers], accoounts => [AccountId | Accounts]}, Acc)
    end.

accounts_fetch(#{accounts := Accounts} = Map) ->
    Map#{accounts => maps:map(fun account_fetch/2, Accounts)}.

account_fetch(AccountId, Map) ->
    case kzd_accounts:fetch(AccountId) of
        {'error', Error} -> Map#{error => Error};
        {'ok', Account} -> Map#{account => Account}
    end.

resellers_fetch(#{resellers := Resellers} = Map) ->
    Map#{resellers => maps:map(fun reseller_fetch/2, Resellers)}.

reseller_fetch(ResellerId, Map) ->
    case kzd_accounts:fetch(ResellerId) of
        {'error', Error} -> Map#{error => Error};
        {'ok', Reseller} -> Map#{reseller => Reseller}
    end.

accounts_enabled(#{accounts := Accounts} = Map) ->
    Map#{accounts => maps:map(fun account_enabled/2, Accounts)}.

account_enabled(_AccountId, #{error := _} = Map) -> Map;
account_enabled(_AccountId, #{account := Account} = Map) ->
    case kzd_accounts:enabled(Account) of
        'true' -> Map;
        'false' -> Map#{error => <<"account is disabled">>}
    end.

resellers_enabled(#{resellers := Resellers} = Map) ->
    Map#{resellers => maps:map(fun reseller_enabled/2, Resellers)}.

reseller_enabled(_ResellerId, #{error := _} = Map) -> Map;
reseller_enabled(_ResellerId, #{reseller := Reseller} = Map) ->
    case kzd_accounts:enabled(Reseller) of
        'true' -> Map;
        'false' -> Map#{error => <<"reseller is disabled">>}
    end.

accounts_have_im_enabled(#{accounts := Accounts, im := IM} = Map) ->
    Map#{accounts => maps:map(fun(K,V) -> account_has_im_enabled(K, V, kapps_im:type(IM)) end, Accounts)}.

account_has_im_enabled(_AccountId, #{error := _} = Map, _) -> Map;
account_has_im_enabled(AccountId, Map, Type) ->
    case kz_services_im:is_enabled(AccountId, Type) of
        'true' -> Map;
        'false' -> Map#{error => io_lib:format("account does not have ~s enabled", [Type])}
    end.

resellers_have_im_enabled(#{resellers := Resellers, im := IM} = Map) ->
    Map#{resellers => maps:map(fun(K,V) -> reseller_has_im_enabled(K, V, kapps_im:type(IM)) end, Resellers)}.

reseller_has_im_enabled(_ResellerId, #{error := _} = Map, _) -> Map;
reseller_has_im_enabled(ResellerId, Map, Type) ->
    case kz_services_im:is_enabled(ResellerId, Type) of
        'true' -> Map;
        'false' -> Map#{error => io_lib:format("reseller ~s does not have ~s enabled", [ResellerId, Type])}
    end.

accounts_standing_are_acceptable(#{accounts := Accounts} = Map) ->
    Map#{accounts => maps:map(fun account_standing_is_acceptable/2, Accounts)}.

account_standing_is_acceptable(_AccountId, #{error := _} = Map) -> Map;
account_standing_is_acceptable(AccountId, Map) ->
    case kz_services_standing:acceptable(AccountId) of
        {'true', _} -> Map;
        {'false', Error} -> Map#{error => maps:get(reason, Error)}
    end.

resellers_standing_are_acceptable(#{resellers := Resellers} = Map) ->
    Map#{resellers => maps:map(fun reseller_standing_is_acceptable/2, Resellers)}.

reseller_standing_is_acceptable(_ResellerId, #{error := _} = Map) -> Map;
reseller_standing_is_acceptable(ResellerId, Map) ->
    case kz_services_standing:acceptable(ResellerId) of
        {'true', _} -> Map;
        {'false', Error} -> Map#{error => maps:get(reason, Error)}
    end.

set_accounts_rate(#{accounts := Accounts, im := IM} = Map) ->
    Map#{accounts => maps:map(fun(K,V) -> set_account_rate(K, V, IM) end, Accounts)}.

set_account_rate(_AccountId, #{error := _} = Map, _IM) -> Map;
set_account_rate(AccountId, Map, IM) ->
    Rate = kz_services_im:flat_rate(AccountId, kapps_im:type(IM), kapps_im:direction(IM)),
    Map#{rate => Rate}.

set_errors_from_accounts(#{numbers := Numbers, accounts := Accounts} = Map) ->
    Map#{numbers => maps:map(fun(K, V) -> set_error_from_account(K, V, Accounts) end, Numbers)}.

set_error_from_account(_Number, #{error := _} = Map, _) -> Map;
set_error_from_account(_Number, #{account_id := AccountId} = Map, Accounts) ->
    case maps:get(AccountId, Accounts) of
        #{error := Error} -> Map#{error => Error};
        _ -> Map
    end.

set_errors_from_resellers(#{numbers := Numbers, accounts := Accounts, resellers := Resellers} = Map) ->
    Map#{numbers => maps:map(fun(K, V) -> set_error_from_reseller(K, V, Resellers) end, Numbers)
        ,accounts => maps:map(fun(K, V) -> set_error_from_reseller(K, V, Resellers) end, Accounts)
        }.

set_error_from_reseller(_Key, #{error := _} = Map, _) -> Map;
set_error_from_reseller(_Key, #{reseller_id := ResellerId} = Map, Resellers) ->
    case maps:get(ResellerId, Resellers) of
        #{error := Error} -> Map#{error => Error};
        _ -> Map
    end.

log_errors(#{numbers := Numbers, im := IM} = Ctx) ->
    lists:foreach(fun({K, V}) -> log_error(K, V, IM) end, maps:to_list(Numbers)),
    Ctx.

log_error(Number, #{error := Error, account_id := AccountId}, IM) ->
    lager:warning("external ~s request for number ~s validation failed  in account ~s : ~p", [kapps_im:type(IM), Number, AccountId, Error]);
log_error(Number, #{error := Error}, IM) ->
    lager:warning("validation failed in external ~s request for number ~s : ~p", [kapps_im:type(IM), Number, Error]);
log_error(_Number, _Map, _IM) -> ok.

route_errors(#{accounts := Accounts}) ->
    lists:any(fun route_error/1, maps:to_list(Accounts)).

route_error({_AccountId, #{error := _}}) -> false;
route_error({_AccountId, #{route_error := _}}) -> true;
route_error({_AccountId, _Map}) -> false.


route_onnet(#{accounts := Accounts} = Map) ->
    Map#{accounts => maps:map(fun(K,V) -> route_onnet(K, V, Map) end, Accounts)}.

route_onnet(_AccountId, #{error := _} = Map, _) -> Map;
route_onnet(AccountId, #{numbers := Numbers, rate := Rate} = Map, #{request := Payload, im:= IM}) ->
    lager:info("accepted external ~s request ~s for account ~s", [kapps_im:type(IM), kz_binary:join(Numbers), AccountId]),
    Values = [{<<"Account-ID">>, AccountId}
             ,{<<"Rate">>, Rate}
             ,{<<"Charges">>, Rate * length(Numbers)}
             ,{<<"To-Numbers">>, Numbers}
             ],
    API = kz_json:set_values(Values, Payload),
    case kz_im_onnet:route(API) of
        'ok' -> Map#{payload => API, result => 'ack'};
        {'error', Error} ->
            lager:warning("onnet rejected request for account ~s : ~p", [AccountId, Error]),
            Map#{payload => API, result => 'nack', route_error => Error}
    end.

handle_confirm(#'basic.ack'{delivery_tag = Idx, multiple = 'true'}
              ,#state{confirms = #{pids := Pids} = Confirms} = State
              ) ->
    Keys = maps:fold(fun reply_ok/3, [], maps:filter(fun(K, _) -> K =< Idx end, Pids)),
    State#state{confirms = Confirms#{pids => maps:without(Keys, Pids)}};
handle_confirm(#'basic.ack'{delivery_tag = Idx, multiple = 'false'}
              ,#state{confirms = #{pids := Pids} = Confirms} = State
              ) ->
    Keys = maps:fold(fun reply_ok/3, [], maps:with([Idx], Pids)),
    State#state{confirms = Confirms#{pids => maps:without(Keys, Pids)}};
handle_confirm(#'basic.nack'{delivery_tag = Idx, multiple = 'true'}
              ,#state{confirms = #{pids := Pids} = Confirms} = State
              ) ->
    Keys = maps:fold(fun reply_error/3, [], maps:filter(fun(K, _) -> K =< Idx end, Pids)),
    State#state{confirms = Confirms#{pids => maps:without(Keys, Pids)}};
handle_confirm(#'basic.nack'{delivery_tag = Idx, multiple = 'false'}
              ,#state{confirms = #{pids := Pids} = Confirms} = State
              ) ->
    Keys = maps:fold(fun reply_error/3, [], maps:with([Idx], Pids)),
    State#state{confirms = Confirms#{pids => maps:without(Keys, Pids)}}.

reply_ok(Key, #{payload := Payload, from := Pid}, Acc) ->
    gen_server:reply(Pid, 'ok'),
    _ = kz_process:spawn(fun create_ledger/2, ['outbound', Payload]),
    [Key | Acc].

reply_error(Key, Pid, Acc) ->
    gen_server:reply(Pid, {'error', <<"server declined message">>}),
    [Key | Acc].

-spec create_ledger(kapps_im:direction(), kz_json:object()) -> 'ok'.
create_ledger(Type, Payload) ->
    IM = kapps_im:from_payload(Payload),
    kapps_im:put_message_id(IM),
    lager:debug("creating ~s ledger", [Type]),
    kz_im_flat_rate:debit(IM).
