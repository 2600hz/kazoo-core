%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
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
-module(kz_directory_device_mobile).

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

-define(ENDPOINT_CONFIG_CAT, <<"kazoo_endpoint">>).
-define(MOBILE_CONFIG_CAT, <<(?ENDPOINT_CONFIG_CAT)/binary, ".mobile">>).
-define(MOBILE_APP_CONFIG, 'kazoo_endpoint.mobile').
-define(DEFAULT_MOBILE_FORMATER, <<"^\\+?1?([2-9][0-9]{2}[2-9][0-9]{6})$">>).
-define(DEFAULT_MOBILE_PREFIX, <<>>).
-define(DEFAULT_MOBILE_SUFFIX, <<>>).
-define(DEFAULT_MOBILE_REALM, <<"mobile.k.zswitch.net">>).
-define(DEFAULT_MOBILE_PATH, <<>>).
-define(DEFAULT_MOBILE_CODECS, [<<"PCMU">>]).
-define(DEFAULT_CALLER_ID_NAME, <<"unknown">>).

-spec authorizing_type(kz_json:object()) -> binary().
authorizing_type(_Endpoint) -> <<"mobile">>.

-spec set_invite_uri(kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
set_invite_uri(URI, CCVs) ->
    kz_json:set_values([{<<"SIP-Invite-URI">>, URI}], CCVs).

-spec invite_uri(kz_json:object(), kz_json:object()) -> kz_json:object().
invite_uri(Endpoint, CCVs) ->
    case mobile_route(Endpoint) of
        {error, _} -> CCVs;
        Route -> set_invite_uri(Route, CCVs)
    end.

-spec mobile_route(kz_json:object()) ->
          kz_term:ne_binary() |
          {'error', 'mdn_missing'}.
mobile_route(Endpoint) ->
    case kz_json:get_ne_value([<<"mobile">>, <<"mdn">>], Endpoint) of
        'undefined' ->
            lager:info("unable to build mobile endpoint, MDN missing", []),
            {'error', 'mdn_missing'};
        MDN -> build_mobile_route(MDN)
    end.

-spec build_mobile_route(kz_term:ne_binary()) ->
          kz_term:ne_binary() |
          {'error', 'invalid_mdn'}.
build_mobile_route(MDN) ->
    Regex = kapps_config:get_binary(?MOBILE_CONFIG_CAT, <<"formatter">>, ?DEFAULT_MOBILE_FORMATER),
    case re:run(MDN, Regex, [{'capture', 'all', 'binary'}]) of
        'nomatch' ->
            lager:info("unable to build mobile endpoint, invalid MDN ~s", [MDN]),
            {'error', 'invalid_mdn'};
        {'match', Captures} ->
            Root = lists:last(Captures),
            Prefix = kapps_config:get_binary(?MOBILE_CONFIG_CAT, <<"prefix">>, ?DEFAULT_MOBILE_PREFIX),
            Suffix = kapps_config:get_binary(?MOBILE_CONFIG_CAT, <<"suffix">>, ?DEFAULT_MOBILE_SUFFIX),
            Realm = kapps_config:get_binary(?MOBILE_CONFIG_CAT, <<"realm">>, ?DEFAULT_MOBILE_REALM),
            list_to_binary(["sip:"
                           ,Prefix, Root, Suffix
                           ,"@", Realm
                           ])
    end.

-spec ignore_early_media(kz_json:object()) -> boolean().
ignore_early_media(_Endpoint) -> true.

-spec bypass_media(kz_json:object()) -> boolean().
bypass_media(_Endpoint) -> false.

-spec invite_format(kz_json:object()) -> kz_term:api_ne_binary().
invite_format(_Endpoint) -> <<"route">>.

-spec sip_route(kz_json:object()) -> kz_term:api_ne_binary().
sip_route(Endpoint) ->
    case mobile_route(Endpoint) of
        {error, _} -> undefined;
        Route -> Route
    end.

-spec sip_route_uri(kz_json:object()) -> kz_term:api_ne_binary().
sip_route_uri(_Endpoint) ->
    Path = kapps_config:get_binary(?MOBILE_CONFIG_CAT, <<"path">>, ?DEFAULT_MOBILE_PATH),
    case kz_term:is_empty(Path) of
        'false' -> <<"sip:", Path/binary>>;
        'true' -> undefined
    end.

-spec sip_interface(kz_json:object()) -> kz_term:api_ne_binary().
sip_interface(_Endpoint) ->
    kapps_config:get_binary(?MOBILE_CONFIG_CAT, <<"custom_sip_interface">>).

-spec codecs(kz_json:object()) -> 'undefined' | kz_term:ne_binaries().
codecs(_Endpoint) ->
    kapps_config:get(?MOBILE_CONFIG_CAT, <<"codecs">>, ?DEFAULT_MOBILE_CODECS).

-spec mobile_ccvs() -> kz_json:object().
mobile_ccvs() ->
    kz_app_config:get_json(?MOBILE_APP_CONFIG, <<"custom_channel_variables">>, kz_json:new()).

-spec mobile_device_ccvs(kz_json:object()) -> kz_json:object().
mobile_device_ccvs(Endpoint) ->
    kz_json:merge(mobile_ccvs(), kzd_devices:sip_custom_channel_vars(Endpoint, kz_json:new())).

-spec routing_ccvs(kz_json:object(), kz_json:object()) -> kz_json:object().
routing_ccvs(Endpoint, CRVs) ->
    MobileCCVs = mobile_device_ccvs(Endpoint),
    MobileCRVs = kz_custom_channel_vars:routing(MobileCCVs, kz_json:new()),
    kz_json:merge(CRVs, MobileCRVs).

-spec sip_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
sip_headers(_Endpoint, Headers) ->
    Headers.

-spec sip_auth(kz_json:object(), kz_json:object()) -> kz_json:object().
sip_auth(Endpoint, CCVs) ->
    case {kzd_devices:sip_username(Endpoint)
         ,kzd_devices:sip_password(Endpoint)
         }
    of
        {undefined, _} -> CCVs;
        {_, undefined} -> CCVs;
        {Username, Password} ->
            KVs = [{<<"Auth-User">>, Username}
                  ,{<<"Auth-Password">>, Password}
                  ],
            kz_json:set_values(KVs, CCVs)
    end.
