%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2016-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_scope_db).

-define(DEFAULT_SCOPE_PROVIDER, <<"local">>).
-define(SCOPE_DB
       ,kapps_config:get_ne_binary(<<"auth">>, <<"iam_scope_db">>, ?DEFAULT_SCOPE_PROVIDER)
       ).
-define(SCOPE_DB_MOD, kz_term:to_atom(<<"kz_scope_db_",(?SCOPE_DB)/binary>>, 'true')).

-include("kz_auth_scope.hrl").

-export ([scopes/0
         ,scope/1, has_scope/1
         ,claims/1, has_claims/1
         ,mod/1, has_mod/1
         ,privileges/1, has_privileges/1
         ]).

                                                % behavior callbacks
-callback scopes() -> {'ok', kz_json:objects()}  | scope_error().
-callback has_scope(Scope :: kz_term:binary()) -> boolean().
-callback claims(Scope :: kz_term:binary()) -> kz_json:object() | scope_error().

%%------------------------------------------------------------------------------
%% @doc Fetch all scopes
%% @end
%%------------------------------------------------------------------------------
-spec scopes() -> {'ok', kz_json:objects()}  | scope_error().
scopes() ->
    (?SCOPE_DB_MOD):scopes().

%%------------------------------------------------------------------------------
%% @doc Check if scope exists
%% @end
%%------------------------------------------------------------------------------
-spec has_scope(kz_term:ne_binary()) -> boolean().
has_scope(Scope) ->
    (?SCOPE_DB_MOD):has_scope(Scope).

%%------------------------------------------------------------------------------
%% @doc Fetch scope data
%% @end
%%------------------------------------------------------------------------------
-spec scope(kz_term:ne_binary()) -> boolean().
scope(Scope) ->
    (?SCOPE_DB_MOD):scope(Scope).

%%------------------------------------------------------------------------------
%% @doc Fetch claims for a scope
%% @end
%%------------------------------------------------------------------------------
-spec claims(kz_term:binary()) -> kz_json:object() | scope_error().
claims(Scope) ->
    (?SCOPE_DB_MOD):claims(Scope).

%%------------------------------------------------------------------------------
%% @doc Verify a scope has claims
%% @end
%%------------------------------------------------------------------------------
-spec has_claims(kz_term:binary()) -> boolean().
has_claims(Scope) ->
    (?SCOPE_DB_MOD):has_claims(Scope).

%%------------------------------------------------------------------------------
%% @doc Fetch mapping module for a Scope
%% @end
%%------------------------------------------------------------------------------
-spec mod(kz_term:binary()) -> kz_json:object() | scope_error().
mod(Scope) ->
    (?SCOPE_DB_MOD):mod(Scope).

%%------------------------------------------------------------------------------
%% @doc Verify a scope has a mapping module
%% @end
%%------------------------------------------------------------------------------
-spec has_mod(kz_term:binary()) -> boolean().
has_mod(Scope) ->
    (?SCOPE_DB_MOD):mod(Scope) =/= 'undefined'.

%%------------------------------------------------------------------------------
%% @doc Fetch scope privileges
%% @end
%%------------------------------------------------------------------------------
-spec privileges(kz_term:binary()) -> kz_json:object() | scope_error().
privileges(Scope) ->
    (?SCOPE_DB_MOD):privileges(Scope).

%%------------------------------------------------------------------------------
%% @doc Verify scope has privileges
%% @end
%%------------------------------------------------------------------------------
-spec has_privileges(kz_term:binary()) -> boolean().
has_privileges(Scope) ->
    (?SCOPE_DB_MOD):has_privileges(Scope).
