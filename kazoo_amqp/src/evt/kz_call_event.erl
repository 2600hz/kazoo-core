%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2015-2023, 2600Hz
%%% @doc Call Event JSON Object
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_call_event).

-export([account_id/1, account_id/2
        ,application_data/1
        ,application_error_code/1, application_error_code/2
        ,application_error_message/1, application_error_message/2
        ,application_event/1
        ,application_name/1
        ,application_response/1, application_response/2
        ,application_uuid/1
        ,authorizing_id/1
        ,authorizing_type/1
        ,billing_seconds/1
        ,call_direction/1, call_direction/2
        ,call_id/1
        ,channel_answer_state/1
        ,channel_call_state/1
        ,channel_name/1
        ,channel_state/1
        ,connecting_b_leg_id/1
        ,custom_channel_var/2, custom_channel_var/3
        ,custom_channel_vars/1, custom_channel_vars/2
        ,custom_application_var/2, custom_application_var/3
        ,custom_application_vars/1, custom_application_vars/2
        ,custom_sip_headers/1
        ,disposition/1
        ,dtmf_digit/1, dtmf_digit/2
        ,duration_seconds/1
        ,endpoint_disposition/1
        ,error_message/1, error_message/2
        ,event_name/1
        ,hangup_cause/1, hangup_cause/2
        ,hangup_code/1, hangup_code/2
        ,is_authorized/1
        ,is_call_forwarded/1, is_call_forwarded/2
        ,other_leg_call_id/1
        ,other_leg_destination_number/1, other_leg_destination_number/2
        ,owner_id/1
        ,replaced_by/1
        ,request/1
        ,response_code/1
        ,response_message/1
        ,ringing_seconds/1
        ,switch_nodename/1
        ,timestamp/1
        ,caller_id/1, caller_id_number/1, caller_id_name/1
        ,callee_id/1, callee_id_number/1, callee_id_name/1
        ,recording_length/1
        ,fetch_id/1
        ]).

-export([transfer_disposition/1
        ,transfer_leg/1
        ,transfer_destination/1
        ,transfer_is_semi_attended/1, transfer_is_semi_attended/2
        ]).

-export([bridge_hangup_cause/1, bridge_hangup_cause/2]).

-type payload() :: kz_json:object().
-export_type([payload/0]).

-spec call_direction(payload()) -> kz_term:api_ne_binary().
call_direction(JObj) ->
    call_direction(JObj, 'undefined').

