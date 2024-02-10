%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
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
            io:format("successfully linked cluster to marketplace, you can now restart ~p~n", [?APP]),
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
            io:format("successfully unlinked cluster from marketplace, you can now stop ~p~n", [?APP]),
            'no_return';
        {'error', _Reason} ->
            io:format("failed to unlink cluster from marketplace: ~n~p~n", [_Reason]),
            'no_return'
    end.
