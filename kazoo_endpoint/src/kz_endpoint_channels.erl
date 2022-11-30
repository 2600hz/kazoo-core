%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoint_channels).

-export([count/1, count/2, count/3]).

-export([query_method/0, set_query_method/1]).

-spec query_method() -> 'amqp' | 'rpc'.
query_method() ->
    persistent_term:get(kz_endpoint_channel_query_method, 'rpc').

-spec set_query_method('amqp' | 'rpc') -> ok.
set_query_method(Method) ->
    persistent_term:put(kz_endpoint_channel_query_method, Method).

-spec count(kapps_call:call()) -> integer().
count(Call) ->
    case kapps_call:authorizing_id(Call) of
        undefined -> 0;
        AuthorizingId ->  count(AuthorizingId, Call)
    end.

-spec count(kz_term:ne_binary(), kz_term:ne_binary() | kapps_call:call()) -> integer().
count(EndpointId, AccountId) ->
    count(EndpointId, AccountId, undefined).

-spec count(kz_term:ne_binary(), kz_term:ne_binary() | kapps_call:call(), kz_term:api_ne_binary()) -> integer().

count(EndpointId, AccountId, Direction) when is_binary(AccountId) ->
    count(EndpointId, AccountId, Direction, query_method());
count(EndpointId, Call, Direction) ->
    count(EndpointId, kapps_call:account_id(Call), Direction).


count(EndpointId, AccountId, Direction, 'amqp') ->
    amqp_count(EndpointId, AccountId, Direction);
count(EndpointId, AccountId, Direction, 'rpc') ->
    rpc_count(EndpointId, AccountId, Direction).

amqp_count(EndpointId, AccountId, Direction) ->
    API = [{<<"Account-ID">>, AccountId}
          ,{<<"Endpoint-ID">>, EndpointId}
          ,{<<"Direction">>, Direction}
          ,{<<"Count-Only">>, true}
          | kz_api:default_headers()
          ],
    case kz_amqp_worker:call_collect(API, fun kapi_call:publish_query_endpoint_channels_req/1, {ecallmgr, true}) of
        {error, _} -> 0;
        {ok, []} -> 0;
        {ok, JObjs} -> amqp_count_result(JObjs)
    end.

amqp_count_result(JObjs) ->
    lists:sum(kz_json:values(lists:foldl(fun amqp_count_result/2, kz_json:new(), JObjs))).

amqp_count_result(JObj, Acc) ->
    Zone = kz_api:zone(JObj),
    Value = kz_json:get_integer_value(<<"Count">>, JObj),
    case kz_json:get_integer_value(Zone, Acc) of
        undefined -> kz_json:set_value(Zone, Value, Acc);
        Existing when Existing < Value -> kz_json:set_value(Zone, Value, Acc);
        _Existing -> Acc
    end.

rpc_count(EndpointId, AccountId, Direction) ->
    lists:sum([rpc_responses(Zone, ReqIds) || {Zone, ReqIds} <- rpc_requests(rpc_members(), AccountId, EndpointId, Direction)]).


rpc_responses(_Zone, ReqIds) ->
    lists:max([erpc:receive_response(ReqId, infinity) || ReqId <- ReqIds]).

rpc_requests(Members, AccountId, EndpointId, Direction) ->
    [rpc_requests(Zone, Pids, AccountId, EndpointId, Direction) || {Zone, Pids} <- Members].

rpc_requests(Zone, Pids, AccountId, EndpointId, Direction) ->
    {Zone, [rpc_request(Pid, AccountId, EndpointId, Direction) || Pid <- Pids]}.

rpc_request(Pid, AccountId, EndpointId, Direction) ->
    erpc:send_request(node(Pid), ecallmgr_fs_channels, count_endpoint_channels, [AccountId, EndpointId, Direction]).

-spec rpc_members() -> [{atom(), [pid()]}].
rpc_members() ->
    [{Zone, pg:get_members(Z)} || Z = {Zone, channel_cache} <- pg:which_groups()].
