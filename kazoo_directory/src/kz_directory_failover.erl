%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
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
-module(kz_directory_failover).

-export([failover/3]).

-include("kazoo_directory.hrl").

-define(CONFIRM_PLAY_COUNT, 3).
-define(CONFIRM_READ_TIMEOUT_SEC, 3).

-spec failover(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_term:api_object().
failover(EndpointId, AccountId, Endpoint) ->
    case is_call_failover_enabled(Endpoint) of
        'false' -> maybe_legacy_failover(EndpointId, AccountId, Endpoint);
        'true' -> build_failover(EndpointId, AccountId, Endpoint)
    end.

-spec maybe_legacy_failover(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_term:api_object().
maybe_legacy_failover(EndpointId, AccountId, Endpoint) ->
    CallForward = kzd_endpoint:call_forward(Endpoint, kz_json:new()),
    case kz_json:is_true(<<"failover">>, CallForward) of
        false -> undefined;
        true -> build_legacy_failover(EndpointId, AccountId, Endpoint, CallForward)
    end.

build_legacy_failover(EndpointId, AccountId, Endpoint, CallForward) ->
    EP = kz_json:set_value(<<"call_failover">>, CallForward, kz_json:delete_key(<<"call_forward">>, Endpoint)),
    build_failover(EndpointId, AccountId, EP).

-spec is_call_failover_enabled(kz_json:object()) -> boolean().
is_call_failover_enabled(Endpoint) ->
    Failover = kzd_endpoint:call_failover(Endpoint, kz_json:new()),
    kz_term:is_not_empty(kzd_call_failover:number(Failover))
        andalso kzd_call_failover:enabled(Failover).

-spec build_failover(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
build_failover(EndpointId, AccountId, Endpoint) ->
    Failover = kzd_endpoint:call_failover(Endpoint, kz_json:new()),
    Number = kzd_call_failover:number(Failover),
    IsReconcilable = knm_converters:is_reconcilable(Number, AccountId),
    Realm = get_realm(Endpoint),
    CallFwdURI = list_to_binary([Number, "@", Realm]),
    CCVs = call_failover_properties(EndpointId, AccountId, Endpoint, IsReconcilable),
    kz_json:set_values([{<<"Call-Forward-Request-URI">>, CallFwdURI}
                       ,{<<"Custom-Channel-Vars">>, CCVs}
                       ]
                      ,kz_json:new()
                      ).

-spec call_failover_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), boolean()) -> kz_json:object().
call_failover_properties(EndpointId, AccountId, Endpoint, IsReconcilable) ->
    Routines = [fun call_failover_base_properties/4
               ,fun call_failover_confirm_properties/4
               ,fun call_failover_maybe_retain_cid/4
               ],
    Props = lists:foldl(fun(Fun, Acc) ->
                                Acc ++ Fun(EndpointId, AccountId, Endpoint, IsReconcilable)
                        end
                       ,[]
                       ,Routines
                       ),
    kz_json:from_list(Props).

-spec call_failover_base_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), boolean()) -> kz_term:proplist().
call_failover_base_properties(_EndpointId, _AccountId, Endpoint, _IsReconcilable) ->
    Failover = kzd_endpoint:call_failover(Endpoint, kz_json:new()),
    [{<<"Call-Forward">>, 'true'}
    ,{<<"Direct-Calls-Only">>, kzd_call_failover:direct_calls_only(Failover)}
    ,{<<"Require-Ignore-Early-Media">>, 'true'}
    ,{<<"Ignore-Early-Media">>, 'true'}
    ,{<<"Call-Forward-From">>, <<"${kz_ctx_Inception}">>}
    ,{<<"Call-Forward-For-UUID">>, <<"${kz_originate_aleg_uuid}">>}
    ,{<<"Failover-Reasons">>, cfw_failover_reasons()}
    ].

-spec call_failover_cid_type_name(boolean()) -> kz_term:ne_binary().
call_failover_cid_type_name('true') -> <<"External">>;
call_failover_cid_type_name('false') -> <<"Internal">>.

-spec cfw_single_reject() -> kz_term:ne_binaries().
cfw_single_reject() ->
    [<<"USER_BUSY">>
    ,<<"CALL_REJECTED">>
    ,<<"NO_ANSWER">>
    ,<<"NO_ENDPOINTS">>
    ,<<"NORMAL_CLEARING">>
    ,<<"PROGRESS_TIMEOUT">>
    ,<<"ALLOTTED_TIMEOUT">>
    ].

-spec cfw_failover_reasons() -> kz_term:ne_binaries().
cfw_failover_reasons() ->
    [<<"SUBSCRIBER_ABSENT">>
    ,<<"RECOVERY_ON_TIMER_EXPIRE">>
    ].

-spec call_failover_confirm_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), boolean()) -> kz_term:proplist().
call_failover_confirm_properties(_EndpointId, _AccountId, Endpoint, _IsReconcilable) ->
    Failover = kzd_endpoint:call_failover(Endpoint, kz_json:new()),
    case kzd_call_failover:require_keypress(Failover) of
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

-spec call_failover_maybe_retain_cid(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), boolean()) -> kz_term:proplist().
call_failover_maybe_retain_cid(_EndpointId, _AccountId, Endpoint, IsReconcilable) ->
    Failover = kzd_endpoint:call_failover(Endpoint, kz_json:new()),
    CIDTypeName = call_failover_cid_type_name(IsReconcilable),
    case kzd_call_failover:keep_caller_id(Failover) of
        'false' -> [];
        'true' -> [{<<"Outbound-Caller-ID-Number">>, <<"${first-of(Caller-", CIDTypeName/binary, "-Caller-ID-Number|Caller-Caller-ID-Number)}">>}
                  ,{<<"Outbound-Caller-ID-Name">>, <<"${first-of(Caller-", CIDTypeName/binary, "-Caller-ID-Name|Caller-Caller-ID-Name)}">>}
                  ,{<<"Retain-CID">>, 'true'}
                  ]
    end.

-spec get_realm(kz_json:object()) -> kz_term:ne_binary().
get_realm(Endpoint) ->
    kz_json:get_ne_binary_value(<<"realm">>, Endpoint, <<"norealm">>).
