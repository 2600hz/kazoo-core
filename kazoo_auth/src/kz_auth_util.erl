%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_util).

-include("kazoo_auth.hrl").

%%==============================================================================
%% API functions
%%==============================================================================

-export([get_json_from_url/1, get_json_from_url/2]).
-export([fetch_access_code/2, fetch_access_code/3, fetch_access_code/4]).
-export([run/2]).
-export([compose_url/2]).

-spec get_json_from_url(kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
get_json_from_url(Url) ->
    get_json_from_url(Url, []).

-spec get_json_from_url(kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
get_json_from_url(Url, ReqHeaders) ->
    case kz_http:get(kz_term:to_list(Url)
                    ,ReqHeaders
                    ,[{'ssl', kz_ssl:ssl_opts()}]
                    )
    of
        {'ok', 200, _RespHeaders, Body} ->
            JObj = kz_json:decode(Body),
            case kz_term:is_empty(JObj) of
                'true' -> {'error', 'empty'};
                'false' -> {'ok', JObj}
            end;
        {'ok', Code, _RespHeaders, Body} ->
            lager:info("unexpected resp code ~b downloading JSON from ~s : ~s", [Code, Url, Body]),
            {'error', 'unexpected_result'};
        Else ->
            lager:warning("error contacting ~s: ~p", [Url, Else]),
            {'error', Else}
    end.

-spec fetch_access_code(kz_term:ne_binary() | map(), kz_term:ne_binary() ) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_access_code(AppId, AuthorizationCode) ->
    fetch_access_code(AppId, AuthorizationCode, <<"postmessage">>).

-spec fetch_access_code(kz_term:ne_binary() | map(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_access_code(AppId, AuthorizationCode, RedirectURI) ->
    fetch_access_code(AppId, AuthorizationCode, RedirectURI, 'undefined').

%% see https://www.oauth.com/oauth2-servers/pkce/authorization-code-exchange/
-spec fetch_access_code(kz_term:ne_binary() | map(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_access_code(<<AppId/binary>>, AuthorizationCode, RedirectURI, CodeVerifier) ->
    lager:debug("getting auth-app ~p", [AppId]),
    case kz_auth_apps:get_auth_app(AppId, 'app_and_provider') of
        #{} = Map -> fetch_access_code(Map, AuthorizationCode, RedirectURI, CodeVerifier);
        Error -> Error
    end;
fetch_access_code(#{auth_app := #{name := AuthAppName}=AuthApp
                   ,auth_provider := #{access_code_url := URL}
                   }=_Map
                 ,AuthorizationCode
                 ,RedirectURI
                 ,CodeVerifier
                 ) ->
    Secret = maps:get('pvt_secret', AuthApp, 'undefined'),
    ClientId = maps:get('pvt_client_id', AuthApp, AuthAppName),

    Headers = [{"Content-Type", "application/x-www-form-urlencoded"}],

    FormBody = ["client_id=", ClientId
               ,"&redirect_uri=", RedirectURI
               ,maybe_client_secret(Secret)
               ,"&grant_type=authorization_code"
               ,"&code=", AuthorizationCode
               ,maybe_code_verifier(CodeVerifier)
               ],
    case kz_http:post(kz_term:to_list(URL)
                     ,Headers
                     ,FormBody
                     ,[{'ssl', kz_ssl:https_opts()}]
                     )
    of
        {'ok', 200, _RespHeaders, RespJSON} ->
            {'ok', kz_json:decode(RespJSON)};
        {'ok', Code, _RespHeaders, _RespBody} ->
            lager:warning("failure contacting ~s: ~p: ~p", [URL, Code, _RespHeaders]),
            lager:warning("~s", [_RespBody]),
            {'error', Code};
        {'error', _Error}=Else ->
            lager:warning("failure contacting ~s: ~p", [URL, _Error]),
            {'error', Else}
    end.

maybe_client_secret(Secret) ->
    case kz_term:is_empty(Secret) of
        'true' -> [];
        'false' ->
            ["&secret=", Secret]
    end.

maybe_code_verifier(CodeVerifier) ->
    case kz_term:is_empty(CodeVerifier) of
        'true' -> [];
        'false' ->
            ["&code_verifier=", CodeVerifier]
    end.

-spec run(map(), list()) -> {'ok' | 'error', map()}.
run(Token, []) -> {'ok', Token};
run(Token, [Fun | Routines]) ->
    try Fun(Token) of
        #{'error' := _Err}=Error -> {'error', Error};
        {'ok', NewToken} -> run(NewToken, Routines);
        {'done', NewToken} -> {'ok', NewToken};
        {'error', Error} -> {'error', Token#{error => Error}};
        NewToken -> run(NewToken, Routines)
    catch
        _E:_R:ST ->
            lager:debug("exception executing ~p : ~p , ~p, ~p", [Fun, _E, _R, Token]),
            kz_log:log_stacktrace(ST),
            {'error', Token}
    end.

-define(COMPOSE_URL_REGEX, <<"\/\:([^\/]+)">>).
-define(COMPOSE_URL_REGEX_OPTIONS, [{'capture', 'all_but_first', 'binary'}, 'global']).
-define(COMPOSE_URL_REPLACE_OPTIONS, ['global', {'return', 'binary'}]).

-spec compose_url(kz_term:ne_binary(), map()) -> binary().
compose_url(Url, Params) ->
    case re:run(Url, ?COMPOSE_URL_REGEX, ?COMPOSE_URL_REGEX_OPTIONS) of
        {'match', [_ | _] = Fields} -> compose_url(Url, lists:flatten(Fields), Params);
        _ -> Url
    end.

-spec compose_url(kz_term:ne_binary(), kz_term:ne_binaries(), map()) -> binary().
compose_url(Url, Fields, Params) ->
    lists:foldl(compose_url_fun(Params), Url, Fields).

compose_url_fun(Params) ->
    fun(Field, Acc) ->
            V = kz_maps:get(Field, Params, <<>>),
            re:replace(Acc, <<":", Field/binary>>, V, ?COMPOSE_URL_REPLACE_OPTIONS)
    end.
