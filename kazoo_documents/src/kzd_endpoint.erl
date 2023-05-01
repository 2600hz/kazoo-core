%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_endpoint).

-export([addresses/1, addresses/2, set_addresses/2]).
-export([addresses_emergency/1, addresses_emergency/2, set_addresses_emergency/2]).
-export([id/1]).
-export([type/1]).
-export([owner_id/1]).
-export([account_id/1, account_name/1, account_realm/1]).
-export([language/1, language/2]).
-export([get_prompt/2, get_prompt_url/2]).
-export([moh/1, moh_media_path/1, moh_url/1, moh_options/1]).
-export([presence_id/1]).
-export([presence_aliases/1, presence_aliases/2]).
-export([presence_monitoring_aliases/1, presence_monitoring_aliases/2]).
-export([presence_publishing_aliases/1, presence_publishing_aliases/2]).
-export([call_forward/1, call_forward/2, set_call_forward/2]).
-export([call_failover/1, call_failover/2]).
-export([call_limits/1, call_limits/2, set_call_limits/2]).
-export([tags/1, tags/2]).
-export([meta_id/1]).

-export([build_options/1]).

-type endpoint() :: kz_json:object().
-type type() :: kz_term:ne_binary().
-export_type([endpoint/0
             ,type/0
             ]).

-type presence_aliases() :: kz_json:object() | kz_term:ne_binaries().
-type api_presence_aliases() :: presence_aliases() | undefined.
-export_type([presence_aliases/0, api_presence_aliases/0]).

-spec addresses(endpoint()) -> kz_term:api_object().
addresses(Doc) ->
    addresses(Doc, 'undefined').

-spec addresses(endpoint(), Default) -> kz_json:object() | Default.
addresses(Doc, Default) ->
    kz_json:get_json_value([<<"addresses">>], Doc, Default).

-spec set_addresses(endpoint(), kz_json:object()) -> endpoint().
set_addresses(Doc, Addresses) ->
    kz_json:set_value([<<"addresses">>], Addresses, Doc).

-spec addresses_emergency(endpoint()) -> kz_json:api_object().
addresses_emergency(Endpoint) ->
    addresses_emergency(Endpoint, 'undefined').

-spec addresses_emergency(endpoint(), Default) -> kz_json:object() | Default.
addresses_emergency(Endpoint, Default) ->
    kz_json:get_json_value([<<"addresses">>, <<"emergency">>], Endpoint, Default).

-spec set_addresses_emergency(endpoint(), kz_json:api_object()) -> kz_json:object().
set_addresses_emergency(Endpoint, EmergencyAddr) ->
    kz_json:set_value([<<"addresses">>, <<"emergency">>], EmergencyAddr, Endpoint).

-spec id(endpoint()) -> kz_term:ne_binary().
id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"Endpoint-ID">>, Endpoint).

-spec type(endpoint()) -> kz_term:ne_binary().
type(Endpoint) ->
    kz_json:get_ne_binary_value(<<"Endpoint-Type">>, Endpoint).

-spec account_id(endpoint()) -> kz_term:ne_binary().
account_id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"Account-ID">>, Endpoint, kz_doc:account_id(Endpoint)).

-spec account_name(endpoint()) -> kz_term:ne_binary().
account_name(Endpoint) ->
    kz_json:get_ne_binary_value(<<"account_name">>, Endpoint).

-spec account_realm(endpoint()) -> kz_term:ne_binary().
account_realm(Endpoint) ->
    kz_json:get_ne_binary_value(<<"account_realm">>, Endpoint).

-spec owner_id(endpoint()) -> kz_term:api_ne_binary().
owner_id(Endpoint) ->
    kz_json:get_ne_binary_value([<<"owner_id">>], Endpoint).

-spec language(endpoint()) -> kz_term:ne_binary().
language(Endpoint) ->
    language(Endpoint, default_endpoint_language()).

-spec language(endpoint(), kz_term:api_ne_binary()) -> kz_term:ne_binary().
language(Endpoint, Default) ->
    endpoint_language(kz_json:get_ne_binary_value([<<"language">>], Endpoint, Default)).

-spec endpoint_language(kz_term:api_binary()) -> kz_term:ne_binary().
endpoint_language('undefined') -> default_endpoint_language();
endpoint_language(Lang) -> kz_term:to_lower_binary(Lang).

-spec default_endpoint_language() -> kz_term:ne_binary().
default_endpoint_language() -> <<"en-us">>.

-spec get_prompt(endpoint(), kz_term:ne_binary()) -> kz_term:api_ne_binary().
get_prompt(Endpoint, PromptId) ->
    kz_media_util:get_prompt(PromptId, language(Endpoint), account_id(Endpoint)).

