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
-module(kz_directory_endpoint).

-export([profile/2, profile/3]).

-include("kazoo_directory.hrl").

-spec profile(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
profile(EndpointId, AccountId) ->
    profile(EndpointId, AccountId, []).

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
profile(EndpointId, AccountId, Options) ->
    case kz_datamgr:open_cache_doc(AccountId, EndpointId) of
        {'ok', Endpoint} -> profile(EndpointId, AccountId, Options, kz_doc:type(Endpoint));
        _Error -> maybe_from_options(EndpointId, AccountId, Options)
    end.

maybe_from_options(EndpointId, AccountId, Options) ->
    Endpoint = props:get_value('endpoint', Options),
    case kz_json:is_valid_json_object(Endpoint) of
        'true' -> profile(EndpointId, AccountId, Options, kz_doc:type(Endpoint));
        'false' -> {'error', 'not_found'}
    end.

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist(), kz_term:api_ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
profile(EndpointId, AccountId, Options, <<"device">>) ->
    kz_directory_device:profile(EndpointId, AccountId, Options);
profile(EndpointId, AccountId, Options, <<"user">>) ->
    kz_directory_user:profile(EndpointId, AccountId, Options);
profile(EndpointId, AccountId, Options, <<"group">>) ->
    kz_directory_group:profile(EndpointId, AccountId, Options);
profile(EndpointId, AccountId, Options, <<"sys_info">>) ->
    kz_directory_trunkstore:profile(EndpointId, AccountId, Options);
profile(_EndpointId, _AccountId, _Options, _Type) ->
    {'error', 'not_found'}.
