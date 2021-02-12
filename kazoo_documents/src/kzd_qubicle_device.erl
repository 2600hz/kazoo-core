%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_qubicle_device).

-export([new/0]).
-export([suppress_unregister_notifications/1, suppress_unregister_notifications/2, set_suppress_unregister_notifications/2]).
-export([enabled/1, enabled/2, set_enabled/2]).
-export([device_type/1, device_type/2, set_device_type/2]).
-export([name/1, name/2, set_name/2]).
-export([owner_id/1, owner_id/2, set_owner_id/2]).
-export([sip_username/1, sip_username/2, set_sip_username/2]).
-export([sip_password/1, sip_password/2, set_sip_password/2]).
-export([sip_invite_format/1, sip_invite_format/2, set_sip_invite_format/2]).
-export([sip_method/1, sip_method/2, set_sip_method/2]).
-export([sip_expire_seconds/1, sip_expire_seconds/2, set_sip_expire_seconds/2]).
-export([media_webrtc/1, media_webrtc/2, set_media_webrtc/2]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-type docs() :: [doc()].
-export_type([doc/0, docs/0]).

-define(SCHEMA, <<"devices">>).
-define(STATIC_FLAGS, <<"static">>).
-define(DYNAMIC_FLAGS, <<"dynamic">>).

-spec new() -> doc().
new() ->
    kz_doc:set_type(kz_json_schema:default_object(?SCHEMA), type()).

-spec suppress_unregister_notifications(doc()) -> boolean().
suppress_unregister_notifications(Doc) ->
    suppress_unregister_notifications(Doc, false).

-spec suppress_unregister_notifications(doc(), Default) -> boolean() | Default.
suppress_unregister_notifications(Doc, Default) ->
    kz_json:get_boolean_value([<<"suppress_unregister_notifications">>], Doc, Default).

-spec set_suppress_unregister_notifications(doc(), boolean()) -> doc().
set_suppress_unregister_notifications(Doc, SuppressUnregisterNotifications) ->
    kz_json:set_value([<<"suppress_unregister_notifications">>], SuppressUnregisterNotifications, Doc).

-spec enabled(doc()) -> boolean().
enabled(Doc) ->
    enabled(Doc, true).

-spec enabled(doc(), Default) -> boolean() | Default.
enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"enabled">>], Doc, Default).

-spec set_enabled(doc(), boolean()) -> doc().
set_enabled(Doc, Enabled) ->
    kz_json:set_value([<<"enabled">>], Enabled, Doc).

-spec device_type(doc()) -> kz_term:api_binary().
device_type(Doc) ->
    device_type(Doc, 'undefined').

-spec device_type(doc(), Default) -> binary() | Default.
device_type(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"device_type">>], Doc, Default).

-spec set_device_type(doc(), binary()) -> doc().
set_device_type(Doc, DeviceType) ->
    kz_json:set_value([<<"device_type">>], DeviceType, Doc).

-spec type() -> kz_term:ne_binary().
type() -> <<"device">>.

-spec name(doc()) -> kz_term:api_ne_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> kz_term:ne_binary() | Default.
name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), kz_term:ne_binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

-spec owner_id(doc()) -> kz_term:api_ne_binary().
owner_id(Doc) ->
    owner_id(Doc, 'undefined').

-spec owner_id(doc(), Default) -> kz_term:ne_binary() | Default.
owner_id(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"owner_id">>], Doc, Default).

-spec set_owner_id(doc(), kz_term:ne_binary()) -> doc().
set_owner_id(Doc, OwnerId) ->
    kz_json:set_value([<<"owner_id">>], OwnerId, Doc).

-spec sip_username(doc()) -> kz_term:api_ne_binary().
sip_username(Doc) ->
    sip_username(Doc, 'undefined').

-spec sip_username(doc(), Default) -> kz_term:ne_binary() | Default.
sip_username(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"sip">>, <<"username">>], Doc, Default).

-spec set_sip_username(doc(), kz_term:ne_binary()) -> doc().
set_sip_username(Doc, SipUsername) ->
    kz_json:set_value([<<"sip">>, <<"username">>], SipUsername, Doc).

-spec sip_password(doc()) -> kz_term:api_ne_binary().
sip_password(Doc) ->
    sip_password(Doc, 'undefined').

-spec sip_password(doc(), Default) -> kz_term:ne_binary() | Default.
sip_password(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"sip">>, <<"password">>], Doc, Default).

-spec set_sip_password(doc(), kz_term:ne_binary()) -> doc().
set_sip_password(Doc, SipPassword) ->
    kz_json:set_value([<<"sip">>, <<"password">>], SipPassword, Doc).

-spec sip_invite_format(doc()) -> binary().
sip_invite_format(Doc) ->
    sip_invite_format(Doc, <<"contact">>).

-spec sip_invite_format(doc(), Default) -> binary() | Default.
sip_invite_format(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"sip">>, <<"invite_format">>], Doc, Default).

-spec set_sip_invite_format(doc(), binary()) -> doc().
set_sip_invite_format(Doc, SipInviteFormat) ->
    kz_json:set_value([<<"sip">>, <<"invite_format">>], SipInviteFormat, Doc).

-spec sip_method(doc()) -> binary().
sip_method(Doc) ->
    sip_method(Doc, <<"password">>).

-spec sip_method(doc(), Default) -> binary() | Default.
sip_method(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"sip">>, <<"method">>], Doc, Default).

-spec set_sip_method(doc(), binary()) -> doc().
set_sip_method(Doc, SipMethod) ->
    kz_json:set_value([<<"sip">>, <<"method">>], SipMethod, Doc).

-spec sip_expire_seconds(doc()) -> integer().
sip_expire_seconds(Doc) ->
    sip_expire_seconds(Doc, 300).

-spec sip_expire_seconds(doc(), Default) -> integer() | Default.
sip_expire_seconds(Doc, Default) ->
    kz_json:get_integer_value([<<"sip">>, <<"expire_seconds">>], Doc, Default).

-spec set_sip_expire_seconds(doc(), integer()) -> doc().
set_sip_expire_seconds(Doc, SipExpireSeconds) ->
    kz_json:set_value([<<"sip">>, <<"expire_seconds">>], SipExpireSeconds, Doc).

-spec media_webrtc(doc()) -> kz_term:api_ne_binary().
media_webrtc(Doc) ->
    media_webrtc(Doc, 'undefined').

-spec media_webrtc(doc(), Default) -> kz_term:ne_binary() | Default.
media_webrtc(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"media">>, <<"webrtc">>], Doc, Default).

-spec set_media_webrtc(doc(), kz_term:ne_binary()) -> doc().
set_media_webrtc(Doc, SipPassword) ->
    kz_json:set_value([<<"media">>, <<"webrtc">>], SipPassword, Doc).
