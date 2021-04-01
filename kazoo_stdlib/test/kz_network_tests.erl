%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_network_tests).

-include_lib("eunit/include/eunit.hrl").

validate_ip_test_() ->
    [?_assertEqual('false', kz_network_utils:is_ip("00000"))
    ,?_assertEqual('false', kz_network_utils:is_ip("20181210"))
    ,?_assertEqual('false', kz_network_utils:is_ip("0000:0000:0000:0000:0000:0000:0001"))
    ,?_assertEqual('true', kz_network_utils:is_ip("0.0.0.0"))
    ,?_assertEqual('true', kz_network_utils:is_ip("1.1.1.1"))
    ,?_assertEqual('true', kz_network_utils:is_ip("192.168.0.10"))
    ,?_assertEqual('true', kz_network_utils:is_ip("10.0.0.1"))
    ,?_assertEqual('true', kz_network_utils:is_ip("8.8.8.8"))
    ,?_assertEqual('true', kz_network_utils:is_ip("0000:0000:0000:0000:0000:0000:0000:0001"))
    ].
