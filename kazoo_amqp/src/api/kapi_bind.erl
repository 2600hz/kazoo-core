%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2021, 2600Hz
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

-type exchange_option() :: {'name', kz_term:ne_binary()} |
                           {'type', kz_term:ne_binary()} |
                           {'options', kz_amqp_util:declare_exchange_options()} |
                           {'bindings', gen_listener:bindings()}.
-type exchange_options() :: [exchange_option()].

-type bind_option() :: {'exchange', exchange_options()} |
                       {'routing', kz_term:ne_binary()}.
-type bind_options() :: [bind_option()].

-spec bind_q(kz_term:ne_binary(), bind_options()) -> 'ok'.
bind_q(Q, Props) ->
    declare_exchange(Props),
    Exchange = exchange_name(exchange(Props)),
    Routing = props:get_value('routing', Props),
    kz_amqp_util:bind_q_to_exchange(Q, Routing, Exchange).

-spec unbind_q(kz_term:ne_binary(), bind_options()) -> 'ok'.
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
-spec declare_exchange(bind_options()) -> 'ok'.
declare_exchange(Props) ->
    Exchange = exchange(Props),
    kz_amqp_util:new_exchange(exchange_name(Exchange)
                             ,exchange_type(Exchange)
                             ,exchange_options(Exchange)
                             ),
    bind_exchange(Props).

-spec bind_exchange(bind_options()) -> 'ok'.
bind_exchange(Props) ->
    Exchange = exchange(Props),
    ExchangeName = exchange_name(Exchange),
    Bindings = bindings(Exchange),
    Fun = fun({KAPI, Binding}) ->
                  bind_kapi(KAPI, ExchangeName, Binding)
          end,
    lists:foreach(Fun, Bindings).

declare_bound_exchange(null) -> ok;
declare_bound_exchange(undefined) -> ok;
declare_bound_exchange(KAPI) ->
    APIModule = kz_term:to_atom(list_to_binary([<<"kapi_">>, kz_term:to_binary(KAPI)]), 'true'),
    declare_bound_exchange(kz_module:is_exported(APIModule, declare_exchanges, 0), APIModule).

declare_bound_exchange(true, APIModule) -> APIModule:declare_exchanges();
declare_bound_exchange(false, _APIModule) -> ok.

-spec bind_kapi(atom(), binary(), kz_term:proplist()) -> 'ok'.
bind_kapi(KAPI, Exchange, Props) ->
    declare_bound_exchange(KAPI),
    Source = props:get_value(source, Props, kz_term:to_binary(KAPI)),
    bind_cmd(Exchange, Source, props:get_ne_binary_value(routing, Props)),
    Fun = fun(RK) -> bind_cmd(Exchange, Source, RK) end,
    lists:foreach(Fun, props:get_value('routings', Props, [])).

-spec bind_cmd(binary(), binary(), kz_term:api_binary()) -> 'ok'.
bind_cmd(_Exchange, _Source, 'undefined') -> 'ok';
bind_cmd(Exchange, Source, Routing) ->
    BindCmd = #'exchange.bind'{destination=Exchange
                              ,source = Source
                              ,routing_key= Routing
                              ,nowait=false
                              ,arguments=[]
                              },
    kz_amqp_channel:command(BindCmd).

-spec exchange(bind_options()) -> exchange_options().
exchange(Props) ->
    props:get_value('exchange', Props).

-spec exchange_name(exchange_options()) -> kz_term:ne_binary().
exchange_name(Props) ->
    props:get_value('name', Props).

-spec exchange_type(exchange_options()) -> kz_term:ne_binary().
exchange_type(Props) ->
    props:get_value('type', Props).

-spec exchange_options(exchange_options()) -> kz_amqp_util:declare_exchange_options().
exchange_options(Props) ->
    props:get_value('options', Props, []).

-spec bindings(exchange_options()) -> gen_listener:bindings().
bindings(Props) ->
    props:get_value('bindings', Props, []).
