%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoints_v5).

-export([by_owner_id/3]).

-include("kazoo_endpoint.hrl").

-spec by_owner_id(kz_term:ne_binary(), kz_json:object(), kapps_call:call()) ->
          kz_endpoint:endpoints() | {error, kz_endpoint:build_errors()}.
by_owner_id(OwnerId, Data, Call) ->
    ModifiedCall = maybe_add_cavs_to_call(OwnerId, Data, Call),
    case kz_endpoint_v5:build(OwnerId, Data, ModifiedCall) of
        {ok, Endpoints} -> Endpoints;
        Error -> Error
    end.

%%------------------------------------------------------------------------------
%% @doc Will add default custom application variables on to the Call record if
%% the keys defined in the sysconfig are available in the user doc
%% @end
%%------------------------------------------------------------------------------
maybe_add_cavs_to_call(OwnerId, Data, Call) ->
    case kapps_config:get(?CONFIG_CAT, <<"default_cavs">>) of
        'undefined' ->
            Call;
        CAVList ->
            kapps_call:maybe_add_default_cavs_to_call(OwnerId, Data, Call, CAVList)
    end.
