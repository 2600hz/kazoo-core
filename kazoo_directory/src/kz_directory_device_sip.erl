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
-module(kz_directory_device_sip).

-export([codecs/1]).
-export([sip_interface/1]).
-export([sip_route/1, sip_route_uri/1]).
-export([invite_format/1]).
-export([authorizing_type/1]).
-export([ignore_early_media/1]).
-export([bypass_media/1]).
-export([invite_uri/2]).

-include("kazoo_directory.hrl").

-spec authorizing_type(kz_json:object()) -> binary().
authorizing_type(Endpoint) ->
    kz_doc:type(Endpoint).

-spec set_invite_uri(kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
set_invite_uri(URI, CCVs) ->
    kz_json:set_values([{<<"SIP-Invite-To-URI">>, URI}
                       ,{<<"SIP-Invite-Request-URI">>, URI}
                       ], CCVs).

-spec set_invite_uri(kz_term:api_ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
set_invite_uri('undefined', _Realm, CCVs) -> CCVs;
set_invite_uri(URIUser, Realm, CCVs) ->
    URI = <<"sip:", URIUser/binary, "@", Realm/binary>>,
    set_invite_uri(URI, CCVs).

-type invite_uri_fun() :: fun((kz_term:ne_binary()) -> kz_term:ne_binary()).

-spec set_invite_uri(invite_uri_fun(), kz_term:api_ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
set_invite_uri(_Fun, 'undefined', RuntimeContextField, Realm, CCVs) ->
    set_invite_uri(<<"${kz_ctx_request_", RuntimeContextField/binary, "}">>, Realm, CCVs);
set_invite_uri(Fun, URIUser, _RuntimeContextField, Realm, CCVs) ->
    set_invite_uri(Fun(URIUser), Realm, CCVs).

-spec invite_uri(kz_json:object(), kz_json:object()) -> kz_json:object().
invite_uri(Endpoint, CCVs) ->
    Realm = get_realm(Endpoint),
    case kzd_devices:sip_invite_format(Endpoint) of
        <<"route">> -> set_invite_uri(kzd_devices:sip_route(Endpoint), CCVs);
        <<"e164">> -> set_invite_uri(fun knm_converters:normalize/1, kzd_devices:sip_number(Endpoint), <<"e164">>, Realm, CCVs);
        <<"1npan">> -> set_invite_uri(fun knm_converters:to_1npan/1, kzd_devices:sip_number(Endpoint), <<"1npan">>, Realm, CCVs);
        <<"npan">> -> set_invite_uri(fun knm_converters:to_npan/1, kzd_devices:sip_number(Endpoint), <<"npan">>, Realm, CCVs);
        <<"strip_plus">> -> set_invite_uri(fun knm_converters:to_strip_plus/1, kzd_devices:sip_number(Endpoint), <<"strip_plus">>, Realm, CCVs);
        <<"contact">> -> set_invite_uri(kzd_devices:sip_username(Endpoint), Realm, CCVs);
        <<"username">> -> set_invite_uri(kzd_devices:sip_username(Endpoint), Realm, CCVs)
    end.

-spec ignore_early_media(kz_json:object()) -> boolean().
ignore_early_media(Endpoint) ->
    kz_json:is_true([<<"media">>, <<"ignore_early_media">>], Endpoint).

-spec bypass_media(kz_json:object()) -> boolean().
bypass_media(Endpoint) ->
    kz_json:is_true([<<"media">>, <<"bypass_media">>], Endpoint).

-spec invite_format(kz_json:object()) -> kz_term:api_ne_binary().
invite_format(Endpoint) ->
    kzd_devices:sip_invite_format(Endpoint).

-spec sip_route(kz_json:object()) -> kz_term:api_ne_binary().
sip_route(Endpoint) ->
    kzd_devices:sip_route(Endpoint).

-spec sip_route_uri(kz_json:object()) -> kz_term:api_ne_binary().
sip_route_uri(Endpoint) ->
    kzd_devices:sip_route_uri(Endpoint).

-spec sip_interface(kz_json:object()) -> kz_term:api_ne_binary().
sip_interface(Endpoint) ->
    kzd_devices:sip_custom_sip_interface(Endpoint).

-spec codecs(kz_json:object()) -> kz_term:ne_binaries().
codecs(JObj) ->
    audio_codecs(JObj) ++ video_codecs(JObj).

-spec audio_codecs(kz_json:object()) -> kz_term:ne_binaries().
audio_codecs(JObj) ->
    kz_json:get_ne_binaries([<<"media">>, <<"audio">>, <<"codecs">>], JObj, []).

-spec video_codecs(kz_json:object()) -> kz_term:ne_binaries().
video_codecs(JObj) ->
    kz_json:get_ne_binaries([<<"media">>, <<"video">>, <<"codecs">>], JObj, []).

-spec get_realm(kz_json:object()) -> kz_term:ne_binary().
get_realm(Endpoint) ->
    kz_json:get_ne_binary_value(<<"realm">>, Endpoint, <<"norealm">>).
