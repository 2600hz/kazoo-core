%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzt_util).

-export([http_method/1
        ,record_store_method/1
        ,resolve_uri/2
        ,offnet_req/3
        ,update_call_status/2, get_call_status/2
        ,get_request_vars/1
        ,add_error/3, get_errors/1
        ,set_hangup_dtmf/2, get_hangup_dtmf/1
        ,set_digit_pressed/2, get_digit_pressed/1
        ,set_is_caller_hungup/2, get_is_caller_hungup/1
        ,set_call_timeout/2, get_call_timeout/1
        ,set_call_time_limit/2, get_call_time_limit/1
        ,set_record_call/2, get_record_call/1
        ,set_recording_stereo/2, get_recording_stereo/1
        ,set_voice_uri/2, get_voice_uri/1
        ,set_voice_uri_method/2, get_voice_uri_method/1

        ,set_digits_collected/2, get_digits_collected/1
        ,add_digit_collected/2, clear_digits_collected/1

        ,set_recording_url/2, get_recording_url/1
        ,set_recording_duration/2, get_recording_duration/1
        ,set_recording_sid/2, get_recording_sid/1

        ,set_transcription_sid/2, get_transcription_sid/1
        ,set_transcription_text/2, get_transcription_text/1
        ,set_transcription_status/2, get_transcription_status/1
        ,set_transcription_url/2, get_transcription_url/1

        ,set_dial_call_status/2, get_dial_call_status/1
        ,set_dial_call_sid/2, get_dial_call_sid/1
        ,set_dial_call_duration/2, get_dial_call_duration/1
        ,set_queue_sid/2, get_queue_sid/1
        ,set_dequeue_result/2, get_dequeue_result/1
        ,set_dequeued_call_sid/2, get_dequeued_call_sid/1
        ,set_dequeued_call_queue_time/2, get_dequeued_call_queue_time/1
        ,set_dequeued_call_duration/2, get_dequeued_call_duration/1
        ,set_media_meta/2, get_media_meta/1
        ,set_amqp_listener/2, get_amqp_listener/1

        ,set_gather_pidref/2, get_gather_pidref/1

        ,set_conference_profile/2, get_conference_profile/1
        ,set_caller_controls/2, get_caller_controls/1
        ,set_advertise/2, get_advertise/1
        ,set_chat_permissions/2, get_chat_permissions/1

        ,add_stream/3, get_streams/1

        ,iteration/1, increment_iteration/1
        ,set_serverless/2, get_serverless/1
        ]).

-include("kzt.hrl").
-include_lib("kazoo_amqp/include/kz_api_literals.hrl").
-include_lib("kazoo_amqp/include/kapi_offnet_resource.hrl").

-define(DEFAULT_HTTP_METHOD, 'post').
-define(ALLOWED_RECORD_METHOD, [<<"post">>, <<"put">>, <<"patch">>]).

-spec http_method(kz_term:api_binary() | list()) -> 'get' | 'post'.
http_method(L) when is_list(L) ->
    http_method(kz_term:to_binary(props:get_value('method', L)));
http_method('undefined') -> ?DEFAULT_HTTP_METHOD;
http_method(<<_/binary>> = Method) ->
    MethodBin = kz_term:to_lower_binary(Method),

    try kz_term:to_atom(MethodBin) of
        'get' -> 'get';
        'post' -> 'post';
        _ -> ?DEFAULT_HTTP_METHOD
    catch
        _E:_R -> ?DEFAULT_HTTP_METHOD
    end;
http_method(Method) -> http_method(kz_term:to_binary(Method)).

-spec record_store_method(kz_term:proplist()) -> kz_term:api_ne_binary().
record_store_method(Props) ->
    case props:get_ne_binary_value('recordingMethod', Props) of
        'undefined' ->
            'undefined';
        Method0 ->
            Method = kz_term:to_lower_binary(Method0),
            case lists:member(Method, ?ALLOWED_RECORD_METHOD) of
                'true' ->
                    Method;
                'false' ->
                    lager:warning("store record method ~s is not allowed", [Method]),
                    'undefined'
            end
    end.


