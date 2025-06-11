%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
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

compare_test_() ->
    Tests = [{'eq', <<"1.0.0">>, <<"1.0.0">>}
            ,{'gt', <<"1.0.1">>, <<"1.0.0">>}
            ,{'lt', <<"1.0.0">>, <<"1.0.1">>}
            ,{'lt', <<"3.0.0">>, <<"10.0.0">>}
            ,{'gt', <<"10.0.0">>, <<"3.0.0">>}
            ,{'lt', <<"3.4.0">>, <<"3.11.0">>}
            ,{'gt', <<"3.14.0">>, <<"3.1.0">>}

            ,{'eq', <<"1.0.0-alpha">>, <<"1.0.0-alpha">>}
            ,{'eq', <<"1.0.0-0.3.7">>, <<"1.0.0-0.3.7">>}

            ,{'eq', <<"1.0.0-alpha+buildinfo">>, <<"1.0.0-alpha">>}
            ,{'eq', <<"1.0.0-alpha+buildinfo">>, <<"1.0.0-alpha+versioninfo">>}
            ,{'eq', <<"1.0.0-alpha">>, <<"1.0.0-alpha+versioninfo">>}

            ,{'lt', <<"1.0.0-alpha">>, <<"1.0.0">>}

            ,{'undefined', <<"5.4.7.22 - 26">>, <<"5.4.32.10 - 26">>}
            ],
    [?_assertEqual(Result, kz_semver:compare(V1, V2))
     || {Result, V1, V2} <- Tests
    ].

parse_prerelease_test_() ->
    Tests = [{<<"1.0.0-alpha">>, [<<"alpha">>]}
            ,{<<"1.0.0-alpha.1">>, [<<"alpha">>, 1]}
            ,{<<"1.0.0-0.3.7">>, [0, 3, 7]}
            ,{<<"1.0.0-x.7.z.92">>, [<<"x">>, 7, <<"z">>, 92]}
            ,{<<"1.0.0-x-y-z.--">>, [<<"x-y-z">>, <<"--">>]}
            ],
    [{"Parse " ++ kz_term:to_list(Version)
     ,[{"prerelease", ?_assertEqual(PreRelease, kz_semver:prerelease(SemVer))}
      ,{"buildinfo", ?_assertEqual('undefined', kz_semver:buildinfo(SemVer))}
      ,{"major", ?_assertEqual(1, kz_semver:major(SemVer))}
      ,{"minor", ?_assertEqual(0, kz_semver:minor(SemVer))}
      ,{"patch", ?_assertEqual(0, kz_semver:patch(SemVer))}
      ]}
     || {Version, PreRelease} <- Tests,
        SemVer <- [kz_semver:parse(Version)]
    ].

parse_buildinfo_test_() ->
    Tests = [{<<"1.0.0-alpha+001">>, [<<"alpha">>], [<<"001">>]}
            ,{<<"1.0.0+20130313144700">>, 'undefined', [<<"20130313144700">>]}
            ,{<<"1.0.0-beta+exp.sha.5114f85">>, [<<"beta">>], [<<"exp">>, <<"sha">>, <<"5114f85">>]}
            ,{<<"1.0.0+21AF26D3----117B344092BD">>, 'undefined', [<<"21AF26D3----117B344092BD">>]}
            ],
    [{"Parse " ++ kz_term:to_list(Version)
     ,[{"prerelease", ?_assertEqual(PreRelease, kz_semver:prerelease(SemVer))}
      ,{"buildinfo", ?_assertEqual(BuildInfo, kz_semver:buildinfo(SemVer))}
      ,{"major", ?_assertEqual(1, kz_semver:major(SemVer))}
      ,{"minor", ?_assertEqual(0, kz_semver:minor(SemVer))}
      ,{"patch", ?_assertEqual(0, kz_semver:patch(SemVer))}
      ]}
     || {Version, PreRelease, BuildInfo} <- Tests,
        SemVer <- [kz_semver:parse(Version)]
    ].
