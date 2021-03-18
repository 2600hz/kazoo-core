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

-export([create_claims/1]).

-export([join/1
        ,split/1
        ]).

-export([maybe_deny_access/2]).

-export([scope_doc_id/1
        ,restriction_doc_id/1
        ]).

-define(SCOPE_PREFIX, "scope:").
-define(SCOPE_RESTRICTION_PREFIX, "scope_rule:").

-define(SCOPE_DELIM, <<":">>).
-define(SCOPE_SEP, <<" ">>).

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
    Scopes = fetch_scopes(Options),
    maybe_flatten_scopes(Scopes).

-spec available_scopes(atom() | kz_term:ne_binary()) -> kz_term:binaries().
available_scopes(Scope) when is_atom(Scope) ->
    available_scopes(kz_term:to_binary(Scope));
available_scopes(ScopeBin) ->
    Options = [{'key', ScopeBin}
              ,'include_docs'
              ],
    Scopes = fetch_scopes(Options),
    maybe_flatten_scopes(Scopes).

%%------------------------------------------------------------------------------
%% @doc Filters a list of scopes by owner
%% @end
%%------------------------------------------------------------------------------
-spec fetch_scopes(kazoo_data:view_options()) -> kz_term:ne_binaries().
fetch_scopes(ViewOptions) ->
    case kz_datamgr:get_results(?KZ_AUTH_DB, <<"scopes/crossbar_listing">>, ViewOptions) of
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
-spec create_claims(kz_term:proplist()) -> kz_either:either(kz_term:ne_binary(), kz_term:proplist()).
create_claims(Claims) ->
    AccountId = props:get_value(<<"account_id">>, Claims),
    OwnerId = props:get_value(<<"owner_id">>, Claims),

    UserScopes = get_user_scopes(AccountId, OwnerId),
    AccountScopes = get_account_scopes(AccountId),

    create_claims(Claims, UserScopes, AccountScopes).

-spec create_claims(kz_term:proplist()
                   ,kz_either:either(kz_term:binary(), kz_term:ne_binaries())
                   ,kz_either:either(kz_term:binary(), kz_term:ne_binaries())
                   ) -> kz_either:either(kz_term:ne_binary(), kz_term:proplist()).
create_claims(Claims, {'ok', UserScopes}, {'ok', AccountScopes}) ->
    ReqScopes = allowed_request_scopes(props:get_value(<<"scopes">>, Claims, [])),
    Scope = join(lists:usort(ReqScopes ++ UserScopes ++ AccountScopes)),
    {'ok', props:set_value(<<"scope">>, Scope, props:delete_keys([<<"scopes">>], Claims))};
create_claims(_, {'error', _Reason}=Error, _) ->
    lager:debug("failed to get scopes: ~s", [_Reason]),
    Error;
create_claims(_, _, {'error', _Reason}=Error) ->
    lager:debug("failed to get scopes: ~s", [_Reason]),
    Error.

allowed_request_scopes([]) ->
    [];
allowed_request_scopes(Scopes) ->
    Options = [{'keys', Scopes}],
    case kz_datamgr:get_results(?KZ_AUTH_DB, <<"scopes/list_allowed_by_scope_id">>, Options) of
        {'ok', JObjs} ->
            [kzd_scopes:scopes(JObj)
             || JObj <- JObjs,
                kzd_scopes:allow_api_request(JObj)
            ];
        _ -> []
    end.

-spec get_user_scopes(kz_term:api_ne_binary(), kz_term:api_ne_binary()) ->
          kz_either:either(kz_term:binary(), kz_term:ne_binaries()).
get_user_scopes(<<AccountId/binary>>, <<OwnerId/binary>>) ->
    case kzd_users:fetch(AccountId, OwnerId) of
        {'ok', JObj} ->
            case kz_doc:type(JObj) =:= kzd_users:type() of
                'true' ->
                    {'ok', [kzd_users:priv_level(JObj) | kzd_users:scopes(JObj)]};
                'false' ->
                    {'error', kz_binary:format("doc ~s is not an user", [OwnerId])}
            end;
        {'error', _Reason} ->
            {'error', kz_binary:format("failed to open doc ~s with error ~p", [OwnerId, _Reason])}
    end;
get_user_scopes(_, _) ->
    {'ok', []}.

-spec get_account_scopes(kz_term:api_ne_binary()) ->
          kz_either:either(kz_term:binary(), kz_term:ne_binaries()).
get_account_scopes(<<AccountId/binary>>) ->
    case kzd_accounts:fetch(AccountId) of
        {'ok', JObj} ->
            case kz_doc:type(JObj) =:= kzd_accounts:type() of
                'true' ->
                    {'ok', kzd_accounts:scopes(JObj)};
                'false' ->
                    {'error', kz_binary:format("doc ~s is not an account", [AccountId])}
            end;
        {'error', _Reason} ->
            {'error', kz_binary:format("failed to open doc ~s: ~p", [AccountId, _Reason])}
    end;
