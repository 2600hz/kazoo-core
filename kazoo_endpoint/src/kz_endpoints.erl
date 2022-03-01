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
-module(kz_endpoints).

-export([by_owner_id/3
        ,ignore_early_media/1
        ]).

-include("kazoo_endpoint.hrl").

-spec by_owner_id(kz_term:ne_binary(), kz_json:object(), kapps_call:call()) ->
          kz_endpoint:endpoints().
by_owner_id(OwnerId, Data, Call) ->
    by_owner_id(OwnerId, Data, Call, ?MODNAME).

by_owner_id(OwnerId, Data, Call, Mod) ->
    lists:foldr(fun(EndpointId, Acc) ->
                        case Mod:build(EndpointId, Data, Call) of
                            {'ok', Endpoint} -> Endpoint ++ Acc;
                            {'error', _E} -> Acc
                        end
                end
               ,[]
               ,kz_attributes:owned_by(OwnerId, <<"device">>, Call)
               ).

-spec ignore_early_media(kz_endpoint:endpoints()) -> boolean().
ignore_early_media(Endpoints) ->
    not any_keeping_early_media(Endpoints).

-spec any_keeping_early_media(kz_endpoint:endpoints()) -> boolean().
any_keeping_early_media(Endpoints) ->
    lists:any(fun keeping_early_media/1, Endpoints).

-spec keeping_early_media(kz_endpoint:endpoint()) -> boolean().
keeping_early_media(Endpoint) ->
    kz_json:is_false(<<"Ignore-Early-Media">>, Endpoint).
