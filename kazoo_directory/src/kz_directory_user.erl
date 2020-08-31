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
-module(kz_directory_user).

-export([profile/2, profile/3]).

-include("kazoo_directory.hrl").

-spec profile(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId) ->
    profile(EndpointId, AccountId, []).

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId, Options) ->
    case kz_endpoint:get(EndpointId, AccountId) of
        {'ok', Endpoint} -> profile(EndpointId, AccountId, Endpoint, Options);
        Error -> Error
    end.

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
profile(EndpointId, AccountId, Endpoint, Options) ->
    case kz_json:get_ne_binary_value(<<"Endpoint-Type">>, Endpoint) of
        <<"user">> ->
            case kz_cache:fetch_local(?CACHE_NAME, {EndpointId, AccountId}) of
                {ok, Profile} -> {ok, Profile};
                {error, not_found} -> build_and_cache(EndpointId, AccountId, Endpoint, Options)
            end;
        _ -> {'error', 'not_user'}
    end.

-spec build_and_cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
build_and_cache(EndpointId, AccountId, Endpoint, Options) ->
    {ok, Profile} = build(EndpointId, AccountId, Endpoint, Options),
    cache(EndpointId, AccountId, Profile).

-spec cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> {'ok', kz_json:object()}.
cache(EndpointId, AccountId, Profile) ->
    Origins = cache_origin(EndpointId, AccountId, Profile),
    CacheProps = [{'origin', Origins}
                 ,{'callback', fun cache_callback/3}
                 ],
    kz_cache:store_local_async(?CACHE_NAME, {EndpointId, AccountId}, Profile, CacheProps),
    {ok, Profile}.

-spec cache_callback(tuple(), kz_json:object(), callback_msg()) -> ok.
cache_callback({EndpointId, AccountId}, CachedValue, 'erase') ->
    lager:debug("directory cache erased key (~s / ~s)", [EndpointId, AccountId]),
    timer:sleep(kz_term:to_integer(?MILLISECONDS_IN_SECOND * 0.15)),
    case kz_endpoint:get(EndpointId, AccountId) of
        {'ok', Endpoint} ->
            {ok, NewProfile} = build(EndpointId, AccountId, Endpoint, []),
            maybe_notify(EndpointId, AccountId, kz_json:are_equal(NewProfile, CachedValue)),
            cache(EndpointId, AccountId, NewProfile);
        _Error -> notify(EndpointId, AccountId)
    end;
cache_callback(_, _, _) -> ok.

maybe_notify(EndpointId, AccountId, true) ->
    lager:debug("directory cache erased key hasn't changed (~s / ~s)", [EndpointId, AccountId]);
maybe_notify(EndpointId, AccountId, false) -> notify(EndpointId, AccountId).

notify(EndpointId, AccountId) ->
    kz_directory_cache:clear(<<EndpointId/binary, "@", AccountId/binary>>),
    lager:debug("directory cache erased key changed (~s / ~s)", [EndpointId, AccountId]).

