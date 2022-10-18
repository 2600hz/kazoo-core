%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% This module is kind of a mirror of j5_endpoint_limit_ra module, in order to
%%% avoid inter-applications dependencies.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoint_transactions).

-export([reserve/2
        ,release/1
        ,summary/0, summary/1, summary/2
        ]).

%%------------------------------------------------------------------------------
%% @doc Makes a new reservation if endpoint has not reached limit, yet.
%% @end
%%------------------------------------------------------------------------------
-spec reserve(j5_endpoint_limit_ra:account_id(), j5_endpoint_limit_ra:endpoint_id()) ->
          j5_endpoint_limit_ra:reserve_ok_resp() | j5_endpoint_limit_ra:reserve_error_resp().
reserve(AccountId, EndpointId) ->
    j5_endpoint_limit_ra:reserve(AccountId, EndpointId).

%%------------------------------------------------------------------------------
%% @doc Frees EndpointId's reservation.
%% @end
%%------------------------------------------------------------------------------
-spec release(j5_endpoint_limit_ra:uuid()) -> j5_endpoint_limit_ra:release_resp().
release(UUID) ->
    j5_endpoint_limit_ra:release(UUID).

%%%=============================================================================
%%% Queries
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Reservations listing.
%% @end
%%------------------------------------------------------------------------------
-spec summary() -> j5_endpoint_limit_ra:reservations_summary().
summary() ->
    summary('undefined').

%%------------------------------------------------------------------------------
%% @doc Reservations per Account listing.
%% @end
%%------------------------------------------------------------------------------
-spec summary(j5_endpoint_limit_ra:account_id() | 'undefined') -> j5_endpoint_limit_ra:reservations_summary().
summary(AccountId) ->
    summary(AccountId, 'undefined').

%%------------------------------------------------------------------------------
%% @doc Reservations per EndpointId listing.
%% @end
%%------------------------------------------------------------------------------
-spec summary(j5_endpoint_limit_ra:account_id() | 'undefined', j5_endpoint_limit_ra:endpoint_id() | 'undefined') ->
          j5_endpoint_limit_ra:reservations_summary().
summary(AccountId, EndpointId) ->
    j5_endpoint_limit_ra:reservations(AccountId, EndpointId).
