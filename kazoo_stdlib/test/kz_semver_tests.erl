%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_semver_tests).

-include_lib("eunit/include/eunit.hrl").

-spec from_centos_version_test_() -> list().
from_centos_version_test_() ->
    [?_assertEqual({'ok', <<"2022.2.54-master.1456">>}, kz_semver:from_centos_version(<<"2022.2.54-master.1456">>))
    ,?_assertEqual({'ok', <<"2022.2.0-master.1456">>}, kz_semver:from_centos_version(<<"2022.2-master.1456">>))
    ,?_assertEqual({'ok', <<"5.0.63">>}, kz_semver:from_centos_version(<<"5.0-63">>))
    ,?_assertEqual({'ok', <<"5.0.0">>}, kz_semver:from_centos_version(<<"5.0">>))
    ,?_assertEqual({'ok', <<"5.0.63-pre.84">>}, kz_semver:from_centos_version(<<"5.0.63-pre.84">>))
    ,?_assertEqual({'ok', <<"5.0.0-pre">>}, kz_semver:from_centos_version(<<"5.0-pre">>))
    ,?_assertEqual({'ok', <<"5.0.0-pre">>}, kz_semver:from_centos_version(<<"5.0-pre">>))
    ,?_assertEqual({'error', 'invalid_version'}, kz_semver:from_centos_version(<<>>))
    ,?_assertEqual({'error', 'invalid_version'}, kz_semver:from_centos_version(<<"23.3.4.5">>))
    ,?_assertEqual({'error', {'invalid_patch', 'leading_zero'}}, kz_semver:from_centos_version(<<"5.0.03">>))
    ,?_assertEqual({'error', {'invalid_patch', 'nan'}}, kz_semver:from_centos_version(<<"5.0.lol">>))
    ,?_assertEqual({'error', {'invalid_min', 'nan'}}, kz_semver:from_centos_version(<<"5.lol.1">>))
    ,?_assertEqual({'error', {'invalid_maj', 'nan'}}, kz_semver:from_centos_version(<<"lol.0.1">>))
    ].
