%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_transport_websocket).

-export([maybe_deny_access/3]).

-include("kz_auth_scope.hrl").

%%%------------------------------------------------------------------------------
%%% @doc
%%% @end
%%%------------------------------------------------------------------------------
-spec maybe_deny_access(AuthDoc::kz_json:object(), Routing::kz_term:api_binary(), ScopeRules::kz_json:objects()) -> boolean().
maybe_deny_access(_, 'undefined', _) ->
    'false';
maybe_deny_access(_, <<>>, _) ->
    'false';
maybe_deny_access(_, _, []) ->
    'false';
maybe_deny_access(_AuthDoc, Routing, ScopeRules) ->
    match_rules(binary:split(Routing, <<".">>, ['global']), ScopeRules).

-spec match_rules(kz_term:ne_binaries(), kz_json:objects()) -> boolean().
match_rules(_RoutingParts, []) ->
    'false';
match_rules(RoutingParts, [ScopeRule|ScopeRules]) ->
    Rules = kzd_scope_rules:rules(ScopeRule),
    ScopeName = kzd_scope_rules:scope_name(ScopeRule),
    Allow = kz_json:get_ne_binaries(<<"allow">>, Rules, []),
    Deny = kz_json:get_ne_binaries(<<"deny">>, Rules, []),
    Precedence = kzd_scope_rules:precedence(ScopeRule, <<"allow">>),

    case maybe_deny_access(RoutingParts, Precedence, ScopeName, Allow, Deny) of
        'no_match' -> match_rules(RoutingParts, ScopeRules);
        'allow' -> 'false';
        'deny' -> 'true'
    end.

maybe_deny_access(RoutingParts, <<"allow">>, ScopeName, Allow, Deny) ->
    case matches(RoutingParts, Allow) of
        'no_match' ->
            case matches(RoutingParts, Deny) of
                'no_match' -> 'no_match';
                Binding -> deny_access(RoutingParts, ScopeName, Binding)
            end;
        Binding ->
            allow_access(RoutingParts, ScopeName, Binding)
    end;
maybe_deny_access(RoutingParts, <<"deny">>, ScopeName, Allow, Deny) ->
    case matches(RoutingParts, Deny) of
        'no_match' ->
            case matches(RoutingParts, Allow) of
                'no_match' -> 'no_match';
                Binding -> allow_access(RoutingParts, ScopeName, Binding)
            end;
        Binding ->
            deny_access(RoutingParts, ScopeName, Binding)
    end;
maybe_deny_access(_RoutingParts, _Precedence, _, _, _) ->
    'no_match'.

matches(_, []) ->
    'no_match';
matches(RoutingParts, [Binding | Bindings]) ->
    case kazoo_bindings:matches(binary:split(Binding, <<".">>, ['global']), RoutingParts) of
        'true' -> Binding;
        'false' -> matches(RoutingParts, Bindings)
    end.

deny_access(_RoutingParts, ScopeName, _Binding) ->
    lager:debug("scope ~s denies access to websocket binding", [ScopeName]),
    'deny'.

allow_access(_RoutingParts, ScopeName, _Binding) ->
    lager:debug("scope ~s allows access to websocket binding", [ScopeName]),
    'allow'.
