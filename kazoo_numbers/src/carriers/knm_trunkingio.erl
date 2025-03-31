%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2025, 2600Hz
%%% @doc A Number Manager module for carrier: trunking.io
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_trunkingio).
-behaviour(knm_gen_carrier).

-export([info/0]).
-export([is_local/0]).
-export([find_numbers/3]).
-export([acquire_number/1]).
-export([disconnect_number/1]).
-export([is_number_billable/1]).
-export([should_lookup_cnam/0]).
-export([check_numbers/1]).
-export([route_outbound_im/1]).

-include("knm.hrl").

-define(MOD_CONFIG_CAT, <<(?KNM_CONFIG_CAT)/binary, ".trunkingio">>).

-define(IS_SANDBOX_PROVISIONING_TRUE
       ,kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"sandbox_provisioning">>, 'false')
       ).
-define(IS_PROVISIONING_ENABLED
       ,kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"enable_provisioning">>, 'true')
       ).
-define(API_URL, kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"api_url">>, <<"https://api.onsip.com/api">>)).
-define(API_TOKEN, kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"api_token">>)).
-define(API_USERNAME, kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"username">>)).
-define(API_PASSWORD, kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"password">>)).

-define(ACCOUNT_ID, kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"account_id">>)).

-define(MESSAGE_API_URL, kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"messaging_api_url">>, <<"https://messaging.trunking.io/api">>)).

-type api_errors() :: {'error', 'invalid_response' | 'empty_response' | 'no_account_id' | 'noauth' | 'unauthenticated' | atom() | kz_term:ne_binary()}.
-type api_resp() :: {'ok', kz_json:object()} | api_errors().
-type auth_resp() :: {'ok', {'api_token' | 'session_id' | 'login', kz_term:ne_binary()}} | api_errors().
-type api_req() :: {'ok', kz_term:proplist()} | api_errors().
-type handle_action_resp_ret() :: {'ok', kz_json:object() | kz_json:objects()} | {'error', any()}.

%%% API

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec info() -> map().
info() ->
    #{?CARRIER_INFO_MAX_PREFIX => 3
     }.

%%------------------------------------------------------------------------------
%% @doc Is this carrier handling numbers local to the system?
%%
%% <div class="notice">A non-local (foreign) carrier module makes HTTP requests.</div>
%% @end
%%------------------------------------------------------------------------------
-spec is_local() -> boolean().
is_local() -> 'false'.

-spec is_number_billable(knm_phone_number:pn_record()) -> boolean().
is_number_billable(_Number) -> 'true'.

%%------------------------------------------------------------------------------
%% @doc Check with carrier if these numbers are registered with it.
%% @end
%%------------------------------------------------------------------------------
-spec check_numbers(kz_term:ne_binaries()) -> {'ok', kz_json:object()} |
          {'error', any()}.
check_numbers(_Numbers) -> {'error', 'not_implemented'}.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec route_outbound_im(kz_json:object()) -> 'ok' | {'error', any()}.
route_outbound_im(Payload) ->
    Req = [{<<"from">>, kz_im:from(Payload)}
          ,{<<"to">>, message_to(kz_im:to(Payload))}
          ],
    case kz_im:type(Payload) of
        <<"sms">> ->
            Text = kz_im:body(Payload),
            lager:info("sending outbound sms from ~tp to ~tp", [kz_im:from(Payload), kz_im:to(Payload)]),
            handle_outbound_im(Payload, call_messaging(<<"messages/send">>, kz_json:from_list([{<<"text">>, Text} | Req])));
        <<"mms">> ->
            maybe_send_mms(Payload, Req, mime_to_base64_files(kz_im:body(Payload)));
        _Type ->
            lager:debug("unsupported im type ~tp", [_Type]),
            {'error', kz_binary:format("unsupported im type ~tp", [_Type])}
    end.

