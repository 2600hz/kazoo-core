%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoint_recording).

-export([maybe_record_inbound/3
        ,maybe_record_outbound/3
        ]).

-define(ENDPOINT_INBOUND_RECORDING(Network), [<<"call_recording">>, <<"endpoint">>, <<"inbound">>, Network]).
-define(ENDPOINT_OUTBOUND_RECORDING(Network), [<<"call_recording">>, <<"endpoint">>, <<"outbound">>, Network]).
-define(ENDPOINT_INBOUND_RECORDING_LABEL(Network), <<"inbound from ", Network/binary, " to endpoint">>).
-define(ENDPOINT_OUTBOUND_RECORDING_LABEL(Network), <<"outbound to ", Network/binary, " from endpoint">>).

-type network() :: kapps_call:inception_type().

%% @doc should recording be started on call TO the endpoint
-spec maybe_record_inbound(network(), kz_endpoint:endpoint(), kapps_call:call()) ->
          {'true', {kz_json:path(), kz_json:object()}} | 'false'.
maybe_record_inbound(FromNetwork, Endpoint, Call) ->
    RecordingSettings = inbound_recording_settings(FromNetwork, Endpoint),
    maybe_record_inbound(FromNetwork, Endpoint, Call, RecordingSettings).

-spec maybe_record_inbound(network(), kz_endpoint:endpoint(), kapps_call:call(), kz_term:api_object()) ->
          {'true', {kz_json:path(), kz_json:object()}} | 'false'.
maybe_record_inbound(_FromNetwork, _Endpoint, _Call, 'undefined') -> 'false';
maybe_record_inbound(_FromNetwork, Endpoint, Call, Data) ->
    case kz_account_recording:should_record_call(Call, Data) of
        'false' -> 'false';
        'true' ->
            EndpointId = kzd_endpoint:id(Endpoint),
            lager:info("setting endpoint ~s to record on answer", [EndpointId]),
            Call1 = kapps_call:kvs_store('recording_follow_transfer', 'false', Call),
            App = kapps_call_recording:record_call_command(Data, Call1),
            {'true', {[<<"Execute-On-Answer">>, <<"Record-Endpoint">>], App}}
    end.

-spec inbound_recording_settings(network(), kz_endpoint:endpoint()) -> kz_term:api_object().
inbound_recording_settings(FromNetwork, Endpoint) ->
    case kz_json:get_json_value(?ENDPOINT_INBOUND_RECORDING(FromNetwork), Endpoint) of
        'undefined' -> 'undefined';
        RecordingSettings ->
            EndpointId = kzd_endpoint:id(Endpoint),
            Values = [{<<"origin">>, ?ENDPOINT_INBOUND_RECORDING_LABEL(FromNetwork)}
                     ,{<<"endpoint_id">>, EndpointId}
                     ],
            kz_json:set_values(Values, RecordingSettings)
    end.

%% @doc maybe start recording on call made FROM the endpoint
-spec maybe_record_outbound(network(), kz_endpoint:endpoint(), kapps_call:call()) ->
          kapps_call:call().
maybe_record_outbound(ToNetwork, Endpoint, Call) ->
    RecordingSettings = outbound_recording_settings(ToNetwork, Endpoint),
    maybe_record_outbound(ToNetwork, Endpoint, Call, RecordingSettings).

-spec maybe_record_outbound(network(), kz_endpoint:endpoint(), kapps_call:call(), kz_term:api_object()) ->
          kapps_call:call().
maybe_record_outbound(_ToNetwork, _Endpoint, Call, 'undefined') -> Call;
maybe_record_outbound(ToNetwork, Endpoint, Call, Data) ->
    case kz_account_recording:should_record_call(Call, Data) of
        'false' -> Call;
        'true' ->
            EndpointId = kzd_endpoint:id(Endpoint),
            lager:debug("starting endpoint ~s recording (~s outbound)", [EndpointId, ToNetwork]),
            kapps_call:start_recording(
              Data
             ,kapps_call:kvs_store('recording_follow_transfer', 'false', Call)
             )
    end.

-spec outbound_recording_settings(network(), kz_endpoint:endpoint()) -> kz_term:api_object().
outbound_recording_settings(ToNetwork, Endpoint) ->
    case kz_json:get_json_value(?ENDPOINT_OUTBOUND_RECORDING(ToNetwork), Endpoint) of
        'undefined' -> 'undefined';
        RecordingSettings ->
            kz_json:set_value(<<"origin">>
                             ,?ENDPOINT_OUTBOUND_RECORDING_LABEL(ToNetwork)
                             ,RecordingSettings
                             )
    end.
