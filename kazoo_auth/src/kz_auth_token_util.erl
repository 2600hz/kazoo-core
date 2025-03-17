%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_token_util).

%%==============================================================================
%% API functions
%%==============================================================================

-export([add_application/1
        ,add_provider/1
        ,add_discovery/1
        ,verify/1
        ,access_code/1
        ,access_token/1
        ,create_claims/1
        ,id_token/1
        ]).

-include("kazoo_auth.hrl").

-spec add_application(kz_auth_jwt:parsed_token()) -> kz_auth_jwt:parsed_token().
add_application(#{auth_app := _App}=Token) -> Token;
add_application(#{clientId := ClientId}=Token) ->
    Token#{auth_app => kz_auth_apps:get_auth_app(ClientId)};
add_application(#{client_id := ClientId}=Token) ->
    Token#{auth_app => kz_auth_apps:get_auth_app(ClientId)};
add_application(#{}=Token) -> Token.

-spec add_provider(kz_auth_jwt:parsed_token()) -> kz_auth_jwt:parsed_token().
add_provider(#{auth_app := #{pvt_auth_provider := Provider}}=Token) ->
    Token#{auth_provider => kz_auth_providers:get_auth_provider(Provider)};
add_provider(#{claims := #{iss := Issuer}}=Token) ->
    Token#{auth_provider => kz_auth_providers:provider_by_issuer(Issuer)};
add_provider(#{}=Token) -> Token.

-spec add_discovery(kz_auth_jwt:parsed_token()) -> kz_auth_jwt:parsed_token().
add_discovery(#{auth_provider := #{discovery := DiscoveryUrl}}=Token) ->
    lager:debug("getting discovery document from ~s", [DiscoveryUrl]),
    case kz_auth_util:get_json_from_url(DiscoveryUrl) of
        {'ok', JObj} -> Token#{discovery => JObj};
        _ -> Token
    end;
add_discovery(#{auth_provider := #{name := <<"kazoo">>}}=Token) ->
    Token;
add_discovery(#{payload := #{<<"iss">> := <<"http", _/binary>> = Issuer}}=Token) ->
    DiscoveryUrl = <<Issuer/binary, "/.well-known/openid-configuration">>,
    case kz_auth_util:get_json_from_url(DiscoveryUrl) of
        {'ok', JObj} -> Token#{discovery => JObj};
        _ -> Token
    end;
add_discovery(#{}=Token) -> Token.

-spec access_code(kz_auth_jwt:parsed_token()) ->
          kz_auth_jwt:parsed_token() |
          {'error', 'authentication_failed'}.
access_code(#{code := Code
             ,original := JObj
             } = Token
           ) ->
    AppId = kz_json:get_first_defined(?APPID_KEYS, JObj),
    RedirectURI = kz_json:get_first_defined(?REDIRECT_URI_KEYS, JObj, <<"postmessage">>),
    CodeVerifier = kz_json:get_ne_binary_value(<<"code_verifier">>, JObj),
    lager:debug("trying to get access_code ~p for ~p with redirect ~p", [Code, AppId, RedirectURI]),
    case kz_auth_util:fetch_access_code(AppId, Code, RedirectURI, CodeVerifier) of
        {'ok', CodeJObj} ->
            %% access_token and id_token JWTs typically included
            Map = kz_maps:keys_to_atoms(kz_json:to_map(CodeJObj)),
            Map1 = maps:merge(Token, Map),
            Map2 = Map1#{original => kz_json:merge_jobjs(JObj, CodeJObj)},
            maybe_fix_token_type(Map2);
        {'error', FourXX} when is_integer(FourXX), FourXX >= 400, FourXX < 500 ->
            lager:info("4xx error fetching access code: ~p", [FourXX]),
            {'error', 'authentication_failed'};
        {'error', _Error} ->
            lager:error("error fetching access code: ~p", [_Error]),
            Token
    end;
access_code(#{} = Token) -> Token.

-spec maybe_fix_token_type(map()) -> map().
maybe_fix_token_type(#{auth_provider := #{static_token_type := TokenType}} = Token) ->
    Token#{token_type => TokenType};
maybe_fix_token_type(#{token_type := <<"bearer">>
                      ,auth_provider := #{fix_token_type_caps := 'true'}
                      } = Token
                    ) ->
    Token#{token_type => <<"Bearer">>};
maybe_fix_token_type(Token) -> Token.

-spec access_token(map()) -> map().
access_token(#{access_token := <<AccessToken/binary>>
              ,token_type := TokenType
              ,auth_provider := #{static_tokens := 'true'}
              } = Token
            ) ->
    Token#{static_token => kz_json:from_list([{<<"token_type">>, TokenType}
                                             ,{<<"access_token">>, AccessToken}
                                             ])
          };
access_token(#{} = Token) -> Token.

%% send access token to the token_info_url for verification
-spec verify(map()) -> map().
verify(#{verified_token := _}=Token) -> Token;
verify(#{auth_provider := #{token_info_url := <<TokenInfoUrl/binary>>}
        ,access_token := <<AccessToken/binary>>
        }=Token
      ) ->
    RespJObj = verify(TokenInfoUrl, AccessToken),
    Token#{verified_token => RespJObj};
verify(#{}=Token) -> Token#{verified_token => kz_json:new()}.

verify(TokenInfoUrl, AccessToken) ->
    URL = <<TokenInfoUrl/binary, AccessToken/binary>>,
    case kz_http:get(URL) of
        {'ok', 200, _RespHeaders, RespBody} ->
            kz_json:decode(RespBody);
        {'ok', _RespCode, _RespHeaders, _RespBody} ->
            lager:info("unable to verify oauth token: ~p: ~s", [_RespCode, _RespBody]),
            kz_json:new();
        {'error', _E} ->
            lager:info("error contacting ~s: ~p", [URL, _E]),
            kz_json:new()
    end.

-spec create_claims(map()) -> map().
create_claims(#{user_doc := Doc
               ,profile := Profile
               }=Token
             ) ->
    case build_claims(?JWT_CLAIMS, [Doc, Profile]) ++
        build_claims(?JWT_MAP_CLAIMS, Token)
    of
        [] -> Token;
        Claims -> Token#{claims => Claims}
    end;
create_claims(#{}=Token) -> Token.

-type claim_map_input() :: map() | kz_json:objects().

-spec build_claims(kz_term:proplist(), claim_map_input()) -> kz_term:proplist().
build_claims(ClaimsMap, BuildFrom) ->
    build_claims(ClaimsMap, BuildFrom, []).

-spec build_claims(kz_term:proplist(), claim_map_input(), kz_term:proplist()) -> kz_term:proplist().
build_claims([], _, Claims) -> Claims;
build_claims([{K1, K2} | KVs], Map, Claims)
  when is_map(Map) ->
    case kz_maps:get(K1, Map) of
        'undefined' -> build_claims(KVs, Map, Claims);
        V -> build_claims(KVs, Map, [{K2, V} | Claims])
    end;
build_claims([{K1, K2} | KVs], JObjs, Claims)
  when is_list(JObjs) ->
    case kz_json:find(K1, JObjs) of
        'undefined' -> build_claims(KVs, JObjs, Claims);
        V -> build_claims(KVs, JObjs, [{K2, V} | Claims])
    end.

%% decode the id_token for its claims
-spec id_token(map()) -> map().
id_token(#{claims := _Claims}=Token) -> Token;
id_token(#{id_token := IdToken}=Token) ->
    case kz_auth_jwt:decode(IdToken) of
        {'ok', _Header, Claims} -> Token#{claims => Claims};
        _ -> Token
    end;
id_token(#{}=Token) -> Token#{claims => []}.

%%==============================================================================
%% Internal functions
%%==============================================================================
