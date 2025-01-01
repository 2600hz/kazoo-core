%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_account_recording).

-export([maybe_record_inbound/3
        ,maybe_record_outbound/3
        ,should_record_call/2
        ]).

-define(ACCOUNT_INBOUND_RECORDING(Network), [<<"call_recording">>, <<"account">>, <<"inbound">>, Network]).
-define(ACCOUNT_OUTBOUND_RECORDING(Network), [<<"call_recording">>, <<"account">>, <<"outbound">>, Network]).
-define(ACCOUNT_INBOUND_RECORDING_LABEL(Network), <<"inbound from ", Network/binary, " to account">>).
-define(ACCOUNT_OUTBOUND_RECORDING_LABEL(Network), <<"outbound to ", Network/binary, " from account">>).

-type network() :: kapps_call:inception_type().

%% @doc should recording be started on call TO the endpoint
-spec maybe_record_inbound(network(), kz_endpoint:endpoint(), kapps_call:call()) ->
          kapps_call:call().
maybe_record_inbound(FromNetwork, Endpoint, Call) ->
    case kapps_call:is_call_forward(Call) of
        'true' -> Call;
        'false' ->
            InboundSettings = inbound_recording_settings(FromNetwork, Endpoint),
            maybe_record_inbound(FromNetwork, Endpoint, Call, InboundSettings)
    end.

-spec maybe_record_inbound(network(), kz_endpoint:endpoint(), kapps_call:call(), kz_term:api_object()) ->
          kapps_call:call().
maybe_record_inbound(_FromNetwork, _Endpoint, Call, 'undefined') -> Call;
maybe_record_inbound(FromNetwork, Endpoint, Call, Data) ->
    case should_record_call(Call, Data) of
        'false' -> Call;
        'true' ->
            EndpointId = kzd_endpoint:id(Endpoint),
            lager:debug("starting account ~s recording (~s inbound)", [EndpointId, FromNetwork]),
            kapps_call:start_recording(
              Data
             ,kapps_call:kvs_store('recording_follow_transfer', 'true', Call)
             )
    end.

-spec inbound_recording_settings(network(), kz_endpoint:endpoint()) -> kz_term:api_object().
inbound_recording_settings(FromNetwork, Endpoint) ->
    case kz_json:get_json_value(?ACCOUNT_INBOUND_RECORDING(FromNetwork), Endpoint) of
        'undefined' -> 'undefined';
        RecordingSettings ->
            kz_json:set_value(<<"origin">>
                             ,?ACCOUNT_INBOUND_RECORDING_LABEL(FromNetwork)
                             ,RecordingSettings
                             )
    end.

-spec should_record_call(kapps_call:call(), kz_json:object()) -> boolean().
should_record_call(Call, Data) ->
    should_record_call(Call, Data, kz_json:is_true(<<"enabled">>, Data)).

should_record_call(_Call, _Data, 'false') ->
    %% recording is disabled
    'false';
should_record_call(Call, Data, 'true') ->
    %% check if call is to a feature code *and* feature code recording is disabled
    not kapps_call:should_skip_feature_calls_recording(Call, Data).

%% @doc maybe start recording on call made FROM the endpoint
-spec maybe_record_outbound(network(), kz_endpoint:endpoint(), kapps_call:call()) ->
          kapps_call:call().
maybe_record_outbound(ToNetwork, Endpoint, Call) ->
    case kapps_call:is_call_forward(Call) of
        'true' -> Call;
        'false' ->
            OutboundSettings = outbound_recording_settings(ToNetwork, Endpoint),
            maybe_record_outbound(ToNetwork, Endpoint, Call, OutboundSettings)
    end.

-spec maybe_record_outbound(network(), kz_endpoint:endpoint(), kapps_call:call(), kz_term:api_object()) ->
          kapps_call:call().
maybe_record_outbound(_ToNetwork, _Endpoint, Call, 'undefined') -> Call;
maybe_record_outbound(ToNetwork, Endpoint, Call, Data) ->
    case should_record_call(Call, Data) of
        'false' -> Call;
        'true' ->
            EndpointId = kzd_endpoint:id(Endpoint),
            lager:debug("starting account ~s recording (~s outbound)", [EndpointId, ToNetwork]),
            kapps_call:start_recording(
              Data
             ,kapps_call:kvs_store('recording_follow_transfer', 'true', Call)
             )
    end.

-spec outbound_recording_settings(network(), kz_endpoint:endpoint()) -> kz_term:api_object().
outbound_recording_settings(ToNetwork, Endpoint) ->
    case kz_json:get_json_value(?ACCOUNT_OUTBOUND_RECORDING(ToNetwork), Endpoint) of
        'undefined' -> 'undefined';
        RecordingSettings ->
            kz_json:set_value(<<"origin">>
                             ,?ACCOUNT_OUTBOUND_RECORDING_LABEL(ToNetwork)
                             ,RecordingSettings
                             )
    end.
