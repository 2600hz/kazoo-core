%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2023, 2600Hz
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
        ,available_scopes/0, available_scopes/1
        ,exists/1
        ,to_list/1
        ,to_str/1
        ]).

-define(SCOPE_DELIM, <<":">>).
-define(SCOPE_SEP, <<" ">>).
-define(SCOPES_KEY, <<"scopes">>).
-define(SCOPES_CAT, <<"system_auth">>).
-define(SCOPES_LIST, <<"scopes/crossbar_listing">>).

-type jwt() :: map().
-type token() :: jwt() | kz_term:ne_binary() | 'undefined'.
-type has_scope_option() :: 'any' | 'all'.

%%------------------------------------------------------------------------------
%% @doc Test if all requested scopes are present in token
%% @end
%%------------------------------------------------------------------------------
-spec all(token(), kz_term:ne_binaries()) -> boolean().
all(Token, ScopeList) ->
    has_scopes(Token, ScopeList, 'all').

%%------------------------------------------------------------------------------
%% @doc Test if any scopes are present in token
%% @end
%%------------------------------------------------------------------------------
-spec any(token(), kz_term:ne_binaries()) -> boolean().
any(Token, ScopeList) ->
    has_scopes(Token, ScopeList, 'any').

%%------------------------------------------------------------------------------
%% @doc Test if scope is present in token
%% @end
%%------------------------------------------------------------------------------
-spec has(token(), kz_term:ne_binary()) -> boolean().
has(Token, Scope) ->
    has_scopes(Token, [Scope], 'all').

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
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

%%------------------------------------------------------------------------------
%% @doc Fetches scope by name
%% @end
%%------------------------------------------------------------------------------
-spec available_scopes() -> kz_term:proplist().
available_scopes() ->
    Options = ['include_docs'],
    Scopes = fetch_scopes(?SCOPES_LIST, Options),
    maybe_flatten_scopes(Scopes).

-spec available_scopes(atom() | kz_term:ne_binary() | kz_term:ne_binaries()) -> kz_term:binaries().
available_scopes(Scope) when is_atom(Scope) ->
    available_scopes(kz_term:to_binary(Scope));
available_scopes(ScopeBin) ->
    Options = [{'key', [ScopeBin]}
              ,'include_docs'
              ],
    Scopes = fetch_scopes(?SCOPES_LIST, Options),
    maybe_flatten_scopes(Scopes).

%%------------------------------------------------------------------------------
%% @doc Filters a list of scopes by owner
%% @end
%%------------------------------------------------------------------------------
-spec fetch_scopes(kz_term:ne_binary(), kazoo_data:view_options()) -> kz_term:ne_binaries().
fetch_scopes(View, ViewOptions) ->
    case kz_datamgr:get_results(?SCOPES_CAT, View, ViewOptions) of
        {'ok', Scopes} -> Scopes;
        _ -> []
    end.

%%------------------------------------------------------------------------------
%% @doc checks if scope is defined in system_auth
%% @end
%%------------------------------------------------------------------------------
-spec exists(kz_term:ne_binary() | kz_term:binaries()) -> boolean().
exists(<<Scope/binary>>) ->
    exists(to_list(Scope));
exists(Scope) ->
    lists:member(Scope, available_scopes()).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_flatten_scopes(kz_json:objects()) -> kz_term:proplist().
maybe_flatten_scopes([]) -> [];
maybe_flatten_scopes(Scopes) ->
    lists:usort(lists:foldl(fun flatten_scopes_fold/2, [], Scopes)).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
flatten_scopes_fold(JObj, Acc) ->
    ScopeId = kz_json:get_ne_binary_value([<<"key">>], JObj),
    Doc = kz_json:get_json_value([<<"doc">>], JObj, []),
    maybe_explode_scopes(ScopeId, Doc, Acc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
maybe_explode_scopes(_ScopeId, 'null', Acc) -> Acc;
maybe_explode_scopes(_ScopeId, [], Acc) ->  Acc;
maybe_explode_scopes(ScopeId, Doc, Acc) ->
    Scopes = kz_json:get_list_value([?SCOPES_KEY], Doc, []),
    [{ScopeId, Scopes} | Acc].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec scopes(token()) -> kz_term:ne_binaries().
scopes('undefined') -> [];
scopes(JWToken)
  when is_binary(JWToken) ->
    scopes(kz_auth_jwt:token(JWToken));
scopes(Token) ->
    Routines = [fun init_scopes/1
               ,fun from_claim/1
               ,fun resolve_scopes/1
               ,fun explode_scopes/1
               ],
    #{scopes := Scopes} = kz_maps:exec(Routines, Token),
    Scopes.

%%------------------------------------------------------------------------------
%% @doc Initialize jwt token map
%% @end
%%------------------------------------------------------------------------------
-spec init_scopes(jwt()) -> jwt().
init_scopes(Token) ->
    Token#{scopes => []}.

%%------------------------------------------------------------------------------
%% @doc Extracts scope claim from token
%% @end
%%------------------------------------------------------------------------------
-spec from_claim(jwt()) -> jwt().
from_claim(#{scopes := Scopes
            ,payload := #{<<"scope">> := Scope}
            } = Token) ->
    Token#{scopes => Scopes ++ to_list(Scope, ?SCOPE_SEP)};