-spec maybe_send_mms(kz_json:object(), kz_term:proplist(), {'ok', kz_term:ne_binaries()} | {'error', any()}) -> 'ok' | {'error', any()}.
maybe_send_mms(Payload, Req, {'ok', MediaFiles}) ->
    lager:info("sending outbound mms from ~tp to ~tp with ~b media files", [kz_im:from(Payload), kz_im:to(Payload), length(MediaFiles)]),
    handle_outbound_im(Payload, call_messaging(<<"messages/send">>, kz_json:from_list([{<<"base64_media">>, MediaFiles} | Req])));
maybe_send_mms(_Payload, _Req, {'error', _}=Error) ->
    Error.

-spec handle_outbound_im(kz_json:object(), api_resp()) -> 'ok' | {'error', any()}.
handle_outbound_im(_Payload, {'ok', _Resp}) ->
    'ok';
handle_outbound_im(_Payload, {'error', _}=Error) ->
    Error.

%%------------------------------------------------------------------------------
%% @doc Query the system for a quantity of available numbers in a rate center
%% @end
%%------------------------------------------------------------------------------
-spec find_numbers(kz_term:ne_binary(), pos_integer(), knm_search:options()) ->
          knm_search:mod_response().
find_numbers(<<"+", Rest/binary>>, Quantity, Options) ->
    find_numbers(Rest, Quantity, Options);
find_numbers(<<"1", Rest/binary>>, Quantity, Options) ->
    find_numbers(Rest, Quantity, Options);
find_numbers(Number, Quantity, Options) ->
    Resp = make_request(<<"DidBrowseUpstreamProviders">>, did_browse_params(Number, Quantity)),
    MaybeJson = handle_action_resp('find_numbers', Quantity, Resp),
    find_resp(MaybeJson, knm_search:query_id(Options)).

%%------------------------------------------------------------------------------
%% @doc Acquire a given number from the carrier
%% @end
%%------------------------------------------------------------------------------
-spec acquire_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
acquire_number(PN) ->
    Debug = ?IS_SANDBOX_PROVISIONING_TRUE,
    case ?IS_PROVISIONING_ENABLED of
        'false' when Debug ->
            lager:debug("allowing sandbox provisioning"),
            PN;
        'false' ->
            knm_errors:unspecified('provisioning_disabled', PN);
        'true' ->
            N = sanitize_number(
                  knm_phone_number:number(PN)
                 ),
            Resp = make_request(<<"DidRequestPurchaseFromUpstreamProvider">>, did_purchase_params(N)),
            Ret = handle_action_resp('acquire_number', [N], Resp),
            maybe_return(Ret, PN)
    end.

%%------------------------------------------------------------------------------
%% @doc Release a number from the routing table
%% @end
%%------------------------------------------------------------------------------
-spec disconnect_number(knm_phone_number:pn_record()) ->
          knm_phone_number:pn_record().
disconnect_number(PN) ->
    Debug = ?IS_SANDBOX_PROVISIONING_TRUE,
    case ?IS_PROVISIONING_ENABLED of
        'false' when Debug ->
            lager:debug("allowing sandbox provisioning"),
            PN;
        'false' ->
            knm_errors:unspecified('provisioning_disabled', PN);
        'true' ->
            N = sanitize_number(
                  knm_phone_number:number(PN)
                 ),
            Resp = make_request(<<"DidRelease">>, did_release_params(N)),
            Ret = handle_action_resp('disconnect_number', [N], Resp),
            maybe_return(Ret, PN)
    end.

-spec should_lookup_cnam() -> boolean().
should_lookup_cnam() -> 'true'.


%%%=============================================================================
%%% Internals
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec did_browse_params(kz_term:ne_binary(), pos_integer()) -> api_req().
did_browse_params(<<NPA:3/binary, _/binary>>, Quantity) when ?IS_US_TOLLFREE(NPA) ->
    add_tio_account_id([{<<"TnMask">>, NPA}
                       ,{<<"Sequential">>, <<"true">>}
                       ,{<<"Quantity">>, kz_term:to_binary(Quantity)}
                       ]
                      );
did_browse_params(<<NPA:3/binary, _/binary>>, Quantity) when ?IS_US_TOLLFREE_WILDCARD(NPA) ->
    add_tio_account_id([{<<"TnWildCard">>, NPA}
                       ,{<<"Sequential">>, <<"true">>}
                       ,{<<"Quantity">>, kz_term:to_binary(Quantity)}
                       ]
                      );