get_account_scopes(_) ->
    {'ok', []}.

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
    ScopeId = kz_doc:id(JObj),
    Doc = kz_json:get_json_value([<<"doc">>], JObj),
    maybe_explode_scopes(ScopeId, Doc, Acc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
maybe_explode_scopes(_ScopeId, 'undefined', Acc) -> Acc;
maybe_explode_scopes(ScopeId, Doc, Acc) ->
    [{ScopeId, kzd_scopes:scopes(Doc)} | Acc].

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
%% @doc Extract scope binary into list of subscopes (internal usage).
%%
%% api:read_only results in `[api, read_only]'.
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
%% @doc
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

-spec join(kz_term:ne_binaries()) -> kz_term:ne_binary().
join(ScopeList) -> binstr:join(ScopeList, ?SCOPE_SEP).

-spec split(kz_term:ne_binary()) -> kz_term:ne_binaries().
split(Scope) -> binary:split(Scope, ?SCOPE_SEP, ['global']).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_deny_access(AuthDoc::kz_json:object(), Options::kz_term:proplist()) ->
          {'ok', AuthDoc::kz_json:object()} |
          {'error', any()}.
maybe_deny_access(AuthDoc, Options) ->
    Scopes = split(kz_json:get_binary_value(<<"scope">>, AuthDoc, <<>>)),
    Transport = props:get_value('transport', Options),
    maybe_deny_access(AuthDoc, Options, Scopes, Transport).

maybe_deny_access(_, _, [], _) ->
    'false';
maybe_deny_access(_, _, _, 'undefined') ->
    lager:warning("scope transport is undefined"),
    'false';
maybe_deny_access(AuthDoc, Options, Scopes, Transport) ->
    case kz_module:is_exported(Transport, 'maybe_deny_scopes', 3) of
        'true' ->
            call_transport(AuthDoc, Options, Scopes, Transport);
        'false' ->
            lager:debug("invalid scope transport ~s", [Transport]),
            'false'
    end.

call_transport(AuthDoc, Options, Scopes, Transport) ->
    ScopeRestrcitionIds = [restriction_doc_id(Scope) || Scope <- Scopes],
    State = #{auth_doc => kz_json:to_map(AuthDoc)
             ,scopes => Scopes
             ,restrcition_ids => ScopeRestrcitionIds
             ,transport => Transport
             ,options => maps:from_list(Options)
             },
    Funs = [fun fetch_system_restrictions/1
           ,fun fetch_reseller_restrictions/1
           ,fun fetch_account_restrictions/1
           ],
    maybe_deny_scopes(Funs, State).

maybe_deny_scopes([], #{}) ->
    'false';
maybe_deny_scopes([FetchFun | FetchFuns], #{transport := Transport} = State) ->
    Restrictions = FetchFun(State),
    case kz_term:is_not_empty(Restrictions)
        andalso Transport:maybe_deny_scopes(Restrictions, State)
    of
        'true' -> 'true';
        'false' -> maybe_deny_scopes(FetchFuns, State)
    end.

fetch_system_restrictions(State) -> fetch_restrictions(?KZ_AUTH_DB, State).

fetch_reseller_restrictions(#{auth_doc := #{account_id := AccountId}}=State) ->
    case kz_services_reseller:is_reseller(AccountId) of
        'true' -> [];
        'false' ->
            case kz_services_reseller:get_id(AccountId) of
                'undefined' -> [];
                ResellerId -> fetch_restrictions(ResellerId, State)
            end
    end.

fetch_account_restrictions(#{auth_doc := #{account_id := AccountId}}=State) ->
    fetch_restrictions(AccountId, State).

fetch_restrictions(Db, #{restrcition_ids := DocIds}) ->
    case kz_datamgr:open_docs(Db, DocIds) of
        {'ok', JObjs} ->
            [Doc || JObj <- JObjs,
                    Doc <- [kz_json:get_ne_json_value(<<"doc">>, JObj)],
                    Doc =/= 'undefined'
            ];
        {'error', _Reason} ->
            lager:debug("failed to fetch scope restrictions from ~s: ~p", [Db, _Reason]),
            []
    end.

-spec restriction_doc_id(kz_term:ne_binary()) -> kz_term:ne_binary().
restriction_doc_id(<<?SCOPE_RESTRICTION_PREFIX, _/binary>> = Id) -> Id;
restriction_doc_id(Scope) -> <<?SCOPE_RESTRICTION_PREFIX, Scope/binary>>.

-spec scope_doc_id(kz_term:ne_binary()) -> kz_term:ne_binary().
scope_doc_id(<<?SCOPE_PREFIX, _/binary>> = Id) -> Id;
scope_doc_id(Scope) -> <<?SCOPE_PREFIX, Scope/binary>>.
