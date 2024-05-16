%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2024, 2600Hz
%%% @doc API for events related to webhooks and their configurations
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @author Daniel Finke <danielfinke2011@gmail.com>
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_webhooks).

-export([api_definitions/0, api_definition/1]).

-export([reenable_req/1
        ,reenable_req_v/1
        ,publish_reenable_req/1, publish_reenable_req/2
        ]).
-export([reenable_resp/1
        ,reenable_resp_v/1
        ,publish_reenable_resp/2, publish_reenable_resp/3
        ]).

-export([bind_q/2
        ,unbind_q/2
        ,declare_exchanges/0
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(WEBHOOKS_EVENT_CATEGORY, <<"webhooks">>).

-define(REENABLE_REQ_EVENT_NAME, <<"reenable_req">>).
-define(REENABLE_RESP_EVENT_NAME, <<"reenable_resp">>).
-define(REENABLE_BINDING, <<"webhooks.reenable">>).

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [reenable_req_definition()
    ,reenable_resp_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(?REENABLE_REQ_EVENT_NAME) ->
    reenable_req_definition();
api_definition(?REENABLE_RESP_EVENT_NAME) ->
    reenable_resp_definition().

%%------------------------------------------------------------------------------
%% @doc Create the `kapi' definition for a `reenable_req'.
%% @end
%%------------------------------------------------------------------------------
-spec reenable_req_definition() -> kapi_definition:api().
reenable_req_definition() ->
    EventName = ?REENABLE_REQ_EVENT_NAME,
    Category = ?WEBHOOKS_EVENT_CATEGORY,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Reenable Req">>}
              ,{fun kapi_definition:set_description/2, <<"Re-enable webhooks in an account">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun reenable_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun reenable_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_reenable_req/1}
              ,{fun kapi_definition:set_binding/2, ?REENABLE_BINDING}
              ,{fun kapi_definition:set_required_headers/2, [<<"Account-ID">>
                                                            ,<<"Target">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Target">>, [<<"account">>, <<"descendants">>]}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Account-ID">>, fun kz_term:is_ne_binary/1}]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Create the `kapi' definition for a `reenable_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec reenable_resp_definition() -> kapi_definition:api().
reenable_resp_definition() ->
    EventName = ?REENABLE_RESP_EVENT_NAME,
    Category = ?WEBHOOKS_EVENT_CATEGORY,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Reenable Resp">>}
              ,{fun kapi_definition:set_description/2
               ,<<"Respond with the result of re-enabling webhooks in an account">>
               }
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun reenable_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun reenable_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_reenable_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Status">>]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Status">>, [<<"success">>]}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Build a `reenable_req'.
%% @end
%%------------------------------------------------------------------------------
-spec reenable_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
reenable_req(Req) ->
    kapi_definition:build_message(Req, reenable_req_definition()).

%%------------------------------------------------------------------------------
%% @doc Validate that `Req' is a `reenable_req'.
%% @end
%%------------------------------------------------------------------------------
-spec reenable_req_v(kz_term:api_terms()) -> boolean().
reenable_req_v(Req) ->
    kapi_definition:validate(Req, reenable_req_definition()).

%%------------------------------------------------------------------------------
%% @doc Publish a `reenable_req'.
%% @end
%%------------------------------------------------------------------------------
-spec publish_reenable_req(kz_term:api_terms()) -> 'ok'.
publish_reenable_req(API) ->
    publish_reenable_req(API, ?DEFAULT_CONTENT_TYPE).

-spec publish_reenable_req(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_reenable_req(Req, ContentType) ->
    Definition = reenable_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:kapps_publish(kapi_definition:binding(Definition)
                              ,Payload
                              ,ContentType
                              ,[{'mandatory', 'true'}]
                              ).

%%------------------------------------------------------------------------------
%% @doc Build a `reenable_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec reenable_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
reenable_resp(Resp) ->
    kapi_definition:build_message(Resp, reenable_resp_definition()).

%%------------------------------------------------------------------------------
%% @doc Validate that `Req' is a `reenable_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec reenable_resp_v(kz_term:api_terms()) -> boolean().
reenable_resp_v(Resp) ->
    kapi_definition:validate(Resp, reenable_resp_definition()).

%%------------------------------------------------------------------------------
%% @doc Publish a `reenable_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec publish_reenable_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_reenable_resp(RespQ, API) ->
    publish_reenable_resp(RespQ, API, ?DEFAULT_CONTENT_TYPE).

-spec publish_reenable_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_reenable_resp(RespQ, Resp, ContentType) ->
    Definition = reenable_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Resp
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(RespQ, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Bind to and unbind from a queue of this API exchange and events.
%% @end
%%------------------------------------------------------------------------------
-spec bind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Q, _Props) ->
    'ok' = kz_amqp_util:bind_q_to_kapps(Q, <<"webhooks.*">>).

-spec unbind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Q, _Props) ->
    'ok' = kz_amqp_util:unbind_q_from_kapps(Q, <<"webhooks.*">>).

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:kapps_exchange(),
    kz_amqp_util:targeted_exchange().