did_browse_params(<<NPA:3/binary>>, Quantity) ->
    add_tio_account_id([{<<"Npa">>, NPA}
                       ,{<<"Quantity">>, kz_term:to_binary(Quantity)}
                       ]
                      );
did_browse_params(<<NPA:3/binary, NXX:3/binary, _/binary>>, Quantity) ->
    add_tio_account_id([{<<"Npa">>, NPA}
                       ,{<<"Nxx">>, NXX}
                       ,{<<"Quantity">>, kz_term:to_binary(Quantity)}
                       ]
                      ).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec did_purchase_params(kz_term:ne_binary()) -> api_req().
did_purchase_params(<<NPA:3/binary, _/binary>>) when ?IS_US_TOLLFREE(NPA) ->
    add_tio_account_id([{<<"RequestedDids">>, [NPA]}
                       ,{<<"IsTollFree">>, <<"true">>}
                       ]
                      );
did_purchase_params(<<NPA:3/binary, _/binary>>) when ?IS_US_TOLLFREE_WILDCARD(NPA) ->
    add_tio_account_id([{<<"RequestedDids">>, [NPA]}
                       ,{<<"IsTollFree">>, <<"true">>}
                       ]
                      );
did_purchase_params(NPA) ->
    add_tio_account_id([{<<"RequestedDids">>, [NPA]}
                       ,{<<"IsTollFree">>, <<"false">>}
                       ]
                      ).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec did_release_params(kz_term:ne_binary()) -> api_req().
did_release_params(NPA) ->
    add_tio_account_id([{<<"RequestedDids">>, [NPA]}
                       ,{<<"IsTollFree">>, <<"false">>}
                       ]
                      ).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec add_tio_account_id(kz_term:proplist()) -> api_req().
add_tio_account_id(Props) ->
    case ?ACCOUNT_ID of
        'undefined' ->
            lager:error("carrier account id is not defined"),
            {'error', 'no_account_id'};
        AccountId ->
            {'ok', [{<<"AccountId">>, AccountId} | Props]}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec find_resp(handle_action_resp_ret(), kz_term:ne_binary()) -> knm_search:mod_response().
find_resp({'error', _}, _) ->
    {'error', 'datastore_fault'};
