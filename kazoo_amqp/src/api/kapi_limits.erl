%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc Limits-related messages, AMQP API.
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_limits).

-export([api_definitions/0, api_definition/1]).

-export([endpoint_channel_req/1
        ,endpoint_channel_req_v/1
        ,publish_endpoint_channel_req/1
        ]).
-export([endpoint_channel_resp/1
        ,endpoint_channel_resp_v/1
        ,publish_endpoint_channel_resp/2
        ]).

-export([bind_q/2, unbind_q/2]).
-export([declare_exchanges/0]).

-define(EXCHANGE_NAME, <<"limits">>).
-define(EXCHANGE_TYPE, <<"topic">>).

-define(ENDPOINT_CHANNEL_RK, <<"endpoint.channel">>).

-include_lib("kazoo_amqp/src/kz_amqp_util.hrl").

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [endpoint_channel_req_definition()
    ,endpoint_channel_resp_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(<<"endpoint_channel_req">>) ->
    endpoint_channel_req_definition();
api_definition(<<"endpoint_channel_resp">>) ->
    endpoint_channel_resp_definition().

-spec endpoint_channel_req_definition() -> kapi_definition:api().
endpoint_channel_req_definition() ->
    Category = <<"limits">>,
    EventName = <<"endpoint_channel_req">>,

    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Endpoint Channel Limits Request">>}
              ,{fun kapi_definition:set_description/2, <<"Endpoint Channel Limits Request">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun endpoint_channel_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun endpoint_channel_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_endpoint_channel_req/1}
              ,{fun kapi_definition:set_binding/2, ?ENDPOINT_CHANNEL_RK}
              ,{fun kapi_definition:set_required_headers/2, [<<"Account-ID">>
                                                            ,<<"Endpoint-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Direction">>]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Direction">>, [<<"inbound">>, <<"outbound">>]}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Account-ID">>, fun kz_term:is_ne_binary/1}
                ,{<<"Endpoint-ID">>, fun kz_term:is_ne_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec endpoint_channel_resp_definition() -> kapi_definition:api().
endpoint_channel_resp_definition() ->
    Category = <<"limits">>,
    EventName = <<"endpoint_channel_resp">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Endpoint Channel Limits Response">>}
              ,{fun kapi_definition:set_description/2, <<"Endpoint Channel Limits Response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun endpoint_channel_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun endpoint_channel_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_endpoint_channel_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Allowed">>]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Limit-ID">>]}
              ,{fun kapi_definition:set_values/2, kapi_definition:event_type_headers(Category, EventName)}
              ,{fun kapi_definition:set_types/2
               ,[{<<"Allowed">>, fun is_boolean/1}
                ,{<<"Limit-ID">>, fun kz_term:is_ne_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Inquire into the status of a channel.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_channel_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
endpoint_channel_req(Req) ->
    kapi_definition:build_message(Req, endpoint_channel_req_definition()).

-spec endpoint_channel_req_v(kz_term:api_terms()) -> boolean().
endpoint_channel_req_v(Req) ->
    kapi_definition:validate(Req, endpoint_channel_req_definition()).

-spec publish_endpoint_channel_req(kz_term:api_terms()) -> 'ok'.
publish_endpoint_channel_req(API) ->
    Definition = endpoint_channel_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:basic_publish(?EXCHANGE_NAME
                              ,kapi_definition:binding(Definition)
                              ,Payload
                              ,?DEFAULT_CONTENT_TYPE
                              ).

%%------------------------------------------------------------------------------
%% @doc Respond with status of a channel, either active or nonexistent.
%% Takes {@link lz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_channel_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
endpoint_channel_resp(Req) ->
    kapi_definition:build_message(Req, endpoint_channel_resp_definition()).

-spec endpoint_channel_resp_v(kz_term:api_terms()) -> boolean().
endpoint_channel_resp_v(Req) ->
    kapi_definition:validate(Req, endpoint_channel_resp_definition()).

-spec publish_endpoint_channel_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_endpoint_channel_resp(RespQ, JObj) ->
    Definition = endpoint_channel_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(JObj
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(RespQ, Payload, ?DEFAULT_CONTENT_TYPE).

-spec bind_q(kz_term:api_ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Queue, Props) ->
    Events = props:get_value('restrict_to', Props),
    bind(Queue, Events).

bind(Q, 'undefined') ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q, ?ENDPOINT_CHANNEL_RK, ?EXCHANGE_NAME);
bind(Q, ['endpoint_channel' | T]) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q, ?ENDPOINT_CHANNEL_RK, ?EXCHANGE_NAME),
    bind(Q, T);
bind(_Q, []) -> 'ok'.

-spec unbind_q(kz_term:api_ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Queue, Props) ->
    Events = props:get_value('restrict_to', Props),
    unbind(Queue, Events).

unbind(Q, 'undefined') ->
    'ok' = kz_amqp_util:unbind_q_from_exchange(Q, ?ENDPOINT_CHANNEL_RK, ?EXCHANGE_NAME);
unbind(Q, ['endpoint_channel' | T]) ->
    _ = kz_amqp_util:unbind_q_from_exchange(Q, ?ENDPOINT_CHANNEL_RK, ?EXCHANGE_NAME),
    unbind(Q, T);
unbind(_Q, []) -> 'ok'.

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:new_exchange(?EXCHANGE_NAME, ?EXCHANGE_TYPE).
