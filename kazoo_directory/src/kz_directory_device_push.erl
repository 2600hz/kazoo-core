%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
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
-module(kz_directory_device_push).

-behaviour(kz_directory_device_spec).

-export([codecs/1]).
-export([sip_interface/1]).
-export([sip_route/1, sip_route_uri/1]).
-export([invite_format/1]).
-export([authorizing_type/1]).
-export([ignore_early_media/1]).
-export([bypass_media/1]).
-export([invite_uri/2]).
-export([routing_ccvs/2]).
-export([sip_headers/2]).
-export([sip_auth/2]).

-spec authorizing_type(kz_json:object()) -> kz_term:api_ne_binary().
authorizing_type(Endpoint) ->
    kz_doc:type(Endpoint).

-spec set_invite_uri(kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
set_invite_uri(URI, CCVs) ->
    kz_json:set_values([{<<"SIP-Invite-URI">>, URI}], CCVs).

-spec invite_uri(kz_json:object(), kz_json:object()) -> kz_json:object().
invite_uri(Endpoint, CCVs) ->
    AccountId = kzd_endpoint:account_id(Endpoint),
    Realm = kzd_accounts:fetch_realm(AccountId),
    URI = list_to_binary(["sip:", kzd_devices:sip_username(Endpoint), "@", kzd_devices:sip_realm(Endpoint, Realm)]),
    set_invite_uri(URI, CCVs).

-spec ignore_early_media(kz_json:object()) -> boolean().
ignore_early_media(Endpoint) ->
    kz_json:is_true([<<"media">>, <<"ignore_early_media">>], Endpoint).

-spec bypass_media(kz_json:object()) -> boolean().
bypass_media(Endpoint) ->
    kz_json:is_true([<<"media">>, <<"bypass_media">>], Endpoint).

-spec invite_format(kz_json:object()) -> kz_term:api_ne_binary().
invite_format(_Endpoint) ->
    'undefined'.

-spec sip_route(kz_json:object()) -> kz_term:api_ne_binary().
sip_route(Endpoint) ->
    AccountId = kzd_endpoint:account_id(Endpoint),
    Realm = kzd_accounts:fetch_realm(AccountId),
    list_to_binary(["sip:", kzd_devices:sip_username(Endpoint), "@", kzd_devices:sip_realm(Endpoint, Realm)]).

-spec sip_route_uri(kz_json:object()) -> kz_term:api_ne_binary().
sip_route_uri(Endpoint) ->
    kz_json:get_value(<<"Token-Proxy">>, push_properties(Endpoint)).

-spec sip_interface(kz_json:object()) -> kz_term:api_ne_binary().
sip_interface(Endpoint) ->
    kzd_devices:sip_custom_sip_interface(Endpoint).

-spec codecs(kz_json:object()) -> kz_term:ne_binaries().
codecs(JObj) ->
    audio_codecs(JObj) ++ video_codecs(JObj).

-spec audio_codecs(kz_json:object()) -> kz_term:ne_binaries().
audio_codecs(JObj) ->
    kz_codecs:audio_codecs(JObj, []).

-spec video_codecs(kz_json:object()) -> kz_term:ne_binaries().
video_codecs(JObj) ->
    kz_codecs:video_codecs(JObj, []).

-spec routing_ccvs(kz_json:object(), kz_json:object()) -> kz_json:object().
routing_ccvs(Endpoint, CCVs) ->
    kz_json:merge(CCVs, kz_custom_channel_vars:routing(kzd_devices:sip_custom_channel_vars(Endpoint, kz_json:new()), kz_json:new())).

-spec sip_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
sip_headers(Endpoint, Headers) ->
    PushHeaders = push_headers(push_properties(Endpoint)),
    kz_json:merge(Headers, PushHeaders).

-spec push_properties(kz_json:object()) -> kz_json:object().
push_properties(Endpoint) ->
    PushJObj = kz_json:get_json_value(<<"push">>, Endpoint, kz_json:new()),
    case kz_json:get_ne_binary_value(<<"Token-Type">>, PushJObj) of
        'undefined' -> PushJObj;
        _ ->
            Headers = kz_json:from_list([{<<"Endpoint-ID">>, kzd_endpoint:id(Endpoint)}
                                        ,{<<"Account-ID">>, kzd_endpoint:account_id(Endpoint)}
                                        ]),
            kz_json:merge(PushJObj, Headers)
    end.

-spec push_headers(kz_json:object()) -> kz_json:object().
push_headers(PushJObj) ->
    kz_json:map(fun(K, V) -> {<<"X-KAZOO-PUSHER-", K/binary>>, V} end, PushJObj).

-spec sip_auth(kz_json:object(), kz_json:object()) -> kz_json:object().
sip_auth(Endpoint, CCVs) ->
    case {kzd_devices:sip_username(Endpoint)
         ,kzd_devices:sip_password(Endpoint)
         }
    of
        {'undefined', _} -> CCVs;
        {_, 'undefined'} -> CCVs;
        {Username, Password} ->
            KVs = [{<<"Auth-User">>, Username}
                  ,{<<"Auth-Password">>, Password}
                  ],
            kz_json:set_values(KVs, CCVs)
    end.
