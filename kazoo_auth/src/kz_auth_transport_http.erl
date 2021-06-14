%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_transport_http).

-export([maybe_deny_access/4]).

-include("kz_auth_scope.hrl").

%%%------------------------------------------------------------------------------
%%% @doc
%%% @end
%%%------------------------------------------------------------------------------
-spec maybe_deny_access(AuthDoc::kz_json:object()
                       ,HttpPath::kz_term:api_binary() | kz_term:binaries()
                       ,HttpMethod::kz_term:api_ne_binary()
                       ,Rules::kz_json:objects()
                       ) -> boolean().
maybe_deny_access(_, 'undefined', _, _) ->
    'false';
maybe_deny_access(_, <<>>, _, _) ->
    'false';
maybe_deny_access(_, [], _, _) ->
    'false';
maybe_deny_access(_, _, 'undefined', _) ->
    'false';
maybe_deny_access(AuthDoc, HttpPath, HttpMethod, ScopeRules) ->
    maybe_deny_access1(AuthDoc, path_tokens(HttpPath), kz_term:to_lower_binary(HttpMethod), ScopeRules).

maybe_deny_access1(_, _, _, []) ->
    'false';
maybe_deny_access1(AuthDoc, Paths, HttpMethod, [ScopeRule | ScopeRules]) ->
    Precedence = kzd_scope_rules:precedence(ScopeRule, <<"allow">>),
    case is_match_endpoint(Paths, HttpMethod, ScopeRule, Precedence) of
        'no_match' -> maybe_deny_access1(AuthDoc, Paths, HttpMethod, ScopeRules);
        'allow' -> 'false';
        'deny' -> 'true'
    end.

-spec path_token(binary()) -> binary().
path_token(Token) -> kz_http_util:urldecode(Token).

-spec path_tokens(binary() | [binary()]) -> [binary()].
path_tokens(<<Path/binary>>) ->
    case [path_token(Token)
          || Token <- binary:split(Path, <<"/">>, ['global', 'trim'])
         ]
    of
        [<<>> | ReqPath] -> ReqPath;
        ReqPath -> ReqPath
    end;
path_tokens([<<>> | ReqPath]) ->
    ReqPath;
path_tokens(ReqPath) when is_list(ReqPath) ->
    ReqPath.

-spec is_match_endpoint([binary()], kz_term:ne_binary(), kz_json:object(), kz_term:ne_binary()) -> boolean().
is_match_endpoint(Paths, HttpMethod, ScopeRule, <<"allow">>) ->
    case is_match_rules(Paths, HttpMethod, ScopeRule, <<"allow">>) of
        {_, 'no_match'} ->
            case is_match_rules(Paths, HttpMethod, ScopeRule, <<"deny">>) of
                {_, 'no_match'} -> 'no_match';
                {MatchedMethod, Path} -> deny_access(Paths, HttpMethod, ScopeRule, MatchedMethod, Path)
            end;
        {MatchedMethod, Path} -> allow_access(Paths, HttpMethod, ScopeRule, MatchedMethod, Path)
    end;
is_match_endpoint(Paths, HttpMethod, ScopeRule, <<"deny">>) ->
    case is_match_rules(Paths, HttpMethod, ScopeRule, <<"deny">>) of
        {_, 'no_match'} ->
            case is_match_rules(Paths, HttpMethod, ScopeRule, <<"allow">>) of
                {_, 'no_match'} -> 'no_match';
                {MatchedMethod, Path} -> allow_access(Paths, HttpMethod, ScopeRule, MatchedMethod, Path)
            end;
        {MatchedMethod, Path} -> deny_access(Paths, HttpMethod, ScopeRule, MatchedMethod, Path)
    end.

is_match_rules(Paths, HttpMethod, ScopeRule, Key) ->
    Rules = kzd_scope_rules:rules(ScopeRule),
    KeyRules = kz_json:get_ne_binaries([Key, HttpMethod], Rules, []),
    CatchAll = kz_json:get_ne_binaries([Key, ?MATCH_ALL_PERMISIONS], Rules, []),
    case matches(Paths, KeyRules) of
        'no_match' -> {?MATCH_ALL_PERMISIONS, matches(Paths, CatchAll)};
        Path -> {HttpMethod, Path}
    end.

matches(_, []) ->
    'no_match';
matches(_, [?MATCH_ALL_PERMISIONS | _]) ->
    ?MATCH_ALL_PERMISIONS;
matches(Paths, [Rule | Rules]) ->
    case Rule of
        <<"/", _/binary>> ->
            case check_full_url(Paths, Rule) of
                'true' -> Rule;
                'false' -> matches(Paths, Rules)
            end;
        _Else ->
            case check_relative_url(Paths, path_tokens(Rule)) of
                'true' -> Rule;
                'false' -> matches(Paths, Rules)
            end
    end.

check_full_url(Paths, Rule) ->
    kazoo_bindings:matches(path_tokens(Rule)
                          ,Paths
                          ).

check_relative_url(Paths, [Module | _]) ->
    lists:member(Module, Paths);
check_relative_url(_, _) ->
    'false'.

deny_access(_Paths, _HttpMethod, ScopeRule, _MatchedMethod, _Path) ->
    lager:debug("scope ~s denies access to http path", [kzd_scope_rules:scope_name(ScopeRule)]),
    'deny'.

allow_access(_Paths, _HttpMethod, ScopeRule, _MatchedMethod, _Path) ->
    lager:debug("scope ~s allows access to http", [kzd_scope_rules:scope_name(ScopeRule)]),
    'allow'.
