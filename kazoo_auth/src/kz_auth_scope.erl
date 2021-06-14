%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope).

-include("kz_auth_scope.hrl").

-export([has/2
        ,any/2
        ,all/2
        ,scopes/1
        ,available_scopes/0, available_scopes/1
        ,exists/1
        ,to_list/1
        ,to_str/1
        ]).

-export([create_claims/1]).
-export([resolve_scopes/2]).

-export([join/1
        ,split/1
        ]).

-export([scope_doc_id/1
        ,normalize_doc_id/1
        ]).

-define(DEFAULT_MISSING_USER_TYPE_SCOPE, <<"other">>).

-type jwt() :: map().
-type claim() :: kz_json:object().
-type token() :: jwt() | claim() | kz_term:ne_binary() | 'undefined'.
-type scope_list_fun() :: fun((kz_term:ne_binary(), kz_term:ne_binaries()) -> boolean()).

%%------------------------------------------------------------------------------
%% @doc Test if all requested scopes are present in token
%% @end
%%------------------------------------------------------------------------------
-spec all(token(), kz_term:ne_binaries()) -> boolean().
all(Token, ScopeList) ->
    has_scopes(Token, ScopeList, fun lists:all/2).

%%------------------------------------------------------------------------------
%% @doc Test if any scopes are present in token
%% @end
%%------------------------------------------------------------------------------
-spec any(token(), kz_term:ne_binaries()) -> boolean().
any(Token, ScopeList) ->
    has_scopes(Token, ScopeList, fun lists:any/2).

%%------------------------------------------------------------------------------
%% @doc Test if scope is present in token
%% @end
%%------------------------------------------------------------------------------
-spec has(token(), kz_term:ne_binary()) -> boolean().
has(Token, Scope) ->
    has_scopes(Token, [Scope], fun lists:all/2).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec has_scopes(token(), kz_term:ne_binaries(), scope_list_fun()) -> boolean().
has_scopes(JWToken, Scopes, ListFun)
  when is_binary(JWToken) ->
    has_scopes(kz_auth_jwt:token(JWToken), Scopes, ListFun);
has_scopes(Token, ScopeList, ListFun) ->
    TokenScopes = scopes(Token),
    Fun = fun(Scope) ->
                  lists:member(Scope, TokenScopes)
          end,
    ListFun(Fun, ScopeList).

%%------------------------------------------------------------------------------
%% @doc Fetches scope by name
%% @end
%%------------------------------------------------------------------------------
-spec available_scopes() -> kz_term:proplist().
available_scopes() ->
    ViewOptions = [],
    get_scopes(?SCOPES_LIST, ViewOptions).

-spec available_scopes(atom() | kz_term:ne_binary() | kz_term:ne_binaries()) -> kz_term:proplist().
available_scopes(Scope) when is_atom(Scope) ->
    available_scopes(kz_term:to_binary(Scope));
available_scopes(<<ScopeBin/binary>>) ->
    Available = get_available_scopes(ScopeBin),
    case props:get_value(ScopeBin, Available) of
        'undefined' -> [];
        Resolved -> [{ScopeBin, Resolved}]
    end;
available_scopes([]) ->
    [];
available_scopes(Scopes) when is_list(Scopes) ->
    [{Scope, Resolved}
     || {Scope, Resolved} <- get_available_scopes(Scopes),
        lists:member(Scope, Scopes)
    ].

-spec get_available_scopes(kz_term:ne_binary() | kz_term:ne_binaries()) -> kz_term:proplist().
get_available_scopes(Key) ->
    case erlang:get(Key) of
        'undefined' ->
            Available = available_scopes(),
            _ = erlang:put({'available_scopes', Key}),
            Available;
        Available -> Available
    end.