-spec get_prompt_url(endpoint(), kz_term:ne_binary()) -> kz_term:api_ne_binary().
get_prompt_url(Endpoint, PromptId) ->
    case get_prompt(Endpoint, PromptId) of
        'undefined' -> 'undefined';
        MediaPath -> kz_media_url:playback(MediaPath)
    end.

-spec moh(endpoint()) -> kz_term:api_ne_binary().
moh(Endpoint) ->
    kz_json:get_ne_binary_value([<<"music_on_hold">>, <<"media_id">>], Endpoint).

-spec moh_options(endpoint()) -> kz_term:api_ne_binaries().
moh_options(Endpoint) ->
    kz_json:get_ne_binaries([<<"music_on_hold">>, <<"options">>], Endpoint).

-spec moh_media_path(endpoint()) -> kz_term:api_ne_binary().
moh_media_path(Endpoint) ->
    case moh(Endpoint) of
        'undefined' -> 'undefined';
        MediaId -> kz_media_util:media_path(MediaId, account_id(Endpoint))
    end.

-spec moh_url(endpoint()) -> kz_term:api_ne_binary().
moh_url(Endpoint) ->
    case moh_media_path(Endpoint) of
        'undefined' -> 'undefined';
        MediaPath -> moh_playback_url(MediaPath)
    end.

moh_playback_url(MediaPath) ->
    case kz_media_url:playback(MediaPath) of
        {'error', _} -> 'undefined';
        URL -> URL
    end.

-spec presence_id(endpoint()) -> kz_term:api_ne_binary().
presence_id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"presence_id">>, Endpoint).

-spec presence_aliases(endpoint()) -> api_presence_aliases().
presence_aliases(Endpoint) ->
    kzd_endpoint_aliases:aliases(Endpoint).

-spec presence_aliases(endpoint(), Default) -> presence_aliases() | Default.
presence_aliases(Endpoint, Default) ->
    kzd_endpoint_aliases:aliases(Endpoint, Default).

-spec presence_monitoring_aliases(endpoint()) -> kz_term:api_ne_binaries().
presence_monitoring_aliases(Endpoint) ->
    kzd_endpoint_aliases:monitoring(Endpoint).

-spec presence_monitoring_aliases(endpoint(), Default) -> kz_term:ne_binaries() | Default.
presence_monitoring_aliases(Endpoint, Default) ->
    kzd_endpoint_aliases:monitoring(Endpoint, Default).

-spec presence_publishing_aliases(endpoint()) -> kz_term:api_ne_binaries().
presence_publishing_aliases(Endpoint) ->
    kzd_endpoint_aliases:publishing(Endpoint).

-spec presence_publishing_aliases(endpoint(), Default) -> kz_term:ne_binaries() | Default.
presence_publishing_aliases(Endpoint, Default) ->
    kzd_endpoint_aliases:publishing(Endpoint, Default).

-spec build_options(endpoint()) -> kz_term:api_object().
build_options(Endpoint) ->
    kz_json:get_json_value(<<"Endpoint-Build-Options">>, Endpoint).

-spec call_failover(endpoint()) -> kz_term:api_object().
call_failover(Endpoint) ->
    call_failover(Endpoint, 'undefined').

-spec call_failover(endpoint(), Default) -> kz_json:object() | Default.
call_failover(Endpoint, Default) ->
    kz_json:get_json_value([<<"call_failover">>], Endpoint, Default).

-spec call_forward(endpoint()) -> kz_term:api_object().
call_forward(Endpoint) ->
    call_forward(Endpoint, 'undefined').

-spec call_forward(endpoint(), Default) -> kz_json:object() | Default.
call_forward(Endpoint, Default) ->
    kz_json:get_json_value([<<"call_forward">>], Endpoint, Default).

-spec set_call_forward(endpoint(), kz_json:object()) -> endpoint().
set_call_forward(Doc, CallForward) ->
    kz_json:set_value([<<"call_forward">>], CallForward, Doc).

-spec call_limits(endpoint()) -> kz_term:api_object().
call_limits(Doc) ->
    call_limits(Doc, 'undefined').

-spec call_limits(endpoint(), Default) -> kz_json:object() | Default.
call_limits(Doc, Default) ->
    kz_json:get_json_value([<<"call_limits">>], Doc, Default).

-spec set_call_limits(endpoint(), kz_json:object()) -> endpoint().
set_call_limits(Doc, CallLimits) ->
    kz_json:set_value([<<"call_limits">>], CallLimits, Doc).

-spec tags(endpoint()) -> kz_term:api_objects().
tags(Endpoint) ->
    tags(Endpoint, 'undefined').

-spec tags(endpoint(), Default) -> kz_json:ne_objects() | Default.
tags(Endpoint, Default) ->
    kz_json:get_ne_json_list([<<"tags">>], Endpoint, Default).

-spec meta_id(endpoint()) -> kz_term:api_ne_binary().
meta_id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"endpoint_meta_id">>, Endpoint).