-spec call_direction(payload(), Default) -> kz_term:ne_binary() | Default.
call_direction(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Call-Direction">>, JObj, Default).

-spec call_id(payload()) -> kz_term:api_ne_binary().
call_id(JObj) ->
    kz_json:get_ne_binary_value(<<"Call-ID">>, JObj).

-spec other_leg_call_id(payload()) -> kz_term:api_ne_binary().
other_leg_call_id(JObj) ->
    kz_json:get_ne_binary_value(<<"Other-Leg-Call-ID">>, JObj).

-spec other_leg_destination_number(payload()) -> kz_term:api_ne_binary().
other_leg_destination_number(JObj) ->
    other_leg_destination_number(JObj, 'undefined').

-spec other_leg_destination_number(payload(), Default) -> kz_term:ne_binary() | Default.
other_leg_destination_number(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Other-Leg-Destination-Number">>, JObj, Default).

-spec replaced_by(payload()) -> kz_term:api_ne_binary().
replaced_by(JObj) ->
    kz_json:get_ne_binary_value(<<"Replaced-By">>, JObj).

-spec request(payload()) -> kz_json:object().
request(JObj) ->
    kz_json:get_json_value(<<"Request">>, JObj).

-spec channel_name(payload()) -> kz_term:api_ne_binary().
channel_name(JObj) ->
    kz_json:get_ne_binary_value(<<"Channel-Name">>, JObj).

-spec channel_state(payload()) -> kz_term:api_ne_binary().
channel_state(JObj) ->
    kz_json:get_ne_binary_value(<<"Channel-State">>, JObj).

-spec channel_call_state(payload()) -> kz_term:api_ne_binary().
channel_call_state(JObj) ->
    kz_json:get_ne_binary_value(<<"Channel-Call-State">>, JObj).

-spec channel_answer_state(payload()) -> kz_term:api_ne_binary().
channel_answer_state(JObj) ->
    kz_json:get_ne_binary_value(<<"Channel-Answer-State">>, JObj).

-spec connecting_b_leg_id(payload()) -> kz_term:api_ne_binary().
connecting_b_leg_id(JObj) ->
    kz_json:get_ne_binary_value(<<"Connecting-Leg-B-UUID">>, JObj).

-spec custom_channel_vars(payload()) -> kz_term:api_object().
custom_channel_vars(JObj) ->
    custom_channel_vars(JObj, 'undefined').

-spec custom_channel_vars(payload(), Default) -> kz_json:object() | Default.
custom_channel_vars(JObj, Default) ->
    kz_json:get_json_value(<<"Custom-Channel-Vars">>, JObj, Default).

-spec custom_channel_var(payload(), kz_json:key()) ->
          kz_term:api_ne_binary().
custom_channel_var(JObj, Key) ->
    custom_channel_var(JObj, Key, 'undefined').

-spec custom_channel_var(payload(), kz_json:key(), Default) ->
          kz_term:ne_binary() | Default.
custom_channel_var(JObj, Key, Default) ->
    kz_json:get_ne_binary_value([<<"Custom-Channel-Vars">>, Key], JObj, Default).

-spec custom_application_vars(payload()) -> kz_term:api_object().
custom_application_vars(JObj) ->
    custom_application_vars(JObj, 'undefined').

-spec custom_application_vars(payload(), Default) -> kz_json:object() | Default.
custom_application_vars(JObj, Default) ->
    kz_json:get_json_value(<<"Custom-Application-Vars">>, JObj, Default).

-spec custom_application_var(payload(), kz_json:key()) ->
          kz_term:api_ne_binary().
custom_application_var(JObj, Key) ->
    custom_application_var(JObj, Key, 'undefined').

-spec custom_application_var(payload(), kz_json:key(), Default) ->
          kz_term:ne_binary() | Default.
custom_application_var(JObj, Key, Default) ->
    kz_json:get_ne_binary_value([<<"Custom-Application-Vars">>, Key], JObj, Default).

-spec custom_sip_headers(payload()) -> kz_term:api_object().
custom_sip_headers(JObj) ->
    kz_json:get_json_value(<<"Custom-SIP-Headers">>, JObj).

-spec authorizing_id(payload()) -> kz_term:api_binary().
authorizing_id(JObj) ->
    custom_channel_var(JObj, <<"Authorizing-ID">>).

-spec authorizing_type(payload()) -> kz_term:api_binary().
authorizing_type(JObj) ->
    custom_channel_var(JObj, <<"Authorizing-Type">>).

-spec is_authorized(payload()) -> boolean().
is_authorized(JObj) ->
    kz_term:is_true(
      custom_channel_var(JObj, <<"Channel-Authorized">>)
     ).

-spec dtmf_digit(payload()) -> kz_term:api_ne_binary().
dtmf_digit(JObj) ->
    dtmf_digit(JObj, 'undefined').

-spec dtmf_digit(payload(), Default) -> kz_term:ne_binary() | Default.
dtmf_digit(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"DTMF-Digit">>, JObj, Default).

-spec event_name(payload()) -> kz_term:api_ne_binary().
event_name(JObj) ->
    kz_json:get_ne_binary_value(<<"Event-Name">>, JObj).

-spec hangup_cause(payload()) -> kz_term:api_ne_binary().
hangup_cause(JObj) ->
    hangup_cause(JObj, 'undefined').

-spec hangup_cause(payload(), Default) -> kz_term:ne_binary() | Default.
hangup_cause(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Hangup-Cause">>, JObj, Default).

-spec hangup_code(payload()) -> kz_term:api_ne_binary().
hangup_code(JObj) ->
    hangup_code(JObj, 'undefined').

-spec hangup_code(payload(), Default) -> kz_term:ne_binary() | Default.
hangup_code(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Hangup-Code">>, JObj, Default).

-spec disposition(payload()) -> kz_term:api_ne_binary().
disposition(JObj) ->
    kz_json:get_ne_binary_value(<<"Disposition">>, JObj).

-spec application_name(payload()) -> kz_term:api_ne_binary().
application_name(JObj) ->
    kz_json:get_ne_binary_value(<<"Application-Name">>, JObj).

-spec application_event(payload()) -> kz_term:api_ne_binary().
application_event(JObj) ->
    kz_json:get_ne_binary_value(<<"Application-Event">>, JObj).

-spec application_data(payload()) -> kz_json:object().
application_data(JObj) ->
    kz_json:get_json_value(<<"Application-Data">>, JObj, kz_json:new()).

-spec application_uuid(payload()) -> kz_term:api_binary().
application_uuid(JObj) ->
    kz_json:get_ne_binary_value(<<"Application-UUID">>, JObj).

-spec application_response(payload()) -> kz_term:api_ne_binary().
application_response(JObj) ->
    application_response(JObj, 'undefined').

-spec application_response(payload(), Default) -> kz_term:ne_binary() | Default.
application_response(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Application-Response">>, JObj, Default).

-spec application_error_code(payload()) -> kz_term:api_ne_binary().
application_error_code(JObj) ->
    application_error_code(JObj, undefined).

-spec application_error_code(payload(), Default) -> kz_term:ne_binary() | Default.
application_error_code(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Application-Error-Code">>, JObj, Default).

-spec application_error_message(payload()) -> kz_term:api_ne_binary().
application_error_message(JObj) ->
    application_error_message(JObj, undefined).

-spec application_error_message(payload(), Default) -> kz_term:ne_binary() | Default.
application_error_message(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Application-Error-Msg">>, JObj, Default).

-spec response_message(payload()) -> kz_term:api_ne_binary().
response_message(JObj) ->
    kz_json:get_ne_binary_value(<<"Response-Message">>, JObj).

-spec response_code(payload()) -> kz_term:api_ne_binary().
response_code(JObj) ->
    kz_json:get_ne_binary_value(<<"Response-Code">>, JObj).

-spec account_id(payload()) -> kz_term:api_ne_binary().
account_id(JObj) ->
    account_id(JObj, 'undefined').

-spec account_id(payload(), Default) -> kz_term:ne_binary() | Default.
account_id(JObj, Default) ->
    custom_channel_var(JObj, <<"Account-ID">>, Default).

-spec owner_id(payload()) -> kz_term:api_ne_binary().
owner_id(JObj) ->
    custom_channel_var(JObj, <<"Owner-ID">>).

-spec timestamp(payload()) -> kz_term:api_integer().
timestamp(JObj) ->
    kz_json:get_integer_value(<<"Timestamp">>, JObj).

-spec ringing_seconds(payload()) -> kz_term:api_integer().
ringing_seconds(JObj) ->
    kz_json:get_integer_value(<<"Ringing-Seconds">>, JObj).

-spec billing_seconds(payload()) -> kz_term:api_integer().
billing_seconds(JObj) ->
    kz_json:get_integer_value(<<"Billing-Seconds">>, JObj).

-spec duration_seconds(payload()) -> kz_term:api_integer().
duration_seconds(JObj) ->
    kz_json:get_integer_value(<<"Duration-Seconds">>, JObj).

-spec is_call_forwarded(payload()) -> kz_term:api_boolean().
is_call_forwarded(JObj) ->
    is_call_forwarded(JObj, 'undefined').

-spec is_call_forwarded(payload(), Default) -> boolean() | Default.
is_call_forwarded(JObj, Default) ->
    case custom_channel_var(JObj, <<"Call-Forward">>, Default) of
        'undefined' -> Default;
        Default -> Default;
        IsForwarded -> kz_term:is_true(IsForwarded)
    end.

-spec error_message(payload()) -> kz_term:api_ne_binary().
error_message(JObj) ->
    error_message(JObj, 'undefined').

-spec error_message(payload(), Default) -> kz_term:ne_binary() | Default.
error_message(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Error-Message">>, JObj, Default).

-spec switch_nodename(payload()) -> kz_term:api_ne_binary().
switch_nodename(JObj) ->
    kz_json:get_ne_binary_value(<<"Switch-Nodename">>, JObj).

-spec caller_id_name(payload()) -> kz_term:api_ne_binary().
caller_id_name(JObj) ->
    kz_json:get_ne_binary_value(<<"Caller-ID-Name">>, JObj).

-spec caller_id_number(payload()) -> kz_term:api_ne_binary().
caller_id_number(JObj) ->
    kz_json:get_ne_binary_value(<<"Caller-ID-Number">>, JObj).

-spec callee_id_name(payload()) -> kz_term:api_ne_binary().
callee_id_name(JObj) ->
    kz_json:get_ne_binary_value(<<"Callee-ID-Name">>, JObj).

-spec callee_id_number(payload()) -> kz_term:api_ne_binary().
callee_id_number(JObj) ->
    kz_json:get_ne_binary_value(<<"Callee-ID-Number">>, JObj).

-spec caller_id(payload()) -> {kz_term:api_ne_binary(), kz_term:api_ne_binary()}.
caller_id(JObj) ->
    {caller_id_number(JObj), caller_id_name(JObj)}.

-spec callee_id(payload()) -> {kz_term:api_ne_binary(), kz_term:api_ne_binary()}.
callee_id(JObj) ->
    {callee_id_number(JObj), callee_id_name(JObj)}.

-spec recording_length(payload()) -> kz_term:api_integer().
recording_length(JObj) ->
    kz_json:get_integer_value(<<"Length">>, JObj).

-spec fetch_id(payload()) -> kz_term:api_ne_binary().
fetch_id(JObj) ->
    kz_json:get_ne_binary_value(<<"Fetch-ID">>, JObj, custom_channel_var(JObj, <<"Fetch-ID">>)).

-spec endpoint_disposition(payload()) -> kz_term:api_ne_binary().
endpoint_disposition(JObj) ->
    kz_json:get_ne_binary_value(<<"Endpoint-Disposition">>, JObj).

-spec transfer_disposition(payload()) -> kz_term:api_ne_binary().
transfer_disposition(JObj) ->
    kz_json:get_ne_binary_value(<<"Transfer-Disposition">>, JObj).

-spec transfer_leg(payload()) -> kz_term:api_ne_binary().
transfer_leg(JObj) ->
    kz_json:get_ne_binary_value(<<"Transfer-Leg">>, JObj).

-spec transfer_destination(payload()) -> kz_term:api_ne_binary().
transfer_destination(JObj) ->
    kz_json:get_ne_binary_value(<<"Transfer-Destination">>, JObj).

-spec transfer_is_semi_attended(payload()) -> kz_term:api_boolean().
transfer_is_semi_attended(JObj) ->
    transfer_is_semi_attended(JObj, undefined).

-spec transfer_is_semi_attended(payload(), Default) -> kz_term:boolean() | Default.
transfer_is_semi_attended(_JObj, _Default) ->
    'false'.

-spec bridge_hangup_cause(payload()) -> kz_term:api_ne_binary().
bridge_hangup_cause(JObj) ->
    bridge_hangup_cause(JObj, 'undefined').

-spec bridge_hangup_cause(payload(), Default) -> kz_term:ne_binary() | Default.
bridge_hangup_cause(JObj, Default) ->
    kz_json:get_ne_binary_value(<<"Bridge-Hangup-Cause">>, JObj, Default).
