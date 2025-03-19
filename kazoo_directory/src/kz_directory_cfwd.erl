%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%% @author Luis Azedo
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_directory_cfwd).

-export([call_forward/3]).

-include("kazoo_directory.hrl").

-define(CONFIRM_PLAY_COUNT, 3).
-define(CONFIRM_READ_TIMEOUT_SEC, 3).

-spec call_forward(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_term:api_object().
call_forward(EndpointId, AccountId, Endpoint) ->
    case is_legacy_failover(Endpoint) of
        'true' -> 'undefined';
        'false' -> maybe_build_call_forward(EndpointId, AccountId, Endpoint)
    end.

-spec is_legacy_failover(kz_json:object()) -> boolean().
is_legacy_failover(Endpoint) ->
    kz_json:is_true(<<"failover">>, kzd_endpoint:call_forward(Endpoint, kz_json:new())).

maybe_build_call_forward(EndpointId, AccountId, Endpoint) ->
    CallForward = call_forward(Endpoint),
    case is_call_forward_enabled(CallForward) of
        'true' -> build_call_forward(EndpointId, AccountId, Endpoint, CallForward);
        'false' -> 'undefined'
    end.

-spec call_forward(kz_json:object()) -> kz_json:object().
call_forward(Endpoint) ->
    CallForward = kzd_endpoint:call_forward(Endpoint, kz_json:new()),
    call_forward(CallForward, kzd_call_forward:is_legacy(CallForward)).

call_forward(CallForward, 'true') ->
    CallForward;
call_forward(CallForward, 'false') ->
    case kzd_call_forward:enabled(CallForward) of
        'true' -> kzd_call_forward:merged(CallForward, fun kzd_call_forward:unconditional/1, kz_json:new());
        'false' -> kz_json:new()
    end.

-spec is_call_forward_enabled(kz_json:object()) -> boolean().
is_call_forward_enabled(CallForward) ->
    kzd_call_forward:number(CallForward) =/= 'undefined'
        andalso kzd_call_forward:enabled(CallForward).

-spec build_call_forward(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kzd_call_forward:doc()) -> kz_json:object().
build_call_forward(EndpointId, AccountId, Endpoint, CallForward) ->
    Number = kzd_call_forward:number(CallForward),
    IsReconcilable = knm_converters:is_reconcilable(Number, AccountId),
    Realm = get_realm(Endpoint),
    CallFwdURI = list_to_binary([Number, "@", Realm]),
    CCVs = call_forward_properties(EndpointId, AccountId, Endpoint, CallForward, IsReconcilable),
    kz_json:set_values([{<<"Call-Forward-Request-URI">>, CallFwdURI}
                       ,{<<"Custom-Channel-Vars">>, CCVs}
                       ]
                      ,kz_json:new()
                      ).

-spec call_forward_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_json:object(), boolean()) -> kz_json:object().
call_forward_properties(EndpointId, AccountId, Endpoint, CallForward, IsReconcilable) ->
    Routines = [fun call_forward_base_properties/5
               ,fun call_forward_confirm_properties/5
               ,fun call_forward_maybe_retain_cid/5
               ],
    Props = lists:foldl(fun(Fun, Acc) -> Acc ++ Fun(EndpointId, AccountId, Endpoint, CallForward, IsReconcilable) end, [], Routines),
    kz_json:from_list(Props).

-spec call_forward_base_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_json:object(), boolean()) -> kz_term:proplist().
call_forward_base_properties(_EndpointId, _AccountId, _Endpoint, CallForward, _IsReconcilable) ->
    [{<<"Call-Forward">>, 'true'}
    ,{<<"Is-Substitute">>, kzd_call_forward:substitute(CallForward)}
    ,{<<"Direct-Calls-Only">>, kzd_call_forward:direct_calls_only(CallForward)}
    ,{<<"Require-Ignore-Early-Media">>, 'true'}
    ,{<<"Ignore-Early-Media">>, 'true'}
    ,{<<"Call-Forward-From">>, <<"${kz_ctx_Inception}">>}
    ,{<<"Call-Forward-Number">>, <<"${kz_ctx_request_e164}">>}
    ,{<<"Call-Forward-For-UUID">>, <<"${kz_originate_aleg_uuid}">>}
    ,{<<"Call-Forward-Diversions">>, <<"${sip_diversions}">>}
    ,{<<"Call-Forward-From-Endpoint-ID">>, <<"${Caller-Endpoint-ID}">>}
    ].

-spec call_forward_cid_type_name(boolean()) -> kz_term:ne_binary().
call_forward_cid_type_name('true') -> <<"External">>;
call_forward_cid_type_name('false') -> <<"Internal">>.

-spec cfw_single_reject() -> kz_term:ne_binaries().
cfw_single_reject() ->
    [<<"ALLOTTED_TIMEOUT">>
    ,<<"CALL_REJECTED">>
    ,<<"NO_ANSWER">>
    ,<<"NO_ENDPOINTS">>
    ,<<"NO_ROUTE_DESTINATION">>
    ,<<"NORMAL_CLEARING">>
    ,<<"PROGRESS_TIMEOUT">>
    ,<<"UNALLOCATED_NUMBER">>
    ,<<"USER_BUSY">>
    ].

-spec call_forward_confirm_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_json:object(), boolean()) -> kz_term:proplist().
call_forward_confirm_properties(_EndpointId, _AccountId, Endpoint, CallForward, _IsReconcilable) ->
    case kzd_call_forward:require_keypress(CallForward) of
        'false' -> [];
        'true' ->
            [{<<"Confirm-Key">>, <<"1">>}
            ,{<<"Confirm-Cancel-Timeout">>, 'true'}
            ,{<<"Confirm-Read-Timeout">>, ?CONFIRM_READ_TIMEOUT_SEC * ?MILLISECONDS_IN_SECOND}
            ,{<<"Confirm-Play-Count">>, ?CONFIRM_PLAY_COUNT}
            ,{<<"Confirm-File">>, kzd_endpoint:get_prompt(Endpoint, <<"ivr-group_confirm">>)}
            ,{<<"Require-Ignore-Early-Media">>, 'true'}
            ,{<<"Require-Fail-On-Single-Reject">>, cfw_single_reject()}
            ]
    end.

-spec call_forward_maybe_retain_cid(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_json:object(), boolean()) -> kz_term:proplist().
call_forward_maybe_retain_cid(_EndpointId, _AccountId, _Endpoint, CallForward, IsReconcilable) ->
    CIDTypeName = call_forward_cid_type_name(IsReconcilable),
    case kzd_call_forward:keep_caller_id(CallForward) of
        'false' -> [];
        'true' -> [{<<"Outbound-Caller-ID-Number">>, <<"${first-of(Caller-", CIDTypeName/binary, "-Caller-ID-Number|Caller-Caller-ID-Number)}">>}
                  ,{<<"Outbound-Caller-ID-Name">>, <<"${first-of(Caller-", CIDTypeName/binary, "-Caller-ID-Name|Caller-Caller-ID-Name)}">>}
                  ,{<<"Retain-CID">>, 'true'}
                  ]
    end.

-spec get_realm(kz_json:object()) -> kz_term:ne_binary().
get_realm(Endpoint) ->
    kz_json:get_ne_binary_value(<<"realm">>, Endpoint, <<"norealm">>).
