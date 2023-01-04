%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_custom_channel_vars).

-export([inbound/1, inbound/2, set_inbound/2
        ,outbound/1, outbound/2, set_outbound/2
        ,inbound_variable/2, inbound_variable/3
        ,outbound_variable/2, outbound_variable/3
        ,routing/1, routing/2, set_routing/2
        ,routing_variable/2, routing_variable/3
        ]).

-define(IN, <<"in">>).
-define(OUT, <<"out">>).
-define(ROUTING, <<"routing">>).

-spec filter_ccv({kz_term:ne_binary(), any()}) -> boolean().
filter_ccv({?IN, _}) -> 'false';
filter_ccv({?OUT, _}) -> 'false';
filter_ccv({?ROUTING, _}) -> 'false';
filter_ccv(_) -> 'true'.

-spec inbound(kz_json:object()) -> kz_term:api_object().
inbound(CCVs) ->
    inbound(CCVs, 'undefined').

-spec inbound(kz_json:object(), Default) -> kz_json:object() | Default.
inbound(CCVs, Default) ->
    LegacyCCVs = kz_json:filter(fun filter_ccv/1, CCVs),
    InboundCCVs = kz_json:get_json_value(?IN, CCVs, kz_json:new()),
    CustomVars = kz_json:merge(LegacyCCVs, InboundCCVs),
    case kz_json:is_empty(CustomVars) of
        'false' -> CustomVars;
        'true' -> Default
    end.

-spec inbound_variable(kz_json:object(), kz_json:key()) -> kz_json:json_term() | 'undefined'.
inbound_variable(DeviceJObj, Name) ->
    inbound_variable(DeviceJObj, Name, 'undefined').

-spec inbound_variable(kz_json:object(), kz_json:key(), Default) -> kz_json:json_term() | Default.
inbound_variable(DeviceJObj, Name, Default) ->
    kz_json:get_ne_value(Name, inbound(DeviceJObj), Default).

-spec outbound_variable(kz_json:object(), kz_json:key()) -> kz_json:json_term() | 'undefined'.
outbound_variable(DeviceJObj, Name) ->
    outbound_variable(DeviceJObj, Name, 'undefined').

-spec outbound_variable(kz_json:object(), kz_json:key(), Default) -> kz_json:json_term() | Default.
outbound_variable(DeviceJObj, Name, Default) ->
    kz_json:get_ne_value(Name, outbound(DeviceJObj), Default).


-spec outbound(kz_json:object()) -> kz_term:api_object().
outbound(CCVs) ->
    outbound(CCVs, 'undefined').

-spec outbound(kz_json:object(), Default) -> kz_json:object() | Default.
outbound(CCVs, Default) ->
    LegacyCCVs = kz_json:filter(fun filter_ccv/1, CCVs),
    OutboundCCVs = kz_json:get_json_value(?OUT, CCVs, kz_json:new()),
    CustomVars = kz_json:merge(LegacyCCVs, OutboundCCVs),
    case kz_json:is_empty(CustomVars) of
        'false' -> CustomVars;
        'true' -> Default
    end.

-spec set_inbound(kz_json:object(), kz_json:object()) -> kz_json:object().
set_inbound(CCVs, Variables) ->
    kz_json:set_value(?IN, Variables, CCVs).

-spec set_outbound(kz_json:object(), kz_json:object()) -> kz_json:object().
set_outbound(CCVs, Variables) ->
    kz_json:set_value(?OUT, Variables, CCVs).

-spec routing(kz_json:object()) -> kz_term:api_object().
routing(CCVs) ->
    routing(CCVs, 'undefined').

-spec routing(kz_json:object(), Default) -> kz_json:object() | Default.
routing(CCVs, Default) ->
    CustomVars = kz_json:get_json_value(?ROUTING, CCVs, kz_json:new()),
    case kz_json:is_empty(CustomVars) of
        'false' -> CustomVars;
        'true' -> Default
    end.

-spec routing_variable(kz_json:object(), kz_json:key()) -> kz_json:json_term() | 'undefined'.
routing_variable(DeviceJObj, Name) ->
    routing_variable(DeviceJObj, Name, 'undefined').

-spec routing_variable(kz_json:object(), kz_json:key(), Default) -> kz_json:json_term() | Default.
routing_variable(DeviceJObj, Name, Default) ->
    kz_json:get_ne_value(Name, routing(DeviceJObj), Default).

-spec set_routing(kz_json:object(), kz_json:object()) -> kz_json:object().
set_routing(CCVs, Variables) ->
    kz_json:set_value(?ROUTING, Variables, CCVs).
