%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023-2024, 2600Hz
%%% @doc
%%% @author Kusal Fernando
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_crm).

-export([bind_q/2
        ,unbind_q/2
        ,declare_exchanges/0
        ]).

-export([api_definitions/0, api_definition/1]).

-export([authenticate/1
        ,authenticate_v/1
        ,publish_authenticate/1
        ,publish_authenticate/2
        ]).
-export([authenticate_resp/1
        ,authenticate_resp_v/1
        ,publish_authenticate_resp/2
        ]).

-export([caller_info/1
        ,caller_info_v/1
        ,publish_caller_info/1
        ,publish_caller_info/2
        ]).
-export([caller_info_resp/1
        ,caller_info_resp_v/1
        ,publish_caller_info_resp/2
        ]).

-export([interaction/1
        ,interaction_v/1
        ,publish_interaction/1
        ,publish_interaction/2
        ]).
-export([interaction_resp/1
        ,interaction_resp_v/1
        ,publish_interaction_resp/2
        ]).

-include_lib("kz_amqp_util.hrl").
-include("kapi_crm.hrl").

%%------------------------------------------------------------------------------
%% @doc Bind to and unbind from a queue of this API exchange and events.
%% Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec bind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Queue, Props) ->
    AccountId   = props:get_value('account_id', Props, <<"*">>),
    EventName   = props:get_value('event_name', Props, <<"*">>),
    kz_amqp_util:bind_q_to_exchange(Queue, ?CRM_ROUTE(AccountId, EventName), ?CRM_EXCHANGE).

-spec unbind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Queue, Props) ->
    AccountId   = props:get_value('account_id', Props, <<"*">>),
    EventName   = props:get_value('event_name', Props, <<"*">>),
    kz_amqp_util:unbind_q_from_exchange(Queue, ?CRM_ROUTE(AccountId, EventName), ?CRM_EXCHANGE).

-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:new_exchange(?CRM_EXCHANGE, ?CRM_EXCHANGE_TYPE).

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [authenticate_definition()
    ,authenticate_resp_definition()
    ,caller_info_definition()
    ,caller_info_resp_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(<<"authenticate">>) ->
    authenticate_definition();
api_definition(<<"authenticate_resp">>) ->
    authenticate_resp_definition();
api_definition(<<"caller_info">>) ->
    caller_info_definition();
api_definition(<<"caller_info_resp">>) ->
    caller_info_resp_definition();
api_definition(<<"interaction">>) ->
    interaction_definition();
api_definition(<<"interaction_resp">>) ->
    interaction_resp_definition().

-spec authenticate_definition() -> kapi_definition:api().
authenticate_definition() ->
    EventName = <<"authenticate">>,
    Category = <<"crm">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"CRM Authentication">>}
              ,{fun kapi_definition:set_description/2, <<"CRM authentication">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun authenticate/1}
              ,{fun kapi_definition:set_validate_fun/2, fun authenticate_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_authenticate/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Account-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, [{<<"Account-ID">>, fun kz_term:is_ne_binary/1}
                                                 ]}
              ],
    kapi_definition:setters(Setters).

-spec authenticate_resp_definition() -> kapi_definition:api().
authenticate_resp_definition() ->
    EventName = <<"authenticate_reply">>,
    Category = <<"crm">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"CRM Authentication Response">>}
              ,{fun kapi_definition:set_description/2, <<"CRM authentication response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun authenticate_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun authenticate_resp_v/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Auth-Response">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, [{<<"Auth-Response">>, fun kz_json:is_json_object/1}
                                                 ]}
              ],
    kapi_definition:setters(Setters).

-spec caller_info_definition() -> kapi_definition:api().
caller_info_definition() ->
    EventName = <<"caller_info">>,
    Category = <<"crm">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Query Caller Info">>}
              ,{fun kapi_definition:set_description/2, <<"Query caller info in CRM">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun caller_info/1}
              ,{fun kapi_definition:set_validate_fun/2, fun caller_info_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_caller_info/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Caller-ID">>
                                                            ,<<"Account-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"CRM-Platform">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, [{<<"Caller-ID">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"CRM-Platform">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"Account-ID">>, fun kz_term:is_ne_binary/1}
                                                 ]}
              ],
    kapi_definition:setters(Setters).

-spec caller_info_resp_definition() -> kapi_definition:api().
caller_info_resp_definition() ->
    EventName = <<"caller_info_reply">>,
    Category = <<"crm">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"CRM Query Response">>}
              ,{fun kapi_definition:set_description/2, <<"Caller info query response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun caller_info_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun caller_info_resp_v/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Caller-Info-Response">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Caller-Info-Response">>, fun kz_json:is_json_object/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec interaction_definition() -> kapi_definition:api().
interaction_definition() ->
    EventName = <<"interaction">>,
    Category = <<"crm">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Post Call Interaction">>}
              ,{fun kapi_definition:set_description/2, <<"Post call interaction in CRM">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun interaction/1}
              ,{fun kapi_definition:set_validate_fun/2, fun interaction_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_interaction/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Duration">>
                                                            ,<<"Callee-ID">>
                                                            ,<<"Direction">>
                                                            ,<<"Account-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"CRM-Platform">>
                                                            ,<<"Status">>
                                                            ,<<"Description">>
                                                            ,<<"Disposition">>
                                                            ,<<"Caller-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, [{<<"Status">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"Description">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"Duration">>, fun kz_term:is_pos_integer/1}
                                                 ,{<<"Contact-ID">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"Direction">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"Disposition">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"CRM-Platform">>, fun kz_term:is_ne_binary/1}
                                                 ,{<<"Account-ID">>, fun kz_term:is_ne_binary/1}
                                                 ]}
              ],
    kapi_definition:setters(Setters).

