%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Functions for working with Semantic Version.
%%%
%%% Parses according to SemVer 2.0: https://semver.org/spec/v2.0.0.html
%%%
%%% @author Hesaam Farhang
%%% @author James Aimonetti
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_semver).

-export([parse/1
        ,compare/2
        ]).

%% record accessors
-export([major/1, minor/1, patch/1, prerelease/1, buildinfo/1]).

-export([from_centos_version/1]).

-type major() :: non_neg_integer().
-type minor() :: non_neg_integer().
-type patch() :: non_neg_integer().
-type prerelease() :: 'undefined' | [non_neg_integer() | kz_term:ne_binary()].
-type buildinfo() :: 'undefined' | [non_neg_integer() | kz_term:ne_binary()].

-record(semver, {major = 0 :: major()
                ,minor = 0 :: minor()
                ,patch = 0 :: patch()
                ,prerelease = 'undefined' :: prerelease()
                ,buildinfo = 'undefined' :: buildinfo()
                }).
-type semver() :: #semver{}.
-export_type([semver/0]).

%% @doc returns how Version1 compared to Version2 according to SemVer 2.0
%% Major.Minor.Patch-PreRelease+BuildInfo
-spec compare(kz_term:ne_binary(), kz_term:ne_binary()) -> 'eq' | 'gt' | 'lt' | 'undefined'.
compare(<<Version/binary>>, <<Version/binary>>) -> 'eq';
compare(<<Version1/binary>>, <<Version2/binary>>) ->
    maybe_compare(parse(Version1), parse(Version2)).

