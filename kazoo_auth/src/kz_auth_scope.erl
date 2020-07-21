%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope).

-include("kazoo_auth.hrl").

-export([has/2
        ,any/2
        ,all/2
        ,scopes/1
        ]).

-type jwt() :: map().
-type token() :: jwt() | kz_term:ne_binary().
-type has_scope_option() :: any | all.

-spec all(token(), kz_term:ne_binaries()) -> boolean().
all(Token, ScopeList) ->
    has_scopes(Token, ScopeList, all).

-spec any(token(), kz_term:ne_binaries()) -> boolean().
any(Token, ScopeList) ->
    has_scopes(Token, ScopeList, any).

-spec has(token(), kz_term:ne_binary()) -> boolean().
has(Token, Scope) ->
    has_scopes(Token, [Scope], all).

-spec has_scopes(token(), kz_term:ne_binaries(), has_scope_option()) -> boolean().
has_scopes(JWToken, Scopes, Option)
  when is_binary(JWToken) ->
    has_scopes(kz_auth_jwt:token(JWToken), Scopes, Option);
has_scopes(Token, ScopeList, Option) ->
    Scopes = scopes(Token),
    Fun = fun(Scope) ->
             lists:member(Scope, Scopes)
          end,
    lists:Option(Fun, ScopeList).

-spec scopes(token()) -> kz_term:ne_binaries().
scopes(JWToken)
  when is_binary(JWToken) ->
    scopes(kz_auth_jwt:token(JWToken));
scopes(Token) ->
    Routines = [fun init_scopes/1
               ,fun from_claim/1
               ],
    #{scopes := Scopes} = kz_maps:exec(Routines, Token),
    Scopes.

init_scopes(Token) ->
    Token#{scopes => []}.

from_claim(#{scopes := Scopes
            ,payload := #{<<"scope">> := Scope}
            } = Token) ->
    Token#{scopes => Scopes ++ binary:split(Scope, <<" ">>, [global])};
from_claim(Token) -> Token.
