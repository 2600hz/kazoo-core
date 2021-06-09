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

-export([maybe_deny_scopes/2]).
-include("kazoo_auth.hrl").

%%%------------------------------------------------------------------------------
%%% @doc
%%% @end
%%%------------------------------------------------------------------------------
-spec maybe_deny_scopes(Restrictions::kz_json:objects(), State::map()) -> boolean().
maybe_deny_scopes([], _) ->
    'false';
maybe_deny_scopes([Restriction | Restrictions], #{options := #{http_path := ReqPath}}=State) ->
    case kz_term:is_empty(ReqPath) of
        'true' -> 'false';
        'false' ->
            case is_match_endpoint(path_tokens(ReqPath), get_method_rules(State, Restriction)) of
                'true' -> 'true';
                'false' -> maybe_deny_scopes(Restrictions, State)
            end
    end;
maybe_deny_scopes(_, _) ->
    'false'.

-spec get_method_rules(State::map(), Restriction::kz_json:object()) -> kz_term:ne_binaries().
get_method_rules(State, Restriction) ->
    Options = maps:get('options', State, #{}),
    case maps:get('http_method', Options, 'undefined') of
        'undefined' -> [];
        Method ->
            HttpMethod = kz_term:to_lower_binary(Method),
            Precedence = kz_json:get_ne_binary_value(<<"precedence">>, Restriction),
            get_method_rules(kz_json:get_ne_binaries([<<"allow">>, HttpMethod], Restriction)
                            ,kz_json:get_ne_binaries([<<"deny">>, HttpMethod], Restriction)
                            ,kz_json:get_ne_binaries([<<"_">>, HttpMethod], Restriction)
                            ,Precedence
                            )
    end.

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

-spec path_tokens(map()) -> kz_term:ne_binaries().
path_tokens(#{options := #{http_path := <<Path/binary>>}}) ->
    [path_token(Token)
     || Token <- binary:split(Path, <<"/">>, ['global', 'trim'])
    ];
path_tokens(#{options := #{http_path := [<<>>, _]=ReqPath}}) ->
    ReqPath;
path_tokens(#{options := #{http_path := ReqPath}}) when is_list(ReqPath) ->
    [<<>> | ReqPath].

-spec is_match_endpoint(kz_term:ne_binaries(), kz_term:ne_binaries()) -> boolean().
is_match_endpoint(_, []) ->
    'false';
is_match_endpoint(PathParam, [Rule|Rules]) ->
    case kazoo_bindings:matches(binary:split(Rule, <<"/">>, ['global', 'trim'])
                               ,PathParam
                               )
    of
        'false' -> is_match_endpoint(PathParam, Rules);
        'true' -> 'true'
    end.