-spec resolve_uri(kz_term:api_binary(), kz_term:ne_binary()) -> kz_term:api_ne_binary().
resolve_uri('undefined', NewPath) ->
    resolve_action_uri(NewPath);
resolve_uri(<<>>, NewPath) ->
    resolve_action_uri(NewPath);
resolve_uri(Path, NewPath) ->
    kz_http_util:resolve_uri(Path, NewPath).

resolve_action_uri(<<"http", _/binary>>=Uri) ->
    Uri;
resolve_action_uri(_Other) ->
    lager:debug("nobase voice_uri, and invalid action uri ~p", [_Other]),
    'undefined'.

%% See cf_resources.erl.
%% Try to match cf_resources as much as possible.
%% Preserve code style for quick eyeballing.
-spec offnet_req(kz_term:proplist(), kz_term:proplist(), kapps_call:call()) -> 'ok'.
offnet_req(Data, OffnetProps, Call) ->
    {ECIDNum, ECIDName} = kz_attributes:caller_id(<<"emergency">>, Call),

    %% {AssertedNumber, AssertedName, AssertedRealm} =
    %%     get_asserted_identity(Data, Call),

    {CIDNumber, CIDName} = kz_attributes:caller_id(<<"external">>, Call),

    CCVs = kapps_call:custom_channel_vars(Call),
    PrivacyFlags = kz_privacy:flags(CCVs),

    Req = kz_json:from_list(
            [{?KEY_ACCOUNT_ID, kapps_call:account_id(Call)}
            ,{?KEY_ACCOUNT_REALM, kapps_call:from_realm(Call)}
            ,{?KEY_APPLICATION_NAME, ?APPLICATION_BRIDGE}
             %% ,{?KEY_BYPASS_E164, get_bypass_e164(Data)}
            ,{?KEY_B_LEG_EVENTS, [<<"DTMF">>]}
            ,{?KEY_CALL_ID, kapps_call:call_id(Call)}
             %% ,{?KEY_CCVS, get_channel_vars(Call)}
             %% ,{?KEY_CAVS, kapps_call:custom_application_vars(Call)}
             %% ,{?KEY_REQUESTOR_CCVS, kapps_call:custom_channel_vars(Call)}
            ,{?KEY_CONTROL_QUEUE, kapps_call:control_queue(Call)}
             %% ,{?KEY_CSHS, get_sip_headers(Data, Call)}
             %% ,{?KEY_REQUESTOR_CSHS, kapps_call:custom_sip_headers(Call)}
            ,{?KEY_E_CALLER_ID_NAME, ECIDName}
            ,{?KEY_E_CALLER_ID_NUMBER, ECIDNum}
            ,{?KEY_FLAGS, get_flags(Data, Call)}
            ,{?KEY_FORMAT_FROM_URI, 'false'}
             %% ,{?KEY_FORMAT_FROM_URI, kz_json:is_true(<<"format_from_uri">>, Data)}
             %% ,{?KEY_FROM_URI_REALM, get_from_uri_realm(Data, Call)}
            ,{?KEY_FROM_URI_REALM, maybe_get_call_from_realm(Call)}
            ,{?KEY_HUNT_ACCOUNT_ID, get_hunt_account_id(Data, Call)}
             %% ,{?KEY_IGNORE_EARLY_MEDIA, get_ignore_early_media(Data)}
            ,{?KEY_IGNORE_EARLY_MEDIA, 'false'}
            ,{?KEY_INCEPTION, get_inception(Call)}
             %% ,{?KEY_MEDIA, kz_json:get_ne_binary_value(<<"Media">>, Data)} %% set by kzt_twiml_dial
            ,{?KEY_MSG_ID, kz_binary:rand_hex(6)}
            ,{?KEY_OUTBOUND_CALLER_ID_NAME, CIDName}
            ,{?KEY_OUTBOUND_CALLER_ID_NUMBER, CIDNumber}
            ,{?KEY_PRESENCE_ID, maybe_presence_id(Call)}
            ,{?KEY_ASSERTED_IDENTITY_NAME, 'undefined'}
            ,{?KEY_ASSERTED_IDENTITY_NUMBER, 'undefined'}
            ,{?KEY_ASSERTED_IDENTITY_REALM, 'undefined'}
             %% ,{?KEY_RINGBACK, props:get_value(<<"ringback">>, Data)}
             %% ,{?KEY_T38_ENABLED, get_t38_enabled(Call)}
             %% ,{?KEY_TIMEOUT, props:get_value(<<"timeout">>, Data)} %% may set by kzt_twiml_dial
             %% ,{?KEY_TO_DID, get_to_did(Data, Call)}
            ,{?KEY_TO_DID, kapps_call:request_user(Call)}
            ,{?KEY_DENIED_CALL_RESTRICTIONS, kapps_call:kvs_fetch('denied_call_restrictions', Call)}
            ,{?KEY_OUTBOUND_ACTIONS, kapps_call:kvs_fetch('outbound_actions', Call)}
            ,{?KEY_PRIVACY_METHOD, props:get_value(?KEY_PRIVACY_METHOD, PrivacyFlags)}
            ,{?KEY_PRIVACY_HIDE_NAME, props:get_value(?KEY_PRIVACY_HIDE_NAME, PrivacyFlags)}
            ,{?KEY_PRIVACY_HIDE_NUMBER, props:get_value(?KEY_PRIVACY_HIDE_NUMBER, PrivacyFlags)}
            ,{?KEY_SIP_DIVERSIONS, kapps_call:bridge_diversions(Call)}
             %% ,{?KEY_EMERGENCY_ADDRESS, get_emergency_address(Data, Call)}
            ,{?KEY_RESOURCE_TYPE, ?RESOURCE_TYPE_AUDIO}
            | kz_api:default_headers(kapps_call:controller_queue(Call), ?APP_NAME, ?APP_VERSION)
            ] ++ OffnetProps),

    kz_amqp_worker:cast(Req, fun kapi_offnet_resource:publish_req/1).

