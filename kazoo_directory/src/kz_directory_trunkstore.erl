%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2024, 2600Hz
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
-module(kz_directory_trunkstore).

-export([profile/2, profile/3]).

-include("kazoo_directory.hrl").

-spec profile(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId) ->
    profile(EndpointId, AccountId, []).

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId, Options) ->
    case kz_datamgr:open_cache_doc(AccountId, EndpointId) of
        {'ok', Endpoint} -> maybe_generate_profile(EndpointId, AccountId, Endpoint, Options);
        Error -> Error
    end.

-spec generate_ccvs(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
generate_ccvs(_EndpointId, AccountId, Endpoint) ->
    Realm = get_realm(Endpoint),
    Props = [{<<"Account-ID">>, AccountId}
            ,{<<"Reseller-ID">>, kz_services_reseller:get_id(AccountId)}
            ,{<<"Realm">>, Realm}
            ],
    CCVs = kz_json:from_list(Props),

    CCVFuns = [{fun trunk_id/2, Endpoint}
              ],
    kz_json:exec(CCVFuns, CCVs).

-spec trunk_id(kz_json:object(), kz_json:object()) -> kz_json:object().
trunk_id(Endpoint, CCVs) ->
    kz_json:set_values([{<<"Authorizing-ID">>, kz_doc:id(Endpoint)}
                       ,{<<"Authorizing-Type">>, kz_doc:type(Endpoint)}
                       ]
                      ,CCVs
                      ).

-spec maybe_generate_profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
maybe_generate_profile(EndpointId, AccountId, Endpoint, Options) ->
    case kz_doc:type(Endpoint) of
        <<"sys_info">> -> generate_profile(EndpointId, AccountId, Endpoint, Options);
        _ -> {'error', 'not_user'}
    end.

-spec generate_profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
generate_profile(EndpointId, AccountId, Endpoint, _Options) ->
    CCVs = generate_ccvs(EndpointId, AccountId, Endpoint),

    CPVs = [{<<"Account-ID">>, AccountId}
           ,{<<"Endpoint-ID">>, EndpointId}
           ,{<<"Endpoint-Type">>, <<"sys_info">>}
           ],
    Profile = [{<<"Endpoint-Type">>, <<"sys_info">>}
              ,{<<"Domain-Name">>, AccountId}
              ,{<<"User-ID">>, EndpointId}
              ,{<<"Custom-Channel-Vars">>, CCVs}
              ,{<<"Custom-Profile-Vars">>, kz_json:from_list(CPVs)}
              ,{<<"Expires">>, ?DIRECORY_CACHE_TIME_MS}
              ],
    {'ok', kz_json:from_list(Profile)}.

-spec get_realm(kz_json:object()) -> kz_term:ne_binary().
get_realm(Endpoint) ->
    AccountId = kz_doc:account_id(Endpoint),
    {'ok', Account} = kzd_accounts:fetch(AccountId),
    Default = kzd_accounts:realm(Account, <<"norealm">>),
    kzd_trunkstore:account_auth_realm(Endpoint, Default).
