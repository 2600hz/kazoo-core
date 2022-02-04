%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_client_maintenance).

-export([listing/0
        ,refresh/0
        ,loaded/0

        ,set_cluster_secret/1
        ]).

-elvis([{'elvis_style', 'no_debug_call', 'disable'}]).

-spec listing() -> 'ok'.
listing() ->
    lists:foreach(fun print_app_listing/1, appex_client_client:listings()).

print_app_listing(AppDetails) ->
    io:format("~14s:", [kz_json:get_ne_binary_value(<<"name">>, AppDetails)]),
    kz_json:foreach(fun print_app_details/1, AppDetails),
    io:format("~n").

print_app_details({<<"version">>, Version}) ->
    io:format(" ~s", [Version]);
print_app_details(_KV) -> 'ok'.

-spec loaded() -> 'no_return'.
loaded() ->
    io:format("loaded: ~w~n", [appex_client_client:loaded()]),
    'no_return'.

-spec refresh() -> 'ok'.
refresh() ->
    appex_client_client:refresh_listing(),
    io:format("refresh initiated~n").

%% @doc set the secret for the appex client
-spec set_cluster_secret(kz_term:ne_binary()) -> 'ok'.
set_cluster_secret(ClusterSecret) ->
    _ = appex_client_config:set_cluster_secret(ClusterSecret),
    io:format("configured cluster with id ~s~n", [appex_client_config:cluster_id()]).
