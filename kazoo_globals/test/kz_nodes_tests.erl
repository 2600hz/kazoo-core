%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_nodes_tests).

-include_lib("eunit/include/eunit.hrl").


nodename_test_() ->
    [?_assertEqual('true', kz_term:is_ne_binary(kz_nodes:node_name()))
    ,?_assertEqual('true', kz_term:is_ne_binary(kz_nodes:node_hostname()))
    ].
