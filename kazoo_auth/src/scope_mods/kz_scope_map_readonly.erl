%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2016-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_scope_map_readonly).

-export([map/2]).

-include("kz_auth_scope.hrl").

-define(RO_CLAIM, <<"_read_only">>).

%%------------------------------------------------------------------------------
%% @doc map auth properties to claims
%% @end
%%------------------------------------------------------------------------------
-spec map(kz_term:api_binaries(), kz_term:proplist()) -> kz_term:proplist().
map(_Map, _Props) ->
    [{?RO_CLAIM, 'true'}].