maybe_compare(#semver{}=SemVer1, #semver{}=SemVer2) ->
    %% Buildinfo is not considered when determining precedence
    compare_parsed(SemVer1#semver{buildinfo='undefined'}
                  ,SemVer2#semver{buildinfo='undefined'}
                  );
maybe_compare(_, _) -> 'undefined'.

compare_parsed(#semver{}=Version, #semver{}=Version) -> 'eq';

compare_parsed(#semver{major=Major, minor=Minor, patch=Patch, prerelease=Pre1}
              ,#semver{major=Major, minor=Minor, patch=Patch, prerelease=Pre2}
              ) ->
    compare_identifiers(Pre1, Pre2);

compare_parsed(#semver{major=Major, minor=Minor, patch=Patch1}
              ,#semver{major=Major, minor=Minor, patch=Patch2}
              ) ->
    gt_or_lt(Patch1 > Patch2);

compare_parsed(#semver{major=Major, minor=Minor1}
              ,#semver{major=Major, minor=Minor2}
              ) ->
    gt_or_lt(Minor1 > Minor2);

compare_parsed(#semver{major=Major1}
              ,#semver{major=Major2}
              ) ->
    gt_or_lt(Major1 > Major2).

gt_or_lt('true') -> 'gt';
gt_or_lt('false') -> 'lt'.


compare_identifiers('undefined', 'undefined') -> 'eq';

%% versions with no identifiers are considered higher in precedence, so 'undefined' > [...]
compare_identifiers(_Ids1, 'undefined') -> 'lt';
compare_identifiers('undefined', _Ids2) -> 'gt';

compare_identifiers([], []) -> 'eq';
compare_identifiers([Id | Ids1], [Id | Ids2]) ->
    compare_identifiers(Ids1, Ids2);
compare_identifiers([Id1 | _], [Id2 | _]) ->
    gt_or_lt(Id1 > Id2).

-spec parse(kz_term:ne_binary()) -> semver() | 'undefined'.
parse(<<Version/binary>>) ->
    try lists:foldl(fun parse_fold/2
                   ,{Version, #semver{}}
                   ,[fun parse_build/2
                    ,fun parse_prerelease/2
                    ,fun parse_major_minor_patch/2
                    ])
    catch
        _E:_R ->
            lager:debug("failed to parse semver ~s: ~p", [Version, _R]),
            'undefined'
    end.

parse_fold(Fun, {V, SemVer}) ->
    Fun(V, SemVer).

parse_build(Version, #semver{}=SemVer) ->
    case binary:split(Version, <<"+">>) of
        [NoBuildInfo] -> {NoBuildInfo, SemVer#semver{buildinfo='undefined'}};
        [Vsn, BuildInfo] -> {Vsn, SemVer#semver{buildinfo=binary:split(BuildInfo, <<".">>, ['global'])}}
    end.

parse_prerelease(Version, #semver{}=SemVer) ->
    case binary:split(Version, <<"-">>) of
        [NoPreRelease] -> {NoPreRelease, SemVer#semver{prerelease='undefined'}};
        [Vsn, Pre] ->
            {Vsn, SemVer#semver{prerelease=parse_identifiers(Pre)}}
    end.

parse_identifiers(Pre) ->
    [kz_term:safe_cast(Id, Id, fun kz_term:to_integer/1) || Id <- binary:split(Pre, <<".">>, ['global'])].

parse_major_minor_patch(Version, #semver{}=SemVer) ->
    case binary:split(Version, <<".">>, ['global']) of
        [Major] -> SemVer#semver{major=kz_term:to_integer(Major)};
        [Major, Minor] -> SemVer#semver{major=kz_term:to_integer(Major)
                                       ,minor=kz_term:to_integer(Minor)
                                       };
        [Major, Minor, Patch] -> SemVer#semver{major=kz_term:to_integer(Major)
                                              ,minor=kz_term:to_integer(Minor)
                                              ,patch=kz_term:to_integer(Patch)
                                              }
    end.

-spec major(semver()) -> major().
major(#semver{major=M}) -> M.

-spec minor(semver()) -> minor().
minor(#semver{minor=M}) -> M.

-spec patch(semver()) -> patch().
patch(#semver{patch=P}) -> P.

-spec prerelease(semver()) -> prerelease().
prerelease(#semver{prerelease=P}) -> P.

-spec buildinfo(semver()) -> buildinfo().
buildinfo(#semver{buildinfo=B}) -> B.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec from_centos_version(binary()) ->
          {'ok', kz_term:ne_binary()} |
          {'error', 'invalid_version'} |
          {'error', {'invalid_maj' |
                     'invalid_min' |
                     'invalid_patch'
                    ,'leading_zero' | 'nan'
                    }}.
from_centos_version(<<>>) -> {'error', 'invalid_version'};
from_centos_version(Version) ->
    [VerPre | _Build] = binary:split(Version, [<<"+">>], ['global']),
    [Ver, Pre1] = case binary:split(VerPre, [<<"-">>], []) of
                      [V] -> [V, <<>>];
                      [_, _]=VerPreSplit -> VerPreSplit;
                      _ -> [<<>>, <<>>]
                  end,
    [Maj1, Min1, Patch1, Other] = split_version(Ver),
    kz_either:pipe({'ok', []}
                  ,[fun(Acc) -> version_no_other_part(Other, Acc) end
                   ,fun(Acc) -> version_part_to_digit(Maj1, Acc, 'invalid_maj') end
                   ,fun(Acc) -> version_part_to_digit(Min1, Acc, 'invalid_min') end
                   ,fun(Acc) -> version_maybe_incorporate_pre(Patch1, Acc, Pre1) end
                   ,fun([_Maj, _Min, _Patch]=Acc) ->
                            {'ok', kz_binary:join(Acc, <<".">>)};
                       ([Maj, Min, Patch, <<>>]) ->
                            {'ok', kz_binary:join([Maj, Min, Patch], <<".">>)};
                       ([Maj, Min, Patch, Pre]) ->
                            {'ok', <<(kz_binary:join([Maj, Min, Patch], <<".">>))/binary, "-", Pre/binary>>}
                    end
                   ]
                  ).

-spec version_no_other_part(kz_term:api_ne_binary() | 'error', kz_term:ne_binaries()) ->
          {'ok', kz_term:ne_binaries()} |
          {'error', 'invalid_version'}.
version_no_other_part('undefined', Acc) ->
    {'ok', Acc};
version_no_other_part(_, _) ->
    {'error', 'invalid_version'}.

-spec version_part_to_digit(kz_term:ne_binary(), kz_term:ne_binaries(), Error) ->
          {'ok', kz_term:ne_binaries()} |
          {'error', {Error,'leading_zero' | 'nan'}}.
version_part_to_digit(<<"0">> = Part, Acc, _Error) ->
    {'ok', Acc ++ [Part]};
version_part_to_digit(<<"0", _/binary>>, _Acc, Error) ->
    {'error', {Error, 'leading_zero'}};
version_part_to_digit(Part, Acc, Error) ->
    try kz_term:to_integer(Part) of
        _Int -> {'ok', Acc ++ [Part]}
    catch
        _C:_R:_ST ->
            {'error', {Error, 'nan'}}
    end.

-spec version_maybe_incorporate_pre(kz_term:api_ne_binary(), kz_term:ne_binaries(), binary()) ->
          {'ok', kz_term:ne_binaries()} |
          {'error', {'invalid_patch','leading_zero' | 'nan'}}.
version_maybe_incorporate_pre('undefined', Acc, Pre) ->
    [Part | PreOther] = binary:split(Pre, <<".">>, ['global']),
    try kz_term:to_integer(Part) of
        _Int ->
            {'ok', Acc ++ [Part, kz_binary:join(PreOther, <<".">>)]}
    catch
        _C:_R:_ST ->
            %% no patch version, coerce to semver by pretending patch as zero and join pre to version
            {'ok', Acc ++ [<<"0">>, Pre]}
    end;
version_maybe_incorporate_pre(Part, Acc, Pre) ->
    case version_part_to_digit(Part, Acc, 'invalid_patch') of
        {'ok', PatchAcc} ->
            {'ok', PatchAcc ++ [Pre]};
        {'error', _}=Error ->
            Error
    end.

%% @private
-spec split_version(binary()) -> ['error' | 'undefined' | binary() | [binary()], ...].
split_version(Str) ->
    case binary:split(Str, [<<".">>], ['global']) of
        [Maj0, Min0] ->
            [Maj0, Min0, 'undefined', 'undefined'];
        [Maj, Min, P] ->
            [Maj, Min, P, 'undefined'];
        [Major, Minor, Patch | Rest] ->
            [Major, Minor, Patch, Rest];
        _ ->
            ['error', 'error', 'error', 'error']
    end.
