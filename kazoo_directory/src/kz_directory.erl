%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%% @author Luis Azedo
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_directory).

-export([lookup/2, lookup/3]).

-include("kazoo_directory.hrl").

-spec lookup(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
lookup(EndpointId, AccountId) ->
    lookup(EndpointId, AccountId, []).

-spec lookup(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
lookup(EndpointId, AccountId, Options) ->
    Routines = [fun cached/3
               ,fun kz_directory_endpoint:profile/3
               ,fun kz_directory_resource:profile/3
               ],
    lookup(Routines, EndpointId, AccountId, Options).

-spec lookup([fun()], kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
lookup([], _EndpointId, _AccountId, _Options) ->
    {'error', 'not_found'};
lookup([Fun | Routines], EndpointId, AccountId, Options) ->
    try Fun(EndpointId, AccountId, Options) of
        {'ok', _Endpoint} = OK -> OK;
        _Error -> lookup(Routines, EndpointId, AccountId, Options)
    catch
        _Ex:_Err:_ST ->
            lookup(Routines, EndpointId, AccountId, Options)
    end.

-spec cached(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', 'not_found'}.
cached(EndpointId, AccountId, _Options) ->
    kz_cache:fetch_local(?CACHE_NAME, {EndpointId, AccountId}).
