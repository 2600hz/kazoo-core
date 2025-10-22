%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_channels).

-export([count/1, count/2, count/3, count/4]).
-export([query/1]).

-export([query_method/0, set_query_method/1]).
-export([query_timeout/0, set_query_timeout/1]).

-type count_args() :: #{account := kz_term:ne_binary()
                       ,device => kz_term:api_ne_binary()
                       ,endpoint => kz_term:api_ne_binary()
                       ,owner => kz_term:api_ne_binary()
                       ,user => kz_term:api_ne_binary()
                       ,direction => kz_term:api_ne_binary()
                       }.

-export_type([count_args/0]).

-type query_args() :: #{account := kz_term:ne_binary()
                       ,device => kz_term:api_ne_binary()
                       ,endpoint => kz_term:api_ne_binary()
                       ,owner => kz_term:api_ne_binary()
                       ,user => kz_term:api_ne_binary()
                       ,direction => kz_term:api_ne_binary()
                       ,fields => channel_fields()
                       }.

-export_type([query_args/0]).

-type channel_field() :: atom().
%%TODO restrict to the enumeration of the channel record field names

-type channel_fields() :: [channel_field()].

-type method() :: 'amqp' | 'genserver'.

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(RECEIVE_TIMEOUT, 2 * ?MILLISECONDS_IN_SECOND).

-spec query_method() -> method().
query_method() ->
    persistent_term:get('kz_channels_query_method', 'genserver').

-spec set_query_method('amqp' | 'genserver') -> 'ok'.
set_query_method(Method) ->
    persistent_term:put('kz_channels_query_method', Method).

-spec query_timeout() -> timeout().
query_timeout() ->
    persistent_term:get('kz_channels_query_timeout', ?RECEIVE_TIMEOUT).

-spec set_query_timeout(timeout()) -> 'ok'.
set_query_timeout(Timeout) ->
    persistent_term:put('kz_channels_query_timeout', Timeout).

-spec count(kapps_call:call() | count_args()) -> map().
count(M) when is_map(M)  ->
    do_count(M);
