%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2024, 2600Hz
%%% @doc Kazoo Duo Universal multifactor authenticator.
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_mfa_duo_universal).

-export([authenticate/2
        ,duo_health_check/0
        ,duo_authorize/1
        ,duo_access_token/2, duo_access_token/3
        ,default_provider_settings/0
        ]).

-include("kazoo_auth.hrl").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-elvis([{elvis_style, no_debug_call, disable}]).

-define(DUO_CONFIG_CAT, <<"duo.universal">>).

%%------------------------------------------------------------------------------
%% @doc Takes the Duo configuration and authenticate the `Claims'.
%% First request is always result in a signed signature response. When `Claims'
%% has the Duo response to the sign signature, it will verifies this Duo's response.
%% @end
%%------------------------------------------------------------------------------
-spec authenticate(kz_term:proplist(), kz_json:object()) -> mfa_result().
authenticate(Claims, AcctProviderSettings) ->
    ProviderSettings = kz_json:merge(default_provider_settings(), AcctProviderSettings),

    MFAResp = props:get_value(<<"mfa_resp">>, Claims, kz_json:new()),
    Code = kz_json:get_ne_binary_value(<<"code">>, MFAResp),
    RedirectURI = kz_json:get_ne_binary_value(<<"redirect_uri">>, MFAResp),

    case duo_access_token(Code, RedirectURI, ProviderSettings) of
        {'ok', TokenJObj} ->
            verify_user(Claims, TokenJObj);
        {'error', 401, RespJObj} ->
            UserId = props:get_value(<<"owner_id">>, Claims),
            {'error', 401
            ,maybe_duo_authorize(UserId, ProviderSettings, RespJObj)
            }
    end.

verify_user(Claims, TokenJObj) ->
    UserId = props:get_value(<<"owner_id">>, Claims),
    PrefUsername = kz_json:get_ne_binary_value(<<"preferred_username">>, TokenJObj),

    AuthResult = kz_json:get_json_value(<<"auth_result">>, TokenJObj),

    case <<"allow">> =:= kz_json:get_ne_binary_value(<<"result">>, AuthResult)
        andalso <<"allow">> =:= kz_json:get_ne_binary_value(<<"status">>, AuthResult)
    of
        'false' ->
            lager:info("auth result did not allow the request: ~p", [AuthResult]),
            {'error', 401, kz_json:from_list([{<<"message">>, <<"DUO authentication failed - disallowed">>}])};
        'true' when UserId =/= PrefUsername ->
            lager:info("user id ~s does not match preferred username ~s", [UserId, PrefUsername]),
            {'error', 401, kz_json:from_list([{<<"message">>, <<"DUO authentication failed - DUO username did not match auth user's ID">>}])};
        'true' ->
            lager:info("DUO auth matches expected auth user"),
            {'ok', 'authenticated'}
    end.

%%------------------------------------------------------------------------------
%% @doc Calls the DUO OAuth HealthCheck API to verify your DUO
%% settings are correct
%% see https://duo.com/docs/oauthapi#health-check
%% @end
%%------------------------------------------------------------------------------
-spec duo_health_check() -> 'ok'.
duo_health_check() ->
    duo_health_check(default_provider_settings()).

duo_health_check(ProviderSettings) ->
    ClientId = kz_json:get_ne_binary_value(<<"client_id">>, ProviderSettings),
    APIHostname = kz_json:get_ne_binary_value(<<"api_hostname">>, ProviderSettings),

    BaseURL = <<"https://", APIHostname/binary>>,

    HCURL = health_check_url(BaseURL),

    JWT = duo_jwt(ProviderSettings, ClientId, HCURL),

    FormBody = ["client_id=", ClientId
               ,"&client_assertion=", JWT
               ],

    case kz_http:post(HCURL
                     ,[{<<"Content-Type">>, <<"application/x-www-form-urlencoded">>}]
                     ,FormBody
                     )
    of
        {'ok', 200, _, Body} -> io:format("health check resp: ~s~n", [Body]);
        {'ok', _Code, _Hdrs, _Body} -> io:format("health check resp: ~p: ~p~n~p~n", [_Code, _Hdrs, _Body]);
        {'error', _Error} -> io:format("health check error: ~p~n", [_Error])
    end.