%%------------------------------------------------------------------------------
%% @doc Filters a list of scopes by owner
%% @end
%%------------------------------------------------------------------------------
-spec get_scopes(kz_term:ne_binary(), kazoo_data:view_options()) -> kz_json:objects().
get_scopes(View, ViewOptions) ->
    case kz_cache:fetch_local(?SCOPES_CACHE, 'available_scopes') of
        {'ok', Scopes} ->
            Scopes;
        {'error', 'not_found'} ->
            JObjs = fetch_scopes(?SCOPES_CAT, View, ViewOptions),
            Scopes0 = maybe_flatten_scopes(JObjs),
            Scopes = [{Scope, resolve_scopes([Scope], Scopes0)} || {Scope, _} <- Scopes0],
            CacheProps = [{'origin', [{'db', ?SCOPES_CAT, <<"scope">>}]}],
            kz_cache:store_local(?SCOPES_CACHE, 'available_scopes', Scopes, CacheProps),
            Scopes
    end.

-spec fetch_scopes(kz_term:ne_binary(), kz_term:ne_binary(), kazoo_data:view_options()) ->
          kz_json:objects().
fetch_scopes(Db, View, ViewOptions) ->
    case kz_datamgr:get_results(Db, View, ViewOptions) of
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
    ScopeId = kz_json:get_ne_binary_value(<<"key">>, JObj),
    Scopes = kz_json:get_value([<<"value">>], JObj),
    maybe_explode_scopes(ScopeId, Scopes, Acc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
maybe_explode_scopes(_ScopeId, 'undefined', Acc) -> Acc;
maybe_explode_scopes(ScopeId, Scopes, Acc) ->
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
scopes(Token) when is_map(Token) ->
    Routines = [fun init_scopes/1
               ,fun from_claim/1
               ,fun resolve_scopes/1
               ,fun explode_scopes/1
               ],
    #{scopes := Scopes} = kz_maps:exec(Routines, Token),
    Scopes;
scopes(Claim) ->
    scopes(#{payload => kz_json:to_map(Claim)}).

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
resolve_scopes(#{available_scopes := Available
                ,scopes := Scopes
                } = Token) ->
    resolve_scopes(Token#{scopes => kz_term:uniq_list(Scopes ++ Available)});
resolve_scopes(#{scopes := Scopes} = Token) ->
    resolve_scopes(Token#{available_scopes => available_scopes(Scopes)}).

%% Called by available_scopes to resolve/expand superset scopes.
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

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec create_claims(kz_term:proplist()) -> kz_either:either(kz_term:ne_binary(), kz_term:proplist()).
create_claims(Claims) ->
    AccountId = props:get_value(<<"account_id">>, Claims),
    OwnerId = props:get_value(<<"owner_id">>, Claims),

    UserJObj = get_user_doc(AccountId, OwnerId),
    UserScopes = get_user_scopes(UserJObj),
    AccountScopes = get_account_scopes(AccountId),

    ReqScopes = get_requested_scopes(Claims, UserJObj),
    Scope = join(lists:usort(ReqScopes ++ UserScopes ++ AccountScopes)),
    case kz_term:is_empty(Scope) of
        'true' ->
            props:delete_keys([<<"scopes">>], Claims);
        'false' ->
            props:set_value(<<"scope">>, Scope, props:delete_keys([<<"scopes">>], Claims))
    end.

-spec get_requested_scopes(kz_term:proplist(), kz_json:object()) -> kz_term:ne_binaries().
get_requested_scopes(Claims, UserJObj) ->
    Scopes = props:get_value(<<"scopes">>, Claims, []),
    AccountId = props:get_value(<<"account_id">>, Claims),
    case kz_term:is_not_empty(Scopes)
        andalso kz_term:is_not_empty(AccountId)
    of
        'true' ->
            get_requested_scopes(Scopes, AccountId, UserJObj);
        'false' -> []
    end.

-spec get_requested_scopes(kz_term:ne_binaries(), kz_term:ne_binary(), kz_term:api_object()) ->
          kz_term:ne_binaries().
get_requested_scopes(Scopes, AccountId, UserJObj) ->
    AccountType = account_type(AccountId),
    Options = [{'keys', [[ScopeId, [AccountType, PrivLevel]]
                         || ScopeId <- Scopes,
                            PrivLevel <- user_type_query(UserJObj)
                        ]
               }
              ],
    case kz_datamgr:get_results(?SCOPES_CAT, <<"scopes/list_by_id_permission">>, Options) of
        {'ok', [JObj | _]} ->
            kz_json:get_ne_binaries(<<"key">>, JObj, []);
        _ -> []
    end.

-spec account_type(kz_term:ne_binary()) -> kz_term:ne_binary().
account_type(AccountId) ->
    case kapps_util:account_type(AccountId) of
        'regular' -> <<"non-reseller">>;
        Type -> kz_term:to_binary(Type)
    end.

%% Should we allow catch all for account?
%% -spec account_type_query(kz_term:api_ne_binary()) -> kz_term:ne_binaries().
%% account_type_query('undefined') ->
%%     [?CATCH_ALL];
%% account_type_query(AccountId) ->
%%     [kz_term:to_binary(kapps_util:account_type(AccountId)), ?CATCH_ALL].

-spec user_type_query(kz_term:api_ne_binary()) -> kz_term:ne_binaries().
user_type_query('undefined') ->
    [?CATCH_ALL];
user_type_query(UserJObj) ->
    [kzd_users:priv_level(UserJObj), ?CATCH_ALL].

-spec get_user_doc(kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> kz_term:api_object().
get_user_doc(<<AccountId/binary>>, <<OwnerId/binary>>) ->
    case kzd_users:fetch(AccountId, OwnerId) of
        {'ok', JObj} ->
            case kz_doc:type(JObj) =:= kzd_users:type() of
                'true' -> JObj;
                'false' ->
                    lager:warning("doc ~s is not an user doc", [OwnerId]),
                    'undefined'
            end;
        {'error', _Reason} ->
            lager:warning("failed to open doc ~s with error ~p", [OwnerId, _Reason]),
            'undefined'
    end;
get_user_doc(_, _) ->
    'undefined'.

-spec get_user_scopes(kz_term:api_object()) -> kz_term:ne_binaries().
get_user_scopes('undefined') ->
    [];
get_user_scopes(JObj) ->
    [user_type_scope(kzd_users:priv_level(JObj)) | kzd_users:scopes(JObj)].

-spec user_type_scope(kz_term:ne_binary()) -> kz_term:ne_binary().
user_type_scope(PrivLevel) -> <<"user:", PrivLevel/binary>>.

-spec get_account_scopes(kz_term:api_ne_binary()) -> kz_term:ne_binaries().
get_account_scopes(<<AccountId/binary>>) ->
    case kzd_accounts:fetch(AccountId) of
        {'ok', JObj} ->
            case kz_doc:type(JObj) =:= kzd_accounts:type() of
                'true' ->
                    kzd_accounts:scopes(JObj);
                'false' ->
                    lager:warning("doc ~s is not an account", [AccountId]),
                    []
            end;
        {'error', _Reason} ->
            lager:warning("failed to open doc ~s: ~p", [AccountId, _Reason]),
            []
    end;
get_account_scopes(_) ->
    [].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec join(kz_term:ne_binaries()) -> kz_term:ne_binary().
join(ScopeList) -> binstr:join(ScopeList, ?SCOPE_SEP).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec split(kz_term:ne_binary()) -> kz_term:ne_binaries().
split(Scope) -> binary:split(Scope, ?SCOPE_SEP, ['global']).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec scope_doc_id(kz_term:ne_binary()) -> kz_term:ne_binary().
scope_doc_id(<<?SCOPE_DOC_ID_PREFIX, _/binary>> = Id) ->
    normalize_doc_id(Id);
scope_doc_id(Scope) ->
    normalize_doc_id(<<?SCOPE_DOC_ID_PREFIX, Scope/binary>>).

%%------------------------------------------------------------------------------
%% @doc Convert DocId to a CouchDB 3 compatible ID.
%%
%% CouchDB 3 is using the first colon (`:') as the partition name
%% (if db is partitioned). We need to normalize DocId and convert it to a
%% proper format to not break that feature if in future releases we started
%% using it.
%% @end
%%------------------------------------------------------------------------------
-spec normalize_doc_id(kz_term:ne_binary()) -> kz_term:ne_binary().
normalize_doc_id(<<Id/binary>>) ->
    binary:replace(Id, <<":">>, <<"_">>, ['global']).
