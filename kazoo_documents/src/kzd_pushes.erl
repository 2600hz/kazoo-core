%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `pushes' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_pushes).

-export([new/0]).
-export([alert/1, alert/2, set_alert/2]).
-export([alert_body/1, alert_body/2, set_alert_body/2]).
-export([alert_body_key/1, alert_body_key/2, set_alert_body_key/2]).
-export([alert_body_params/1, alert_body_params/2, set_alert_body_params/2]).
-export([alert_subtitle/1, alert_subtitle/2, set_alert_subtitle/2]).
-export([alert_title/1, alert_title/2, set_alert_title/2]).
-export([alert_title_key/1, alert_title_key/2, set_alert_title_key/2]).
-export([alert_title_params/1, alert_title_params/2, set_alert_title_params/2]).
-export([apns/1, apns/2, set_apns/2]).
-export([apns_alert/1, apns_alert/2, set_apns_alert/2]).
-export([apns_alert_subtitle_key/1, apns_alert_subtitle_key/2, set_apns_alert_subtitle_key/2]).
-export([apns_alert_subtitle_params/1, apns_alert_subtitle_params/2, set_apns_alert_subtitle_params/2]).
-export([apns_push_type/1, apns_push_type/2, set_apns_push_type/2]).
-export([apns_thread_id/1, apns_thread_id/2, set_apns_thread_id/2]).
-export([apns_topic/1, apns_topic/2, set_apns_topic/2]).
-export([badge/1, badge/2, set_badge/2]).
-export([call_id/1, call_id/2, set_call_id/2]).
-export([category/1, category/2, set_category/2]).
-export([collapse_id/1, collapse_id/2, set_collapse_id/2]).
-export([content_available/1, content_available/2, set_content_available/2]).
-export([content_mutable/1, content_mutable/2, set_content_mutable/2]).
-export([data/1, data/2, set_data/2]).
-export([fcm/1, fcm/2, set_fcm/2]).
-export([fcm_android/1, fcm_android/2, set_fcm_android/2]).
-export([fcm_android_channel_id/1, fcm_android_channel_id/2, set_fcm_android_channel_id/2]).
-export([fcm_android_color/1, fcm_android_color/2, set_fcm_android_color/2]).
-export([fcm_android_icon/1, fcm_android_icon/2, set_fcm_android_icon/2]).
-export([fcm_android_tag/1, fcm_android_tag/2, set_fcm_android_tag/2]).
-export([priority/1, priority/2, set_priority/2]).
-export([sound/1, sound/2, set_sound/2]).
-export([ttl/1, ttl/2, set_ttl/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"pushes">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec alert(doc()) -> kz_term:api_object().
alert(Doc) ->
    alert(Doc, 'undefined').

-spec alert(doc(), Default) -> kz_json:object() | Default.
alert(Doc, Default) ->
    kz_json:get_json_value([<<"alert">>], Doc, Default).

-spec set_alert(doc(), kz_json:object()) -> doc().
set_alert(Doc, Alert) ->
    kz_json:set_value([<<"alert">>], Alert, Doc).

-spec alert_body(doc()) -> kz_term:api_binary().
alert_body(Doc) ->
    alert_body(Doc, 'undefined').

-spec alert_body(doc(), Default) -> binary() | Default.
alert_body(Doc, Default) ->
    kz_json:get_binary_value([<<"alert">>, <<"body">>], Doc, Default).

-spec set_alert_body(doc(), binary()) -> doc().
set_alert_body(Doc, AlertBody) ->
    kz_json:set_value([<<"alert">>, <<"body">>], AlertBody, Doc).

-spec alert_body_key(doc()) -> kz_term:api_binary().
alert_body_key(Doc) ->
    alert_body_key(Doc, 'undefined').

-spec alert_body_key(doc(), Default) -> binary() | Default.
alert_body_key(Doc, Default) ->
    kz_json:get_binary_value([<<"alert">>, <<"body_key">>], Doc, Default).

-spec set_alert_body_key(doc(), binary()) -> doc().
set_alert_body_key(Doc, AlertBodyKey) ->
    kz_json:set_value([<<"alert">>, <<"body_key">>], AlertBodyKey, Doc).

-spec alert_body_params(doc()) -> kz_term:api_ne_binaries().
alert_body_params(Doc) ->
    alert_body_params(Doc, 'undefined').

-spec alert_body_params(doc(), Default) -> kz_term:ne_binaries() | Default.
alert_body_params(Doc, Default) ->
    kz_json:get_list_value([<<"alert">>, <<"body_params">>], Doc, Default).

-spec set_alert_body_params(doc(), kz_term:ne_binaries()) -> doc().
set_alert_body_params(Doc, AlertBodyParams) ->
    kz_json:set_value([<<"alert">>, <<"body_params">>], AlertBodyParams, Doc).

-spec alert_subtitle(doc()) -> kz_term:api_binary().
alert_subtitle(Doc) ->
    alert_subtitle(Doc, 'undefined').

-spec alert_subtitle(doc(), Default) -> binary() | Default.
alert_subtitle(Doc, Default) ->
    kz_json:get_binary_value([<<"alert">>, <<"subtitle">>], Doc, Default).

-spec set_alert_subtitle(doc(), binary()) -> doc().
set_alert_subtitle(Doc, AlertSubtitle) ->
    kz_json:set_value([<<"alert">>, <<"subtitle">>], AlertSubtitle, Doc).

-spec alert_title(doc()) -> kz_term:api_binary().
alert_title(Doc) ->
    alert_title(Doc, 'undefined').

-spec alert_title(doc(), Default) -> binary() | Default.
alert_title(Doc, Default) ->
    kz_json:get_binary_value([<<"alert">>, <<"title">>], Doc, Default).

-spec set_alert_title(doc(), binary()) -> doc().
set_alert_title(Doc, AlertTitle) ->
    kz_json:set_value([<<"alert">>, <<"title">>], AlertTitle, Doc).

-spec alert_title_key(doc()) -> kz_term:api_binary().
alert_title_key(Doc) ->
    alert_title_key(Doc, 'undefined').

-spec alert_title_key(doc(), Default) -> binary() | Default.
alert_title_key(Doc, Default) ->
    kz_json:get_binary_value([<<"alert">>, <<"title_key">>], Doc, Default).

-spec set_alert_title_key(doc(), binary()) -> doc().
set_alert_title_key(Doc, AlertTitleKey) ->
    kz_json:set_value([<<"alert">>, <<"title_key">>], AlertTitleKey, Doc).

-spec alert_title_params(doc()) -> kz_term:api_ne_binaries().
alert_title_params(Doc) ->
    alert_title_params(Doc, 'undefined').

-spec alert_title_params(doc(), Default) -> kz_term:ne_binaries() | Default.
alert_title_params(Doc, Default) ->
    kz_json:get_list_value([<<"alert">>, <<"title_params">>], Doc, Default).

-spec set_alert_title_params(doc(), kz_term:ne_binaries()) -> doc().
set_alert_title_params(Doc, AlertTitleParams) ->
    kz_json:set_value([<<"alert">>, <<"title_params">>], AlertTitleParams, Doc).

-spec apns(doc()) -> kz_term:api_object().
apns(Doc) ->
    apns(Doc, 'undefined').

-spec apns(doc(), Default) -> kz_json:object() | Default.
apns(Doc, Default) ->
    kz_json:get_json_value([<<"apns">>], Doc, Default).

-spec set_apns(doc(), kz_json:object()) -> doc().
set_apns(Doc, Apns) ->
    kz_json:set_value([<<"apns">>], Apns, Doc).

-spec apns_alert(doc()) -> kz_term:api_object().
apns_alert(Doc) ->
    apns_alert(Doc, 'undefined').

-spec apns_alert(doc(), Default) -> kz_json:object() | Default.
apns_alert(Doc, Default) ->
    kz_json:get_json_value([<<"apns">>, <<"alert">>], Doc, Default).

-spec set_apns_alert(doc(), kz_json:object()) -> doc().
set_apns_alert(Doc, ApnsAlert) ->
    kz_json:set_value([<<"apns">>, <<"alert">>], ApnsAlert, Doc).

-spec apns_alert_subtitle_key(doc()) -> kz_term:api_binary().
apns_alert_subtitle_key(Doc) ->
    apns_alert_subtitle_key(Doc, 'undefined').

-spec apns_alert_subtitle_key(doc(), Default) -> binary() | Default.
apns_alert_subtitle_key(Doc, Default) ->
    kz_json:get_binary_value([<<"apns">>, <<"alert">>, <<"subtitle_key">>], Doc, Default).

-spec set_apns_alert_subtitle_key(doc(), binary()) -> doc().
set_apns_alert_subtitle_key(Doc, ApnsAlertSubtitleKey) ->
    kz_json:set_value([<<"apns">>, <<"alert">>, <<"subtitle_key">>], ApnsAlertSubtitleKey, Doc).

-spec apns_alert_subtitle_params(doc()) -> kz_term:api_ne_binaries().
apns_alert_subtitle_params(Doc) ->
    apns_alert_subtitle_params(Doc, 'undefined').

-spec apns_alert_subtitle_params(doc(), Default) -> kz_term:ne_binaries() | Default.
apns_alert_subtitle_params(Doc, Default) ->
    kz_json:get_list_value([<<"apns">>, <<"alert">>, <<"subtitle_params">>], Doc, Default).

-spec set_apns_alert_subtitle_params(doc(), kz_term:ne_binaries()) -> doc().
set_apns_alert_subtitle_params(Doc, ApnsAlertSubtitleParams) ->
    kz_json:set_value([<<"apns">>, <<"alert">>, <<"subtitle_params">>], ApnsAlertSubtitleParams, Doc).

-spec apns_push_type(doc()) -> kz_term:api_binary().
apns_push_type(Doc) ->
    apns_push_type(Doc, 'undefined').

-spec apns_push_type(doc(), Default) -> binary() | Default.
apns_push_type(Doc, Default) ->
    kz_json:get_binary_value([<<"apns">>, <<"push_type">>], Doc, Default).

-spec set_apns_push_type(doc(), binary()) -> doc().
set_apns_push_type(Doc, ApnsPushType) ->
    kz_json:set_value([<<"apns">>, <<"push_type">>], ApnsPushType, Doc).

-spec apns_thread_id(doc()) -> kz_term:api_binary().
apns_thread_id(Doc) ->
    apns_thread_id(Doc, 'undefined').

-spec apns_thread_id(doc(), Default) -> binary() | Default.
apns_thread_id(Doc, Default) ->
    kz_json:get_binary_value([<<"apns">>, <<"thread_id">>], Doc, Default).

-spec set_apns_thread_id(doc(), binary()) -> doc().
set_apns_thread_id(Doc, ApnsThreadId) ->
    kz_json:set_value([<<"apns">>, <<"thread_id">>], ApnsThreadId, Doc).

-spec apns_topic(doc()) -> kz_term:api_binary().
apns_topic(Doc) ->
    apns_topic(Doc, 'undefined').

-spec apns_topic(doc(), Default) -> binary() | Default.
apns_topic(Doc, Default) ->
    kz_json:get_binary_value([<<"apns">>, <<"topic">>], Doc, Default).

-spec set_apns_topic(doc(), binary()) -> doc().
set_apns_topic(Doc, ApnsTopic) ->
    kz_json:set_value([<<"apns">>, <<"topic">>], ApnsTopic, Doc).

-spec badge(doc()) -> kz_term:api_integer().
badge(Doc) ->
    badge(Doc, 'undefined').

-spec badge(doc(), Default) -> integer() | Default.
badge(Doc, Default) ->
    kz_json:get_integer_value([<<"badge">>], Doc, Default).

-spec set_badge(doc(), integer()) -> doc().
set_badge(Doc, Badge) ->
    kz_json:set_value([<<"badge">>], Badge, Doc).

-spec call_id(doc()) -> kz_term:api_ne_binary().
call_id(Doc) ->
    call_id(Doc, 'undefined').

-spec call_id(doc(), Default) -> kz_term:ne_binary() | Default.
call_id(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"call_id">>], Doc, Default).

-spec set_call_id(doc(), kz_term:ne_binary()) -> doc().
set_call_id(Doc, CallId) ->
    kz_json:set_value([<<"call_id">>], CallId, Doc).

-spec category(doc()) -> kz_term:api_binary().
category(Doc) ->
    category(Doc, 'undefined').

-spec category(doc(), Default) -> binary() | Default.
category(Doc, Default) ->
    kz_json:get_binary_value([<<"category">>], Doc, Default).

-spec set_category(doc(), binary()) -> doc().
set_category(Doc, Category) ->
    kz_json:set_value([<<"category">>], Category, Doc).

-spec collapse_id(doc()) -> kz_term:api_binary().
collapse_id(Doc) ->
    collapse_id(Doc, 'undefined').

-spec collapse_id(doc(), Default) -> binary() | Default.
collapse_id(Doc, Default) ->
    kz_json:get_binary_value([<<"collapse_id">>], Doc, Default).

-spec set_collapse_id(doc(), binary()) -> doc().
set_collapse_id(Doc, CollapseId) ->
    kz_json:set_value([<<"collapse_id">>], CollapseId, Doc).

-spec content_available(doc()) -> kz_term:api_boolean().
content_available(Doc) ->
    content_available(Doc, 'undefined').

-spec content_available(doc(), Default) -> boolean() | Default.
content_available(Doc, Default) ->
    kz_json:get_boolean_value([<<"content_available">>], Doc, Default).

-spec set_content_available(doc(), boolean()) -> doc().
set_content_available(Doc, ContentAvailable) ->
    kz_json:set_value([<<"content_available">>], ContentAvailable, Doc).

-spec content_mutable(doc()) -> kz_term:api_boolean().
content_mutable(Doc) ->
    content_mutable(Doc, 'undefined').

-spec content_mutable(doc(), Default) -> boolean() | Default.
content_mutable(Doc, Default) ->
    kz_json:get_boolean_value([<<"content_mutable">>], Doc, Default).

-spec set_content_mutable(doc(), boolean()) -> doc().
set_content_mutable(Doc, ContentMutable) ->
    kz_json:set_value([<<"content_mutable">>], ContentMutable, Doc).

-spec data(doc()) -> kz_term:api_object().
data(Doc) ->
    data(Doc, 'undefined').

-spec data(doc(), Default) -> kz_json:object() | Default.
data(Doc, Default) ->
    kz_json:get_json_value([<<"data">>], Doc, Default).

-spec set_data(doc(), kz_json:object()) -> doc().
set_data(Doc, Data) ->
    kz_json:set_value([<<"data">>], Data, Doc).

-spec fcm(doc()) -> kz_term:api_object().
fcm(Doc) ->
    fcm(Doc, 'undefined').

-spec fcm(doc(), Default) -> kz_json:object() | Default.
fcm(Doc, Default) ->
    kz_json:get_json_value([<<"fcm">>], Doc, Default).

-spec set_fcm(doc(), kz_json:object()) -> doc().
set_fcm(Doc, Fcm) ->
    kz_json:set_value([<<"fcm">>], Fcm, Doc).

-spec fcm_android(doc()) -> kz_term:api_object().
fcm_android(Doc) ->
    fcm_android(Doc, 'undefined').

-spec fcm_android(doc(), Default) -> kz_json:object() | Default.
fcm_android(Doc, Default) ->
    kz_json:get_json_value([<<"fcm">>, <<"android">>], Doc, Default).

-spec set_fcm_android(doc(), kz_json:object()) -> doc().
set_fcm_android(Doc, FcmAndroid) ->
    kz_json:set_value([<<"fcm">>, <<"android">>], FcmAndroid, Doc).

-spec fcm_android_channel_id(doc()) -> kz_term:api_binary().
fcm_android_channel_id(Doc) ->
    fcm_android_channel_id(Doc, 'undefined').

-spec fcm_android_channel_id(doc(), Default) -> binary() | Default.
fcm_android_channel_id(Doc, Default) ->
    kz_json:get_binary_value([<<"fcm">>, <<"android">>, <<"channel_id">>], Doc, Default).

-spec set_fcm_android_channel_id(doc(), binary()) -> doc().
set_fcm_android_channel_id(Doc, FcmAndroidChannelId) ->
    kz_json:set_value([<<"fcm">>, <<"android">>, <<"channel_id">>], FcmAndroidChannelId, Doc).

-spec fcm_android_color(doc()) -> kz_term:api_binary().
fcm_android_color(Doc) ->
    fcm_android_color(Doc, 'undefined').

-spec fcm_android_color(doc(), Default) -> binary() | Default.
fcm_android_color(Doc, Default) ->
    kz_json:get_binary_value([<<"fcm">>, <<"android">>, <<"color">>], Doc, Default).

-spec set_fcm_android_color(doc(), binary()) -> doc().
set_fcm_android_color(Doc, FcmAndroidColor) ->
    kz_json:set_value([<<"fcm">>, <<"android">>, <<"color">>], FcmAndroidColor, Doc).

-spec fcm_android_icon(doc()) -> kz_term:api_binary().
fcm_android_icon(Doc) ->
    fcm_android_icon(Doc, 'undefined').

-spec fcm_android_icon(doc(), Default) -> binary() | Default.
fcm_android_icon(Doc, Default) ->
    kz_json:get_binary_value([<<"fcm">>, <<"android">>, <<"icon">>], Doc, Default).

-spec set_fcm_android_icon(doc(), binary()) -> doc().
set_fcm_android_icon(Doc, FcmAndroidIcon) ->
    kz_json:set_value([<<"fcm">>, <<"android">>, <<"icon">>], FcmAndroidIcon, Doc).

-spec fcm_android_tag(doc()) -> kz_term:api_binary().
fcm_android_tag(Doc) ->
    fcm_android_tag(Doc, 'undefined').

-spec fcm_android_tag(doc(), Default) -> binary() | Default.
fcm_android_tag(Doc, Default) ->
    kz_json:get_binary_value([<<"fcm">>, <<"android">>, <<"tag">>], Doc, Default).

-spec set_fcm_android_tag(doc(), binary()) -> doc().
set_fcm_android_tag(Doc, FcmAndroidTag) ->
    kz_json:set_value([<<"fcm">>, <<"android">>, <<"tag">>], FcmAndroidTag, Doc).

-spec priority(doc()) -> binary().
priority(Doc) ->
    priority(Doc, <<"high">>).

-spec priority(doc(), Default) -> binary() | Default.
priority(Doc, Default) ->
    kz_json:get_binary_value([<<"priority">>], Doc, Default).

-spec set_priority(doc(), binary()) -> doc().
set_priority(Doc, Priority) ->
    kz_json:set_value([<<"priority">>], Priority, Doc).

-spec sound(doc()) -> kz_term:api_binary().
sound(Doc) ->
    sound(Doc, 'undefined').

-spec sound(doc(), Default) -> binary() | Default.
sound(Doc, Default) ->
    kz_json:get_binary_value([<<"sound">>], Doc, Default).

-spec set_sound(doc(), binary()) -> doc().
set_sound(Doc, Sound) ->
    kz_json:set_value([<<"sound">>], Sound, Doc).

-spec ttl(doc()) -> kz_term:api_integer().
ttl(Doc) ->
    ttl(Doc, 'undefined').

-spec ttl(doc(), Default) -> integer() | Default.
ttl(Doc, Default) ->
    kz_json:get_integer_value([<<"ttl">>], Doc, Default).

-spec set_ttl(doc(), integer()) -> doc().
set_ttl(Doc, Ttl) ->
    kz_json:set_value([<<"ttl">>], Ttl, Doc).