health_check_url(BaseURL) ->
    <<BaseURL/binary, "/oauth/v1/health_check">>.

maybe_duo_authorize('undefined', _ProviderSettings, RespJObj) -> RespJObj;
maybe_duo_authorize(<<UserId/binary>>, ProviderSettings, RespJObj) ->
    case duo_authorize(UserId, ProviderSettings) of
        {'error', _} -> RespJObj;
        {'ok', AuthzProps} ->
            kz_json:set_values(AuthzProps, RespJObj)
    end.

%% @doc setup authorize request with redirect URI for DUO to call back
%% to if successful 2FA.
-spec duo_authorize(kzd_users:doc() | kz_term:ne_binary()) ->
          {'ok', kz_json:json_proplist()} |
          {'error', atom()}.
duo_authorize(UserJObj) ->
    duo_authorize(UserJObj, default_provider_settings()).

duo_authorize(<<UserId/binary>>, ProviderSettings) ->
    ClientId = kz_json:get_ne_binary_value(<<"client_id">>, ProviderSettings),
    APIHostname = kz_json:get_ne_binary_value(<<"api_hostname">>, ProviderSettings),
    RedirectURI = kz_json:get_ne_binary_value(<<"redirect_uri">>, ProviderSettings),

    BaseURL = <<"https://", APIHostname/binary>>,

    AURL = authorize_url(BaseURL),

    State = kz_binary:rand_hex(16),
    JWT = duo_authorize_jwt(ProviderSettings, ClientId, RedirectURI, UserId, State, AURL),

    FormBody = ["response_type=code"
               ,"&client_id=", ClientId
               ,"&request=", JWT
               ,"&redirect_uri=", RedirectURI, ""
               ,"&scope=openid"
               ,"&nonce=", kz_binary:rand_hex(16)
               ],

    case kz_http:post(AURL
                     ,[{<<"Content-Type">>, <<"application/x-www-form-urlencoded">>}]
                     ,FormBody
                     ,[{'autoredirect', 'false'}] %% resp uses Location header
                     )
    of
        {'ok', 303, RespHeaders, _Body} ->
            Location = props:get_value("location", RespHeaders),
            lager:info("location header redirect found"),

            {'ok'
            ,[{<<"duo_redirect">>, iolist_to_binary([BaseURL, Location])}
             ,{<<"duo_state">>, State}
             ]
            };
        {'ok', _Code, _Hdrs, _Body} ->
            lager:info("unexpected authz resp: ~p: ~p", [_Code, _Hdrs]),
            lager:info("body: ~p", [_Body]),
            {'error', 'no_location'};
        {'error', _Error}=Error ->
            lager:info("authz error: ~p", [_Error]),
            Error
    end;
duo_authorize(UserJObj, ProviderSettings) ->
    duo_authorize(kz_doc:id(UserJObj), ProviderSettings).

authorize_url(BaseURL) ->
    <<BaseURL/binary, "/oauth/v1/authorize">>.

%% @doc validates the 'code' returned from Duo 2FA and supplied in an
%% API auth request
%% https://duo.com/docs/oauthapi#access-token
%% RedirectURI is the URI the client supplies to Duo for redirection
%% after the 2FA on Duo's page
-spec duo_access_token(kz_term:ne_binary(), kz_term:ne_binary()) -> mfa_result().
duo_access_token(Code, RedirectURI) ->
    ProviderSettings = default_provider_settings(),

    duo_access_token(Code, RedirectURI, ProviderSettings).

reply_401() ->
    Resp = [{<<"provider_name">>, <<"duo_universal">>}],
    {'error', 401, kz_json:from_list(Resp)}.

-spec duo_access_token(kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_json:object()) ->
          {'ok', kz_json:object()} |
          {'error', non_neg_integer(), kz_json:object()}.
