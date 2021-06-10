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
                       ,HttpPath::binary() | kz_term:binaries()
                       ,HttpMethod::kz_term:api_ne_binary()
                       ,Rules::kz_json:objects()
                       ) -> boolean().
maybe_deny_access(_, _, 'undefined', _) ->
    'false';
maybe_deny_access(AuthDoc, HttpPath, HttpMethod, Rules) ->
    case kz_term:is_empty(HttpPath) of
        'true' -> 'false';
        'false' ->
            maybe_deny_access1(AuthDoc, path_tokens(HttpPath), HttpMethod, Rules)
    end.

maybe_deny_access1(_, _, _, []) ->
    'false';
maybe_deny_access1(AuthDoc, Paths, HttpMethod, [Rule | Rules]) ->
    case is_match_endpoint(Paths, get_method_rules(HttpMethod, Rule)) of
        'true' -> 'true';
        'false' -> maybe_deny_access(AuthDoc, Paths, HttpMethod, Rules)
    end.

-spec get_method_rules(kz_term:ne_binary(), kz_json:object()) -> kz_term:ne_binaries().
get_method_rules(Method, Rule) ->
    HttpMethod = kz_term:to_lower_binary(Method),
    Precedence = kzd_scope_rules:precedence(Rule),
    get_method_rules(kz_json:get_ne_binaries([<<"rules">>, <<"allow">>, HttpMethod], Rule)
                    ,kz_json:get_ne_binaries([<<"rules">>, <<"deny">>, HttpMethod], Rule)
                    ,kz_json:get_ne_binaries([<<"rules">>, <<"_">>, HttpMethod], Rule)
                    ,Precedence
                    ).

-spec get_method_rules(kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary()) ->
          kz_term:ne_binaries().
get_method_rules('undefined', 'undefined', 'undefined', _Precedence) -> [];
get_method_rules('undefined', 'undefined', CatchAll, _Precedence) -> CatchAll;
get_method_rules('undefined', Deny, _CatchAll, _Precedence) -> Deny;
get_method_rules(Allow, 'undefined', _CatchAll, _Precedence) -> Allow;
get_method_rules(Allow, _Deny, _CatchAll, <<"allow">>) -> Allow;
get_method_rules(_Allow, Deny, _CatchAll, <<"deny">>) -> Deny;
get_method_rules(_Allow, _Deny, _Catchall, _Precedence) -> [].

-spec path_token(binary()) -> binary().
path_token(Token) -> kz_http_util:urldecode(Token).

-spec path_tokens(binary() | [binary()]) -> [binary()].
path_tokens(<<Path/binary>>) ->
    [path_token(Token)
     || Token <- binary:split(Path, <<"/">>, ['global', 'trim'])
    ];
path_tokens([<<>>, _]=ReqPath) ->
    ReqPath;
path_tokens(ReqPath) when is_list(ReqPath) ->
    [<<>> | ReqPath].

-spec is_match_endpoint([binary()], kz_term:ne_binaries()) -> boolean().
is_match_endpoint(_, []) ->
    'false';
is_match_endpoint(Paths, [Rule|Rules]) ->
    case Rule of
        <<"/", _binary>> ->
            check_full_url(Paths, Rule)
                orelse is_match_endpoint(Paths, Rules);
        _Else ->
            check_relative_url(Paths, path_tokens(Rule))
                orelse is_match_endpoint(Paths, Rules)
    end.

check_full_url(Paths, Rule) ->
    kazoo_bindings:matches(binary:split(Rule, <<"/">>, ['global', 'trim'])
                          ,Paths
                          ).

check_relative_url(Paths, [<<>>, Module | _]) ->
    lists:member(Module, Paths);
check_relative_url(_, _) ->
    'false'.
