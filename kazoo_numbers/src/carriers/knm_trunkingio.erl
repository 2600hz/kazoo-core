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

%% no usable with tio
-export([find_numbers/3]).
-export([acquire_number/1]).
-export([disconnect_number/1]).

-export([info/0]).
-export([is_local/0]).
-export([is_number_billable/1]).
-export([should_lookup_cnam/0]).
-export([check_numbers/1]).

%% new api
-export([acquire_number/2]).
-export([disconnect_number/2]).
-export([route_outbound_im/1]).

%% new inbound callback apis
-export([authenticate_req/2, authenticate_req/3]).
-export([validate_im/1]).

%% Shared TIO account related functions
-export([read_settings/1
        ,find_account_settings/1, find_account_settings/2
        ,create_im_webhook/4
        ]).

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

-define(RETRIES, kapps_config:get_non_neg_integer(?MOD_CONFIG_CAT, <<"mms_retries">>, 1)).

-type api_errors() :: {'error', 'invalid_response' | 'empty_response' | 'no_account_id' | 'noauth' | 'unauthenticated' | atom() | kz_term:ne_binary()}.
-type api_resp() :: {'ok', kz_json:object()} | api_errors().
-type knm_optionish() :: knm_options:options() | knm_search:options() | kz_term:proplist().

-type handle_action_resp_ret() :: {'ok', kz_json:object() | kz_json:objects()} | {'error', any()}.

-type system_token_types() :: 'api_token' | 'session_id' | 'login'.
-type system_token() :: {'ok', {system_token_types(), kz_term:ne_binary()}} | api_errors().

-type system_auth() :: {'ok', {'system_auth', system_token_types(), kz_term:ne_binary(), kz_term:ne_binary()}} | api_errors().
-type account_auth() :: {'ok', {'reseller_auth', kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_json:object()}} | api_errors().
-type auth_resp() :: account_auth() | system_auth().

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
    Options = [{'account_id', kz_im:account_id(Payload)}],
    Req = [{<<"from">>, kz_im:from(Payload)}
          ,{<<"to">>, message_to(kz_im:to(Payload, []))}
          ],
    case kz_im:type(Payload) of
        <<"sms">> ->
            Text = kz_im:body(Payload),
            lager:info("sending outbound sms from ~tp to ~tp", [kz_im:from(Payload), kz_im:to(Payload)]),
            handle_outbound_im(Payload, call_messaging(Options, <<"messages/send">>, kz_json:from_list([{<<"text">>, Text} | Req])));
        <<"mms">> ->
            maybe_send_mms(Payload, Req, mime_to_base64_files(kz_im:body(Payload)));
        _Type ->
            lager:debug("unsupported im type ~tp", [_Type]),
            {'error', kz_binary:format("unsupported im type ~tp", [_Type])}
    end.

-spec maybe_send_mms(kz_json:object(), kz_term:proplist(), {'ok', kz_term:ne_binaries()} | {'error', any()}) -> 'ok' | {'error', any()}.
maybe_send_mms(Payload, Req, {'ok', MediaFiles}) ->
    Options = [{'account_id', kz_im:account_id(Payload)}],
    lager:info("sending outbound mms from ~tp to ~tp with ~b media files", [kz_im:from(Payload), kz_im:to(Payload), length(MediaFiles)]),
    handle_outbound_im(Payload, call_messaging(Options, <<"messages/send">>, kz_json:from_list([{<<"base64_media">>, MediaFiles} | Req])));
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
    Action = <<"DidBrowseUpstreamProviders">>,
    Resp = make_request(Action, Options, did_browse_params(Number, Quantity)),
    MaybeJson = handle_action_resp('find_numbers', Quantity, Resp),
    find_resp(MaybeJson, knm_search:query_id(Options)).

%%------------------------------------------------------------------------------
%% @doc Acquire a given number from the carrier
%% @end
%%------------------------------------------------------------------------------
-spec acquire_number(knm_phone_number:pn_record()) -> no_return().
acquire_number(PN) ->
    knm_errors:by_carrier(?MODULE, 'not_implemented', PN).

-spec acquire_number(knm_phone_number:pn_record(), knm_options:options()) -> knm_phone_number:pn_record().
acquire_number(PN, Options) ->
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
            Action = <<"DidRequestPurchaseFromUpstreamProvider">>,
            Resp = make_request(Action, ensure_account_id(PN, Options), did_purchase_params(N)),
            Ret = handle_action_resp('acquire_number', [N], Resp),
            maybe_return(Ret, PN)
    end.

