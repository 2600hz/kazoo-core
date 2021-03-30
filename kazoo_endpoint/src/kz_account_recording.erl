%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
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
        ]).

-include("kazoo_endpoint.hrl").

-define(ACCOUNT_INBOUND_RECORDING(Network), [<<"call_recording">>, <<"account">>, <<"inbound">>, Network]).
-define(ACCOUNT_OUTBOUND_RECORDING(Network), [<<"call_recording">>, <<"account">>, <<"outbound">>, Network]).

-define(ACCOUNT_INBOUND_RECORDING_LABEL(Network), <<"inbound from ", Network/binary, " to account">>).
-define(ACCOUNT_OUTBOUND_RECORDING_LABEL(Network), <<"outbound to ", Network/binary, " from account">>).

%% @doc should recording be started on call TO the endpoint
-spec maybe_record_inbound(kz_term:ne_binary(), kz_json:object(), kapps_call:call()) ->
          {'true', kapps_call:call()} | 'false'.
maybe_record_inbound(FromNetwork, Endpoint, Call) ->
    maybe_record_inbound(FromNetwork, Endpoint, Call, kz_json:get_json_value(?ACCOUNT_INBOUND_RECORDING(FromNetwork), Endpoint)).

-spec maybe_record_inbound(kz_term:ne_binary(), kz_json:object(), kapps_call:call(), kz_term:api_object()) ->
          {'true', kapps_call:call()} | 'false'.
maybe_record_inbound(_FromNetwork, _Endpoint, _Call, 'undefined') -> 'false';
maybe_record_inbound(FromNetwork, _Endpoint, Call, Data) ->
    case kz_json:is_true(<<"enabled">>, Data) of
        'true' -> do_recording(<<"inbound">>, FromNetwork, Call, Data);
        _ -> 'false'
    end.

%% @doc maybe start recording on call made FROM the endpoint
-spec maybe_record_outbound(kz_term:ne_binary(), kz_json:object(), kapps_call:call()) ->
          {'true', kapps_call:call()} | 'false'.
maybe_record_outbound(ToNetwork, Endpoint, Call) ->
    maybe_record_outbound(ToNetwork, Endpoint, Call, kz_json:get_json_value(?ACCOUNT_OUTBOUND_RECORDING(ToNetwork), Endpoint)).

-spec maybe_record_outbound(kz_term:ne_binary(), kz_json:object(), kapps_call:call(), kz_term:api_object()) ->
          {'true', kapps_call:call()} | 'false'.
maybe_record_outbound(_ToNetwork, _Endpoint, _Call, 'undefined') -> 'false';
maybe_record_outbound(ToNetwork, _Endpoint, Call, Data) ->
    case kz_json:is_true(<<"enabled">>, Data) of
        'true' -> do_recording(<<"outbound">>, ToNetwork, Call, Data);
        _ -> 'false'
    end.

-spec do_recording(kz_term:ne_binary(), kz_term:ne_binary(), kapps_call:call(), kz_json:object()) ->
          {'true', kapps_call:call()} | 'false'.
do_recording(Direction, ToNetwork, Call, Data) ->
    case kapps_call:already_recording(Direction, Call) of
        'false' ->
            lager:debug("recording call for ~s : ~s", [Direction, ToNetwork]),
            LabeledData = kz_json:set_value(<<"origin">>, ?ACCOUNT_OUTBOUND_RECORDING_LABEL(ToNetwork), Data),
            C2 = kapps_call:set_recording(Direction, ToNetwork, Call),
            C3 = kapps_call:kvs_store('recording_follow_transfer', 'false', C2),
            {'true', kapps_call:start_recording(LabeledData, C3)};
        'true' ->
            lager:debug("not recording, call is already being recorded for ~s : ~s", [Direction, ToNetwork]),
            'false'
    end.
