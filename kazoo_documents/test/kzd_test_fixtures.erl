%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_test_fixtures).

-export([setup/0, setup/1
        ,cleanup/1
        ]).

-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").

setup() ->
    setup('false').

setup(SilentLager) ->
    kazoo_fixturedb:start(SilentLager).

cleanup(LinkPid) ->
    _DataLink = erlang:exit(LinkPid, 'normal'),
    Ref = monitor('process', LinkPid),
    receive
        {'DOWN', Ref, 'process', LinkPid, _Reason} ->
            _KConfig = application:stop('kazoo_config'),
            ?LOG_DEBUG(":: Stopped Kazoo FixtureDB, data_link: ~p kazoo_config: ~p", [_DataLink, _KConfig])
    after ?MILLISECONDS_IN_SECOND ->
            _KConfig = application:stop('kazoo_config'),
            ?LOG_DEBUG(":: Stopped Kazoo FixtureDB, data_link: timeout kazoo_config: ~p", [_KConfig])
    end.
