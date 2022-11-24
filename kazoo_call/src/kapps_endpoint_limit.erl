%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2022, 2600Hz
%%% @doc API for ecallmgr_fs_endpoint_limit module.
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_endpoint_limit).

-include("kapps_call.hrl").
-include_lib("kazoo_amqp/src/kz_amqp_util.hrl").

%% API {
-export([has_reached_limit/3
        ]).
%% }

-type endpoint_id() :: kz_term:ne_binary(). %% Can be the id of either a "user" or a "device".
-type endpoint_type() :: kz_term:ne_binary(). %% "account", "user", or "device".
-type endpoint_limit() :: non_neg_integer().

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Whether or not the given endpoint has reached its configured or inherited limit.
%% @end
%%------------------------------------------------------------------------------
-spec has_reached_limit(endpoint_id(), endpoint_type(), endpoint_limit()) -> boolean().
has_reached_limit(EndpointId, EndpointType, EndpointLimit) ->
    Req = [{<<"Endpoint-ID">>, EndpointId}
          ,{<<"Endpoint-Type">>, EndpointType}
          ,{<<"Endpoint-Limit">>, EndpointLimit}
          ,{?KEY_MSG_ID, kz_binary:rand_hex(16)}
          | kz_api:default_headers(<<"channel">>
                                  ,<<"enforce_endpoint_limit_req">>
                                  ,?KAPPS_CALL_APP_NAME
                                  ,?KAPPS_CALL_APP_VERSION
                                  )
          ],

    Resp = kz_amqp_worker:call(Req
                              ,fun kapi_call:publish_enforce_endpoint_limit_req/1
                              ,fun kapi_call:enforce_endpoint_limit_resp_v/1
                              ),
    get_reply_from_response(Resp).

%%------------------------------------------------------------------------------
%% @doc If response's validation fails or the response is not in the form of `{ok | returned, JObj}',
%% `false' will be returned to avoid blocking the callee from receiving the call.
%% @end
%%------------------------------------------------------------------------------
-spec get_reply_from_response(kz_amqp_worker:request_return()) -> boolean().
get_reply_from_response({Success, JObj}) when 'ok' =:= Success; 'returned' =:= Success ->
    HasReachedLimit = kz_json:get_boolean_value(<<"Has-Reached-Limit">>, JObj),
    lager:debug("did endpoint reach its configured limit?: ~p", [HasReachedLimit]),
    HasReachedLimit;
get_reply_from_response(_Unexpected) ->
    lager:debug("Unexpected response: ~p", [_Unexpected]),
    'false'.
