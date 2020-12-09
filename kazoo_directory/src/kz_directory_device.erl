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
-module(kz_directory_device).

-export([profile/2, profile/3]).

-include("kazoo_directory.hrl").

-spec profile(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
profile(EndpointId, AccountId) ->
    profile(EndpointId, AccountId, []).

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
profile(EndpointId, AccountId, Options) ->
    case kz_endpoint:get(EndpointId, AccountId, Options) of
        {'ok', Endpoint} -> profile(EndpointId, AccountId, Endpoint, Options);
        Error -> Error
    end.

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
profile(EndpointId, AccountId, Endpoint, Options) ->
    case kz_json:get_ne_binary_value(<<"Endpoint-Type">>, Endpoint) of
        <<"device">> ->
            case get_device_module(Endpoint) of
                'undefined' -> {'error', 'not_device'};
                Module -> profile(EndpointId, AccountId, Endpoint, Options, Module)
            end;
        _Type ->
            lager:debug("endpoint type ~s", [_Type]),
            {'error', 'not_device'}
    end.

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), atom()) -> {'ok', kz_json:object()}.
profile(EndpointId, AccountId, Endpoint, Options, Module) ->
    case kz_cache:fetch_local(?CACHE_NAME, {EndpointId, AccountId}) of
        {'ok', Profile} -> {'ok', Profile};
        {'error', 'not_found'} -> build_and_cache(EndpointId, AccountId, Endpoint, Options, Module)
    end.

-spec build_and_cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), atom()) -> {'ok', kz_json:object()}.
build_and_cache(EndpointId, AccountId, Endpoint, Options, Module) ->
    {'ok', Profile} = build(EndpointId, AccountId, Endpoint, Options, Module),
    Origins = cache_origin(EndpointId, AccountId, Endpoint),
    cache(EndpointId, AccountId, Profile, Origins).

-spec cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), list()) -> {'ok', kz_json:object()}.
cache(EndpointId, AccountId, Profile, Origins) ->
    CacheProps = [{'origin', Origins}
                 ,{'callback', fun cache_callback/3}
                 ],
    kz_cache:store_local_async(?CACHE_NAME, {EndpointId, AccountId}, Profile, CacheProps),
    {'ok', Profile}.

-spec cache_callback(tuple(), kz_json:object(), callback_msg()) -> 'ok'.
cache_callback({EndpointId, AccountId}, CachedValue, 'erase') ->
    lager:debug("directory cache erased key (~s / ~s)", [EndpointId, AccountId]),
    timer:sleep(kz_term:to_integer(?MILLISECONDS_IN_SECOND * 0.15)),
    case kz_endpoint:get(EndpointId, AccountId) of
        {'ok', Endpoint} ->
            Module = get_device_module(Endpoint),
            {'ok', NewProfile} = build(EndpointId, AccountId, Endpoint, [], Module),
            maybe_notify(EndpointId, AccountId, kz_json:are_equal(NewProfile, CachedValue)),
            Origins = cache_origin(EndpointId, AccountId, Endpoint),
            cache(EndpointId, AccountId, NewProfile, Origins);
        _Error -> notify(EndpointId, AccountId)
    end;
cache_callback(_, _, _) -> 'ok'.

maybe_notify(EndpointId, AccountId, 'true') ->
    lager:debug("directory cache erased key hasn't changed (~s / ~s)", [EndpointId, AccountId]);
maybe_notify(EndpointId, AccountId, 'false') -> notify(EndpointId, AccountId).

notify(EndpointId, AccountId) ->
    kz_directory_cache:clear(<<EndpointId/binary, "@", AccountId/binary>>),
    lager:debug("directory cache erased key changed (~s / ~s)", [EndpointId, AccountId]).