-spec get_flags(kz_term:proplist(), kapps_call:call()) -> kz_term:api_binaries().
get_flags(Data, Call) ->
    DefaultFlags = kz_attributes:get_flags(?APP_NAME, Call),
    case props:get_value('outboundFlags', Data, []) of
        [] -> DefaultFlags;
        Flags when is_list(Flags) ->
            lists:uniq(DefaultFlags ++ [Flag || Flag <- Flags, kz_term:is_ne_binary(Flag)]);
        _ ->
            DefaultFlags
    end.

-spec get_hunt_account_id(kz_term:proplist(), kapps_call:call()) -> kz_term:api_binary().
get_hunt_account_id(Data, Call) ->
    case props:is_true('useLocalResources', Data, kapps_call:should_use_local_resources(Call)) of
        'false' -> 'undefined';
        'true' ->
            AccountId = default_hunt_account_id(Call),
            props:get_ne_binary_value('huntAccountId', Data, AccountId)
    end.

-spec default_hunt_account_id(kapps_call:call()) -> kz_term:api_binary().
default_hunt_account_id(Call) ->
    case kapps_call:hunt_account_id(Call) of
        'undefined' -> kapps_call:account_id(Call);
        AccountId -> AccountId
    end.

-spec maybe_get_call_from_realm(kapps_call:call()) -> kz_term:api_ne_binary().
maybe_get_call_from_realm(Call) ->
    case kapps_call:from_realm(Call) of
        <<"norealm">> ->
            kzd_accounts:fetch_realm(kapps_call:account_id(Call));
        Realm -> Realm
    end.

-spec get_inception(kapps_call:call()) -> kz_term:api_binary().
get_inception(Call) ->
    kz_json:get_value(<<"Inception">>, kapps_call:custom_channel_vars(Call)).

-spec maybe_presence_id(kapps_call:call()) -> kz_term:api_ne_binary().
maybe_presence_id(Call) ->
    case kapps_call:is_call_forward(Call) of
        'true' -> kz_attributes:presence_id(Call);
        'false' -> 'undefined'
    end.

