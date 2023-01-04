%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_directory_device_spec).

-callback codecs(kzd_endpoint:type()) -> kz_term:ne_binaries().

-callback sip_interface(kzd_endpoint:type()) -> kz_term:api_ne_binary().

-callback sip_route(kzd_endpoint:type()) -> kz_term:api_ne_binary().

-callback sip_route_uri(kzd_endpoint:type()) -> kz_term:api_ne_binary().

-callback invite_format(kzd_endpoint:type()) -> kz_term:api_ne_binary().

-callback authorizing_type(kzd_endpoint:type()) -> kz_term:api_ne_binary().

-callback ignore_early_media(kzd_endpoint:type()) -> boolean().

-callback bypass_media(kzd_endpoint:type()) -> boolean().

-callback routing_ccvs(kzd_endpoint:type(), kz_json:object()) -> kz_json:object().

-callback sip_headers(kzd_endpoint:type(), kz_json:object()) -> kz_json:object().

-callback invite_uri(kzd_endpoint:type(), kz_json:object()) -> kz_json:object().

-callback sip_auth(kzd_endpoint:type(), kz_json:object()) -> kz_json:object().