-spec cache_origin(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> list().
cache_origin(EndpointId, AccountId, JObj) ->
    AccountDb = kzs_util:format_account_db(AccountId),
    Routines = [fun(P) -> [{'db', AccountDb, EndpointId} | P] end
               ,fun(P) -> [{'db', AccountDb, AccountId} | P] end
               ,fun(P) -> maybe_cached_owner_id(P, JObj, AccountDb) end
               ,fun(P) -> maybe_cached_hotdesk_ids(P, JObj, AccountDb) end
               ],
    lists:foldl(fun(F, P) -> F(P) end, [], Routines).

-spec maybe_cached_owner_id(kz_term:proplist(), kz_json:object(), kz_term:ne_binary()) -> kz_term:proplist().
maybe_cached_owner_id(Props, JObj, AccountDb) ->
    case kz_json:get_ne_binary_value(<<"owner_id">>, JObj) of
        'undefined' -> Props;
        OwnerId -> [{'db', AccountDb, OwnerId}|Props]
    end.

-spec maybe_cached_hotdesk_ids(kz_term:proplist(), kz_json:object(), kz_term:ne_binary()) -> kz_term:proplist().
maybe_cached_hotdesk_ids(Props, JObj, AccountDb) ->
    case kz_json:get_keys([<<"hotdesk">>, <<"users">>], JObj) of
        [] -> Props;
        OwnerIds -> lists:foldl(fun(Id, P) -> [{'db', AccountDb, Id}|P] end, Props, OwnerIds)
    end.

-spec build(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), atom()) -> {'ok', kz_json:object()}.
build(EndpointId, AccountId, Endpoint, _Options, Module) ->
    CCVs = generate_ccvs(EndpointId, AccountId, Endpoint, Module),
    SIPHeaders = generate_sip_headers(EndpointId, AccountId, Endpoint, Module),

    {CIDNumber, CIDName} = kz_attributes:get_endpoint_cid(<<"internal">>, Endpoint),
    {CEDNumber, CEDName} = kz_attributes:get_endpoint_cid(<<"external">>, Endpoint),

    CPVs = [{<<"Internal-Caller-ID-Number">>, CIDNumber}
           ,{<<"Internal-Caller-ID-Name">>, CIDName}
           ,{<<"External-Caller-ID-Number">>, CEDNumber}
           ,{<<"External-Caller-ID-Name">>, CEDName}
           ,{<<"Account-ID">>, AccountId}
           ,{<<"Endpoint-ID">>, EndpointId}
           ,{<<"Endpoint-Type">>, <<"device">>}
           ,{<<"Endpoint-Owner-ID">>, kzd_endpoint:owner_id(Endpoint)}
           ,{<<"Endpoint-Caller-ID-Number">>, CIDNumber}
           ,{<<"Endpoint-Caller-ID-Name">>, CIDName}
           ,{<<"Endpoint-Presence-ID">>, kz_json:get_ne_binary_value(<<"Presence-ID">>, CCVs)}
           ,{<<"Endpoint-DND">>, dnd(Endpoint)}
           ],
    Profile = [{<<"Endpoint-Type">>, <<"device">>}
              ,{<<"Domain-Name">>, AccountId}
              ,{<<"User-ID">>, EndpointId}
              ,{<<"Account-ID">>, AccountId}
              ,{<<"Custom-Channel-Vars">>, CCVs}
              ,{<<"Custom-Profile-Vars">>, kz_json:from_list(CPVs)}
              ,{<<"Custom-SIP-Headers">>, SIPHeaders}
              ,{<<"Codecs">>, Module:codecs(Endpoint)}
              ,{<<"SIP-Invite-Route-URI">>, Module:sip_route(Endpoint)}
              ,{<<"SIP-Proxy-Route-URI">>, Module:sip_route_uri(Endpoint)}
              ,{<<"SIP-Interface">>, Module:sip_interface(Endpoint)}
              ,{<<"CallForward">> , maybe_build_call_forward(EndpointId, AccountId, Endpoint)}
              ,{<<"Expires">>, ?DIRECORY_CACHE_TIME_MS}
              ],
    {'ok', kz_json:from_list(Profile)}.

-spec get_device_module(kz_json:object()) -> atom().
get_device_module(Endpoint) ->
    case get_endpoint_type(Endpoint) of
        <<"unknown">> -> 'undefined';
        Type -> kz_term:to_atom(<<"kz_directory_device_", Type/binary>>, 'true')
    end.

-spec get_endpoint_type(kz_json:object()) -> kz_term:ne_binary().
get_endpoint_type(Endpoint) ->
    Type = kz_json:get_first_defined([<<"endpoint_type">>
                                     ,<<"device_type">>
                                     ]
                                    ,Endpoint
                                    ),
    case convert_endpoint_type(Type) of
        'undefined' -> maybe_guess_endpoint_type(Endpoint);
        Else -> Else
    end.

