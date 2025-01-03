%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_client_maintenance).

-export([loaded/0

        ,set_cluster_secret/1

        ,link_cluster/1, link_cluster/2
        ,unlink_cluster/0
        ,get_cluster/0
        ,set_cluster_name/1
        ,set_cluster_meta_kazoo_version/1
        ,reset_cluster_secret/0
        ]).

-include("appex_client.hrl").

-elvis([{'elvis_style', 'no_debug_call', 'disable'}]).

-spec loaded() -> 'no_return'.
loaded() ->
    io:format("loaded: ~w~n", [kappex_controller:loaded()]),
    'no_return'.

%% @doc set the secret for the appex client
-spec set_cluster_secret(kz_term:ne_binary()) -> 'ok'.
set_cluster_secret(ClusterSecret) ->
    _ = appex_client_config:set_cluster_secret(ClusterSecret),
    io:format("configured cluster with id ~s~n", [appex_client_config:cluster_id()]).

-spec link_cluster(AccessCode::kz_term:ne_binary()) -> 'no_return'.
link_cluster(AccessCode) ->
    link_cluster(AccessCode, 'undefined').

-spec link_cluster(AccessCode::kz_term:ne_binary(), ClusterName::kz_term:api_ne_binary()) -> 'no_return'.
link_cluster(AccessCode, ClusterName) ->
    io:format("linking cluster to marketplace~n"),
    case appex_client_client:link_cluster(
           kz_json:from_list(
             [{<<"access_code">>, AccessCode}
             ,{<<"name">>, ClusterName}
             ]
            )
          )
    of
        {'ok', _} ->
            io:format("successfully linked cluster to marketplace ~n"),
            'no_return';
        {'error', _Reason} ->
            io:format("failed to link cluster to marketplace: ~n~p~n", [_Reason]),
            'no_return'
    end.

-spec unlink_cluster() -> 'no_return'.
unlink_cluster() ->
    ?SUP_LOG_INFO("unlinking cluster from marketplace"),
    case appex_client_client:unlink_cluster() of
        {'ok', _} ->
            io:format("successfully unlinked cluster from marketplace ~n"),
            'no_return';
        {'error', _Reason} ->
            io:format("failed to unlink cluster from marketplace: ~n~p~n", [_Reason]),
            'no_return'
    end.

-spec get_cluster() -> 'no_return'.
get_cluster() ->
    ?SUP_LOG_INFO("retrieving cluster info from marketplace"),
    case appex_client_client:get_cluster() of
        {'ok', _Data} ->
            io:format("successfully retrieved cluster info from marketplace: ~n~p~n", [_Data]),
            'no_return';
        {'error', _Reason} ->
            io:format("failed to retrieve cluster info from marketplace: ~n~p~n", [_Reason]),
            'no_return'
    end.

-spec set_cluster_name(kz_term:api_ne_binary()) -> 'no_return'.
set_cluster_name(ClusterName) ->
    ?SUP_LOG_INFO("update cluster name in marketplace"),
    case appex_client_client:update_cluster(
           kz_json:from_list(
             [{<<"name">>, ClusterName}]
            )
          )
    of
        {'ok', _Data} ->
            io:format("successfully updated the cluster name in marketplace: ~n~p~n", [_Data]),
            'no_return';
        {'error', _Reason} ->
            io:format("failed to update the cluster name in marketplace: ~n~p~n", [_Reason]),
            'no_return'
    end.

-spec set_cluster_meta_kazoo_version(kz_term:api_ne_binary()) -> 'no_return'.
set_cluster_meta_kazoo_version(KazooVersion) ->
    ?SUP_LOG_INFO("update cluster meta kazoo version in marketplace"),
    case appex_client_client:update_cluster(
           kz_json:from_list(
             [{<<"kazoo_version">>, KazooVersion}]
            )
          )
    of
        {'ok', _Data} ->
            io:format("successfully updated cluster kazoo version in marketplace: ~n~p~n", [_Data]),
            'no_return';
        {'error', _Reason} ->
            io:format("failed to update cluster kazoo version in marketplace: ~n~p~n", [_Reason]),
            'no_return'
    end.

-spec reset_cluster_secret() -> 'no_return'.
reset_cluster_secret() ->
    ?SUP_LOG_INFO("resetting cluster secret in marketplace"),
    case appex_client_client:reset_cluster_secret() of
        {'ok', _} ->
            io:format("successfully reset the cluster secret in marketplace ~n"),
            'no_return';
        {'error', _Reason} ->
            io:format("failed to reset the cluster secret in marketplace: ~n~p~n", [_Reason]),
            'no_return'
    end.
