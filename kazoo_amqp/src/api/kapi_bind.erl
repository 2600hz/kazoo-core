%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc For `gen_listeners' that bind to targeted for direct messaging.
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_bind).

-export([bind_q/2, unbind_q/2]).
-export([declare_exchanges/0]).

-include_lib("kz_amqp_util.hrl").

-spec bind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Q, Props) ->
    declare_exchange(Props),
    Exchange = exchange_name(exchange(Props)),
    Routing = props:get_value('routing', Props),
    kz_amqp_util:bind_q_to_exchange(Q, Routing, Exchange).

-spec unbind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Q, Props) ->
    Exchange = exchange_name(exchange(Props)),
    Routing = props:get_value('routing', Props),
    kz_amqp_util:unbind_q_from_exchange(Q, Routing, Exchange).

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() -> 'ok'.

%%------------------------------------------------------------------------------
%% @doc Declare the Exchange defined in bind.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchange(kz_term:proplist()) -> 'ok'.
declare_exchange(Props) ->
    Exchange = exchange(Props),
    kz_amqp_util:new_exchange(exchange_name(Exchange), exchange_type(Exchange), exchange_options(Exchange)),
    bind_exchange(Props).

-spec bind_exchange(kz_term:proplist()) -> 'ok'.
bind_exchange(Props) ->
    Exchange = exchange(Props),
    ExchangeName = exchange_name(Exchange),
    Bindings = bindings(Exchange),
    Fun = fun({KAPI, Binding}) ->
                  bind_kapi(KAPI, ExchangeName, Binding)
          end,
    lists:foreach(Fun, Bindings).

-spec bind_kapi(atom(), binary(), kz_term:proplist()) -> 'ok'.
bind_kapi(KAPI, Exchange, Props) ->
    APIModule = kz_term:to_atom(list_to_binary([<<"kapi_">>, kz_term:to_binary(KAPI)]), 'true'),
    APIModule:declare_exchanges(),
    Source = props:get_value(source, Props, kz_term:to_binary(KAPI)),
    bind_cmd(Exchange, Source, props:get_ne_binary_value(routing, Props)),
    Fun = fun(RK) -> bind_cmd(Exchange, Source, RK) end,
    lists:foreach(Fun, props:get_value(routings, Props, [])).

-spec bind_cmd(binary(), binary(), kz_term:api_binary()) -> 'ok'.
bind_cmd(_Exchange, _Source, undefined) -> ok;
bind_cmd(Exchange, Source, Routing) ->
    BindCmd = #'exchange.bind'{destination=Exchange
                              ,source = Source
                              ,routing_key= Routing
                              ,nowait=false
                              ,arguments=[]
                              },
    kz_amqp_channel:command(BindCmd).

exchange(Props) ->
    props:get_value(exchange, Props).

exchange_name(Props) ->
    props:get_value(name, Props).

exchange_type(Props) ->
    props:get_value(type, Props).

exchange_options(Props) ->
    props:get_value(options, Props, []).

bindings(Props) ->
    props:get_value(bindings, Props, []).
