%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzv_contact_list_names).

-export([find_all/2]).

-define(VIEW_NAME, <<"crossbar_listings/contact_list_names">>).


%%------------------------------------------------------------------------------
%% @doc Find all.
%% @end
%%------------------------------------------------------------------------------
-spec find_all(kz_term:ne_binary(), kz_view:options()) -> kz_view:result().
find_all(Database, Options) ->
    kz_view:find(Database, ?VIEW_NAME, [], set_options(Options)).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
set_options(Options) -> Options.