find_resp({'ok',JObjs}, QID) ->
    Numbers =
        [{QID, {kz_json:get_value(<<"e164">>, JObj), ?MODULE, ?NUMBER_STATE_DISCOVERY, JObj}}
         || JObj <- JObjs
        ],
    {'ok', Numbers}.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_return(handle_action_resp_ret(), knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
maybe_return({'error', Reason}, PN) ->
    knm_errors:by_carrier(?MODULE, Reason, PN);
maybe_return({'ok', _JObj}, PN) ->
    PN.


%%%=============================================================================
%%% API functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec make_request(kz_term:ne_binary(), api_req()) -> api_resp().
-ifndef(TEST).
make_request(Action, {'ok', Props}) ->
    case get_auth() of
        {'ok', {'api_token', Token}} ->
            do_request(Action, [{<<"ApiToken">>, Token} | Props]);
        {'ok', {'session_id', Token}} ->
            Resp = do_request(Action, [{<<"SessionId">>, Token} | Props]),
            maybe_try_carrier_by_login(Action, Props, Resp);
        {'ok', {'login', Token}} ->
            do_request(Action, [{<<"SessionId">>, Token} | Props]);
        {'error', _}=Error ->
            Error
    end;
make_request(_Action, {'error', _}=Error) ->
    Error.

-spec do_request(kz_term:ne_binary(), kz_term:proplist()) -> api_resp().
do_request(Action, Props0) ->
    Props = [{<<"Action">>, Action}
            ,{<<"Output">>, <<"json">>}
            | Props0
            ],
    Body = unicode:characters_to_binary(kz_http_util:props_to_querystring(Props)),
    Url = ?API_URL,
    Headers = [{"Accept", "*/*"}
              ,{"User-Agent", ?KNM_USER_AGENT}
              ,{"Content-Type", "application/x-www-form-urlencoded"}
              ],
    HTTPOptions = [{'ssl', [{'verify', 'verify_none'}]}
                  ,{'timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  ,{'connect_timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  ],
    lager:info("carrier request: POST ~s with action ~s", [Url, Action]),
    Resp = kz_http:post(Url, Headers, Body, HTTPOptions),
    handle_response(Resp, fun verify_carrier_resp/1).

-spec maybe_try_carrier_by_login(kz_term:ne_binary(), kz_term:proplist(), api_resp()) -> api_resp().
maybe_try_carrier_by_login(Action, Props, {'error', 'unauthenticated'}) ->
    lager:debug("session is expired, maybe try refershing it..."),
    case maybe_auth_by_userpass() of
        {'ok', {_Key, SessionId}} ->
            do_request(Action, [{<<"SessionId">>, SessionId} | Props]);
        Error ->
            Error
    end;
maybe_try_carrier_by_login(_, _, Resp) ->
    Resp.
-else.
make_request(Action, {'ok', Props}) ->
    handle_response({'ok', 200, [], get_response_fixture(Action, Props)}, fun verify_carrier_resp/1);
make_request(_Action, {'error', _}=Error) ->
    Error.

-spec get_response_fixture(kz_term:ne_binary(), kz_term:proplist()) -> binary().
get_response_fixture(<<"DidBrowseUpstreamProviders">>, Props) ->
    case props:get_first_defined([<<"TnMask">>, <<"TnWildCard">>], Props) of
        <<"877">> -> knm_util:fixture("tio_find_tollfree_response.json");
        <<"87*">> -> knm_util:fixture("tio_find_tollfree_response.json");
        _ -> knm_util:fixture("tio_find_npa_response.json")
    end;
get_response_fixture(<<"DidRequestPurchaseFromUpstreamProvider">>, _) ->
    knm_util:fixture("tio_purchase_did.json");
get_response_fixture(<<"DidRelease">>, _) ->
    knm_util:fixture("tio_release_did.json").
-endif.


%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec call_messaging(kz_term:ne_binary(), kz_json:object()) -> api_resp().
call_messaging(Path, ReqJObj) ->
    case get_auth() of
        {'ok', {'session_id', SessionId}} ->
            Resp = call_messaging(Path, ReqJObj, SessionId),
            maybe_try_messaging_by_login(Path, ReqJObj, Resp);
        {'ok', {_Key, AuthToken}} ->
            call_messaging(Path, ReqJObj, AuthToken);
        {'error', _}=Error ->
            Error
    end.

-spec maybe_try_messaging_by_login(kz_term:ne_binary(), kz_json:object(), api_resp()) -> api_resp().
maybe_try_messaging_by_login(Path, ReqJObj, {'error', 'unauthenticated'}) ->
    lager:debug("session is expired, maybe try refershing it..."),
    case maybe_auth_by_userpass() of
        {'ok', {_Key, SessionId}} ->
            call_messaging(Path, ReqJObj, SessionId);
        Error ->
            Error
    end;
maybe_try_messaging_by_login(_, _, Resp) ->
    Resp.

-spec call_messaging(kz_term:ne_binary(), kz_json:object(), kz_term:ne_binary()) -> api_resp().
call_messaging(Path, ReqJObj, AuthToken) ->
    Url = messaging_url(Path),
    Headers = [{"Accept", "application/json"}
              ,{"User-Agent", ?KNM_USER_AGENT}
              ,{"Content-Type", "application/json"}
              ,{"Authorization", kz_term:to_list(<<"Bearer ", AuthToken/binary>>)}
              ],
    HTTPOptions = [{'timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  ,{'connect_timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  | kz_ssl:ssl_opts()
                  ],
    Body = kz_json:encode(kz_json:from_list([{<<"data">>, ReqJObj}])),
    Resp = kz_http:post(Url, Headers, Body, HTTPOptions),
    handle_response(Resp, fun validate_messaging_resp/1).

-spec messaging_url(kz_term:ne_binary()) -> kz_term:ne_binary().
messaging_url(<<"/", Path/binary>>) ->
    messaging_url(Path);
messaging_url(Path) ->
    BaseUrl = ?MESSAGE_API_URL,
    case kz_binary:reverse(BaseUrl) of
        <<"/", _/binary>> ->
            uri_string:resolve(Path, BaseUrl);
        _ ->
            uri_string:resolve(Path, <<BaseUrl/binary, "/">>)
    end.

-spec validate_messaging_resp(binary()) -> api_resp().
validate_messaging_resp(Response) ->
    JObj = kz_json:decode(Response),
    case kz_json:get_ne_binary_value(<<"status">>, JObj) of
        <<"success">> ->
            {'ok', JObj};
        _Status ->
            %% invalid token has http status code 401
            lager:debug("request failed with code ~s and error '~s', full response: ~p"
                       ,[kz_json:get_ne_binary_value(<<"code">>, JObj)
                        ,kz_json:get_ne_binary_value(<<"message">>, JObj)
                        ,JObj
                        ]
                       ),
            {'error', 'unable_to_comply'}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec get_auth() -> auth_resp().
get_auth() ->
    case ?API_TOKEN of
        'undefined' -> maybe_session_id();
        ApiToken ->
            {'ok', {'api_token', ApiToken}}
    end.

%% hopefully we remove this when api_token is there?
-spec maybe_session_id() -> auth_resp().
maybe_session_id() ->
    case kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"session_id">>) of
        'undefined' ->
            maybe_auth_by_userpass();
        SessionId ->
            {'ok', {'session_id', SessionId}}
    end.

%% hopefully we remove this when api_token is there?
-spec maybe_auth_by_userpass() -> auth_resp().
maybe_auth_by_userpass() ->
    case {?API_USERNAME, ?API_PASSWORD} of
        {<<Username/binary>>, <<Password/binary>>} ->
            auth_by_userpass(Username, Password);
        _ ->
            lager:error("carrier authentication is not configured"),
            {'error', 'noauth'}
    end.

%% hopefully we remove this when api_token is there?
-spec auth_by_userpass(kz_term:ne_binary(), kz_term:ne_binary()) -> auth_resp().
auth_by_userpass(Username, Password) ->
    AuthProps = [{<<"Action">>, <<"SessionCreate">>}
                ,{<<"Username">>, Username}
                ,{<<"Password">>, Password}
                ,{<<"Output">>, <<"json">>}
                ],
    Body = kz_http_util:props_to_querystring(AuthProps),
    Url = ?API_URL,
    Headers = [{"Accept", "*/*"}
              ,{"User-Agent", ?KNM_USER_AGENT}
              ,{"Content-Type", "application/x-www-form-urlencoded"}
              ],
    HTTPOptions = [{'ssl', [{'verify', 'verify_none'}]}
                  ,{'timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  ,{'connect_timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  ],
    lager:info("authenticating with carrier: POST ~s", [Url]),
    Resp = kz_http:post(Url, Headers, Body, HTTPOptions),
    case handle_response(Resp, fun verify_carrier_resp/1) of
        {'ok', JObj} ->
            case kz_json:get_ne_binary_value(session_path([<<"SessionId">>]), JObj) of
                'undefined' ->
                    {'error', 'noauth'};
                SessionId ->
                    _ = kapps_config:set_string(?MOD_CONFIG_CAT, <<"session_id">>, SessionId),
                    {'ok', {'login', SessionId}}
            end;
        {'error', _}=Error ->
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_action_resp(atom(), any(), api_resp()) -> handle_action_resp_ret().
handle_action_resp('find_numbers', Quantity, {'ok', JObj}) ->
    DIDs = kz_json:get_list_value(result_path([<<"DidBrowseUpstreamProviders">>, <<"Dids">>, <<"Did">>]), JObj, []),
    lager:debug("found ~p numbers", [length(DIDs)]),
    {'ok',
     [kz_json:from_list(
        [{<<"e164">>, knm_converters:normalize(kz_json:get_ne_binary_value(<<"TelephoneNumber">>, DID))}
        ,{<<"rate_center">>, kz_json:get_ne_binary_value(<<"ReateCenter">>, DID)}
        ,{<<"state">>, kz_json:get_ne_binary_value(<<"State">>, DID)}
        ])
      || DID <- lists:sublist(DIDs, Quantity)
     ]
    };
handle_action_resp('acquire_number', _Numbers, {'ok', RespJObj}) ->
    Path = result_path([<<"DidRequestPurchaseFromUpstreamProvider">>, <<"Dids">>, <<"Did">>]),
    Dids = maybe_list(kz_json:get_value(Path, RespJObj)),
    case [kz_json:from_list([{<<"number">>, kz_json:get_ne_binary_value(<<"Number">>, Did)}])
          || Did <- Dids
         ]
    of
        [Did] ->
            lager:debug("acquired number ~s from carrier", [kz_json:get_ne_binary_value(<<"number">>, Did)]),
            {'ok', Did};
        [] ->
            lager:debug("failed to acquired number from carrier: Number is not available"),
            {'error', <<"Number is not available">>}
    end;
handle_action_resp('disconnect_number', _Numbers, {'ok', RespJObj}) ->
    Path = result_path([<<"DidRequestReleaseFromUpstreamProvider">>, <<"Dids">>, <<"Did">>]),
    Dids = maybe_list(kz_json:get_value(Path, RespJObj)),
    case [kz_json:from_list([{<<"number">>, kz_json:get_ne_binary_value(<<"Number">>, Did)}])
          || Did <- Dids
         ]
    of
        [Did] ->
            lager:debug("released number ~s from carrier", [kz_json:get_ne_binary_value(<<"number">>, Did)]),
            {'ok', Did};
        [] ->
            {'error', 'empty_response'}
    end;
handle_action_resp(_Target, _, {'error',_R}=Error) ->
    Error.

-spec maybe_list(kz_term:api_object() | kz_json:objects()) -> kz_json:objects().
maybe_list('undefined') ->
    [];
maybe_list(List) when is_list(List) ->
    List;
maybe_list(JObj) ->
    case kz_json:is_json_object(JObj)
        andalso kz_json:is_not_empty(JObj)
    of
        'true' ->
            [JObj];
        'false' ->
            []
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_response(kz_http:ret(), fun((binary()) -> api_resp())) -> api_resp().
handle_response({'ok', 200, _Headers, Response}, VerifyFun) ->
    lager:debug("received response"),
    VerifyFun(Response);
handle_response({'ok', Code, _Headers, _Response}, _VerifyFun) ->
    Reason = http_code(Code),
    lager:debug("request error: ~p (~s)", [Code, Reason]),
    {'error', Reason};
handle_response({'error', _}=E, _VerifyFun) ->
    lager:debug("request error: ~p", [E]),
    E.

-spec verify_carrier_resp(binary()) -> api_resp().
verify_carrier_resp(Response) ->
    case kz_json:decode(Response, [{'default', 'undefined'}]) of
        'undefined' ->
            lager:error("request failed with non-JSON response: ~p", [Response]),
            {'error', 'empty_response'};
        JObj ->
            RespIsCompleted = kz_json:is_true(action_path([<<"IsCompleted">>]), JObj),
            ReqIsValid = kz_json:is_true(req_path([<<"IsValid">>]), JObj),
            lager:debug("carrier response, is_completed: ~s, is_req_valid: ~s", [RespIsCompleted, ReqIsValid]),
            verify_carrier_resp(JObj, RespIsCompleted, ReqIsValid)
    end.

verify_carrier_resp(JObj, 'false', 'true') ->
    ErrorCode = kz_json:get_ne_binary_value(action_path([<<"Errors">>, <<"Error">>, <<"Code">>]), JObj, <<"unknown error code">>),
    ErrorMsg = kz_json:get_ne_binary_value(action_path([<<"Errors">>, <<"Error">>, <<"Message">>]), JObj, <<"unknown error">>),
    lager:debug("request failed with error code '~ts' and message '~ts'", [ErrorCode, ErrorMsg]),
    {'error', ErrorMsg};
verify_carrier_resp(JObj, 'false', 'false') ->
    ErrorCode = kz_json:get_ne_binary_value(req_path([<<"Errors">>, <<"Error">>, <<"Code">>]), JObj, <<"unknown error code">>),
    ErrorMsg = kz_json:get_ne_binary_value(req_path([<<"Errors">>, <<"Error">>, <<"Message">>]), JObj, <<"unknown error">>),
    case kz_term:to_lower_binary(ErrorCode) of
        <<"session.authentication">> ->
            lager:error("request failed with error code '~ts' and message '~ts'", [ErrorCode, ErrorMsg]),
            {'error', 'unauthenticated'};
        _ ->
            lager:debug("request failed with error code '~ts' and message '~ts'", [ErrorCode, ErrorMsg]),
            {'error', ErrorMsg}
    end;
verify_carrier_resp(JObj, _, _) ->
    case kz_json:is_empty(JObj) of
        'true' ->
            {'error', 'empty_response'};
        'false'->
            {'ok', JObj}
    end.

-spec http_code(pos_integer()) -> atom().
http_code(401) -> 'unauthenticated';
http_code(403) -> 'unauthorized';
http_code(404) -> 'not_found';
http_code(Code) when Code >= 500 -> 'server_error';
http_code(_Code) -> 'invalid_response'.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
action_path(Path) ->
    [<<"Response">>, <<"Context">>, <<"Action">> | Path].
req_path(Path) ->
    [<<"Response">>, <<"Context">>, <<"Request">> | Path].
session_path(Path) ->
    [<<"Response">>, <<"Sessions">> | Path].
result_path(Path) ->
    [<<"Response">>, <<"Result">> | Path].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec sanitize_number(kz_term:ne_binary()) -> kz_term:ne_binary().
sanitize_number(<<"+", Rest/binary>>) ->
    sanitize_number(Rest);
sanitize_number(Else) ->
    Else.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec message_to(kz_term:ne_binary_or_binaries()) -> kz_term:ne_binaries().
message_to(<<_/binary>> = To) -> [To];
message_to(Tos) -> Tos.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec mime_to_base64_files(kz_term:api_ne_binary()) ->
          {'ok', kz_term:ne_binaries()} |
          {'error', 'empty'}.
mime_to_base64_files('undefined') ->
    {'error', 'empty'};
mime_to_base64_files(BodyTop) ->
    try mimemail:decode(BodyTop) of
        {<<"multipart">>, _SubType, _Headers, _Parameters, Parts} ->
            mime_to_base64_files(Parts, []);
        {Type, SubType, _Headers, _Parameters, Body} ->
            case base64_file(Type, SubType, Body) of
                {'ok', Encoded} -> {'ok', [Encoded]};
                Error -> Error
            end

    catch
        _What:_Why:_ST ->
            lager:debug("body decoding failed with ~p:~p", [_What, _Why]),
            {'error', 'invalid_data'}
    end.

%% someone eventually must enforce these limits:
%% - maximum 5 media files are allowed
%% - each file allowed to be maximum size of 1MB (or less than 1340000 length in Base64 form)
-spec mime_to_base64_files([mimemail:mimetuple()], kz_term:ne_binaries()) ->
          {'ok', kz_term:ne_binaries()} |
          {'error', 'empty'}.
mime_to_base64_files([], Acc) ->
    {'ok', lists:reverse(Acc)};
mime_to_base64_files([{Type, SubType, _Headers, _Parameters, Body} | Rest], Acc) ->
    case base64_file(Type, SubType, Body) of
        {'ok', Encoded} ->
            mime_to_base64_files(Rest, [Encoded | Acc]);
        Error ->
            Error
    end.

-spec base64_file(binary(), binary(), binary()) ->
          {'ok', kz_term:ne_binary()} |
          {'error', 'empty'}.
base64_file(_, _, <<>>) ->
    {'error', 'empty'};
base64_file(Type, SubType, Data) ->
    {'ok', kz_attachment:encode_base64(Type, SubType, Data)}.
