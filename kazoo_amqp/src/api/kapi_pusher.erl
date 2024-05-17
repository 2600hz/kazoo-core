%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2024, 2600Hz
%%% @doc
%%% @author Luis Azedo
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_pusher).

-export([api_definitions/0, api_definition/1]).

-export([endpoint_push_req/1
        ,endpoint_push_req_v/1
        ,publish_endpoint_push_req/1
        ,publish_endpoint_push_req/2
        ]).
-export([endpoint_push_resp/1
        ,endpoint_push_resp_v/1
        ,publish_endpoint_push_resp/2
        ,publish_endpoint_push_resp/3
        ]).
-export([push_req/1, push_req_v/1]).
-export([push_resp/1, push_resp_v/1]).
-export([publish_push_req/1, publish_push_req/2]).
-export([publish_push_resp/1, publish_push_resp/2]).
-export([publish_targeted_push_resp/2, publish_targeted_push_resp/3]).

-export([bind_q/2, unbind_q/2]).

-export([declare_exchanges/0]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(PUSH_EXCHANGE, <<"pushes">>).
-define(PUSH_EVENT_CATEGORY, <<"notification">>).

-define(ENDPOINT_PUSH_REQ_EVENT_NAME, <<"endpoint_push_req">>).
-define(ENDPOINT_PUSH_RESP_EVENT_NAME, <<"endpoint_push_resp">>).
-define(ENDPOINT_PUSH_BINDING, <<"notification.endpoint_push">>).

-type binding_restrictions() :: ['endpoint_push' | 'push'] | 'undefined'.

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [endpoint_push_req_definition()
    ,endpoint_push_resp_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(?ENDPOINT_PUSH_REQ_EVENT_NAME) ->
    endpoint_push_req_definition();
api_definition(?ENDPOINT_PUSH_RESP_EVENT_NAME) ->
    endpoint_push_resp_definition().

%%------------------------------------------------------------------------------
%% @doc Create the `kapi' definition for an `endpoint_push_req'.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_push_req_definition() -> kapi_definition:api().
endpoint_push_req_definition() ->
    EventName = ?ENDPOINT_PUSH_REQ_EVENT_NAME,
    Category = ?PUSH_EVENT_CATEGORY,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Endpoint Push Req">>}
              ,{fun kapi_definition:set_description/2
               ,<<"Send a push notification to a device or a user's devices">>
               }
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun endpoint_push_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun endpoint_push_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_endpoint_push_req/1}
              ,{fun kapi_definition:set_binding/2, ?ENDPOINT_PUSH_BINDING}
              ,{fun kapi_definition:set_required_headers/2, [<<"Account-ID">>
                                                            ,<<"Endpoint">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Alert">>
                                                            ,<<"APNs">>
                                                            ,<<"Badge">>
                                                            ,<<"Call-ID">>
                                                            ,<<"Category">>
                                                            ,<<"Collapse-ID">>
                                                            ,<<"Content-Available">>
                                                            ,<<"Content-Mutable">>
                                                            ,<<"Data">>
                                                            ,<<"FCM">>
                                                            ,<<"Priority">>
                                                            ,<<"Sound">>
                                                            ,<<"TTL">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Priority">>, [<<"low">>, <<"normal">>, <<"high">>]}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Account-ID">>, fun kz_term:is_ne_binary/1}
                ,{<<"Alert">>, fun is_alert/1}
                ,{<<"APNs">>, fun is_apns_payload/1}
                ,{<<"Badge">>, fun is_integer/1}
                ,{<<"Call-ID">>, fun kz_term:is_ne_binary/1}
                ,{<<"Category">>, fun is_binary/1}
                ,{<<"Collapse-ID">>, fun is_collapse_id/1}
                ,{<<"Content-Available">>, fun is_boolean/1}
                ,{<<"Content-Mutable">>, fun is_boolean/1}
                ,{<<"Data">>, fun is_custom_data/1}
                ,{<<"Endpoint">>, fun is_endpoint/1}
                ,{<<"FCM">>, fun is_fcm_payload/1}
                ,{<<"Sound">>, fun is_binary/1}
                ,{<<"TTL">>, fun is_ttl/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Create the `kapi' definition for an `endpoint_push_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_push_resp_definition() -> kapi_definition:api().
endpoint_push_resp_definition() ->
    EventName = ?ENDPOINT_PUSH_RESP_EVENT_NAME,
    Category = ?PUSH_EVENT_CATEGORY,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Endpoint Push Resp">>}
              ,{fun kapi_definition:set_description/2
               ,<<"Respond with the status of sending a push notification to a device or a user's devices">>
               }
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun endpoint_push_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun endpoint_push_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_endpoint_push_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Overall-Status">>
                                                            ,<<"Results">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Overall-Status">>, fun kz_term:is_pos_integer/1}
                ,{<<"Results">>, fun is_endpoint_push_results/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Validate that `Term' is a valid alert object.
%% @end
%%------------------------------------------------------------------------------
-spec is_alert(kz_json:json_term()) -> boolean().
is_alert(Term) ->
    validate(Term, [{<<"Title">>, fun kz_term:is_api_binary/1}
                   ,{<<"Subtitle">>, fun kz_term:is_api_binary/1}
                   ,{<<"Body">>, fun kz_term:is_api_binary/1}
                   ,{<<"Title-Key">>, fun kz_term:is_api_binary/1}
                   ,{<<"Title-Params">>, fun is_maybe_binaries/1}
                   ,{<<"Body-Key">>, fun kz_term:is_api_binary/1}
                   ,{<<"Body-Params">>, fun is_maybe_binaries/1}
                   ]).

%%------------------------------------------------------------------------------
%% @doc Validate that `Term' is a valid object containing APNs-specific push
%% properties.
%% @end
%%------------------------------------------------------------------------------
-spec is_apns_payload(kz_json:json_term()) -> boolean().
is_apns_payload(Term) ->
    validate(Term, [{<<"Alert">>, fun is_maybe_apns_alert_payload/1}
                   ,{<<"Thread-ID">>, fun kz_term:is_api_binary/1}
                   ,{<<"Topic">>, fun kz_term:is_api_binary/1}
                   ,{<<"Push-Type">>, fun is_maybe_apns_push_type/1}
                   ]).

-spec is_maybe_apns_alert_payload(kz_json:api_json_term()) -> boolean().
is_maybe_apns_alert_payload('undefined') -> 'true';
is_maybe_apns_alert_payload(Term) ->
    validate(Term, [{<<"Subtitle-Key">>, fun kz_term:is_api_binary/1}
                   ,{<<"Subtitle-Params">>, fun is_maybe_binaries/1}
                   ]).

-spec is_maybe_apns_push_type(kz_json:api_json_term()) -> boolean().
is_maybe_apns_push_type('undefined') -> 'true';
is_maybe_apns_push_type(Term) ->
    lists:member(Term, [<<"alert">>
                       ,<<"background">>
                       ,<<"complication">>
                       ,<<"fileprovider">>
                       ,<<"location">>
                       ,<<"mdm">>
                       ,<<"voip">>
                       ]).

%%------------------------------------------------------------------------------
%% @doc Validate that `Term' is a collapse identifier binary of 64 bytes or
%% less.
%% @end
%%------------------------------------------------------------------------------
-spec is_collapse_id(kz_json:json_term()) -> boolean().
is_collapse_id(Term) when byte_size(Term) =< 64 -> 'true';
is_collapse_id(_) -> 'false'.

%%------------------------------------------------------------------------------
%% @doc Validate that custom data for an `endpoint_push_req' does not contain
%% banned properties that might conflict with other APNs/FCM message properties.
%% @end
%%------------------------------------------------------------------------------
-spec is_custom_data(kz_json:json_term()) -> boolean().
is_custom_data(Term) ->
    validate(Term, [{<<"aps">>, fun(V) -> V =:= 'undefined' end}
                   ,{<<"from">>, fun(V) -> V =:= 'undefined' end}
                   ,{<<"message_type">>, fun(V) -> V =:= 'undefined' end}
                   ])
        andalso not lists:any(fun has_restricted_prefix/1, kz_json:get_keys(Term)).

-spec has_restricted_prefix(kz_json:key()) -> boolean().
has_restricted_prefix(<<"google", _/binary>>) -> 'true';
has_restricted_prefix(<<"gcm", _/binary>>) -> 'true';
has_restricted_prefix(_Key) -> 'false'.

%%------------------------------------------------------------------------------
%% @doc Validate that `Term' contains valid identification of an endpoint.
%% @end
%%------------------------------------------------------------------------------
-spec is_endpoint(kz_json:json_term()) -> boolean().
is_endpoint(Term) ->
    validate(Term, [{<<"ID">>, fun is_endpoint_id/1}
                   ,{<<"Type">>, fun is_endpoint_type/1}
                   ]).

-spec is_endpoint_id(kz_json:api_json_term()) -> boolean().
is_endpoint_id(<<_:32/binary>>) -> 'true';
is_endpoint_id(_) -> 'false'.

-spec is_endpoint_type(kz_json:api_json_term()) -> boolean().
is_endpoint_type(Term) ->
    lists:member(Term, [<<"device">>, <<"user">>]).

%%------------------------------------------------------------------------------
%% @doc Validate that `Term' is a valid object containing FCM-specific push
%% properties.
%% @end
%%------------------------------------------------------------------------------
-spec is_fcm_payload(kz_json:json_term()) -> boolean().
is_fcm_payload(Term) ->
    validate(Term, [{<<"Android">>, fun is_maybe_fcm_android_payload/1}]).

-spec is_maybe_fcm_android_payload(kz_json:api_json_term()) -> boolean().
is_maybe_fcm_android_payload('undefined') -> 'true';
is_maybe_fcm_android_payload(Term) ->
    validate(Term, [{<<"Channel-ID">>, fun kz_term:is_api_binary/1}
                   ,{<<"Icon">>, fun kz_term:is_api_binary/1}
                   ,{<<"Tag">>, fun kz_term:is_api_binary/1}
                   ,{<<"Color">>, fun kz_term:is_api_binary/1}
                   ]).

%%------------------------------------------------------------------------------
%% @doc Validate that `Term' is a valid time-to-live (in seconds) during which
%% delivery of the push notification can be retried. FCM has an upper limit of
%% 4 weeks.
%% @end
%%------------------------------------------------------------------------------
-spec is_ttl(kz_json:json_term()) -> boolean().
is_ttl(Term) ->
    is_integer(Term)
        andalso Term >= 0
        andalso Term =< 2419200.

%%------------------------------------------------------------------------------
%% @doc Validate that `Term' is a valid list of results from push notification
%% attempts.
%% @end
%%------------------------------------------------------------------------------
-spec is_endpoint_push_results(kz_json:json_term()) -> boolean().
is_endpoint_push_results(Results) when is_list(Results) ->
    lists:all(fun is_endpoint_push_result/1, Results);
is_endpoint_push_results(_) -> 'false'.

-spec is_endpoint_push_result(kz_json:json_term()) -> boolean().
is_endpoint_push_result(Result) ->
    validate(Result, [{<<"Device-ID">>, fun is_endpoint_id/1}
                     ,{<<"Status">>, fun kz_term:is_pos_integer/1}
                     ,{<<"Message">>, fun is_binary/1}
                     ]).

%%------------------------------------------------------------------------------
%% @doc Build an `endpoint_push_req'.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_push_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
endpoint_push_req(Req) ->
    kapi_definition:build_message(Req, endpoint_push_req_definition()).

%%------------------------------------------------------------------------------
%% @doc Validate that `Req' is an `endpoint_push_req'.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_push_req_v(kz_term:api_terms()) -> boolean().
endpoint_push_req_v(Req) ->
    kapi_definition:validate(Req, endpoint_push_req_definition()).

%%------------------------------------------------------------------------------
%% @doc Publish an `endpoint_push_req'.
%% @end
%%------------------------------------------------------------------------------
-spec publish_endpoint_push_req(kz_term:api_terms()) -> 'ok'.
publish_endpoint_push_req(API) ->
    publish_endpoint_push_req(API, ?DEFAULT_CONTENT_TYPE).

-spec publish_endpoint_push_req(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_endpoint_push_req(Req, ContentType) ->
    Definition = endpoint_push_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:basic_publish(?PUSH_EXCHANGE
                              ,kapi_definition:binding(Definition)
                              ,Payload
                              ,ContentType
                              ).

%%------------------------------------------------------------------------------
%% @doc Build an `endpoint_push_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_push_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
endpoint_push_resp(Req) ->
    kapi_definition:build_message(Req, endpoint_push_resp_definition()).

%%------------------------------------------------------------------------------
%% @doc Validate that `Req' is an `endpoint_push_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec endpoint_push_resp_v(kz_term:api_terms()) -> boolean().
endpoint_push_resp_v(Req) ->
    kapi_definition:validate(Req, endpoint_push_resp_definition()).

%%------------------------------------------------------------------------------
%% @doc Publish an `endpoint_push_resp'.
%% @end
%%------------------------------------------------------------------------------
-spec publish_endpoint_push_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_endpoint_push_resp(RespQ, API) ->
    publish_endpoint_push_resp(RespQ, API, ?DEFAULT_CONTENT_TYPE).

-spec publish_endpoint_push_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_endpoint_push_resp(RespQ, Req, ContentType) ->
    Definition = endpoint_push_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(RespQ, Payload, ContentType).

-define(PUSH_REQ_HEADERS, [<<"Token-ID">>
                          ,<<"Token-Type">>
                          ,<<"Token-App">>
                          ,<<"Payload">>
                          ]).
-define(OPTIONAL_PUSH_REQ_HEADERS, [<<"Queue">>, <<"Call-ID">>
                                   ,<<"Badge">>, <<"Sound">>
                                   ,<<"Account-ID">>, <<"Endpoint-ID">>
                                   ,<<"Expires">>
                                   ,<<"Token-Reg">>
                                   ,<<"Alert">>, <<"Alert-Key">>, <<"Alert-Params">>
                                   ]).
-define(PUSH_REQ_VALUES, [{<<"Event-Category">>, ?PUSH_EVENT_CATEGORY}
                         ,{<<"Event-Name">>, <<"push_req">>}
                         ]).
-define(PUSH_REQ_TYPES, [{<<"Expires">>, fun(V) -> is_integer(kz_term:to_integer(V)) end}]).

-define(PUSH_RESP_HEADERS, [<<"Token-ID">>]).
-define(OPTIONAL_PUSH_RESP_HEADERS, []).
-define(PUSH_RESP_VALUES, [{<<"Event-Category">>, ?PUSH_EVENT_CATEGORY}
                          ,{<<"Event-Name">>, <<"push_resp">>}
                          ]).
-define(PUSH_RESP_TYPES, []).

-define(KEY_PUSH, <<"notification.push">>).

-spec push_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
push_req(Prop) when is_list(Prop) ->
    case push_req_v(Prop) of
        'true' -> kz_api:build_message(Prop, ?PUSH_REQ_HEADERS, ?OPTIONAL_PUSH_REQ_HEADERS);
        'false' -> {'error', "Proplist failed validation for push"}
    end;
push_req(JObj) ->
    push_req(kz_json:to_proplist(JObj)).

-spec push_req_v(kz_term:api_terms()) -> boolean().
push_req_v(Prop) when is_list(Prop) ->
    kz_api:validate(Prop, ?PUSH_REQ_HEADERS, ?PUSH_REQ_VALUES, ?PUSH_REQ_TYPES);
push_req_v(JObj) ->
    push_req_v(kz_json:to_proplist(JObj)).

-spec push_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
push_resp(Prop) when is_list(Prop) ->
    case push_resp_v(Prop) of
        'true' -> kz_api:build_message(Prop, ?PUSH_RESP_HEADERS, ?OPTIONAL_PUSH_RESP_HEADERS);
        'false' -> {'error', "Proplist failed validation for push"}
    end;
push_resp(JObj) ->
    push_resp(kz_json:to_proplist(JObj)).

-spec push_resp_v(kz_term:api_terms()) -> boolean().
push_resp_v(Prop) when is_list(Prop) ->
    kz_api:validate(Prop, ?PUSH_RESP_HEADERS, ?PUSH_RESP_VALUES, ?PUSH_RESP_TYPES);
push_resp_v(JObj) ->
    push_resp_v(kz_json:to_proplist(JObj)).

-spec publish_push_req(kz_term:api_terms()) -> 'ok'.
publish_push_req(JObj) ->
    publish_push_req(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_push_req(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_push_req(Req, ContentType) ->
    {'ok', Payload} = kz_api:prepare_api_payload(Req, ?PUSH_REQ_VALUES, fun push_req/1),
    kz_amqp_util:basic_publish(?PUSH_EXCHANGE, push_routing_key(Req), Payload, ContentType).

-spec publish_push_resp(kz_term:api_terms()) -> 'ok'.
publish_push_resp(JObj) ->
    publish_push_resp(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_push_resp(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_push_resp(Req, ContentType) ->
    {'ok', Payload} = kz_api:prepare_api_payload(Req, ?PUSH_RESP_VALUES, fun push_resp/1),
    kz_amqp_util:basic_publish(?PUSH_EXCHANGE, push_routing_key(Req), Payload, ContentType).

-spec publish_targeted_push_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_targeted_push_resp(RespQ, JObj) ->
    publish_targeted_push_resp(RespQ, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_targeted_push_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_targeted_push_resp(RespQ, JObj, ContentType) ->
    {'ok', Payload} = kz_api:prepare_api_payload(JObj, ?PUSH_RESP_VALUES, fun push_resp/1),
    kz_amqp_util:targeted_publish(RespQ, Payload, ContentType).

-spec push_routing_key(kz_term:api_terms()) -> kz_term:ne_binary().
push_routing_key(Req) when is_list(Req) ->
    push_routing_key(props:get_value(<<"Token-Type">>, Req, <<"*">>), props:get_value(<<"Token">>, Req,<<"*">>));
push_routing_key(Req) ->
    push_routing_key(kz_json:get_value(<<"Token-Type">>, Req, <<"*">>), kz_json:get_value(<<"Token">>, Req, <<"*">>)).
push_routing_key(Type, Token) ->
    list_to_binary([?KEY_PUSH, ".", kz_amqp_util:encode(Type), ".", kz_amqp_util:encode(Token)]).

%% API Helpers

-spec bind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Queue, Props) ->
    Token = props:get_value('token', Props, <<"*">>),
    Type = props:get_value('type', Props, <<"*">>),
    bind_q(Queue, Type, Token, props:get_value('restrict_to', Props)).

-spec bind_q(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), binding_restrictions()) -> 'ok'.
bind_q(Queue, Type, Token, 'undefined') ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Queue, ?ENDPOINT_PUSH_BINDING, ?PUSH_EXCHANGE),
    kz_amqp_util:bind_q_to_exchange(Queue, push_routing_key(Type, Token), ?PUSH_EXCHANGE);
bind_q(Queue, Type, Token, ['endpoint_push'|Restrict]) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Queue, ?ENDPOINT_PUSH_BINDING, ?PUSH_EXCHANGE),
    bind_q(Queue, Type, Token, Restrict);
bind_q(Queue, Type, Token, ['push'|Restrict]) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Queue, push_routing_key(Type, Token), ?PUSH_EXCHANGE),
    bind_q(Queue, Type, Token, Restrict);
bind_q(Queue, Type, Token, [_|Restrict]) ->
    bind_q(Queue, Type, Token, Restrict);
bind_q(_Queue, _Type, _Token, []) -> 'ok'.

-spec unbind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Queue, Props) ->
    Token = props:get_value('token', Props, <<"*">>),
    Type = props:get_value('type', Props, <<"*">>),
    unbind_q(Queue, Type, Token, props:get_value('restrict_to', Props)).

-spec unbind_q(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), binding_restrictions()) -> 'ok'.
unbind_q(Queue, Type, Token, 'undefined') ->
    _ = kz_amqp_util:unbind_q_from_exchange(Queue, ?ENDPOINT_PUSH_BINDING, ?PUSH_EXCHANGE),
    _ = kz_amqp_util:unbind_q_from_exchange(Queue, push_routing_key(Type, Token), ?PUSH_EXCHANGE),
    'ok';
unbind_q(Queue, Type, Token, ['endpoint_push'|Restrict]) ->
    _ = kz_amqp_util:unbind_q_from_exchange(Queue, ?ENDPOINT_PUSH_BINDING, ?PUSH_EXCHANGE),
    unbind_q(Queue, Type, Token, Restrict);
unbind_q(Queue, Type, Token, ['push'|Restrict]) ->
    _ = kz_amqp_util:unbind_q_from_exchange(Queue, push_routing_key(Type, Token), ?PUSH_EXCHANGE),
    unbind_q(Queue, Type, Token, Restrict);
unbind_q(Queue, Type, Token, [_|Restrict]) ->
    unbind_q(Queue, Type, Token, Restrict);
unbind_q(_Queue, _Type, _Token, []) -> 'ok'.

-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:targeted_exchange(),
    kz_amqp_util:new_exchange(?PUSH_EXCHANGE, <<"topic">>).

%%------------------------------------------------------------------------------
%% @doc Validate an object's properties against a list of types. If `Term' is
%% not an object, validation fails.
%% @end
%%------------------------------------------------------------------------------
-spec validate(kz_json:json_term(), kz_api:api_types()) -> boolean().
validate(Term, Types) ->
    case kz_json:is_json_object(Term) of
        'true' -> lists:all(fun({K, T}) -> validate(K, T, Term) end, Types);
        'false' -> 'false'
    end.

-spec validate(kz_json:key(), kz_api:formatter_fun(), kz_json:object()) -> boolean().
validate(Key, VFun, JObj) ->
    VFun(kz_json:get_value(Key, JObj)).

%%------------------------------------------------------------------------------
%% @doc Determine whether a value is an optional list of binaries. The value can
%% either be `undefined' or a list where each element must be a defined binary.
%% @end
%%------------------------------------------------------------------------------
-spec is_maybe_binaries(any()) -> boolean().
is_maybe_binaries('undefined') -> 'true';
is_maybe_binaries(V) when is_list(V) -> lists:all(fun is_binary/1, V);
is_maybe_binaries(_) -> 'false'.
