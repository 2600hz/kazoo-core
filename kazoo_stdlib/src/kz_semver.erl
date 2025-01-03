%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Functions for working with Semantic Version.
%%% @author Hesaam Farhang
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_semver).

-export([from_centos_version/1]).

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