-spec update_call_status(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
update_call_status(Status, Call) ->
    kapps_call:kvs_store(<<"call_status">>, Status, Call).

-spec get_call_status(kapps_call:call(), kz_term:ne_binary()) -> kz_term:api_binary().
get_call_status(Call, Default) ->
    kapps_call:kvs_fetch(<<"call_status">>, Default, Call).

-spec set_is_caller_hungup(boolean(), kapps_call:call()) -> kapps_call:call().
set_is_caller_hungup(IsEnded, Call) -> kapps_call:kvs_store(<<"is_caller_hungup">>, IsEnded, Call).

-spec get_is_caller_hungup(kapps_call:call()) -> boolean().
get_is_caller_hungup(Call) -> kz_term:is_true(kapps_call:kvs_fetch(<<"is_caller_hungup">>, Call)).

-spec add_error(kz_term:ne_binary(), any(), kapps_call:call()) -> kapps_call:call().
add_error(K, V, Call) ->
    case kapps_call:kvs_fetch(<<"response_errors">>, Call) of
        'undefined' ->
            kapps_call:kvs_store(<<"response_errors">>, [{K, V}], Call);
        Vs ->
            kapps_call:kvs_append_list(<<"response_errors">>, [{K, V}|Vs], Call)
    end.

-spec get_errors(kapps_call:call()) -> kz_term:proplist().
get_errors(Call) -> kapps_call:kvs_fetch(<<"response_errors">>, Call).

-spec set_hangup_dtmf(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_hangup_dtmf(DTMF, Call) -> kapps_call:kvs_store(<<"hangup_dtmf">>, DTMF, Call).

-spec get_hangup_dtmf(kapps_call:call()) -> kz_term:api_binary().
get_hangup_dtmf(Call) -> kapps_call:kvs_fetch(<<"hangup_dtmf">>, Call).

-spec set_digit_pressed(kz_term:api_binary(), kapps_call:call()) -> kapps_call:call().
set_digit_pressed(DTMF, Call) -> kapps_call:kvs_store(<<"digit_pressed">>, DTMF, Call).

-spec get_digit_pressed(kapps_call:call()) -> kz_term:api_binary() | kz_json:object().
get_digit_pressed(Call) ->
    case kapps_call:kvs_fetch(<<"digit_pressed">>, Call) of
        'undefined' -> get_digits_pressed(Call);
        D -> D
    end.

-spec get_digits_pressed(kapps_call:call()) -> kz_term:api_object().
get_digits_pressed(Call) ->
    kapps_call:kvs_fetch(<<"dtmf_collections">>, Call).

-spec set_record_call(boolean(), kapps_call:call()) -> kapps_call:call().
set_record_call(R, Call) -> kapps_call:kvs_store(<<"record_call">>, R, Call).

-spec get_record_call(kapps_call:call()) -> kz_term:api_boolean().
get_record_call(Call) -> kapps_call:kvs_fetch(<<"record_call">>, Call).

-spec set_recording_stereo(kz_term:api_binary(), kapps_call:call()) -> kapps_call:call().
set_recording_stereo(<<"record-from-bridge-dual">>, Call) -> kapps_call:kvs_store(<<"recording_stereo">>, 'true', Call);
set_recording_stereo(<<"record-from-ringing-dual">>, Call) -> kapps_call:kvs_store(<<"recording_stereo">>, 'true', Call);
set_recording_stereo(_Condition, Call) -> Call.

-spec get_recording_stereo(kapps_call:call()) -> kz_term:api_boolean().
get_recording_stereo(Call) -> kapps_call:kvs_fetch(<<"recording_stereo">>, Call).

-spec set_call_timeout(timeout() | 'undefined', kapps_call:call()) -> kapps_call:call().
set_call_timeout(T, Call) -> kapps_call:kvs_store(<<"call_timeout">>, T, Call).

-spec get_call_timeout(kapps_call:call()) -> timeout() | 'undefined'.
get_call_timeout(Call) -> kapps_call:kvs_fetch(<<"call_timeout">>, Call).

-spec set_call_time_limit(timeout() | 'undefined', kapps_call:call()) -> kapps_call:call().
set_call_time_limit(T, Call) -> kapps_call:kvs_store(<<"call_time_limit">>, T, Call).

-spec get_call_time_limit(kapps_call:call()) -> timeout() | 'undefined'.
get_call_time_limit(Call) -> kapps_call:kvs_fetch(<<"call_time_limit">>, Call).

-spec set_voice_uri(kz_term:api_binary(), kapps_call:call()) -> kapps_call:call().
set_voice_uri(Uri, Call) -> kapps_call:kvs_store(<<"voice_uri">>, Uri, Call).

-spec get_voice_uri(kapps_call:call()) -> kz_term:api_binary().
get_voice_uri(Call) -> kapps_call:kvs_fetch(<<"voice_uri">>, Call).

-spec set_voice_uri_method('get' | 'post', kapps_call:call()) -> kapps_call:call().
set_voice_uri_method(M, Call) -> kapps_call:kvs_store(<<"voice_uri_method">>, M, Call).

-spec get_voice_uri_method(kapps_call:call()) -> 'get' | 'post'.
get_voice_uri_method(Call) -> kapps_call:kvs_fetch(<<"voice_uri_method">>, Call).

-spec set_digits_collected(kz_term:api_binary(), kapps_call:call()) -> kapps_call:call().
set_digits_collected(Ds, Call) -> kapps_call:kvs_store(<<"digits_collected">>, Ds, Call).

-spec get_digits_collected(kapps_call:call()) -> binary().
get_digits_collected(Call) -> kapps_call:kvs_fetch(<<"digits_collected">>, Call).

-spec clear_digits_collected(kapps_call:call()) -> kapps_call:call().
clear_digits_collected(Call) -> kapps_call:kvs_store(<<"digits_collected">>, <<>>, Call).

-spec add_digit_collected(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
add_digit_collected(D, Call) ->
    kapps_call:kvs_update(<<"digits_collected">>, fun(<<_/binary>> = Ds) -> <<Ds/binary, D/binary>>;
                                                     (_) -> D
                                                  end
                         ,D, Call).

-spec set_recording_url(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_recording_url(RU, Call) -> kapps_call:kvs_store(<<"recording_url">>, RU, Call).

-spec get_recording_url(kapps_call:call()) -> kz_term:api_binary().
get_recording_url(Call) -> kapps_call:kvs_fetch(<<"recording_url">>, Call).

-spec set_recording_duration(pos_integer(), kapps_call:call()) -> kapps_call:call().
set_recording_duration(RD, Call) -> kapps_call:kvs_store(<<"recording_duration">>, RD, Call).

-spec get_recording_duration(kapps_call:call()) -> kz_term:api_integer().
get_recording_duration(Call) -> kapps_call:kvs_fetch(<<"recording_duration">>, Call).

-spec set_recording_sid(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_recording_sid(SID, Call) -> kapps_call:kvs_store(<<"recording_sid">>, SID, Call).

-spec get_recording_sid(kapps_call:call()) -> kz_term:api_binary().
get_recording_sid(Call) -> kapps_call:kvs_fetch(<<"recording_sid">>, Call).

-spec set_transcription_sid(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_transcription_sid(SID, Call) -> kapps_call:kvs_store(<<"transcription_sid">>, SID, Call).

-spec get_transcription_sid(kapps_call:call()) -> kz_term:api_binary().
get_transcription_sid(Call) -> kapps_call:kvs_fetch(<<"transcription_sid">>, Call).

-spec set_transcription_text(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_transcription_text(RD, Call) -> kapps_call:kvs_store(<<"transcription_text">>, RD, Call).

-spec get_transcription_text(kapps_call:call()) -> kz_term:api_binary().
get_transcription_text(Call) -> kapps_call:kvs_fetch(<<"transcription_text">>, Call).

-spec set_transcription_status(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_transcription_status(RD, Call) -> kapps_call:kvs_store(<<"transcription_status">>, RD, Call).

-spec get_transcription_status(kapps_call:call()) -> kz_term:api_binary().
get_transcription_status(Call) -> kapps_call:kvs_fetch(<<"transcription_status">>, Call).

-spec set_transcription_url(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_transcription_url(RD, Call) -> kapps_call:kvs_store(<<"transcription_url">>, RD, Call).

-spec get_transcription_url(kapps_call:call()) -> kz_term:api_binary().
get_transcription_url(Call) -> kapps_call:kvs_fetch(<<"transcription_url">>, Call).

-spec set_dial_call_status(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_dial_call_status(DCS, Call) -> kapps_call:kvs_store(<<"dial_call_status">>, DCS, Call).

-spec get_dial_call_status(kapps_call:call()) -> kz_term:api_binary().
get_dial_call_status(Call) -> kapps_call:kvs_fetch(<<"dial_call_status">>, Call).

-spec set_dial_call_sid(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_dial_call_sid(DCS, Call) -> kapps_call:kvs_store(<<"dial_call_sid">>, DCS, Call).

-spec get_dial_call_sid(kapps_call:call()) -> kz_term:api_binary().
get_dial_call_sid(Call) -> kapps_call:kvs_fetch(<<"dial_call_sid">>, Call).

-spec set_dial_call_duration(pos_integer(), kapps_call:call()) -> kapps_call:call().
set_dial_call_duration(DCS, Call) -> kapps_call:kvs_store(<<"dial_call_duration">>, DCS, Call).

-spec get_dial_call_duration(kapps_call:call()) -> kz_term:api_integer().
get_dial_call_duration(Call) -> kapps_call:kvs_fetch(<<"dial_call_duration">>, Call).

-spec set_queue_sid(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_queue_sid(DCS, Call) -> kapps_call:kvs_store(<<"queue_sid">>, DCS, Call).

-spec get_queue_sid(kapps_call:call()) -> kz_term:api_binary().
get_queue_sid(Call) -> kapps_call:kvs_fetch(<<"queue_sid">>, Call).

-spec set_dequeue_result(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_dequeue_result(DCS, Call) -> kapps_call:kvs_store(<<"dequeue_result">>, DCS, Call).

-spec get_dequeue_result(kapps_call:call()) -> kz_term:api_binary().
get_dequeue_result(Call) -> kapps_call:kvs_fetch(<<"dequeue_result">>, Call).

-spec set_dequeued_call_sid(kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
set_dequeued_call_sid(DCS, Call) -> kapps_call:kvs_store(<<"dequeued_call_sid">>, DCS, Call).

-spec get_dequeued_call_sid(kapps_call:call()) -> kz_term:api_binary().
get_dequeued_call_sid(Call) -> kapps_call:kvs_fetch(<<"dequeued_call_sid">>, Call).

-spec set_dequeued_call_queue_time(pos_integer(), kapps_call:call()) -> kapps_call:call().
set_dequeued_call_queue_time(DCS, Call) -> kapps_call:kvs_store(<<"dequeued_call_queue_time">>, DCS, Call).

-spec get_dequeued_call_queue_time(kapps_call:call()) -> kz_term:api_integer().
get_dequeued_call_queue_time(Call) -> kapps_call:kvs_fetch(<<"dequeued_call_queue_time">>, Call).

-spec set_dequeued_call_duration(pos_integer(), kapps_call:call()) -> kapps_call:call().
set_dequeued_call_duration(DCS, Call) -> kapps_call:kvs_store(<<"dequeued_call_duration">>, DCS, Call).

-spec get_dequeued_call_duration(kapps_call:call()) -> kz_term:api_integer().
get_dequeued_call_duration(Call) -> kapps_call:kvs_fetch(<<"dequeued_call_duration">>, Call).

-spec set_media_meta(kz_json:object(), kapps_call:call()) -> kapps_call:call().
set_media_meta(DCS, Call) -> kapps_call:kvs_store(<<"media_meta">>, DCS, Call).

-spec get_media_meta(kapps_call:call()) -> kz_term:api_object().
get_media_meta(Call) -> kapps_call:kvs_fetch(<<"media_meta">>, Call).

-spec set_amqp_listener(pid(), kapps_call:call()) -> kapps_call:call().
set_amqp_listener(Pid, Call) -> kapps_call:kvs_store(<<"amqp_listener">>, Pid, Call).

-spec get_amqp_listener(kapps_call:call()) -> kz_term:api_pid().
get_amqp_listener(Call) -> kapps_call:kvs_fetch(<<"amqp_listener">>, Call).

-spec set_gather_pidref(kz_term:pid_ref() | 'undefined', kapps_call:call()) ->
          kapps_call:call().
set_gather_pidref('undefined', Call) ->
    kapps_call:kvs_store(<<"gather_pidref">>, 'undefined', Call);
set_gather_pidref({_, _}=PidRef, Call) ->
    gen_listener:cast(get_amqp_listener(Call), {'add_event_handler', PidRef}),
    kapps_call:kvs_store(<<"gather_pidref">>, PidRef, Call).

-spec get_gather_pidref(kapps_call:call()) ->
          kz_term:pid_ref() | 'undefined'.
get_gather_pidref(Call) -> kapps_call:kvs_fetch(<<"gather_pidref">>, Call).

-spec set_conference_profile(kz_json:object(), kapps_call:call()) ->
          kapps_call:call().
set_conference_profile(JObj, Call) ->
    kapps_call:kvs_store(<<"conference_profile">>, JObj, Call).

-spec get_conference_profile(kapps_call:call()) ->
          kz_json:object().
get_conference_profile(Call) ->
    kapps_call:kvs_fetch(<<"conference_profile">>, Call).

-spec set_caller_controls(kz_json:object(), kapps_call:call()) ->
          kapps_call:call().
set_caller_controls(JObj, Call) ->
    kapps_call:kvs_store(<<"caller_controls">>, JObj, Call).

-spec get_caller_controls(kapps_call:call()) ->
          kz_json:object().
get_caller_controls(Call) ->
    kapps_call:kvs_fetch(<<"caller_controls">>, Call).

-spec set_advertise(kz_json:object(), kapps_call:call()) ->
          kapps_call:call().
set_advertise(JObj, Call) ->
    kapps_call:kvs_store(<<"advertise">>, JObj, Call).

-spec get_advertise(kapps_call:call()) ->
          kz_json:object().
get_advertise(Call) ->
    kapps_call:kvs_fetch(<<"advertise">>, Call).

-spec set_chat_permissions(kz_json:object(), kapps_call:call()) ->
          kapps_call:call().
set_chat_permissions(JObj, Call) ->
    kapps_call:kvs_store(<<"chat_permissions">>, JObj, Call).

-spec get_chat_permissions(kapps_call:call()) -> kz_json:object().
get_chat_permissions(Call) ->
    kapps_call:kvs_fetch(<<"chat_permissions">>, Call).

-spec add_stream(kz_term:ne_binary(), kz_term:ne_binary(), kapps_call:call()) -> kapps_call:call().
add_stream(StreamId, StreamName, Call) ->
    case get_streams(Call) of
        [] ->
            kapps_call:kvs_store(<<"streams">>, [{StreamId, StreamName}], Call);
        Vs ->
            kapps_call:kvs_append_list(<<"streams">>, [{StreamId, StreamName}|Vs], Call)
    end.

-spec get_streams(kapps_call:call()) -> kz_term:proplist().
get_streams(Call) ->
    kapps_call:kvs_fetch(<<"streams">>, [], Call).

-spec get_request_vars(kapps_call:call()) -> kz_json:object().
get_request_vars(Call) ->
    kz_json:from_list(
      [{<<"Digits">>, get_digits_collected(Call)}
      ,{<<"RecordingUrl">>, get_recording_url(Call)}
      ,{<<"RecordingDuration">>, get_recording_duration(Call)}
      ,{<<"DialCallStatus">>, get_dial_call_status(Call)}
      ,{<<"DialCallSid">>, get_dial_call_sid(Call)}
      ,{<<"DialCallDuration">>, get_dial_call_duration(Call)}
      ,{<<"QueueSid">>, get_queue_sid(Call)}
      ,{<<"CallStatus">>, get_call_status(Call, ?STATUS_IN_PROGRESS)}
      ]).

-spec iteration(kapps_call:call()) -> pos_integer().
iteration(Call) ->
    kapps_call:kvs_fetch('pivot_counter', 1, Call).

-spec increment_iteration(kapps_call:call()) -> kapps_call:call().
increment_iteration(Call) ->
    kapps_call:kvs_update_counter('pivot_counter', 1, Call).

-spec set_serverless(boolean(), kapps_call:call()) ->
          kapps_call:call().
set_serverless(IsServerless, Call) ->
    kapps_call:kvs_store(<<"serverless">>, IsServerless, Call).

-spec get_serverless(kapps_call:call()) -> boolean().
get_serverless(Call) ->
    kz_term:is_true(kapps_call:kvs_fetch(<<"serverless">>, Call)).
