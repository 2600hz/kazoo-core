%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_application_test).

-include_lib("eunit/include/eunit.hrl").

calling_app_test_() ->
    [?_assertEqual('eunit_test', maps:get('app', kz_application:calling_process()))
    ,?_assertMatch('undefined', kz_application:get_app('some_kazoo_app'))
    ].