%%------------------------------------------------------------------------------
%% @doc Release a number from the routing table
%% @end
%%------------------------------------------------------------------------------
-spec disconnect_number(knm_phone_number:pn_record()) -> no_return().
disconnect_number(PN) ->
    knm_errors:by_carrier(?MODULE, 'not_implemented', PN).

-spec disconnect_number(knm_phone_number:pn_record(), knm_options:options()) ->
          knm_phone_number:pn_record().
disconnect_number(PN, Options) ->
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
            Action = <<"DidRelease">>,
            Resp = make_request(Action, ensure_account_id(PN, Options), [{<<"Numbers">>, [N]}]),
            Ret = handle_action_resp('disconnect_number', [N], Resp),
            maybe_return(Ret, PN)
    end.

-spec should_lookup_cnam() -> boolean().
should_lookup_cnam() -> 'true'.

-spec ensure_account_id(knm_phone_number:pn_record(), knm_options:options()) -> knm_options:options().
ensure_account_id(PN, Options) ->
    case knm_phone_number:assigned_to(PN) of
        'undefined' ->
            Options;
        AccountId ->
            props:insert_value('account_id', AccountId, Options)
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec authenticate_req(kz_json:object(), cowboy:http_headers()) -> boolean().
authenticate_req(Payload, Headers) ->
    Secret = kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"inbound_hook_secret">>),
    check_req_hmac(Payload, Headers, Secret).

-spec authenticate_req(kz_json:object(), cowboy:http_headers(), kz_term:api_ne_binary()) -> boolean().
authenticate_req(Payload, Headers, AccountId) ->
    AllowSystem = kapps_config:is_true(?MOD_CONFIG_CAT, <<"use_system_tio_account">>, 'false'),
    case find_account_settings(AccountId, 'false') of
        {'ok', Settings} ->
            lager:info("found trunking.io settings from account ~s", [kz_doc:account_id(Settings)]),
            Secret = kzd_trunkingio_settings:pvt_im_webhook_secret(Settings),
            check_req_hmac(Payload, Headers, Secret);
        {'error', 'not_found'=_Reason} when AllowSystem ->
            lager:debug("failed to find trunking.io settings for the account ~s: ~p, checking for system account", [AccountId, _Reason]),
            authenticate_req(Payload, Headers);
        {'error', 'invalid_db_name'=_Reason} when AllowSystem ->
            lager:debug("failed to find trunking.io settings for the account ~s: ~p, checking for system account", [AccountId, _Reason]),
            authenticate_req(Payload, Headers);
        {'error', _Reason} ->
            lager:debug("failed to find trunking.io settings for the account ~s: ~p", [AccountId, _Reason]),
            'false'
    end.

