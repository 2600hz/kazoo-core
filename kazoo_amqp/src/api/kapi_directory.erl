%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc Switch events messages.
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_directory).

-export([api_definitions/0, api_definition/1]).

-export([cache_flush/1
        ,cache_flush_v/1
        ,publish_cache_flush/0
        ,publish_cache_flush/1
        ]).
-export([cache_clear/1
        ,cache_clear_v/1
        ,publish_cache_clear/1
        ]).

-export([bind_q/2, unbind_q/2]).
-export([declare_exchanges/0]).

-include_lib("kz_amqp_util.hrl").

-define(DIRECTORY_EXCHANGE, <<"directory">>).
-define(DIRECTORY_EXCHANGE_TYPE, <<"topic">>).

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [cache_flush_definition()
    ,cache_clear_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(<<"cache_flush">>) ->
    cache_flush_definition();
api_definition(<<"cache_clear">>) ->
    cache_clear_definition().

-spec cache_flush_definition() -> kapi_definition:api().
cache_flush_definition() ->
    EventName = <<"flush">>,
    Category = <<"cache">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Directory Cache Flush">>}
              ,{fun kapi_definition:set_description/2, <<"Request Directory Cache Flush">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun cache_flush/1}
              ,{fun kapi_definition:set_validate_fun/2, fun cache_flush_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_cache_flush/0}
              ,{fun kapi_definition:set_binding/2, <<"cache.flush">>}
              ,{fun kapi_definition:set_required_headers/2, []}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec cache_clear_definition() -> kapi_definition:api().
cache_clear_definition() ->
    EventName = <<"clear">>,
    Category = <<"cache">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Clear Cached Items">>}
              ,{fun kapi_definition:set_description/2, <<"Request Clear of Cached Items">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun cache_clear/1}
              ,{fun kapi_definition:set_validate_fun/2, fun cache_clear_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_cache_clear/1}
              ,{fun kapi_definition:set_binding/2, <<"cache.clear">>}
              ,{fun kapi_definition:set_required_headers/2, [<<"Keys">>]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, [{<<"Keys">>, fun kz_term:is_ne_binaries/1}]}
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Request Directory Flush.
%% @end
%%------------------------------------------------------------------------------
-spec cache_flush(kz_term:api_terms()) -> kz_api:api_formatter_return().
cache_flush(Req) ->
    kapi_definition:build_message(Req, cache_flush_definition()).

-spec cache_flush_v(kz_term:api_terms()) -> boolean().
cache_flush_v(Req) ->
    kapi_definition:validate(Req, cache_flush_definition()).

-spec publish_cache_flush() -> 'ok'.
publish_cache_flush() ->
    publish_cache_flush(kz_api:default_headers()).

-spec publish_cache_flush(kz_term:api_terms()) -> 'ok'.
publish_cache_flush(API) ->
    Definition = cache_flush_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:basic_publish(?DIRECTORY_EXCHANGE
                              ,kapi_definition:binding(Definition)
                              ,Payload
                              ,?DEFAULT_CONTENT_TYPE
                              ).

%%------------------------------------------------------------------------------
%% @doc Request Directory Cache Clear.
%% @end
%%------------------------------------------------------------------------------
-spec cache_clear(kz_term:api_terms()) -> kz_api:api_formatter_return().
cache_clear(Req) ->
    kapi_definition:build_message(Req, cache_clear_definition()).

-spec cache_clear_v(kz_term:api_terms()) -> boolean().
cache_clear_v(Req) ->
    kapi_definition:validate(Req, cache_clear_definition()).

-spec publish_cache_clear(kz_term:api_terms()) -> 'ok'.
publish_cache_clear(API) ->
    Definition = cache_clear_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:basic_publish(?DIRECTORY_EXCHANGE
                              ,kapi_definition:binding(Definition)
                              ,Payload
                              ,?DEFAULT_CONTENT_TYPE
                              ).

%%------------------------------------------------------------------------------
%% @doc bindings.
%% @end
%%------------------------------------------------------------------------------
-spec bind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Queue, Props) ->
    bind_to_q(Queue, props:get_value('restrict_to', Props), Props).

bind_to_q(Q, 'undefined', _Props) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q, <<"#">>, ?DIRECTORY_EXCHANGE);
bind_to_q(Q, ['cache_flush'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q
                                          ,kapi_definition:binding(cache_flush_definition())
                                          ,?DIRECTORY_EXCHANGE
                                          ),
    bind_to_q(Q, T, Props);
bind_to_q(Q, ['cache_clear'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q
                                          ,kapi_definition:binding(cache_clear_definition())
                                          ,?DIRECTORY_EXCHANGE
                                          ),
    bind_to_q(Q, T, Props);
bind_to_q(Q, ['cache'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q
                                          ,kapi_definition:binding(cache_flush_definition())
                                          ,?DIRECTORY_EXCHANGE
                                          ),
    'ok' = kz_amqp_util:bind_q_to_exchange(Q
                                          ,kapi_definition:binding(cache_clear_definition())
                                          ,?DIRECTORY_EXCHANGE
                                          ),
    bind_to_q(Q, T, Props);
bind_to_q(_Q, [], _Props) -> 'ok'.

-spec unbind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Queue, Props) ->
    unbind_q_from(Queue, props:get_value('restrict_to', Props), Props).

unbind_q_from(Q, 'undefined', _Props) ->
    'ok' = kz_amqp_util:unbind_q_from_exchange(Q, <<"#">>, ?DIRECTORY_EXCHANGE);
unbind_q_from(Q, ['cache_flush'|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_exchange(Q
                                              ,kapi_definition:binding(cache_flush_definition())
                                              ,?DIRECTORY_EXCHANGE
                                              ),
    unbind_q_from(Q, T, Props);
unbind_q_from(Q, ['cache_clear'|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_exchange(Q
                                              ,kapi_definition:binding(cache_clear_definition())
                                              ,?DIRECTORY_EXCHANGE
                                              ),
    unbind_q_from(Q, T, Props);
unbind_q_from(Q, ['cache'|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_exchange(Q
                                              ,kapi_definition:binding(cache_flush_definition())
                                              ,?DIRECTORY_EXCHANGE
                                              ),
    'ok' = kz_amqp_util:unbind_q_from_exchange(Q
                                              ,kapi_definition:binding(cache_clear_definition())
                                              ,?DIRECTORY_EXCHANGE
                                              ),
    unbind_q_from(Q, T, Props);
unbind_q_from(_Q, [], _Props) -> 'ok'.

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:new_exchange(?DIRECTORY_EXCHANGE, ?DIRECTORY_EXCHANGE_TYPE).
