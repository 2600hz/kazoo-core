%%% @copyright (C) 2014-2021, 2600Hz
%%% @doc BYE messages
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzsip_bye).

-export([parse_reason/1]).

%% @doc parse SIP BYE's Reason header
%% For instance, given a header of Reason: Q.850;cause=17;text="USER_BUSY"
%% see https://freeswitch.org/confluence/display/FREESWITCH/Hangup+Cause+Code+Table
-spec parse_reason(binary()) ->
          {'ok', integer(), binary()} |
          {'error', 'not_found'}.
parse_reason(<<"Q.850", ReasonValue/binary>>) ->
    q850(ReasonValue);
parse_reason(<<"SIP", ReasonValue/binary>>) ->
    sip(ReasonValue).

%% @doc https://datatracker.ietf.org/doc/html/rfc3261
sip(CausePlusText) ->
    case parse_cause_text(CausePlusText) of
        'nomatch' -> {'error', 'not_found'};
        {'match', [_, _]=Matches} ->
            AsProp = [list_to_tuple(T) || T <- Matches],
            {props:get_integer_value(<<"cause">>, AsProp)
            ,props:get_binary_value(<<"text">>, AsProp)
            }
    end.

%% interpret ITU-T Q.850 codes
%% see https://www.itu.int/rec/dologin_pub.asp?lang=e&id=T-REC-Q.850-201810-I!!PDF-E&type=items
q850(CausePlusText) ->
    case parse_cause_text(CausePlusText) of
        {'match', [_, _]=Matches} ->
            matches_to_return(Matches, fun q850_cause/1);
        'nomatch' ->
            {'error', 'not_found'}
    end.

%% Unspecified causes codes (no value in the "SIP Equiv." column in
%% the table) are translated to SIP "480 Temporarily Unavailable" by
%% FreeSwitch.
matches_to_return([], _CauseFun) -> {480, <<"TEMPORARY_UNAVAILABLE">>};
matches_to_return([[<<"cause">>, Cause] | _Matches], CauseFun) ->
    CauseFun(Cause);
matches_to_return([_ | Matches], CauseFun) ->
    matches_to_return(Matches, CauseFun).

%% Only list the Q850 -> SIP codes, all unknown Q.850 causes are 0
q850_cause(<<Cause/binary>>) ->
    q850_cause(kz_term:to_integer(Cause));
q850_cause(1) ->
    {404, <<"UNALLOCATED_NUMBER">>};
q850_cause(2) ->
    {404, <<"NO_ROUTE_TRANSIT_NET">>};
q850_cause(3) ->
    {404, <<"NO_ROUTE_DESTINATION">>};
q850_cause(17) ->
    {486, <<"USER_BUSY">>};
q850_cause(18) ->
    {408, <<"NO_USER_RESPONSE">>};
q850_cause(19) ->
    {480, <<"NO_ANSWER">>};
q850_cause(20) ->
    {480, <<"SUBSCRIBER_ABSENT">>};
q850_cause(21) ->
    {603, <<"CALL_REJECTED">>};
q850_cause(22) ->
    {410, <<"NUMBER_CHANGED">>};
q850_cause(23) ->
    {410, <<"REDIRECTION_TO_NEW_DESTINATION">>};
q850_cause(25) ->
    {483, <<"EXCHANGE_ROUTING_ERROR">>};
q850_cause(27) ->
    {502, <<"DESTINATION_OUT_OF_ORDER">>};
q850_cause(28) ->
    {484, <<"INVALID_NUMBER_FORMAT">>};
q850_cause(29) ->
    {501, <<"FACILITY_REJECTED">>};
q850_cause(31) ->
    {480, <<"NORMAL_UNSPECIFIED">>};
q850_cause(34) ->
    {503, <<"NORMAL_CIRCUIT_CONGESTION">>};
q850_cause(38) ->
    {502, <<"NETWORK_OUT_OF_ORDER">>};
q850_cause(41) ->
    {503, <<"NORMAL_TEMPORARY_FAILURE">>};
q850_cause(42) ->
    {503, <<"SWITCH_CONGESTION">>};
q850_cause(44) ->
    {503, <<"REQUESTED_CHAN_UNAVAIL">>};
q850_cause(52) ->
    {403, <<"OUTGOING_CALL_BARRED">>};
q850_cause(54) ->
    {403, <<"INCOMING_CALL_BARRED">>};
q850_cause(57) ->
    {403, <<"BEARERCAPABILITY_NOTAUTH">>};
q850_cause(58) ->
    {403, <<"BEARERCAPABILITY_NOTAVAIL">>};
q850_cause(65) ->
    {488, <<"BEARERCAPABILITY_NOTIMPL">>};
q850_cause(69) ->
    {501, <<"FACILITY_NOT_IMPLEMENTED">>};
q850_cause(79) ->
    {501, <<"SERVICE_NOT_IMPLEMENTED">>};
q850_cause(88) ->
    {488, <<"INCOMPATIBLE_DESTINATION">>};
q850_cause(102) ->
    {504, <<"RECOVERY_ON_TIMER_EXPIRE">>};
q850_cause(487) ->
    {487, <<"ORIGINATOR_CANCEL">>};
q850_cause(_Cause) ->
    {480, <<"TEMPORARY_UNAVAILABLE">>}.

parse_cause_text(CausePlusText) ->
    re:run(CausePlusText
          ,<<";([^=]+)=([^;]+)">>
          ,[{'capture', 'all_but_first', 'binary'}, 'global']
          ).
