%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Math-y stuff
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_math).

-export([a1hash/3
        ,floor/1
        ,ceiling/1
        ,clamp/3
        ]).

-export([xnor/2]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-spec a1hash(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> nonempty_string().
a1hash(User, Realm, Password) ->
    kz_term:to_hex(erlang:md5(list_to_binary([User,":",Realm,":",Password]))).

%% found via trapexit
-spec floor(integer() | float()) -> integer().
floor(X) when X < 0 ->
    T = trunc(X),
    case X - T == 0 of
        'true' -> T;
        'false' -> T - 1
    end;
floor(X) -> trunc(X).

%% found via trapexit
-spec ceiling(integer() | float()) -> integer().
ceiling(X) when X < 0 -> trunc(X);
ceiling(X) ->
    T = trunc(X),
    case X - T == 0 of
        'true' -> T;
        'false' -> T + 1
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec xnor(boolean(), boolean()) -> boolean().
xnor('false', 'false') -> 'true';
xnor('false', 'true') -> 'false';
xnor('true', 'false') -> 'false';
xnor('true', 'true') -> 'true'.


%%------------------------------------------------------------------------------
%% @doc Clamp the value of a number between an upper- and lower-bound (inclusive)
%% @end
%%------------------------------------------------------------------------------
-spec clamp(Upperbound::number(), Lowerbound::number(), Number::number()) ->
          number().
clamp(Upperbound, Lowerbound, Number)
  when Number < Lowerbound
       andalso Upperbound >= Lowerbound
       -> Lowerbound;
clamp(Upperbound, Lowerbound, Number)
  when Number > Upperbound
       andalso Upperbound >= Lowerbound
       -> Upperbound;
clamp(Upperbound, Lowerbound, Number)
  when Upperbound >= Lowerbound
       -> Number.