count(Call) ->
    case kapps_call:authorizing_id(Call) of
        'undefined' -> count(#{account => kapps_call:account_id(Call)});
        AuthorizingId ->
            count(kapps_call:account_id(Call), kapps_call:owner_id(Call), AuthorizingId, 'undefined')
    end.

-spec count(kz_term:ne_binary(), kz_term:ne_binary()) -> map().
count(AccountId, EndpointId) ->
    count(#{account => AccountId, endpoint => EndpointId}).

-spec count(kz_term:ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> map().
count(AccountId, OwnerId, DeviceId) ->
    count(#{account => AccountId, owner => OwnerId, device => DeviceId}).

-spec count(kz_term:ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> map().
count(AccountId, OwnerId, DeviceId, Direction) ->
    count(#{account => AccountId, owner => OwnerId, device => DeviceId, direction => Direction}).

do_count(Args) ->
    do_count(Args, query_method()).

do_count(Args, 'amqp') ->
    amqp_count(Args);
do_count(Args, 'genserver') ->
    genserver_count(Args).

amqp_count(Args) ->
    API = [{<<"Account-ID">>, maps:get('account', Args)}
          ,{<<"Device-ID">>, maps:get('device', Args, 'undefined')}
          ,{<<"Endpoint-ID">>, maps:get('endpoint', Args, 'undefined')}
          ,{<<"User-ID">>, maps:get('user', Args, 'undefined')}
          ,{<<"Owner-ID">>, maps:get('owner', Args, 'undefined')}
          ,{<<"Direction">>, maps:get('direction', Args, 'undefined')}
          | kz_api:default_headers()
          ],
    case kz_amqp_worker:call_collect(API, fun kapi_call:publish_count_req/1, {'ecallmgr', 'true'}) of
        {'error', _} -> #{};
        {'ok', []} -> #{};
        {'ok', JObjs} -> amqp_count_result(JObjs)
    end.

amqp_count_result(JObjs) ->
    case maps:values(lists:foldl(fun amqp_count_result/2, maps:new(), JObjs)) of
        [] -> #{};
        [M] -> M;
        [_ | _] = M -> lists:foldl(fun maps_sum_fold_fun/2, #{}, M)
    end.

amqp_count_result(JObj, Acc) ->
    Zone = kz_term:to_atom(kz_api:zone(JObj)),
    Value = kz_maps:keys_to_atoms(kz_json:to_map(kz_json:get_json_value(<<"Count">>, JObj))),
    case maps:get(Zone, Acc, 'undefined') of
        'undefined' ->
            Acc#{Zone => Value#{by_zone => #{Zone => Value}}};
        Existing ->
            Merged = lists:foldl(fun maps_higher_fold_fun/2, #{}, [maps:without([by_zone], Existing), Value]),
            Acc#{Zone => Merged#{by_zone => #{Zone => Merged}}}
    end.

genserver_count(Args) ->
    case [genserver_count_responses(Zone, ReqIds, fun maps_higher_fold_fun/2)
          || {Zone, ReqIds} <- genserver_requests('count', rpc_members(), Args)
         ]
    of
        [] -> #{};
        [M] -> M;
        [_ | _] = M -> lists:foldl(fun maps_sum_fold_fun/2, #{}, M)
    end.

genserver_responses(ReqIds) ->
    lists:filter(fun(V) -> V =/= 'undefined' end
                ,[genserver_response(ReqId) || ReqId <- ReqIds]
                ).

genserver_response(ReqId) ->
    case gen_server:receive_response(ReqId, ?RECEIVE_TIMEOUT) of
        {'reply', Value} -> Value;
        _Other -> undefined
    end.

maps_higher_fold_fun(M1, M2) ->
    maps:merge_with(fun map_merge_higher/3, M1, M2).

map_merge_higher(_K, V1, V2) when V1 > V2 -> V1;
map_merge_higher(_K, _V1, V2) -> V2.

maps_sum_fold_fun(M1, M2) ->
    maps:merge_with(fun map_merge_sum/3, M1, M2).

map_merge_sum(_K, V1, V2) when is_map(V1), is_map(V2) ->  maps:merge_with(fun map_merge_sum/3, V1, V2);
map_merge_sum(_K, V1, V2) -> V1 + V2.

-spec rpc_members() -> [{atom(), [pid()]}].
rpc_members() ->
    [{Zone, pg:get_members(Z)} || Z = {Zone, 'channel_cache'} <- pg:which_groups()].


genserver_query(Args) ->
    case [genserver_query_responses(Zone, ReqIds, fun kz_maps:merge/2)
          || {Zone, ReqIds} <- genserver_requests('channels', rpc_members(), Args)
         ]
    of
        [] -> #{};
        [M] -> M;
        [_ | _] = M -> lists:foldl(fun kz_maps:merge/2, #{}, M)
    end.

genserver_query_responses(Zone, ReqIds, ResponseFun) ->
    Responses = [set_zone_on_query_result(M, Zone) || M <- genserver_responses(ReqIds)],
    Response = lists:foldl(ResponseFun, #{}, Responses),
    maps:put(by_zone, #{Zone => Response}, Response).

genserver_count_responses(Zone, ReqIds, ResponseFun) ->
    Response = lists:foldl(ResponseFun, #{}, genserver_responses(ReqIds)),
    maps:put(by_zone, #{Zone => Response}, Response).

genserver_requests(Method, Members, Args) ->
    [genserver_requests(Method, Zone, Pids, Args) || {Zone, Pids} <- Members].

genserver_requests(Method, Zone, Pids, Args) ->
    {Zone, [genserver_request(Method, Pid, Args) || Pid <- Pids]}.

genserver_request(Method, Pid, Args) ->
    gen_server:send_request(Pid, {Method, Args}).


amqp_query(Args) ->
    API = [{<<"Account-ID">>, maps:get(account, Args, undefined)}
          ,{<<"Device-ID">>, maps:get(device, Args, undefined)}
          ,{<<"Endpoint-ID">>, maps:get(endpoint, Args, undefined)}
          ,{<<"User-ID">>, maps:get(user, Args, undefined)}
          ,{<<"Owner-ID">>, maps:get(owner, Args, undefined)}
          ,{<<"Direction">>, maps:get(direction, Args, undefined)}
          ,{<<"Fields">>, maps:get(fields, Args, undefined)}
          | kz_api:default_headers()
          ],
    case kz_amqp_worker:call_collect(API, fun kapi_call:publish_channels_req/1, {'ecallmgr', 'true'}) of
        {'error', _} -> #{};
        {'ok', []} -> #{};
        {'ok', JObjs} -> amqp_query_result(JObjs)
    end.

amqp_query_result(JObjs) ->
    lists:foldl(fun amqp_query_result/2, maps:new(), JObjs).

amqp_query_result(JObj, Acc) ->
    Zone = kz_term:to_atom(kz_api:zone(JObj)),
    Value = set_zone_on_query_result(amqp_query_result_channels(JObj), Zone),
    kz_maps:merge(Acc, Value#{by_zone => #{Zone => Value}}).

amqp_query_result_channels(JObj) ->
    Channels = kz_maps:keys_to_atoms(kz_json:to_map(kz_json:get_json_value(<<"Channels">>, JObj, kz_json:new())), false),
    maps:map(fun(_K1, V1) -> maps:map(fun(_K2, V2) -> kz_maps:keys_to_atoms(V2) end, V1) end, Channels).

-spec set_zone_on_query_result(map(), kz_term:ne_binary()) -> map().
set_zone_on_query_result(Result, Zone) ->
    maps:map(fun(_K, V) -> set_zone_on_channels(V, Zone) end, Result).

set_zone_on_channels(Channels, Zone) ->
    maps:map(fun(_K, Channel) -> maps:put(zone, Zone, Channel) end, Channels).

-spec query(query_args()) -> map().
query(Args) ->
    query(Args, query_method()).

-spec query(query_args(), method()) -> map().
query(Args, genserver) ->
    genserver_query(Args);
query(Args, amqp) ->
    amqp_query(Args).
