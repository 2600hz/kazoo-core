%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
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

-spec call_forward(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_term:api_object().
call_forward(EndpointId, AccountId, Endpoint) ->
    case is_call_forward_enabled(Endpoint) of
        'false' -> 'undefined';
        'true' -> build_call_forward(EndpointId, AccountId, Endpoint)
    end.

-spec is_call_forward_enabled(kz_json:object()) -> boolean().
is_call_forward_enabled(Endpoint) ->
    kzd_devices:call_forward_number(Endpoint) =/= 'undefined'
        andalso (kzd_devices:call_forward_enabled(Endpoint)
                 orelse kzd_devices:call_forward_failover(Endpoint)
                ).

-spec build_call_forward(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
build_call_forward(EndpointId, AccountId, Endpoint) ->
    Number = kzd_devices:call_forward_number(Endpoint),
    IsReconcilable = knm_converters:is_reconcilable(Number, AccountId),
    Realm = get_realm(Endpoint),
    CallFwdURI = list_to_binary([Number, "@", Realm]),
    CCVs = call_forward_properties(EndpointId, AccountId, Endpoint, IsReconcilable),
    kz_json:set_values([{<<"Call-Forward-Request-URI">>, CallFwdURI}
                       ,{<<"Custom-Channel-Vars">>, CCVs}
                       ]
                      ,kz_json:new()
                      ).

-spec call_forward_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), boolean()) -> kz_json:object().
call_forward_properties(EndpointId, AccountId, Endpoint, IsReconcilable) ->
    Routines = [fun call_forward_base_properties/4
               ,fun call_forward_confirm_properties/4
               ,fun call_forward_maybe_retain_cid/4
               ],
    Props = lists:foldl(fun(Fun, Acc) -> Acc ++ Fun(EndpointId, AccountId, Endpoint, IsReconcilable) end, [], Routines),
    kz_json:from_list(Props).

call_forward_base_properties(_EndpointId, _AccountId, Endpoint, IsReconcilable) ->
    CIDTypeName = call_forward_cid_type_name(IsReconcilable),
    [{<<"Call-Forward">>, 'true'}
    ,{<<"Is-Substitute">>, call_forward_is_substitute(Endpoint)}
    ,{<<"Is-Failover">>, kzd_devices:call_forward_failover(Endpoint)}
    ,{<<"Direct-Calls-Only">>, kzd_devices:call_forward_direct_calls_only(Endpoint)}
    ,{<<"Require-Ignore-Early-Media">>, 'true'}
    ,{<<"Ignore-Early-Media">>, 'true'}
    ,{<<"Loopback-Bowout">>, 'true'}
    ,{<<"Call-Forward-From">>, <<"${kz_ctx_Inception}">>}
    ,{<<"Call-Forward-For-UUID">>, <<"${kz_originate_aleg_uuid}">>}
    ,{<<"Outbound-Caller-ID-Number">>, <<"${Caller-", CIDTypeName/binary, "-Caller-ID-Number}">>}
    ,{<<"Outbound-Caller-ID-Name">>, <<"${Caller-", CIDTypeName/binary, "-Caller-ID-Name}">>}
    ,{<<"Failover-Reasons">>, cfw_failover_reasons()}
    ].

-spec call_forward_cid_type_name(boolean()) -> kz_term:ne_binary().
call_forward_cid_type_name('true') -> <<"External">>;
call_forward_cid_type_name('false') -> <<"Internal">>.

-spec call_forward_is_substitute(kz_json:object()) -> boolean().
call_forward_is_substitute(Endpoint) ->
    kzd_devices:call_forward_substitute(Endpoint)
        andalso not kzd_devices:call_forward_failover(Endpoint).

cfw_single_reject() ->
    [<<"USER_BUSY">>
    ,<<"CALL_REJECTED">>
    ,<<"NO_ANSWER">>
    ,<<"NORMAL_CLEARING">>
    ,<<"PROGRESS_TIMEOUT">>
    ,<<"ALLOTTED_TIMEOUT">>
    ].

cfw_failover_reasons() ->
    [<<"SUBSCRIBER_ABSENT">>
    ,<<"RECOVERY_ON_TIMER_EXPIRE">>
    ].

call_forward_confirm_properties(_EndpointId, _AccountId, Endpoint, _IsReconcilable) ->
    case kzd_devices:call_forward_require_keypress(Endpoint) of
        'false' -> [];
        'true' ->
            [{<<"Confirm-Key">>, <<"1">>}
            ,{<<"Confirm-Cancel-Timeout">>, 'true'}
            ,{<<"Confirm-Read-Timeout">>, 3 * ?MILLISECONDS_IN_SECOND}
            ,{<<"Confirm-File">>, kzd_endpoint:get_prompt_url(Endpoint, <<"ivr-group_confirm">>)}
            ,{<<"Require-Ignore-Early-Media">>, 'true'}
            ,{<<"Require-Fail-On-Single-Reject">>, cfw_single_reject()}
            ]
    end.

call_forward_maybe_retain_cid(_EndpointId, _AccountId, Endpoint, _IsReconcilable) ->
    case kzd_devices:call_forward_keep_caller_id(Endpoint) of
        'false' -> [];
        'true' ->  [{<<"Retain-CID">>, 'true'}]
    end.

-spec get_realm(kz_json:object()) -> kz_term:ne_binary().
get_realm(Endpoint) ->
    kz_json:get_ne_binary_value(<<"realm">>, Endpoint, <<"norealm">>).