-spec convert_endpoint_type(kz_term:ne_binary()) -> kz_term:api_ne_binary().
convert_endpoint_type(<<"sip_", _/binary>>) -> <<"sip">>;
convert_endpoint_type(<<"smartphone">>) -> <<"sip">>;
convert_endpoint_type(<<"softphone">>) -> <<"sip">>;
convert_endpoint_type(<<"cellphone">>) -> <<"sip">>;
convert_endpoint_type(<<"landline">>) -> <<"sip">>;
convert_endpoint_type(<<"fax">>) -> <<"sip">>;
convert_endpoint_type(<<"mobile">>) -> <<"mobile">>;
convert_endpoint_type(_Else) ->
    lager:info("failed to convert endpoint type ~s", [_Else]),
    'undefined'.

-spec maybe_guess_endpoint_type(kz_json:object()) -> kz_term:ne_binary().
maybe_guess_endpoint_type(Endpoint) ->
    case kapps_config:get_is_true(?CONFIG_CAT, <<"restrict_to_known_types">>, 'false') of
        'false' -> guess_endpoint_type(Endpoint);
        'true' ->
            lager:info("unknown endpoint type and callflows restricted to known types", []),
            <<"unknown">>
    end.

-spec guess_endpoint_type(kz_json:object()) -> kz_term:ne_binary().
guess_endpoint_type(Endpoint) ->
    guess_endpoint_type(Endpoint, [<<"mobile">>, <<"sip">>]).

-spec guess_endpoint_type(kz_json:object(), kz_term:ne_binaries()) -> kz_term:ne_binary().
guess_endpoint_type(Endpoint, [Type|Types]) ->
    case kz_json:get_ne_value(Type, Endpoint) of
        'undefined' -> guess_endpoint_type(Endpoint, Types);
        _ -> Type
    end;
guess_endpoint_type(Endpoint, []) ->
    case kz_json:get_ne_value(<<"sip">>, Endpoint) of
        'undefined' -> <<"unknown">>;
        _Else -> <<"sip">>
    end.

-spec endpoint_id(kz_json:object(), kz_json:object()) -> kz_json:object().
endpoint_id(Endpoint, CCVs) ->
    case kz_doc:id(Endpoint) of
        'undefined' -> CCVs;
        EndpointId ->
            AuthType = case get_endpoint_type(Endpoint) of
                           <<"mobile">> -> <<"mobile">>;
                           _ -> kz_doc:type(Endpoint)
                       end,
            kz_json:set_values([{<<"Authorizing-ID">>, EndpointId}
                               ,{<<"Authorizing-Type">>, AuthType}
                               ]
                              ,CCVs
                              )
    end.

-spec owner_id(kz_json:object(), kz_json:object()) -> kz_json:object().
owner_id(Endpoint, CCVs) ->
    case kzd_devices:owner_id(Endpoint) of
        'undefined' -> CCVs;
        OwnerId -> kz_json:set_value(<<"Owner-ID">>, OwnerId, CCVs)
    end.

-spec presence_id(kz_json:object(), kz_json:object()) -> kz_json:object().
presence_id(Endpoint, CCVs) ->
    kz_json:set_value(<<"Presence-ID">>, kzd_devices:calculate_presence_id(Endpoint), CCVs).

-spec hold_music(kz_json:object(), kz_json:object()) -> kz_json:object().
hold_music(Endpoint, CCVs) ->
    case kz_json:get_ne_binary_value([<<"music_on_hold">>, <<"media_id">>], Endpoint) of
        'undefined' -> CCVs;
        MediaId ->
            MOH = list_to_binary(["prompt://", kz_doc:account_id(Endpoint), "/", MediaId]),
            kz_json:set_value(<<"Hold-Media">>, MOH, CCVs)
    end.

