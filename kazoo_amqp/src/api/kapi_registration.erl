%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc Handle registration-related APIs, like `reg_success' and `reg_lookup'.
%%% @author James Aimonetti
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_registration).

-export([api_definitions/0, api_definition/1]).

-export([success/1
        ,success_v/1
        ,publish_success/1
        ,publish_success/2
        ]).
-export([query_req/1
        ,query_req_v/1
        ,publish_query_req/1
        ,publish_query_req/2
        ]).
-export([query_resp/1
        ,query_resp_v/1
        ,publish_query_resp/2
        ,publish_query_resp/3
        ]).
-export([query_err/1
        ,query_err_v/1
        ,publish_query_err/2
        ,publish_query_err/3
        ]).
-export([flush/1
        ,flush_v/1
        ,publish_flush/1
        ,publish_flush/2
        ]).
-export([search_req/1
        ,search_req_v/1
        ,publish_search_req/1
        ]).
-export([search_partial_resp/1
        ,search_partial_resp_v/1
        ,publish_search_partial_resp/2
        ,publish_search_partial_resp/3
        ]).
-export([search_resp/1
        ,search_resp_v/1
        ,publish_search_resp/2
        ]).
-export([sync/1
        ,sync_v/1
        ,publish_sync/1
        ,publish_sync/2
        ]).

-export([bind_q/2, unbind_q/2]).
-export([declare_exchanges/0]).

-export([success_keys/0]).

-export([search_realm_regs/1, search_realm_regs/2, search_realm_regs/3]).

-include("kz_amqp_util.hrl").

-ifdef(TEST).
-export([get_success_routing/2
        ,get_query_routing/2
        ,get_flush_routing/1
        ]).
-endif.

-export_type([query_req/0
             ,success/0
             ]).