from_claim(Token) -> Token.

%%------------------------------------------------------------------------------
%% @doc Explode Token Scopes
%% Transforms "a:b" into ["a", "a:b"]
%% Transforms "a:b:c" into ["a", "a:b", "a:b:c"]
%% @end
%%------------------------------------------------------------------------------
-spec explode_scopes(jwt()) -> jwt().
explode_scopes(#{scopes := Scopes} = Token) ->
    NewScopes = lists:foldl(fun explode_scopes_fold/2, [], Scopes),
    Token#{scopes => NewScopes}.

explode_scopes_fold(Scope, Acc) ->
    Acc ++ lists:foldl(fun explode_scope_fold/2, [], to_list(Scope, ?SCOPE_DELIM)).

explode_scope_fold(Scope, Acc) ->
    Acc ++ [kz_binary:join(lists:filter(fun kz_term:is_not_empty/1, [last(Acc), Scope]), <<":">>)].

last([]) -> <<>>;
last(List) -> lists:last(List).

%%------------------------------------------------------------------------------
%% @doc Resolves superset scopes
%% @end
%%------------------------------------------------------------------------------
-spec resolve_scopes(jwt()) -> jwt().
resolve_scopes(#{scopes := Scopes
                ,scopes_available := Available
                } = Token) ->
    Resolved = resolve_scopes(Scopes, Available),
    Token#{scopes => lists:usort(Scopes ++ Resolved)};
resolve_scopes(#{scopes := _} = Token) ->
    Available = available_scopes(),
    resolve_scopes(Token#{scopes_available => Available}).

-spec resolve_scopes(kz_term:ne_binaries(), kz_term:proplist()) -> kz_term:ne_binaries().
resolve_scopes(Scopes, Available) ->
    resolve_scopes(Scopes, Available, []).

-spec resolve_scopes(kz_term:ne_binaries(), kz_term:proplist(), kz_term:ne_binaries()) -> kz_term:ne_binaries().
resolve_scopes(Scopes, Available, Visited) ->
    {NewScopes, _} = lists:mapfoldl(fun resolve_scopes_fold/2, {Available, Visited}, Scopes),
    lists:flatten(NewScopes).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
resolve_scopes_fold(Scope, {Available, Visited}) ->
    case lists:member(Scope, Visited) of
        'true' ->
            {[Scope], {Available, Visited}};
        'false' ->
            case props:get_value(Scope, Available, []) of
                [] -> {[Scope], {Available, [Scope | Visited]}};
                Scopes -> {[Scope | resolve_scopes(Scopes, Available, [Scope | Visited])], {Available, [Scope | Visited]}}
            end
    end.

%%------------------------------------------------------------------------------
%% @doc Extract scope binary into list of subscopes
%% @end
%%------------------------------------------------------------------------------
-spec to_list(kz_term:ne_binary() | kz_term:ne_binaries()) ->
          [kz_term:ne_binary() | kz_term:ne_binaries()].
to_list(<<ScopeBin/binary>>) ->
    Scopes = to_list(ScopeBin, ?SCOPE_SEP),
    to_list(Scopes);
to_list(ScopeList) ->
    lists:map(fun to_list_by_delim/1, ScopeList).

to_list_by_delim(S) ->
    case to_list(S, ?SCOPE_DELIM) of
        [S] -> S;
        Else -> Else
    end.

-spec to_list(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binary() | kz_term:ne_binaries().
to_list(<<ScopeBin/binary>>, Delim) ->
    binary:split(ScopeBin, Delim, ['global']).

%%------------------------------------------------------------------------------
%% @doc Converts scope list to space separated binary
%% @end
%%------------------------------------------------------------------------------
-spec to_str(kz_term:api_binary() | list()) -> kz_term:api_binary().
to_str(Scope)
  when is_binary(Scope) ->
    Scope;
to_str('undefined') ->
    'undefined';
to_str([]) ->
    'undefined';
to_str(List)
  when is_list(List) ->
    Fun = fun(S) -> to_str(S, ?SCOPE_DELIM) end,
    ScopeList = lists:map(Fun, List),
    to_str(ScopeList, ?SCOPE_SEP);
to_str(_Other) -> 'undefined'.

-spec to_str(kz_term:ne_binary() | kz_term:ne_binaries(), kz_term:ne_binary()) -> kz_term:ne_binary().
to_str(Scope, _Delim)
  when is_binary(Scope) ->
    Scope;
to_str(List, Delim)
  when is_list(List) ->
    Scopes = lists:map(fun kz_term:to_binary/1, List),
    kz_binary:join(Scopes, Delim).