-spec invite_uri(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
invite_uri(Module, Endpoint, CCVs) ->
    Module:invite_uri(Endpoint, CCVs).

-spec rtcp_mux(kz_json:object(), kz_json:object()) -> kz_json:object().
rtcp_mux(Endpoint, CCVs) ->
    case kz_json:get_boolean_value([<<"media">>, <<"rtcp_mux">>], Endpoint) of
        'undefined' -> CCVs;
        RTCP_MUX -> kz_json:set_value(<<"RTCP-MUX">>, RTCP_MUX, CCVs)
    end.

-spec webrtc(kz_json:object(), kz_json:object()) -> kz_json:object().
webrtc(Endpoint, CCVs) ->
    case kz_json:is_true([<<"media">>, <<"webrtc">>], Endpoint) of
        'false' -> CCVs;
        'true' ->
            Props = [{<<"RTCP-MUX">>, 'true'}
                    ,{<<"Media-Webrtc">>, 'true'}
                    ],
            kz_json:set_values(Props, CCVs)
    end.

-spec call_waiting(kz_json:object(), kz_json:object()) -> kz_json:object().
call_waiting(Endpoint, CCVs) ->
    case kz_json:is_true([<<"call_waiting">>, <<"enabled">>], Endpoint, 'true') of
        'true' -> CCVs;
        'false' -> kz_json:set_value(<<"Call-Waiting-Disabled">>, 'true', CCVs)
    end.

-spec enable_fax(kz_json:object(), kz_json:object()) -> kz_json:object().
enable_fax(Endpoint, CCVs) ->
    case kz_json:get_value([<<"media">>, <<"fax_option">>], Endpoint) of
        <<"auto">> -> kz_json:set_value(<<"Fax-Enabled">>, <<"true">>, CCVs);
        _Else -> CCVs
    end.

-spec progress_timeout(kz_json:object(), kz_json:object()) -> kz_json:object().
progress_timeout(Endpoint, CCVs) ->
    case kz_json:get_integer_value([<<"media">>, <<"progress_timeout">>], Endpoint, 0) of
        Timeout when Timeout > 0 -> kz_json:set_value(<<"Endpoint-Progress-Timeout">>, Timeout, CCVs);
        _Else -> CCVs
    end.

-spec ignore_early_media(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
ignore_early_media(Mod, Endpoint, CCVs) ->
    case Mod:ignore_early_media(Endpoint) of
        'true' -> kz_json:set_value(<<"Ignore-Early-Media">>, 'true', CCVs);
        'false' -> CCVs
    end.

-spec bypass_media(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
bypass_media(Mod, Endpoint, CCVs) ->
    case Mod:bypass_media(Endpoint) of
        'true' -> kz_json:set_value(<<"Bypass-Media">>, 'true', CCVs);
        'false' -> CCVs
    end.

-spec ignore_completed_elsewhere(kz_json:object(), kz_json:object()) -> kz_json:object().
ignore_completed_elsewhere(Endpoint, CCVs) ->
    Default = kapps_config:get_is_true(?CONFIG_CAT, <<"default_ignore_completed_elsewhere">>, 'true'),
    Value = kz_json:get_first_defined([[<<"caller_id_options">>, <<"ignore_completed_elsewhere">>]
                                      ,[<<"sip">>, <<"ignore_completed_elsewhere">>]
                                      ,<<"ignore_completed_elsewhere">>
                                      ], Endpoint, Default),
    kz_json:set_value(<<"Ignore-Completed-Elsewhere">>, kz_term:is_true(Value), CCVs).

-spec enforce_security(kz_json:object(), kz_json:object()) -> kz_json:object().
enforce_security(Endpoint, CCVs) ->
    case kz_json:get_ne_binary_value([<<"media">>, <<"encryption">>, <<"security">>], Endpoint) of
        'undefined' ->
            case kz_json:is_true([<<"media">>, <<"encryption">>, <<"enforce_security">>], Endpoint) of
                'true' ->
                    Security = <<"mandatory">>,
                    kz_json:set_value(<<"Media-Encryption">>, Security, CCVs);
                'false' -> CCVs
            end;
        Security -> kz_json:set_value(<<"Media-Encryption">>, Security, CCVs)
    end.

-spec encryption_flags(kz_json:object(), kz_json:object()) -> kz_json:object().
encryption_flags(Endpoint, CCVs) ->
    kz_endpoint:encryption_method_map(CCVs, Endpoint).

-spec add_alert_info(kz_json:object(), kz_json:object()) -> kz_json:object().
add_alert_info(Endpoint, CCVs) ->
    AlertInfo = [{<<"Internal-Alert-Info">>, kz_json:get_value([<<"ringtones">>, <<"internal">>], Endpoint)}
                ,{<<"External-Alert-Info">>, kz_json:get_value([<<"ringtones">>, <<"external">>], Endpoint)}
                ],
    kz_json:set_values(AlertInfo, CCVs).

-spec generate_ccvs(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), module()) -> kz_json:object().
generate_ccvs(_EndpointId, AccountId, Endpoint, Module) ->
    Realm = kzd_devices:sip_realm(Endpoint, kz_json:get_ne_binary_value(<<"realm">>, Endpoint)),
    Props = [{<<"Account-ID">>, AccountId}
            ,{<<"Reseller-ID">>, kz_services_reseller:get_id(AccountId)}
            ,{<<"Realm">>, Realm}
            ,{<<"Username">>, kzd_devices:sip_username(Endpoint)}
            ,{<<"SIP-Invite-Domain">>, Realm}
            ],
    CCVs = kz_json:from_list(Props),

    CCVFuns = [{fun endpoint_id/2, Endpoint}
              ,{fun owner_id/2, Endpoint}
              ,{fun rtcp_mux/2, Endpoint}
              ,{fun webrtc/2, Endpoint}
              ,{fun enable_fax/2, Endpoint}
              ,{fun enforce_security/2, Endpoint}
              ,{fun encryption_flags/2, Endpoint}
              ,{fun presence_id/2, Endpoint}
              ,{fun add_alert_info/2, Endpoint}
              ,{fun hold_music/2, Endpoint}
              ,{fun invite_uri/3, Module, Endpoint}
              ,{fun call_waiting/2, Endpoint}
              ,{fun progress_timeout/2, Endpoint}
              ,{fun ignore_early_media/3, Module, Endpoint}
              ,{fun bypass_media/3, Module, Endpoint}
              ,{fun ignore_completed_elsewhere/2, Endpoint}
              ],
    kz_json:exec(CCVFuns, CCVs).

-spec generate_sip_headers(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), module()) -> kz_json:object().
generate_sip_headers(_EndpointId, _AccountId, Endpoint, Module) ->
    HeaderFuns = [{fun add_sip_headers/2, Endpoint}
                 ,{fun maybe_add_aor/3, Module, Endpoint}
                 ],
    kz_json:exec(HeaderFuns, kz_json:new()).

-spec add_sip_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
add_sip_headers(Endpoint, Headers) ->
    case kzd_devices:custom_sip_headers_outbound(Endpoint) of
        'undefined' -> Headers;
        CustomHeaders -> kz_json:merge_jobjs(CustomHeaders, Headers)
    end.

-spec maybe_add_aor(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
maybe_add_aor(Module, Endpoint, Headers) ->
    Username = kzd_devices:sip_username(Endpoint),
    maybe_add_aor(Module, Username, Endpoint, Headers).

-spec maybe_add_aor(module(), kz_term:api_binary(), kz_json:object(), kz_json:object()) -> kz_json:object().
maybe_add_aor(_Mod, 'undefined', _Endpoint, Headers) -> Headers;
maybe_add_aor(Mod, Username, Endpoint, Headers) ->
    Realm = kzd_devices:sip_realm(Endpoint,  kz_json:get_ne_binary_value(<<"realm">>, Endpoint)),
    Format = Mod:invite_format(Endpoint),
    AOR = [{<<"X-KAZOO-AOR">>, <<"sip:", Username/binary, "@", Realm/binary>>}
          ,{<<"X-KAZOO-INVITE-FORMAT">>, Format}
          ],
    kz_json:set_values(AOR, Headers).

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
    ,{<<"Failover-Reasons">>, cfw_failover_reasons()}
    ].

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

call_forward_confirm_properties(_EndpointId, AccountId, Endpoint) ->
    Lang = kz_media_util:prompt_language(AccountId),
    case kzd_devices:call_forward_require_keypress(Endpoint) of
        'false' -> [];
        'true' -> [{<<"Confirm-Key">>, <<"1">>}
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

-spec dnd(kz_json:object()) -> boolean().
dnd(Endpoint) ->
    kz_json:is_true([<<"do_not_disturb">>, <<"enabled">>], Endpoint).