-spec check_req_hmac(kz_json:object(), cowboy:http_headers() | kz_term:api_ne_binary(), kz_term:api_ne_binary()) -> boolean().
check_req_hmac(Payload, #{}=Headers, Secret) ->
    check_req_hmac(Payload, maps:get(<<"signature">>, Headers, 'undefined'), Secret);
check_req_hmac(_Payload, _Headers, 'undefined') ->
    lager:info("inbound hook secret is undefined"),
    'false';
check_req_hmac(_Payload, 'undefined', _Secret) ->
    lager:info("request signature http header is undefined"),
    'false';
check_req_hmac(Payload, Signature, Secret) ->
    Canonical = kz_json:encode(Payload, ['canonical']),
    Hmac = binary:encode_hex(crypto:mac('hmac', 'sha256', Secret, Canonical), 'lowercase'),
    kz_term:to_lower_binary(Signature) =:= Hmac.

%%------------------------------------------------------------------------------
%% @doc Read the trunkingio settings of the account. It is expected that the caller
%% already checked the account id is a reseller or used its reseller id as
%% account id here.
%% @end
%%------------------------------------------------------------------------------
-spec read_settings(kz_term:api_ne_binary()) -> {'ok', kz_json:object()} | kz_datamgr:data_error().
read_settings(AccountId) ->
    read_settings(AccountId, 'true').

-spec read_settings(kz_term:api_ne_binary(), boolean()) -> {'ok', kz_json:object()} | kz_datamgr:data_error().
read_settings('undefined', _NewOnNotFound) ->
    {'error', 'invalid_db_name'};
read_settings(AccountId, NewOnNotFound) ->
    case kz_datamgr:open_cache_doc(AccountId, kzd_trunkingio_settings:db_id()) of
        {'ok', _} = OK -> OK;
        {'error', 'not_found'} when NewOnNotFound ->
            {'ok', kzd_trunkingio_settings:new(AccountId)};
        {'error', _} = Error ->
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc Try to find reseller's Trunkingio settings, uses account id
%% and checks if it is a reseller or try find its reseller.
%%
%% Internal functions can pass already fetched settings as
%% `trunkingio_settings' option.
%%
%% Option can be either default knm options genereated by Crossbar
%% or knm_search. Internal function may ensure at least account id is set
%% or set it from phonenumber assigned_to field.
%% @end
%%------------------------------------------------------------------------------
-spec find_account_settings(kz_term:api_ne_binary() | knm_optionish()) ->
          {'ok', kz_json:object()} | kz_datamgr:data_error().
find_account_settings(AccountIdOrKnmOptions) ->
    find_account_settings(AccountIdOrKnmOptions, 'true').

-spec find_account_settings(kz_term:api_ne_binary() | knm_optionish(), boolean()) ->
          {'ok', kz_json:object()} | kz_datamgr:data_error().
find_account_settings('undefined', _NewOnNotFound) ->
    {'error', 'datastore_fault'};
find_account_settings(<<AccountId/binary>>, NewOnNotFound) ->
    find_account_settings([{'account_id', AccountId}], NewOnNotFound);
find_account_settings(Options, NewOnNotFound) when is_list(Options) ->
    find_account_settings(Options, NewOnNotFound, props:get_value('trunkingio_settings', Options)).

-spec find_account_settings(kz_term:api_ne_binary() | knm_optionish(), boolean(), kz_term:api_object()) ->
          {'ok', kz_json:object()} | kz_datamgr:data_error().
find_account_settings(Options0, NewOnNotFound, 'undefined') ->
    %% short circuit knm_options and knm_search options for easier key access
    Options = props:set_values(props:get_value('crossbar', Options0, []), Options0),
    AccountId = props:get_ne_binary_value('account_id', Options),

    %% use options, if available, then fallback to get reseller id
    case props:is_true('is_reseller', Options, 'false')
        orelse kz_services_reseller:is_reseller(AccountId)
    of
        'true' -> read_settings(AccountId, NewOnNotFound);
        'false' ->
            lager:info("account is not reseller, finding its reseller"),
            ResellerId = props:get_ne_binary_value('reseller_id', Options),
            maybe_find_reseller_settings(ResellerId, AccountId, NewOnNotFound)
    end;
find_account_settings(_Options, _NewOnNotFound, Settings) ->
    lager:debug("use trunkingio settings from options"),
    {'ok', Settings}.

-spec maybe_find_reseller_settings(kz_term:api_ne_binary(), kz_term:api_ne_binary(), boolean()) ->
          {'ok', kz_json:object()} | kz_datamgr:data_error().
maybe_find_reseller_settings('undefined', 'undefined', _NewOnNotFound) ->
    {'error', 'invalid_db_name'};
maybe_find_reseller_settings('undefined', AccountId, NewOnNotFound) ->
    case kz_services_reseller:get_id(AccountId) of
        'undefined' -> {'error', 'invalid_db_name'};
        ResellerId -> read_settings(ResellerId, NewOnNotFound)
    end;
maybe_find_reseller_settings(ResellerId, _AccountId, NewOnNotFound) ->
    read_settings(ResellerId, NewOnNotFound).

%%------------------------------------------------------------------------------
%% @doc Create the required webhook on trunkingio for receiving IM messages.
%% It is expected that the caller already id checked the account is a reseller
%% or use its reseller id as account id.
%% @end
%%------------------------------------------------------------------------------
-spec create_im_webhook(kz_json:object(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', kz_term:ne_binary()}.
create_im_webhook(Doc, AccountId, ClusterUrl, AuthToken) ->
    Options = [{'account_id', AccountId}
              ,{'trunkingio_settings', Doc}
              ,{'auth_token', AuthToken}
              ],
    Secret = kz_binary:rand_hex(16),
    HookUrl = knm_im:carrier_inbound_url(ClusterUrl, AccountId, <<"trunkingio">>),
    Payload = kz_json:from_list(
                [{<<"display_name">>, <<"2600hz inbound messaging integration">>}
                ,{<<"url">>, HookUrl}
                ,{<<"secret">>, Secret}
                ]
               ),

    lager:info("creating trunkingio webhook for ~s to receive sms/mms", [AccountId]),
    case call_messaging(Options, <<"webhooks/outbound_dlr">>, Payload) of
        {'ok', JObj} ->
            setup_im_webhook(Doc, kz_json:get_ne_binary_value([<<"data">>, <<"id">>], JObj), Secret);
        {'error', _} ->
            {'error', <<"unable to create trunkingio outbound messaging webhook">>}
    end.

-spec setup_im_webhook(kz_json:object(), kz_term:api_ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', kz_term:ne_binary()}.
setup_im_webhook(_Doc, 'undefined', _Secret) ->
    lager:error("we created trunkingio outbound webhook, but tio msg api gave us no webhook id"),
    {'error', <<"got empty webhook id when creating trunkingio outbound messaging webhook">>};
setup_im_webhook(Doc, Id, Secret) ->
    Routines = [{fun kzd_trunkingio_settings:set_pvt_im_webhook_id/2, Id}
               ,{fun kzd_trunkingio_settings:set_pvt_im_webhook_secret/2, Secret}
               ],
    {'ok', kz_doc:setters(Doc, Routines)}.

%%%=============================================================================
%%% Internals
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec did_browse_params(kz_term:ne_binary(), pos_integer()) -> kz_term:proplist().
did_browse_params(<<NPA:3/binary, _/binary>>, Quantity) when ?IS_US_TOLLFREE(NPA) ->
    [{<<"TnMask">>, NPA}
    ,{<<"Quantity">>, kz_term:to_binary(adjust_max_quantity(Quantity))}
    ];
did_browse_params(<<NPA:3/binary, _/binary>>, Quantity) when ?IS_US_TOLLFREE_WILDCARD(NPA) ->
    [{<<"TnWildCard">>, NPA}
    ,{<<"Quantity">>, kz_term:to_binary(adjust_max_quantity(Quantity))}
    ];
did_browse_params(<<NPA:3/binary>>, Quantity) ->
    [{<<"Npa">>, NPA}
    ,{<<"Quantity">>, kz_term:to_binary(adjust_max_quantity(Quantity))}
    ];
did_browse_params(<<NPA:3/binary, NXX:3/binary, _/binary>>, Quantity) ->
    [{<<"Npa">>, NPA}
    ,{<<"Nxx">>, NXX}
    ,{<<"Quantity">>, kz_term:to_binary(adjust_max_quantity(Quantity))}
    ].

adjust_max_quantity(Quantity) ->
    adjust_max_quantity(Quantity, kapps_config:get_integer(?MOD_CONFIG_CAT, <<"max_search_quantity">>, 100)).

adjust_max_quantity(Quantity, MaxAllowed) ->
    case Quantity =< MaxAllowed of
        'true' -> Quantity;
        'false' -> MaxAllowed
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec did_purchase_params(kz_term:ne_binary()) -> kz_term:proplist().
did_purchase_params(<<NPA:3/binary, _/binary>>) when ?IS_US_TOLLFREE(NPA) ->
    [{<<"RequestedDids">>, [NPA]}
    ,{<<"IsTollFree">>, <<"true">>}
    ];
did_purchase_params(<<NPA:3/binary, _/binary>>) when ?IS_US_TOLLFREE_WILDCARD(NPA) ->
    [{<<"RequestedDids">>, [NPA]}
    ,{<<"IsTollFree">>, <<"true">>}
    ];
did_purchase_params(NPA) ->
    [{<<"RequestedDids">>, [NPA]}
    ,{<<"IsTollFree">>, <<"false">>}
    ].

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
-spec make_request(kz_term:ne_binary(), knm_optionish(), kz_term:proplist()) -> api_resp().
-ifndef(TEST).
make_request(Action, Options, Props) ->
    case get_auth(Options) of
        {'ok', {'reseller_auth', 'undefined', AuthToken, Settings}} ->
            AccountId = kzd_trunkingio_settings:pvt_tio_account_id(Settings),
            NewProps = add_account_id(AccountId, Props),
            do_request(Action, [{"X-Auth-Token", kz_term:to_list(AuthToken)}], NewProps);
        {'ok', {'reseller_auth', ApiToken, 'undefined', Settings}} ->
            AccountId = kzd_trunkingio_settings:pvt_tio_account_id(Settings),
            NewProps = add_account_id(AccountId, [{<<"ApiToken">>, ApiToken} | Props]),
            do_request(Action, NewProps);
        {'ok', {'reseller_auth', ApiToken, AuthToken, Settings}} ->
            AccountId = kzd_trunkingio_settings:pvt_tio_account_id(Settings),
            NewProps = add_account_id(AccountId, [{<<"ApiToken">>, ApiToken} | Props]),
            Resp = do_request(Action, NewProps),
            %% TODO: needs re-work when we know how to renew TIO api token
            maybe_try_reseller_auth_token(Action, AuthToken, Settings, NewProps, Resp);
        {'ok', {'system_auth', Type, Token, SystemAccountId}} ->
            NewProps = add_account_id(SystemAccountId, Props),
            try_system(Action, NewProps, Type, Token);
        {'error', _}=Error ->
            Error
    end.

add_account_id(AccountId, Props) ->
    [{<<"AccountId">>, AccountId} | Props].

try_system(Action, Props, 'api_token', Token) ->
    do_request(Action, [{<<"ApiToken">>, Token} | Props]);
try_system(Action, Props, 'session_id', Token) ->
    Resp = do_request(Action, [{<<"SessionId">>, Token} | Props]),
    maybe_try_carrier_by_login(Action, Props, Resp);
try_system(Action, Props, 'login', Token) ->
    do_request(Action, [{<<"SessionId">>, Token} | Props]).

-spec do_request(kz_term:ne_binary(), kz_term:proplist()) -> api_resp().
do_request(Action, Props0) ->
    do_request(Action, [], Props0).

-spec do_request(kz_term:ne_binary(), kz_term:proplist(), kz_term:proplist()) -> api_resp().
do_request(Action, Headers0, Props0) ->
    Props = [{<<"Action">>, Action}
            ,{<<"Output">>, <<"json">>}
            | Props0
            ],
    Body = unicode:characters_to_binary(kz_http_util:props_to_querystring(Props)),
    Url = ?API_URL,
    Headers = [{"Accept", "*/*"}
              ,{"User-Agent", ?KNM_USER_AGENT}
              ,{"Content-Type", "application/x-www-form-urlencoded"}
              ,{"X-Kazoo-Cluster-Id", kz_term:to_list(kzd_cluster:id())}
              | Headers0
              ],
    HTTPOptions = [{'timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  ,{'connect_timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  | kz_ssl:https_opts()
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

-spec maybe_try_reseller_auth_token(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), api_resp()) ->
          api_resp().
maybe_try_reseller_auth_token(_Action, _AuthToken, _Settings, _Props, {'error', 'unauthenticated'}) ->
    lager:debug("api token is expired, all is lost..."),
    %% TODO: needs re-work when we know how to renew TIO api token
    {'error', 'unauthenticated'};
maybe_try_reseller_auth_token(_, _, _, _, Resp) ->
    Resp.
-else.
make_request(Action, _Options, Props) ->
    handle_response({'ok', 200, [], get_response_fixture(Action, Props)}, fun verify_carrier_resp/1).

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
-spec call_messaging(kz_term:proplist(), kz_term:ne_binary(), kz_json:object()) -> api_resp().
call_messaging(Options, Path, ReqJObj) ->
    case get_auth(Options) of
        {'ok', {'reseller_auth', 'undefined', AuthToken, _Settings}} ->
            Headers = [{"X-Auth-Token", AuthToken}],
            do_call_messaging(Path, ReqJObj, Headers);
        {'ok', {'reseller_auth', ApiToken, 'undefined', _Settings}} ->
            %% TODO: needs re-work when we know how to renew TIO api token
            Headers = [{"Authorization", kz_term:to_list(<<"Bearer ", ApiToken/binary>>)}],
            do_call_messaging(Path, ReqJObj, Headers);
        {'ok', {'reseller_auth', _ApiToken, AuthToken, _Settings}} ->
            Headers = [{"X-Auth-Token", AuthToken}],
            do_call_messaging(Path, ReqJObj, Headers);
        {'ok', {'system_auth', 'session_id', SessionId, _SystemAccountId}} ->
            Headers = [{"Authorization", kz_term:to_list(<<"Bearer ", SessionId/binary>>)}],
            Resp = do_call_messaging(Path, ReqJObj, Headers),
            maybe_try_messaging_by_login(Path, ReqJObj, Resp);
        {'ok', {'system_auth', _, AuthToken, _SystemAccountId}} ->
            Headers = [{"Authorization", kz_term:to_list(<<"Bearer ", AuthToken/binary>>)}],
            do_call_messaging(Path, ReqJObj, Headers);
        {'error', _}=Error ->
            Error
    end.

-spec maybe_try_messaging_by_login(kz_term:ne_binary(), kz_json:object(), api_resp()) -> api_resp().
maybe_try_messaging_by_login(Path, ReqJObj, {'error', 'unauthenticated'}) ->
    lager:debug("session is expired, maybe try refershing it..."),
    case maybe_auth_by_userpass() of
        {'ok', {_Key, SessionId}} ->
            Headers = [{"Authorization", kz_term:to_list(<<"Bearer ", SessionId/binary>>)}],
            do_call_messaging(Path, ReqJObj, Headers);
        Error ->
            Error
    end;
maybe_try_messaging_by_login(_, _, Resp) ->
    Resp.

-spec do_call_messaging(kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> api_resp().
do_call_messaging(Path, ReqJObj, Headers0) ->
    Url = messaging_url(Path),
    Headers = [{"Accept", "application/json"}
              ,{"User-Agent", ?KNM_USER_AGENT}
              ,{"Content-Type", "application/json"}
              ,{"X-Kazoo-Cluster-Id", kz_term:to_list(kzd_cluster:id())}
              | Headers0
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
%% @doc Currently Trunkingio need valid AuthToken JWT for authenticating the account
%% if the account (or its reseller) is linked to TIO. This is the intend usage.
%%
%% A reseller account can setup to use TIO and provide services to their sub-account.
%%
%% By default, if account is either not linked or we can find TIO settings
%% or there is no account id, as last attempt we may assume Trunkingio is configured
%% system-wide, and the user its on their own to figure out how and deal with Trunkingio.
%% @end
%%------------------------------------------------------------------------------
-spec get_auth(knm_optionish()) -> auth_resp().
get_auth(Options) ->
    case get_account_auth(Options) of
        {'ok', _} = OK ->
            OK;
        {'error', 'not_found'} ->
            maybe_get_system_auth(Options);
        {'error', 'invalid_db_name'} ->
            %% no account id, maybe try system auth?
            maybe_get_system_auth(Options);
        {'error', _}=Error ->
            Error
    end.

-spec get_account_auth(knm_optionish()) -> account_auth().
get_account_auth(Options) ->
    AccountId = props:get_ne_binary_value('account_id', Options),

    lager:info("looking up trunkingio settings for the account ~s", [AccountId]),

    case find_account_settings(Options, 'false') of
        {'ok', Settings} ->
            lager:info("found settings from account ~s", [kz_doc:account_id(Settings)]),
            get_account_auth(Options, Settings, kzd_trunkingio_settings:is_linked(Settings));
        {'error', _Reason} = Error ->
            Error
    end.

-spec get_account_auth(kz_term:proplist(), kz_json:object(), boolean()) -> account_auth().
get_account_auth(_Options, _Settings, 'false') ->
    lager:info("account is not linked to trunkingio, cannot call carrier"),
    {'error', 'noauth'};
get_account_auth(Options, Settings, 'true') ->
    case {kzd_trunkingio_settings:pvt_tio_api_token(Settings)
         ,props:get_ne_binary_value('auth_token', Options)
         }
    of
        {'undefined', 'undefined'} ->
            AccountId = kz_doc:account_id(Settings),
            ShouldJWT = kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"generate_jwt_auth_token">>, 'true'),
            maybe_generate_auth_token(AccountId, Settings, ShouldJWT);
        {ApiToken, AuthToken} ->
            {'ok', {'reseller_auth', ApiToken, AuthToken, Settings}}
    end.

-spec maybe_generate_auth_token(kz_term:api_ne_binary(), kz_json:object(),boolean()) -> account_auth().
maybe_generate_auth_token('undefined', _Settings, _) ->
    lager:info("account on the trunkingio_settings is undefined"),
    {'error', 'noauth'};
maybe_generate_auth_token(AccountId, Settings, 'true') ->
    Claims = [{<<"account_id">>, AccountId}],
    case kz_auth:create_token(Claims) of
        {'ok', AuthToken} ->
            {'ok', {'reseller_auth', 'undefined', AuthToken, Settings}};
        {'error', _Reason} ->
            lager:info("cannot generate jwt auth_token for reseller ~s: ~p", [AccountId, _Reason]),
            {'error', 'nouath'}
    end;
maybe_generate_auth_token(_AccountId, _Settings, 'false') ->
    lager:info("no api token on the trunkingio settings, cannot call carrier"),
    {'error', 'noauth'}.

-spec maybe_get_system_auth(knm_optionish()) -> system_auth().
maybe_get_system_auth(Options) ->
    AllowSystem = kapps_config:is_true(?MOD_CONFIG_CAT, <<"use_system_tio_account">>, 'false'),
    maybe_get_system_auth(Options, AllowSystem).

-spec maybe_get_system_auth(knm_optionish(), boolean()) -> system_auth().
maybe_get_system_auth(_Options, 'true') ->
    get_system_auth(?ACCOUNT_ID);
maybe_get_system_auth(_Options, 'false') ->
    {'error', 'noauth'}.

-spec get_system_auth(kz_term:api_ne_binary()) -> system_auth().
get_system_auth('undefined') ->
    lager:error("system trunkingio account id is not defined"),
    {'error', 'no_account_id'};
get_system_auth(AccountId) ->
    case get_system_token_or_session() of
        {'ok', {Type, Token}} ->
            {'ok', {'system_auth', Type, Token, AccountId}};
        {'error', _}=Error ->
            Error
    end.

-spec get_system_token_or_session() -> system_token().
get_system_token_or_session() ->
    case ?API_TOKEN of
        'undefined' -> maybe_session_id();
        ApiToken ->
            {'ok', {'api_token', ApiToken}}
    end.


%% hopefully we remove this when api_token is there?
-spec maybe_session_id() -> system_token().
maybe_session_id() ->
    case kapps_config:get_ne_binary(?MOD_CONFIG_CAT, <<"session_id">>) of
        'undefined' ->
            maybe_auth_by_userpass();
        SessionId ->
            {'ok', {'session_id', SessionId}}
    end.

%% hopefully we remove this when api_token is there?
-spec maybe_auth_by_userpass() -> system_token().
maybe_auth_by_userpass() ->
    case {?API_USERNAME, ?API_PASSWORD} of
        {<<Username/binary>>, <<Password/binary>>} ->
            auth_by_userpass(Username, Password);
        _ ->
            lager:error("carrier authentication is not configured"),
            {'error', 'noauth'}
    end.

%% hopefully we remove this when api_token is there?
-spec auth_by_userpass(kz_term:ne_binary(), kz_term:ne_binary()) -> system_token().
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
    HTTPOptions = [{'timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  ,{'connect_timeout', 180 * ?MILLISECONDS_IN_SECOND}
                  | kz_ssl:https_opts()
                  ],
    lager:info("authenticating with carrier: POST ~s", [Url]),
    Resp = kz_http:post(Url, Headers, Body, HTTPOptions),
    case handle_response(Resp, fun verify_carrier_resp/1) of
        {'ok', JObj} ->
            case kz_json:get_ne_binary_value(session_path([<<"SessionId">>]), JObj) of
                'undefined' ->
                    lager:error("authenticating with username and pass failed: ~p", [Resp]),
                    {'error', 'noauth'};
                SessionId ->
                    lager:debug("got sessionId via authenticating with username and pass"),
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
    lager:debug("request error: ~p (~s) ~p", [Code, Reason, _Response]),
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
    lager:debug("request failed with: ~p", [JObj]),
    ErrorMsg = kz_json:get_ne_binary_value(req_path([<<"Errors">>, <<"Error">>, <<"Message">>]), JObj, <<"unknown error">>),
    {'error', ErrorMsg};
verify_carrier_resp(JObj, 'false', 'false') ->
    ErrorCode = kz_json:get_ne_binary_value(req_path([<<"Errors">>, <<"Error">>, <<"Code">>]), JObj, <<"unknown error code">>),
    ErrorMsg = kz_json:get_ne_binary_value(req_path([<<"Errors">>, <<"Error">>, <<"Message">>]), JObj, <<"unknown error">>),
    case kz_term:to_lower_binary(ErrorCode) of
        <<"session.authentication">> ->
            lager:error("request failed with error code '~ts' and message '~ts' ~p", [ErrorCode, ErrorMsg, JObj]),
            {'error', 'unauthenticated'};
        _ ->
            lager:debug("request failed with error code '~ts' and message '~ts' ~p", [ErrorCode, ErrorMsg, JObj]),
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
    [<<"Response">>, <<"Context">>, <<"Session">> | Path].
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
    {'ok', kz_attachment:to_data_base64(Type, SubType, Data)}.

-spec validate_im(kzd_trunkingio_im:doc()) ->
          {'ok', kz_json:object()} | {'error', any()}.
validate_im(Payload) ->
    ImType = im_type(Payload),
    CCVs = [{<<"Authorizing-Type">>, <<ImType/binary, "-provider">>}
           ,{<<"Authorizing-ID">>, <<"tio">>}
           ],
    KVs = [{<<"From">>, kzd_trunkingio_im:from(Payload)}
          ,{<<"To">>, kzd_trunkingio_im:to(Payload, [])}
          ,{<<"Route-Type">>, <<"offnet">>}
          ,{<<"Msg-ID">>, kzd_trunkingio_im:reference_id(Payload)}
          ,{<<"Custom-Vars">>, kz_json:from_list(CCVs)}
          ,{<<"Event-Category">>, ImType}
          ],
    case im_body(Payload) of
        {'ok', Body} ->
            {'ok', kz_json:from_list([{<<"Body">>, Body} | KVs])};
        {'error', _}=Error ->
            Error
    end.

-spec im_type(kz_json:object()) -> kz_term:ne_binary().
im_type(Payload) ->
    case kzd_trunkingio_im:text(Payload) of
        'undefined' -> <<"mms">>;
        _ -> <<"sms">>
    end.

-spec im_body(kzd_trunkingio_im:doc()) -> {'ok', kz_term:ne_binary()} | {'error', any()}.
im_body(Payload) ->
    case kzd_trunkingio_im:text(Payload) of
        'undefined' -> mms_body(Payload);
        <<>> -> {'error', <<"empty text body">>};
        Body -> {'ok', Body}
    end.

-spec mms_body(kzd_trunkingio_im:doc()) -> {'ok', kz_term:ne_binary()} | {'error', any()}.
mms_body(Payload) ->
    MediaUrls = kzd_trunkingio_im:media_urls(Payload),
    case fetch_mms(MediaUrls) of
        {'ok', []} ->
            {'error', <<"empty media_urls">>};
        {'ok', Parts} ->
            Encoded = mimemail:encode_part({<<"multipart">>, <<"related">>, [], #{}, Parts}),
            {'ok', kz_binary:join(Encoded, <<"\r\n">>)};
        {'error', _}=Error ->
            Error
    end.

-spec fetch_mms(kz_term:ne_binaries()) -> {'ok', [mimemail:mimetuple()]} | {'error', any()}.
fetch_mms(Urls) ->
    fetch_mms(Urls, []).

-spec fetch_mms(kz_term:ne_binaries(), [mimemail:mimetuple()]) -> {'ok', [mimemail:mimetuple()]} | {'error', any()}.
fetch_mms([], Acc) -> {'ok', Acc};
fetch_mms([Url|T], Acc) ->
    case do_fetch(Url) of
        {'ok', _, Headers, Body} ->
            fetch_mms(T, [mimepart_from_ret(Url, Headers, Body) | Acc]);
        {'error', _}=Error ->
            Error
    end.

-spec do_fetch(kz_term:ne_binary()) -> kz_http:ret().
do_fetch(Url) ->
    do_fetch(Url, 0, ?RETRIES).

-spec do_fetch(kz_term:ne_binary(), integer(), integer()) -> kz_http:ret().
do_fetch(Url, Tries, Retries) when Tries >= Retries ->
    case kz_http:get(Url) of
        {'ok', 200, _Headers, <<>>} ->
            lager:debug("fetched im media from ~s has no body, skipping"),
            {'error', <<"empty attachment">>};
        {'ok', 200, _Headers, _Body} = Ret ->
            Ret;
        {'ok', _StatusCode, _Headers, _Body} = Ret ->
            lager:debug("fetching im media from ~s got error ~p, response body: ~p. retries exhausted, skipping", [Url, _StatusCode, _Body]),
            Ret;
        {'error', Error} = Ret ->
            lager:debug("could not fetch im media from ~s with error ~s. retries exhausted, skipping", [Url, Error]),
            Ret
    end;
do_fetch(Url, Tries, Retries) ->
    case kz_http:get(Url) of
        {'ok', 200, _Headers, <<>>} ->
            lager:debug("fetched im media from ~s has no body, skipping"),
            {'error', <<"empty attachment">>};
        {'ok', 200, _Headers, _Body} = Ret ->
            Ret;
        {'ok', _StatusCode, _Headers, _Body} ->
            lager:debug("fetching im media from ~s got error ~p, response body: ~p, retrying...", [Url, _StatusCode, _Body]),
            do_fetch(Url, Tries + 1, Retries);
        {'error', Error} ->
            lager:debug("could not fetch im media from ~s with error ~s,retrying...", [Url, Error]),
            do_fetch(Url, Tries + 1, Retries)
    end.

-spec mimepart_from_ret(kz_term:ne_binary(), kz_http:headers(),  kz_term:text()) -> mimemail:mimetuple().
mimepart_from_ret(Url, Headers, Body) ->
    Filename = filename(Url),
    ContentType = kz_json:get_value(<<"Content-Type">>
                                   ,Headers
                                   ,kz_mime:from_filename(Filename)
                                   ),
    MimeHeaders = [{<<"Content-Type">>, <<ContentType/binary, "; name=\"", Filename/binary, "\"">>}
                  ,{<<"Content-Disposition">>, <<"attachment; filename=\"", Filename/binary, "\"">>}
                  ,{<<"Content-Transfer-Encoding">>, <<"base64">>}
                  ],
    [Type, Subtype] = binary:split(ContentType, <<"/">>),
    {Type, Subtype, MimeHeaders, #{}, Body}.

-spec filename(kz_term:ne_binary()) -> binary().
filename(Url) ->
    [Base | _] = binary:split(Url, <<"?">>),
    lists:last(binary:split(Base, <<"/">>, ['global'])).
