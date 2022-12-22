%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_channels).

-export([count/1, count/2, count/3, count/4]).

-export([query_method/0, set_query_method/1]).

-type count_args() :: #{account := kz_term:ne_binary()
                       ,device => kz_term:api_ne_binary()
                       ,endpoint => kz_term:api_ne_binary()
                       ,owner => kz_term:api_ne_binary()
                       ,user => kz_term:api_ne_binary()
                       ,direction => kz_term:api_ne_binary()
                       }.

-export_type([count_args/0]).

-spec query_method() -> 'amqp' | 'genserver'.
query_method() ->
    persistent_term:get('kz_channels_query_method', 'genserver').

-spec set_query_method('amqp' | 'genserver') -> 'ok'.
set_query_method(Method) ->
    persistent_term:put('kz_channels_query_method', Method).

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
    Zone = kz_api:zone(JObj),
    Value = kz_maps:keys_to_atoms(kz_json:to_map(kz_json:get_json_value(<<"Count">>, JObj))),
    case maps:get(Zone, Acc, 'undefined') of
        'undefined' -> maps:put(Zone, Value, Acc);
        Existing -> maps:put(Zone, lists:foldl(fun maps_higher_fold_fun/2, #{}, [Existing, Value]), Acc)
    end.

genserver_count(Args) ->
    case [genserver_responses(Zone, ReqIds)
          || {Zone, ReqIds} <- genserver_requests(rpc_members(), Args)
         ]
    of
        [] -> #{};
        [M] -> M;
        [_ | _] = M -> lists:foldl(fun maps_sum_fold_fun/2, #{}, M)
    end.

genserver_responses(_Zone, ReqIds) ->
    lists:foldl(fun maps_higher_fold_fun/2, #{}, genserver_responses(ReqIds)).

genserver_requests(Members, Args) ->
    [genserver_requests(Zone, Pids, Args) || {Zone, Pids} <- Members].

genserver_requests(Zone, Pids, Args) ->
    {Zone, [genserver_request(Pid, Args) || Pid <- Pids]}.

genserver_request(Pid, Args) ->
    gen_server:send_request(Pid, {'count', Args}).

genserver_responses(ReqIds) ->
    lists:filter(fun(V) -> V =/= 'undefined' end
                ,[genserver_response(ReqId) || ReqId <- ReqIds]
                ).

-if(?OTP_RELEASE >= 24).
genserver_response(ReqId) ->
    case gen_server:receive_response(ReqId, 'infinity') of
        {'reply', Value} -> Value;
        _ -> 'undefined'
    end.
-else.
genserver_response(ReqId) ->
    case gen_server:wait_response(ReqId, 'infinity') of
        {'reply', Value} -> Value;
        _ -> 'undefined'
    end.
-endif.

maps_higher_fold_fun(M1, M2) ->
    maps:fold(fun map_merge_higher/3, M2, M1).

map_merge_higher(K, V, Acc) ->
    case maps:get(K, Acc, 'undefined') of
        'undefined' ->  maps:put(K, V, Acc);
        Value when Value < V -> maps:put(K, V, Acc);
        _Value -> Acc
    end.

maps_sum_fold_fun(M1, M2) ->
    maps:fold(fun map_merge_sum/3, M2, M1).

map_merge_sum(K, V, Acc) ->
    case maps:get(K, Acc, 'undefined') of
        'undefined' ->  maps:put(K, V, Acc);
        Value -> maps:put(K, Value + V, Acc)
    end.

-spec rpc_members() -> [{atom(), [pid()]}].
rpc_members() ->
    [{Zone, pg:get_members(Z)}
     || Z = {Zone, 'channel_cache'} <- pg:which_groups()
    ].