-type query_req() :: kz_json:object().
-type success() :: kz_term:api_terms().

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [success_definition()
    ,query_req_definition()
    ,query_resp_definition()
    ,query_err_definition()
    ,flush_definition()
    ,search_partial_resp_definition()
    ,search_req_definition()
    ,search_resp_definition()
    ,sync_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(<<"success">>) ->
    success_definition();
api_definition(<<"query_req">>) ->
    query_req_definition();
api_definition(<<"query_resp">>) ->
    query_resp_definition();
api_definition(<<"query_err">>) ->
    query_err_definition();
api_definition(<<"flush">>) ->
    flush_definition();
api_definition(<<"search_partial_resp">>) ->
    search_partial_resp_definition();
api_definition(<<"search_req">>) ->
    search_req_definition();
api_definition(<<"search_resp">>) ->
    search_resp_definition();
api_definition(<<"sync">>) ->
    sync_definition().

-spec success_definition() -> kapi_definition:api().
success_definition() ->
    EventName = <<"reg_success">>,
    Category = <<"directory">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Success">>}
              ,{fun kapi_definition:set_description/2, <<"Directory Registration Success">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun success/1}
              ,{fun kapi_definition:set_validate_fun/2, fun success_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_success/1}
              ,{fun kapi_definition:set_binding/2, fun get_success_routing/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Contact">>
                                                            ,<<"Event-Timestamp">>
                                                            ,<<"Expires">>
                                                            ,<<"Realm">>
                                                            ,<<"Username">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Account-DB">>
                                                            ,<<"AOR">>
                                                            ,<<"Authorizing-ID">>
                                                            ,<<"Custom-Channel-Vars">>
                                                            ,<<"First-Registration">>
                                                            ,<<"FreeSWITCH-Hostname">>
                                                            ,<<"FreeSWITCH-Nodename">>
                                                            ,<<"From-Host">>
                                                            ,<<"From-User">>
                                                            ,?KEY_API_ACCOUNT_ID
                                                            ,?KEY_API_CALL_ID
                                                            ,<<"Network-IP">>
                                                            ,<<"Network-Port">>
                                                            ,<<"Original-Contact">>
                                                            ,<<"Presence-Hosts">>
                                                            ,<<"Profile-Name">>
                                                            ,<<"Proxy-IP">>
                                                            ,<<"Proxy-Path">>
                                                            ,<<"Proxy-Port">>
                                                            ,<<"Proxy-Protocol">>
                                                            ,<<"Register-Overwrite-Notify">>
                                                            ,<<"Registrar-Node">>
                                                            ,<<"RPid">>
                                                            ,<<"RUID">>
                                                            ,<<"Source-IP">>
                                                            ,<<"Source-Port">>
                                                            ,<<"Status">>
                                                            ,<<"Suppress-Unregister-Notify">>
                                                            ,<<"To-Host">>
                                                            ,<<"To-User">>
                                                            ,<<"User-Agent">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec query_req_definition() -> kapi_definition:api().
query_req_definition() ->
    EventName = <<"reg_query">>,
    Category = <<"directory">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Query">>}
              ,{fun kapi_definition:set_description/2, <<"Directory Registration Query">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun query_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun query_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_query_req/1}
              ,{fun kapi_definition:set_binding/2, fun get_query_routing/1}
              ,{fun kapi_definition:set_required_headers/2, []}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Count-Only">>
                                                            ,<<"Fields">>
                                                            ,<<"Realm">>
                                                            ,<<"Username">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Fields">>, fun(Fields) when is_list(Fields) ->
                                        SuccessDef = success_definition(),
                                        Allowed = [<<"Bridge-RURI">>
                                                  | kapi_definition:optional_headers(SuccessDef)
                                                   ++ kapi_definition:required_headers(SuccessDef)
                                                  ],
                                        lists:all(fun(<<Field/binary>>) -> lists:member(Field, Allowed);
                                                     ([<<Field/binary>> | _]) -> lists:member(Field, Allowed)
                                                  end
                                                 ,Fields
                                                 );
                                   (_) -> 'false'
                                end}
                ,{<<"Count-Only">>, fun(N) -> kz_term:to_boolean(N) end}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec query_resp_definition() -> kapi_definition:api().
query_resp_definition() ->
    EventName = <<"reg_query_resp">>,
    Category = <<"directory">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Query Response">>}
              ,{fun kapi_definition:set_description/2, <<"Directory Registration Query Response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun query_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun query_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_query_resp/2}
              ,{fun kapi_definition:set_required_headers/2, []}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Count">>
                                                            ,<<"Fields">>
                                                            ,<<"Registrar-Age">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec query_err_definition() -> kapi_definition:api().
query_err_definition() ->
    EventName = <<"reg_query_error">>,
    Category = <<"directory">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Query Error">>}
              ,{fun kapi_definition:set_description/2, <<"Directory Registration Query Error">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun query_err/1}
              ,{fun kapi_definition:set_validate_fun/2, fun query_err_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_query_err/2}
              ,{fun kapi_definition:set_required_headers/2, []}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Registrar-Age">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec flush_definition() -> kapi_definition:api().
flush_definition() ->
    EventName = <<"reg_flush">>,
    Category = <<"directory">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Flush">>}
              ,{fun kapi_definition:set_description/2, <<"Directory Registration Flush">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun flush/1}
              ,{fun kapi_definition:set_validate_fun/2, fun flush_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_flush/1}
              ,{fun kapi_definition:set_binding/2, fun get_flush_routing/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Realm">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Username">>
                                                            ,<<"Cache-Only">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec search_partial_resp_definition() -> kapi_definition:api().
search_partial_resp_definition() ->
    EventName = <<"search_partial_resp">>,
    Category = <<"registration">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Search Partial Response">>}
              ,{fun kapi_definition:set_description/2
               ,<<"Registration partial response for active registrations">>
               }
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun search_partial_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun search_partial_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_search_partial_resp/2}
              ,{fun kapi_definition:set_required_headers/2, []}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Registrations">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec search_req_definition() -> kapi_definition:api().
search_req_definition() ->
    EventName = <<"search_req">>,
    Category = <<"registration">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Search Request">>}
              ,{fun kapi_definition:set_description/2
               ,<<"Search request for active registrations">>
               }
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun search_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun search_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_search_req/1}
              ,{fun kapi_definition:set_binding/2, fun search_req_routing_key/1}
              ,{fun kapi_definition:set_required_headers/2, [[<<"Realm">>, <<"Token-ID">>]
                                                            ,<<"Search-Type">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Username">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Search-Type">>, [<<"detail">>
                                     ,<<"summary">>
                                     ,<<"token">>
                                     ,<<"metas">>
                                     ]
                 }
                |kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec search_resp_definition() -> kapi_definition:api().
search_resp_definition() ->
    EventName = <<"search_resp">>,
    Category = <<"registration">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Search Response">>}
              ,{fun kapi_definition:set_description/2
               ,<<"Search response for active registrations">>
               }
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun search_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun search_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_search_resp/2}
              ,{fun kapi_definition:set_required_headers/2, []}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Registrations">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec sync_definition() -> kapi_definition:api().
sync_definition() ->
    EventName = <<"reg_sync">>,
    Category = <<"directory">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Registration Sync">>}
              ,{fun kapi_definition:set_description/2, <<"Directory Registration Sync">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun sync/1}
              ,{fun kapi_definition:set_validate_fun/2, fun sync_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_sync/1}
              ,{fun kapi_definition:set_binding/2, <<"registration.sync">>}
              ,{fun kapi_definition:set_required_headers/2, []}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Registration Success.
%% Takes proplist, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec success(kz_term:api_terms()) -> kz_api:api_formatter_return().
success(Req) ->
    kapi_definition:build_message(Req, success_definition()).

-spec success_v(kz_term:api_terms()) -> boolean().
success_v(Req) ->
    kapi_definition:validate(Req, success_definition()).

-spec publish_success(kz_term:api_terms()) -> 'ok'.
publish_success(JObj) ->
    publish_success(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_success(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_success(Success, ContentType) ->
    Definition = success_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Success
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:registrar_publish((kapi_definition:binding(Definition))(Success)
                                  ,Payload
                                  ,ContentType
                                  ).

%%------------------------------------------------------------------------------
%% @doc Registration Query.
%% Takes proplist, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec query_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
query_req(Req) ->
    kapi_definition:build_message(Req, query_req_definition()).

-spec query_req_v(kz_term:api_terms()) -> boolean().
query_req_v(Req) ->
    kapi_definition:validate(Req, query_req_definition()).

-spec publish_query_req(kz_term:api_terms()) -> 'ok'.
publish_query_req(JObj) ->
    publish_query_req(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_query_req(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_query_req(Req, ContentType) ->
    Definition = query_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:registrar_publish((kapi_definition:binding(Definition))(Req)
                                  ,Payload
                                  ,ContentType
                                  ).

%%------------------------------------------------------------------------------
%% @doc Registration Query Response.
%% Takes proplist, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec query_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
query_resp(Req) ->
    kapi_definition:build_message(Req, query_resp_definition()).

-spec query_resp_v(kz_term:api_terms()) -> boolean().
query_resp_v(Req) ->
    kapi_definition:validate(Req, query_resp_definition()).

-spec publish_query_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_query_resp(Queue, JObj) ->
    publish_query_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_query_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_query_resp(Queue, Resp, ContentType) ->
    Definition = query_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Resp
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Registration Query Error Response.
%% Takes proplist, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec query_err(kz_term:api_terms()) -> kz_api:api_formatter_return().
query_err(Req) ->
    kapi_definition:build_message(Req, query_err_definition()).

-spec query_err_v(kz_term:api_terms()) -> boolean().
query_err_v(Req) ->
    kapi_definition:validate(Req, query_err_definition()).

-spec publish_query_err(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_query_err(Queue, JObj) ->
    publish_query_err(Queue, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_query_err(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_query_err(Queue, Resp, ContentType) ->
    Definition = query_err_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Resp
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Registration Flush
%% Takes proplist, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec flush(kz_term:api_terms()) -> kz_api:api_formatter_return().
flush(Req) ->
    kapi_definition:build_message(Req, flush_definition()).

-spec flush_v(kz_term:api_terms()) -> boolean().
flush_v(Req) ->
    kapi_definition:validate(Req, flush_definition()).

-spec publish_flush(kz_term:api_terms()) -> 'ok'.
publish_flush(JObj) ->
    publish_flush(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_flush(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_flush(API, ContentType) ->
    Definition = flush_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:registrar_publish((kapi_definition:binding(Definition))(API)
                                  ,Payload
                                  ,ContentType
                                  ).

%%------------------------------------------------------------------------------
%% @doc Search partial response for active registrations.
%% @end
%%------------------------------------------------------------------------------
-spec search_partial_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
search_partial_resp(Req) ->
    kapi_definition:build_message(Req, search_partial_resp_definition()).

-spec search_partial_resp_v(kz_term:api_terms()) -> boolean().
search_partial_resp_v(Req) ->
    kapi_definition:validate(Req, search_partial_resp_definition()).

-spec publish_search_partial_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_search_partial_resp(Queue, JObj) ->
    publish_search_partial_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_search_partial_resp(kz_term:ne_binary(), kz_term:api_terms(), binary()) -> 'ok'.
publish_search_partial_resp(Queue, Resp, ContentType) ->
    Definition = search_partial_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Resp
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Search request for active registrations.
%% @end
%%------------------------------------------------------------------------------
-spec search_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
search_req(Req) ->
    kapi_definition:build_message(Req, search_req_definition()).

-spec search_req_v(kz_term:api_terms()) -> boolean().
search_req_v(Req) ->
    kapi_definition:validate(Req, search_req_definition()).

-spec publish_search_req(kz_term:api_terms()) -> 'ok'.
publish_search_req(JObj) ->
    publish_search_req(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_search_req(kz_term:api_terms(), binary()) -> 'ok'.
publish_search_req(Req, ContentType) ->
    Definition = search_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:registrar_publish((kapi_definition:binding(Definition))(Req)
                                  ,Payload
                                  ,ContentType
                                  ).

%%------------------------------------------------------------------------------
%% @doc Search response for active registrations.
%% @end
%%------------------------------------------------------------------------------
-spec search_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
search_resp(Req) ->
    kapi_definition:build_message(Req, search_resp_definition()).

-spec search_resp_v(kz_term:api_terms()) -> boolean().
search_resp_v(Req) ->
    kapi_definition:validate(Req, search_resp_definition()).

-spec publish_search_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_search_resp(Queue, JObj) ->
    publish_search_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_search_resp(kz_term:ne_binary(), kz_term:api_terms(), binary()) -> 'ok'.
publish_search_resp(Queue, Resp, ContentType) ->
    Definition = search_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Resp
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Registration Sync
%% Takes proplist, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec sync(kz_term:api_terms()) -> kz_api:api_formatter_return().
sync(Req) ->
    kapi_definition:build_message(Req, sync_definition()).

-spec sync_v(kz_term:api_terms()) -> boolean().
sync_v(Req) ->
    kapi_definition:validate(Req, sync_definition()).

-spec publish_sync(kz_term:api_terms()) -> 'ok'.
publish_sync(JObj) ->
    publish_sync(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_sync(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_sync(API, ContentType) ->
    Definition = sync_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:registrar_publish(kapi_definition:binding(Definition)
                                  ,Payload
                                  ,ContentType
                                  ).

%%------------------------------------------------------------------------------
%% @doc Setup and tear down bindings for authn `gen_listeners'.
%% @end
%%------------------------------------------------------------------------------
-spec bind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Q, Props) ->
    bind_q(Q, props:get_value('restrict_to', Props), Props).

bind_q(Q, 'undefined', Props) ->
    'ok' = kz_amqp_util:bind_q_to_registrar(Q, get_success_binding(Props)),
    kz_amqp_util:bind_q_to_registrar(Q, get_query_binding(Props));
bind_q(Q, ['reg_success'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_registrar(Q, get_success_binding(Props)),
    bind_q(Q, T, Props);
bind_q(Q, ['reg_query'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_registrar(Q, get_query_binding(Props)),
    bind_q(Q, T, Props);
bind_q(Q, ['reg_flush'|T], Props) ->
    Realm = props:get_value('realm', Props, <<"*">>),
    'ok' = kz_amqp_util:bind_q_to_registrar(Q, (kapi_definition:binding(flush_definition()))(Realm)),
    bind_q(Q, T, Props);
bind_q(Q, ['search_req'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_registrar(Q, (kapi_definition:binding(search_req_definition()))(Props)),
    bind_q(Q, T, Props);
bind_q(Q, [_|T], Props) -> bind_q(Q, T, Props);
bind_q(_, [], _) -> 'ok'.

-spec unbind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Q, Props) ->
    unbind_q(Q, props:get_value('restrict_to', Props), Props).

unbind_q(Q, 'undefined', Props) ->
    _ = kz_amqp_util:unbind_q_from_registrar(Q, get_success_binding(Props)),
    kz_amqp_util:unbind_q_from_registrar(Q, get_query_binding(Props));
unbind_q(Q, ['reg_success'|T], Props) ->
    _ = kz_amqp_util:unbind_q_from_registrar(Q, get_success_binding(Props)),
    unbind_q(Q, T, Props);
unbind_q(Q, ['reg_query'|T], Props) ->
    _ = kz_amqp_util:unbind_q_from_registrar(Q, get_query_binding(Props)),
    unbind_q(Q, T, Props);
unbind_q(Q, ['reg_flush'|T], Props) ->
    Realm = props:get_value('realm', Props, <<"*">>),
    _ = kz_amqp_util:unbind_q_from_registrar(Q
                                            ,(kapi_definition:binding(flush_definition()))(Realm)
                                            ),
    unbind_q(Q, T, Props);
unbind_q(Q, ['search_req'|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_registrar(Q, (kapi_definition:binding(search_req_definition()))(Props)),
    unbind_q(Q, T, Props);
unbind_q(Q, [_|T], Props) -> unbind_q(Q, T, Props);
unbind_q(_, [], _) -> 'ok'.

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:registrar_exchange().

%%------------------------------------------------------------------------------
%% @doc Special access to the API keys.
%% @end
%%------------------------------------------------------------------------------
-spec success_keys() -> kz_term:ne_binaries().
success_keys() ->
    SuccessDef = success_definition(),
    kapi_definition:optional_headers(SuccessDef) ++ kapi_definition:required_headers(SuccessDef).

-spec get_success_routing(kz_term:api_terms()) -> kz_term:ne_binary().
get_success_routing(Prop) when is_list(Prop) ->
    get_success_routing(props:get_value(<<"Realm">>, Prop), props:get_value(<<"Username">>, Prop));
get_success_routing(JObj) ->
    get_success_routing(kz_json:get_value(<<"Realm">>, JObj)
                       ,kz_json:get_value(<<"Username">>, JObj)
                       ).

-spec get_success_routing(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binary().
get_success_routing(Realm, User) ->
    list_to_binary([<<"registration.success.">>
                   ,kz_amqp_util:encode(Realm)
                   ,".", kz_amqp_util:encode(User)
                   ]).

-spec get_query_routing(kz_term:api_terms()) -> kz_term:ne_binary().
get_query_routing(Prop) when is_list(Prop) ->
    get_query_routing(props:get_value(<<"Realm">>, Prop), props:get_value(<<"Username">>, Prop));
get_query_routing(JObj) ->
    get_query_routing(kz_json:get_value(<<"Realm">>, JObj)
                     ,kz_json:get_value(<<"Username">>, JObj)
                     ).

-spec get_query_routing(kz_term:ne_binary(), kz_term:api_ne_binary()) -> kz_term:ne_binary().
get_query_routing(Realm, 'undefined') ->
    get_query_routing(Realm, <<"*">>);
get_query_routing(Realm, User) ->
    list_to_binary([<<"registration.query.">>
                   ,kz_amqp_util:encode(Realm)
                   ,".", kz_amqp_util:encode(User)
                   ]).

-spec search_req_routing_key(kz_term:api_terms()) -> kz_term:ne_binary().
search_req_routing_key(Prop) when is_list(Prop) ->
    search_req_routing_key1(props:get_first_defined([<<"Realm">>, <<"Token-ID">>], Prop));
search_req_routing_key(JObj) ->
    search_req_routing_key1(kz_json:get_first_defined([<<"Realm">>, <<"Token-ID">>], JObj)).

search_req_routing_key1(Realm) ->
    list_to_binary([<<"registration.search_req.">>, kz_amqp_util:encode(Realm)]).

%%------------------------------------------------------------------------------
%% @doc Allow Queues to be bound for specific realms, and even users within those realms.
%% The resulting binding will be `reg.success.{realm | *}.{user | *}'.
%% The `*' matches one segment only, which means all `reg_success' messages will be published to
%% `key.success.realm.user'.
%% @end
%%------------------------------------------------------------------------------
get_success_binding(Props) ->
    get_success_routing(props:get_value('realm', Props, <<"*">>)
                       ,props:get_value('user', Props, <<"*">>)
                       ).

get_query_binding(Props) ->
    get_query_routing(props:get_value('realm', Props, <<"*">>)
                     ,props:get_value('user', Props, <<"*">>)
                     ).

-spec get_flush_routing(kz_term:ne_binary() | kz_term:proplist() | kz_json:object()) -> kz_term:ne_binary().
get_flush_routing(Realm) when is_binary(Realm) ->
    <<"registration.flush.", (kz_amqp_util:encode(Realm))/binary>>;
get_flush_routing(Prop) when is_list(Prop) ->
    get_flush_routing(props:get_value(<<"Realm">>, Prop));
get_flush_routing(JObj) ->
    get_flush_routing(kz_json:get_value(<<"Realm">>, JObj)).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec search_realm_regs(Realm::kz_term:ne_binary()) ->
          kz_term:ne_binaries() | kz_json:objects().
search_realm_regs(AccountRealm) ->
    search_realm_regs(AccountRealm, <<"summary">>).

-spec search_realm_regs(Realm::kz_term:ne_binary(), SearchType::kz_term:ne_binary()) ->
          kz_term:ne_binaries() | kz_json:objects().
search_realm_regs(AccountRealm, SearchType) ->
    search_realm_regs(AccountRealm, SearchType, 'undefined').

-spec search_realm_regs(Realm::kz_term:ne_binary(), SearchType::kz_term:ne_binary(), Username::kz_term:api_ne_binary()) ->
          kz_term:ne_binaries() | kz_json:objects().
search_realm_regs(AccountRealm, SearchType, Username) ->
    Req = props:filter_undefined(
            [{<<"Realm">>, AccountRealm}
            ,{<<"Search-Type">>, SearchType}
            ,{<<"Username">>, Username}
            | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
            ]),
    NodeCounts = kz_nodes:node_role_count(<<"Registrar">>, 'true'),
    lager:debug("requesting registration ~s from ~B servers", [SearchType, NodeCounts]),
    case kz_amqp_worker:call_collect(Req
                                    ,fun publish_search_req/1
                                    ,{fun collect_results/2, {0, NodeCounts}}
                                    )
    of
        {'error', _R}=Err -> Err;
        {'ok', Registrations} -> process_responses(Registrations);
        {'timeout', Registrations} -> process_responses(Registrations)
    end.

-type collect_params() :: {integer(), integer()}.
-type collect_result() :: 'true' | {'false', collect_params()}.

-spec collect_results(kz_json:objects(), collect_params()) -> collect_result().
collect_results([Response | _], {Count, Max}) ->
    case Count + search_resp_value(kz_api:event_name(Response)) of
        Max -> 'true';
        V -> {'false', {V, Max}}
    end.

-spec search_resp_value(kz_term:ne_binary()) -> 0..1.
search_resp_value(<<"search_resp">>) -> 1;
search_resp_value(_) -> 0.

-spec process_responses(kz_json:objects()) ->
          kz_term:ne_binaries() | kz_json:objects().
process_responses(JObjs) ->
    lists:usort(
      lists:foldl(fun(JObj, Acc) ->
                          case kz_json:get_list_value(<<"Registrations">>, JObj) of
                              'undefined' -> Acc;
                              Registrations -> Registrations ++ Acc
                          end
                  end
                 ,[]
                 ,JObjs
                 )
     ).