duo_access_token('undefined', _Redirect, _ProviderSettings) ->
    lager:info("no code included, asking for MFA"),
    reply_401();
duo_access_token(_Code, 'undefined', _ProviderSettings) ->
    lager:info("no redirect_uri included, asking for MFA"),
    reply_401();
duo_access_token(Code, RedirectURI, ProviderSettings) ->
    ClientId = kz_json:get_ne_binary_value(<<"client_id">>, ProviderSettings),

    APIHostname = kz_json:get_ne_binary_value(<<"api_hostname">>, ProviderSettings),
    BaseURL = <<"https://", APIHostname/binary>>,

    ATURL = access_token_url(BaseURL),

    JWT = duo_jwt(ProviderSettings, ClientId, ATURL),

    FormBody = ["grant_type=authorization_code"
               ,"&code=", Code
               ,"&redirect_uri=", RedirectURI
               ,"&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
               ,"&client_assertion=", JWT
               ,"&client_id=", ClientId
               ],

    case kz_http:post(ATURL
                     ,[{<<"Content-Type">>, <<"application/x-www-form-urlencoded">>}]
                     ,FormBody
                     )
    of
        {'ok', 200, _, Body} -> handle_access_token_resp(Body);
        {'ok', _Code, _Hdrs, Body} ->
            lager:info("failing access token resp: ~p: ~p", [_Code, _Hdrs]),
            lager:info("~s", [Body]),
            {'error', 401, kz_json:decode(Body)};
        {'error', _Error} ->
            lager:info("failed to make access token req: ~p", [_Error]),
            {'error', 401, kz_json:from_list([{<<"error">>, <<"server_error">>}])}
    end.

handle_access_token_resp(Body) ->
    lager:info("token resp: ~s", [Body]),
    RespJObj = kz_json:decode(Body),

    JWT = kz_json:get_ne_binary_value(<<"id_token">>, RespJObj),

    [_HeaderEncoded, PayloadEncoded, _SigEncoded] = binary:split(JWT, <<".">>, ['global']),

    FixedPayloadEncoded = maybe_fix_encoding(PayloadEncoded),

    PayloadJSON = base64:decode(FixedPayloadEncoded),

    {'ok', kz_json:decode(PayloadJSON)}.

%% @doc yes DUO sends unpadded base64-encoded data
%% see https://www.rfc-editor.org/rfc/rfc7515.html#appendix-C
%%
%% Also, under "Terminology" we read
%%
%%   Base64 encoding using the URL- and filename-safe character set
%%   defined in Section 5 of RFC 4648 [RFC4648], with all trailing '='
%%   characters omitted (as permitted by Section 3.2)
%%
%% Visiting https://www.rfc-editor.org/rfc/rfc7515.html#section-3.2
%% we see nothing about removing padding
%%
%% OTP-23 base64:decode/1 does not have an option to ignore missing padding:
%%   https://www.erlang.org/docs/23/man/base64#decode-1
%% OTP-26+ base64:decode/2 has an options map to ignore padding:
%%   https://www.erlang.org/docs/26/man/base64#type-options
maybe_fix_encoding(PayloadEncoded) ->
    maybe_fix_encoding(PayloadEncoded, byte_size(PayloadEncoded)).

%% must be evenly divisible by 4 bytes, otherwise we're missing padding
maybe_fix_encoding(PayloadEncoded, ByteSize) ->
    case ByteSize rem 4 of % how many bytes short are we?
        0 -> PayloadEncoded;
        1 -> ?LOG_DEBUG("fixing payload with ==="), <<PayloadEncoded/binary, "===">>;
        2 -> ?LOG_DEBUG("fixing payload with =="), <<PayloadEncoded/binary, "==">>;
        3 -> ?LOG_DEBUG("fixing payload with ="), <<PayloadEncoded/binary, "=">>
    end.

-ifdef(TEST).
fix_encoding_test_() ->
    [test_data(N) || N <- lists:seq(1,10)].