-spec cache_origin(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> list().
cache_origin(EndpointId, AccountId, Profile) ->
    Members = kz_json:get_ne_binaries(<<"Members">>, Profile),
    AccountDb = kzs_util:format_account_db(AccountId),
    Routines = [fun(P) -> [{'db', AccountDb, EndpointId} | P] end
               ,fun(P) -> [{'db', AccountDb, AccountId} | P] end
               ,fun(P) -> lists:foldl(fun(M, A) -> [{'db', AccountDb, M} | A] end, P, Members) end
               ],
    lists:foldl(fun(F, P) -> F(P) end, [], Routines).

-spec build(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
build(EndpointId, AccountId, Endpoint, _Options) ->
    CCVs = generate_ccvs(EndpointId, AccountId, Endpoint),
    SIPHeaders = generate_sip_headers(EndpointId, AccountId, Endpoint),

    {CIDNumber, CIDName} = kz_attributes:get_endpoint_cid(<<"internal">>, Endpoint),
    {CEDNumber, CEDName} = kz_attributes:get_endpoint_cid(<<"external">>, Endpoint),
    Endpoints = owned_by_query(EndpointId, AccountId),

    CPVs = [{<<"Internal-Caller-ID-Number">>, CIDNumber}
           ,{<<"Internal-Caller-ID-Name">>, CIDName}
           ,{<<"External-Caller-ID-Number">>, CEDNumber}
           ,{<<"External-Caller-ID-Name">>, CEDName}
           ,{<<"Account-ID">>, AccountId}
           ,{<<"Endpoint-ID">>, EndpointId}
           ,{<<"Endpoint-Type">>, <<"user">>}
           ,{<<"Endpoint-Caller-ID-Number">>, CIDNumber}
           ,{<<"Endpoint-Caller-ID-Name">>, CIDName}
           ,{<<"Endpoint-Presence-ID">>, kz_json:get_ne_binary_value(<<"Presence-ID">>, CCVs)}
           ],
    Profile = [{<<"Endpoint-Type">>, <<"user">>}
              ,{<<"Domain-Name">>, AccountId}
              ,{<<"User-ID">>, EndpointId}
              ,{<<"Members">>, Endpoints}
              ,{<<"Custom-Channel-Vars">>, CCVs}
              ,{<<"Custom-Profile-Vars">>, kz_json:from_list(CPVs)}
              ,{<<"Custom-SIP-Headers">>, SIPHeaders}
              ,{<<"CallForward">> , maybe_build_call_forward(EndpointId, AccountId, Endpoint)}
              ,{<<"Expires">>, ?DIRECORY_CACHE_TIME_MS}
              ],
    {'ok', kz_json:from_list(Profile)}.

-spec generate_ccvs(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
generate_ccvs(_EndpointId, AccountId, Endpoint) ->
    Realm = kz_json:get_ne_binary_value(<<"realm">>, Endpoint),
    Props = [{<<"Account-ID">>, AccountId}
            ,{<<"Reseller-ID">>, kz_services_reseller:get_id(AccountId)}
            ,{<<"Realm">>, Realm}
            ,{<<"Username">>, kzd_devices:sip_username(Endpoint)}
            ,{<<"SIP-Invite-Domain">>, Realm}
            ,{<<"Ignore-Early-Media">>, 'true'}
            ],
    CCVs = kz_json:from_list(Props),

    CCVFuns = [{fun owner_id/2, Endpoint}
              ,{fun presence_id/2, Endpoint}
              ,{fun hold_music/2, Endpoint}
              ],
    kz_json:exec(CCVFuns, CCVs).

-spec presence_id(kz_json:object(), kz_json:object()) -> kz_json:object().
presence_id(Endpoint, CCVs) ->
    PresenceId = kzd_devices:presence_id(Endpoint),
    kz_json:set_value(<<"Presence-ID">>, PresenceId, CCVs).

-spec owner_id(kz_json:object(), kz_json:object()) -> kz_json:object().
owner_id(Endpoint, CCVs) ->
    kz_json:set_values([{<<"Authorizing-ID">>, kz_doc:id(Endpoint)}
                       ,{<<"Authorizing-Type">>, kz_doc:type(Endpoint)}
                       ,{<<"Owner-ID">>, kz_doc:id(Endpoint)}
                       ]
                      ,CCVs
                      ).

-spec hold_music(kz_json:object(), kz_json:object()) -> kz_json:object().
hold_music(Endpoint, CCVs) ->
    case kz_json:get_ne_binary_value([<<"music_on_hold">>, <<"media_id">>], Endpoint) of
        'undefined' -> CCVs;
        MediaId ->
            MOH = kz_media_util:media_path(MediaId, kz_doc:account_id(Endpoint)),
            kz_json:set_value(<<"Hold-Media">>, MOH, CCVs)
    end.

-spec generate_sip_headers(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
generate_sip_headers(_EndpointId, _AccountId, Endpoint) ->
    Headers = kz_json:new(),
    HeaderFuns = [{fun add_sip_headers/2, Endpoint}],
    kz_json:exec(HeaderFuns, Headers).

-spec add_sip_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
add_sip_headers(Endpoint, Headers) ->
    case kzd_devices:custom_sip_headers_inbound(Endpoint) of
        'undefined' -> Headers;
        CustomHeaders -> kz_json:merge_jobjs(CustomHeaders, Headers)
    end.

-spec owned_by_query(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:api_binaries().
owned_by_query(OwnerId, AccountId) ->
    ViewOptions = [{'key', [OwnerId, <<"device">>]}],
    AccountDb = kzs_util:format_account_db(AccountId),
    case kz_datamgr:get_result_ids(AccountDb, <<"attributes/owned">>, ViewOptions) of
        {'ok', Ids} -> Ids;
        {'error', _R} -> []
    end.

-spec is_call_forward_enabled(kz_json:object()) -> boolean().
is_call_forward_enabled(Endpoint) ->
    kzd_devices:call_forward_number(Endpoint) =/= 'undefined'
        andalso (kzd_devices:call_forward_enabled(Endpoint)
                 orelse kzd_devices:call_forward_failover(Endpoint)
                ).

-spec maybe_build_call_forward(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_term:api_object().
maybe_build_call_forward(EndpointId, AccountId, Endpoint) ->
    case is_call_forward_enabled(Endpoint) of
        'false' -> 'undefined';
        'true' -> build_call_forward(EndpointId, AccountId, Endpoint)
    end.

-spec build_call_forward(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
build_call_forward(EndpointId, AccountId, Endpoint) ->
    Number = kzd_devices:call_forward_number(Endpoint),
    Realm = get_realm(Endpoint),
    CallFwdURI = list_to_binary([Number, "@", Realm]),
    CCVs = call_forward_properties(EndpointId, AccountId, Endpoint),
    kz_json:set_values([{<<"Call-Forward-Request-URI">>, CallFwdURI}
                       ,{<<"Custom-Channel-Vars">>, CCVs}
                       ]
                      ,kz_json:new()
                      ).

-spec call_forward_properties(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
call_forward_properties(EndpointId, AccountId, Endpoint) ->
    Routines = [fun call_forward_base_properties/3
               ,fun call_forward_confirm_properties/3
               ,fun call_forward_maybe_retain_cid/3
               ],
    Props = lists:foldl(fun(Fun, Acc) -> Acc ++ Fun(EndpointId, AccountId, Endpoint) end, [], Routines),
    kz_json:from_list(Props).

call_forward_base_properties(_EndpointId, _AccountId, Endpoint) ->
    [{<<"Call-Forward">>, 'true'}
    ,{<<"Is-Failover">>, kzd_devices:call_forward_failover(Endpoint)}
    ,{<<"Is-Substitute">>, kzd_devices:call_forward_substitute(Endpoint)}
    ,{<<"Direct-Calls-Only">>, kzd_devices:call_forward_direct_calls_only(Endpoint)}
    ,{<<"Require-Ignore-Early-Media">>, 'true'}
    ,{<<"Ignore-Early-Media">>, 'true'}
    ,{<<"Loopback-Bowout">>, 'true'}
    ,{<<"Call-Forward-From">>, <<"${kz_ctx_Inception}">>}
    ,{<<"Call-Forward-For-UUID">>, <<"${Unique-ID}">>}
    ].

cfw_single_reject() ->
    [<<"USER_BUSY">>
    ,<<"CALL_REJECTED">>
    ,<<"NO_ANSWER">>
    ,<<"NORMAL_CLEARING">>
    ,<<"PROGRESS_TIMEOUT">>
    ,<<"ALLOTTED_TIMEOUT">>
    ].

call_forward_confirm_properties(_EndpointId, AccountId, Endpoint) ->
    Lang = kz_media_util:prompt_language(AccountId),
    case kzd_devices:call_forward_require_keypress(Endpoint) of
        'false' -> [];
        'true' ->
            [{<<"Confirm-Key">>, <<"1">>}
            ,{<<"Confirm-Cancel-Timeout">>, 'true'}
            ,{<<"Confirm-Read-Timeout">>, 3 * ?MILLISECONDS_IN_SECOND}
            ,{<<"Confirm-File">>, kz_media_util:get_prompt(<<"ivr-group_confirm">>, Lang, AccountId)}
            ,{<<"Require-Ignore-Early-Media">>, 'true'}
            ,{<<"Require-Fail-On-Single-Reject">>, cfw_single_reject()}
            ]
    end.

call_forward_maybe_retain_cid(_EndpointId, _AccountId, Endpoint) ->
    case kzd_devices:call_forward_keep_caller_id(Endpoint) of
        'true' -> [{<<"Retain-CID">>, 'true'}];
        'false' -> []
    end.

-spec get_realm(kz_json:object()) -> kz_term:ne_binary().
get_realm(Endpoint) ->
    kz_json:get_ne_binary_value(<<"realm">>, Endpoint, <<"norealm">>).
