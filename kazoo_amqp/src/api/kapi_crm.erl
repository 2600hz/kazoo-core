%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023, 2600Hz
%%% @doc
%%% @author Kusal Fernando
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_crm).

-include_lib("kz_amqp_util.hrl").
-include("kapi_crm.hrl").

%% CRM functions
-export([authenticate/1, caller_info/1]).

%% Ampq response filters
-export([authenticate_resp/1, caller_info_resp/1]).

%%------------------------------------------------------------------------------
%% @doc Sends a authenticate message to a crm process.
%% This will set the auth token in the state.
%% @end
%%------------------------------------------------------------------------------
-spec authenticate(kz_term:proplist()) -> 'ok'.
authenticate(Args) ->
    kz_amqp_worker:cast(Args, fun publish_authenticate/1).

-spec publish_authenticate(kz_term:api_terms()) -> 'ok'.
publish_authenticate(Args) ->
    {'ok', Payload} = kz_api:build_message(Args, ?AUTH_HEADERS, []),
    kz_amqp_util:basic_publish(?CRM_EXCHANGE, route(Args), Payload, ?DEFAULT_CONTENT_TYPE).

-spec authenticate_resp(kz_json:object()) -> boolean().
authenticate_resp(Message) ->
    case kz_api:event_name(Message) of
        <<"authenticate-reply">> -> 'true';
        _ -> 'false'
    end.

-spec caller_info(kz_term:proplist()) -> 'ok'.
caller_info(Args) ->
    kz_amqp_worker:cast(Args, fun publish_caller_info/1).

-spec publish_caller_info(kz_term:api_terms()) -> 'ok'.
publish_caller_info(Args) ->
    {'ok', Payload} = kz_api:build_message(Args, ?CALLER_INFO_HEADERS, []),
    kz_amqp_util:basic_publish(?CRM_EXCHANGE, route(Args), Payload, ?DEFAULT_CONTENT_TYPE).

-spec caller_info_resp(kz_json:object()) -> boolean().
caller_info_resp(Message) ->
    case kz_api:event_name(Message) of
        <<"caller_info-reply">> -> 'true';
        _ -> 'false'
    end.

-spec route(list()) -> binary().
route(Args) ->
    Account   = props:get_value(<<"Account-ID">>, Args, <<"account_id">>),
    EventName = props:get_value(<<"Event-Name">>, Args, <<"event_name">>),
    ?CRM_ROUTE(Account, EventName).