test_data(N) ->
    Seq = lists:seq($a, $a+N),
    TestStr = list_to_binary(Seq),

    EncTestStr = base64:encode(TestStr),
    NoPadStr = binary:replace(EncTestStr, <<"=">>, <<>>, ['global']),

    ?_assertEqual(base64:decode(EncTestStr)
                 ,catch base64:decode(maybe_fix_encoding(NoPadStr))
                 ).

-endif.

access_token_url(BaseURL) ->
    <<BaseURL/binary, "/oauth/v1/token">>.

-spec default_provider_settings() -> kz_json:object().
default_provider_settings() ->
    kz_json:from_list([{<<"client_id">>, kapps_config:get_ne_binary(?DUO_CONFIG_CAT, <<"client_id">>)}
                      ,{<<"client_secret">>, kapps_config:get_ne_binary(?DUO_CONFIG_CAT, <<"client_secret">>)}
                      ,{<<"api_hostname">>, kapps_config:get_ne_binary(?DUO_CONFIG_CAT, <<"api_hostname">>)}
                      ,{<<"redirect_uri">>, kapps_config:get_ne_binary(?DUO_CONFIG_CAT, <<"redirect_uri">>)}
                      ]).

%% @doc
%% NOTE: order of keys in the JSON objects are important
%%
%% it does not appear that Duo uses a "canonical" JSON format so you
%% really need to pay attention in their docs to the order of keys in
%% the JSON object; otherwise the signature will not be computed
%% properly and the JWT will be rejected
%% @end
duo_jwt(ProviderSettings, ClientId, URI) ->
    NowS = kz_time:current_unix_tstamp(),
    PayloadJObj = kz_json:from_list([{<<"iss">>, ClientId}
                                    ,{<<"sub">>, ClientId}
                                    ,{<<"aud">>, URI}
                                    ,{<<"exp">>, NowS + ?SECONDS_IN_MINUTE}
                                    ,{<<"jti">>, kz_binary:rand_hex(10)}
                                     %% ,{<<"iat">>, NowS} % optional
                                    ]),

    build_jwt(ProviderSettings, PayloadJObj).

%% building JWT as https://datatracker.ietf.org/doc/html/rfc7519#section-3.1
build_jwt(ProviderSettings, PayloadJObj) ->
    ClientSecret = kz_json:get_ne_binary_value(<<"client_secret">>, ProviderSettings),

    HeaderJObj = kz_json:from_list([{<<"alg">>, <<"HS512">>}
                                   ,{<<"typ">>, <<"JWT">>}
                                   ]),

    HeaderEncoded = kz_json:encode(HeaderJObj, []),
    PayloadEncoded = kz_json:encode(PayloadJObj, []),

    DataEncoded = iolist_to_binary([base64url:encode(HeaderEncoded)
                                   ,".", base64url:encode(PayloadEncoded)
                                   ]),
    Signature = crypto:mac('hmac', 'sha512', ClientSecret, DataEncoded),
    SignatureEncoded = base64url:encode(Signature),
    <<DataEncoded/binary, $., SignatureEncoded/binary>>.

duo_authorize_jwt(ProviderSettings, ClientId, RedirectURI, DUOUsername, State, AURL) ->
    NowS = kz_time:current_unix_tstamp(),

    PayloadJObj = kz_json:from_list([{<<"response_type">>, <<"code">>}
                                    ,{<<"scope">>, <<"openid">>}
                                    ,{<<"exp">>, NowS + ?SECONDS_IN_MINUTE}
                                    ,{<<"client_id">>, ClientId}
                                    ,{<<"redirect_uri">>, RedirectURI}
                                    ,{<<"state">>, State}
                                    ,{<<"duo_uname">>, DUOUsername}
                                    ,{<<"iss">>, ClientId}
                                    ,{<<"aud">>, AURL}
                                    ,{<<"use_duo_code_attribute">>, 'false'}
                                    ]),
    build_jwt(ProviderSettings, PayloadJObj).