-spec interaction_resp_definition() -> kapi_definition:api().
interaction_resp_definition() ->
    EventName = <<"interaction_reply">>,
    Category = <<"crm">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"CRM Call Interaction Response">>}
              ,{fun kapi_definition:set_description/2, <<"Call interaction response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun interaction_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun interaction_resp_v/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Interaction-Response">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Interaction-Response">>, fun kz_json:is_json_object/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Sends an authenticate message to a CRM process.
%% This will set the auth token in the state.
%% @end
%%------------------------------------------------------------------------------
-spec authenticate(kz_term:api_terms()) -> kz_api:api_formatter_return().
authenticate(Req) ->
    kapi_definition:build_message(Req, authenticate_definition()).

-spec authenticate_v(kz_term:api_terms()) -> boolean().
authenticate_v(Req) ->
    kapi_definition:validate(Req, authenticate_definition()).

-spec publish_authenticate(kz_term:api_terms()) -> 'ok'.
publish_authenticate(JObj) ->
    publish_authenticate(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_authenticate(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_authenticate(API, ContentType) ->
    Definition = authenticate_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:basic_publish(?CRM_EXCHANGE, route(API), Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Reply to a CRM authentication.
%% @end
%%------------------------------------------------------------------------------
-spec authenticate_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
authenticate_resp(Req) ->
    kapi_definition:build_message(Req, authenticate_resp_definition()).

-spec authenticate_resp_v(kz_term:api_terms()) -> boolean().
authenticate_resp_v(Req) ->
    kapi_definition:validate(Req, authenticate_resp_definition()).

-spec publish_authenticate_resp(binary(), kz_term:api_terms()) -> 'ok'.
publish_authenticate_resp(Queue, Req) ->
    Definition = authenticate_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload).

%%------------------------------------------------------------------------------
%% @doc Query Salesforce based on Caller ID.
%% @end
%%------------------------------------------------------------------------------
-spec caller_info(kz_term:api_terms()) -> kz_api:api_formatter_return().
caller_info(Req) ->
    kapi_definition:build_message(Req, caller_info_definition()).

-spec caller_info_v(kz_term:api_terms()) -> boolean().
caller_info_v(Req) ->
    kapi_definition:validate(Req, caller_info_definition()).

-spec publish_caller_info(kz_term:api_terms()) -> 'ok'.
publish_caller_info(JObj) ->
    publish_caller_info(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_caller_info(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_caller_info(API, ContentType) ->
    Definition = caller_info_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:basic_publish(?CRM_EXCHANGE, route(API), Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Reply to caller info query.
%% @end
%%------------------------------------------------------------------------------
-spec caller_info_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
caller_info_resp(Req) ->
    kapi_definition:build_message(Req, caller_info_resp_definition()).

-spec caller_info_resp_v(kz_term:api_terms()) -> boolean().
caller_info_resp_v(Req) ->
    kapi_definition:validate(Req, caller_info_resp_definition()).

-spec publish_caller_info_resp(binary(), kz_term:api_terms()) -> 'ok'.
publish_caller_info_resp(Queue, Req) ->
    Definition = caller_info_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload).

%%------------------------------------------------------------------------------
%% @doc Sends an interaction message to a CRM process.
%% @end
%%------------------------------------------------------------------------------
-spec interaction(kz_term:api_terms()) -> kz_api:api_formatter_return().
interaction(Req) ->
    kapi_definition:build_message(Req, interaction_definition()).

-spec interaction_v(kz_term:api_terms()) -> boolean().
interaction_v(Req) ->
    kapi_definition:validate(Req, interaction_definition()).

-spec publish_interaction(kz_term:api_terms()) -> 'ok'.
publish_interaction(JObj) ->
    publish_interaction(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_interaction(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_interaction(API, ContentType) ->
    Definition = interaction_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:basic_publish(?CRM_EXCHANGE, route(API), Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Reply for posting an interaction.
%% @end
%%------------------------------------------------------------------------------
-spec interaction_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
interaction_resp(Req) ->
    kapi_definition:build_message(Req, interaction_resp_definition()).

-spec interaction_resp_v(kz_term:api_terms()) -> boolean().
interaction_resp_v(Req) ->
    kapi_definition:validate(Req, interaction_resp_definition()).

-spec publish_interaction_resp(binary(), kz_term:api_terms()) -> 'ok'.
publish_interaction_resp(Queue, Req) ->
    Definition = interaction_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload).

-spec route(list()) -> binary().
route(Args) ->
    Account   = props:get_value(<<"Account-ID">>, Args, <<"account_id">>),
    EventName = props:get_value(<<"Event-Name">>, Args, <<"event_name">>),
    ?CRM_ROUTE(Account, EventName).

