%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
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
    lager:debug("looking up device profile ~s@~s"
               ,[EndpointId, AccountId]
               ),
    case kz_cache:fetch_local(?CACHE_NAME, {EndpointId, AccountId}) of
        {'ok', Profile} -> {'ok', Profile};
        {'error', 'not_found'} ->
            fetch_profile(EndpointId, AccountId, Options)
    end.

-spec fetch_profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_profile(EndpointId, AccountId, Options) ->
    case kz_endpoint:get(EndpointId, AccountId, Options) of
        {'ok', Endpoint} -> fetch_profile(EndpointId, AccountId, Endpoint, Options);
        Error ->
            lager:warning("unabled to fetch endpoint ~s in account ~s: ~p"
                         ,[EndpointId, AccountId, Error]
                         ),
            Error
    end.

-spec fetch_profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) ->
          {'ok', kz_json:object()}.
fetch_profile(EndpointId, AccountId, Endpoint, Options) ->
    case kz_json:get_ne_binary_value(<<"Endpoint-Type">>, Endpoint) of
        <<"device">> -> build_and_cache(EndpointId, AccountId, Endpoint, Options);
        _Type ->
            lager:warning("expected a device endpoint but ~s is of type ~s"
                         ,[EndpointId, _Type]
                         ),
            {'error', 'not_device'}
    end.

-spec build_and_cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) ->
          {'ok', kz_json:object()}.
build_and_cache(EndpointId, AccountId, Endpoint, Options) ->
    case get_device_module(Endpoint) of
        'undefined' ->
            lager:warning("unable to determine endpoint module for ~s@~s"
                         ,[EndpointId, AccountId]
                         ),
            {'error', 'no_device_module'};
        Module ->
            build_and_cache(EndpointId, AccountId, Endpoint, Options, Module)
    end.

-spec build_and_cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), atom()) ->
          {'ok', kz_json:object()}.
build_and_cache(EndpointId, AccountId, Endpoint, Options, Module) ->
    lager:debug("building profile ~s@~s with module ~s"
               ,[EndpointId, AccountId, Module]
               ),
    {'ok', Profile} = build(EndpointId, AccountId, Endpoint, Options, Module),
    Origins = cache_origin(EndpointId, AccountId, Endpoint),
    ProfileUpdates = [{<<"Endpoint-Options">>, kz_json:from_list(Options)}
                     ,{<<"Users">>
                      ,[<<UserId/binary, "@", AccountId/binary>>
                            || {'db', _Db, UserId} <- Origins
                                   ,not lists:member(UserId, [EndpointId, AccountId])
                       ]
                      }
                     ],
    cache(EndpointId, AccountId, kz_json:set_values(ProfileUpdates, Profile), Origins).

-spec cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_cache:origin_tuples()) ->
          {'ok', kz_json:object()}.
cache(EndpointId, AccountId, Profile, Origins) ->
    CacheProps = [{'origin', Origins}
                 ,{'callback', fun cache_callback/3}
                 ],
    kz_cache:store_local_async(?CACHE_NAME, {EndpointId, AccountId}, Profile, CacheProps),
    {'ok', Profile}.

-spec cache_callback(tuple(), kz_json:object(), callback_msg()) -> 'ok'.
cache_callback({EndpointId, AccountId}, CachedProfile, 'erase') ->
    lager:debug("profile ~s@~s erased from cache, rebuilding"
               ,[EndpointId, AccountId]
               ),
    timer:sleep(kz_term:to_integer(?MILLISECONDS_IN_SECOND * 0.15)),
    Options = kz_json:to_proplist(
                kz_json:get_ne_json_value(<<"Endpoint-Options">>, CachedProfile, kz_json:new())
               ),
    case fetch_profile(EndpointId, AccountId, Options) of
        {'ok', UpdatedProfile} ->
            maybe_clear(UpdatedProfile, CachedProfile);
        _Error -> clear(CachedProfile)
    end;
cache_callback(_, _, _) -> 'ok'.

-spec maybe_clear(kz_json:object(), kz_json:object()) -> 'ok'.
maybe_clear(UpdatedProfile, CachedProfile) ->
    case kz_json:are_equal(UpdatedProfile, CachedProfile) of
        'true' -> 'ok';
        'false' ->
            erase_new_users(UpdatedProfile, CachedProfile),
            clear(CachedProfile)
    end.

-spec erase_new_users(kz_json:object(), kz_json:object()) -> 'ok'.
erase_new_users(UpdatedProfile, CachedProfile) ->
    UpdatedUsers =
        sets:from_list(
          kz_json:get_ne_binaries(<<"Users">>, UpdatedProfile, [])
         ),
    CachedUsers =
        sets:from_list(
          kz_json:get_ne_binaries(<<"Users">>, CachedProfile, [])
         ),
    NewUsers = sets:to_list(
                 sets:subtract(UpdatedUsers, CachedUsers)
                ),
    _ = lists:map(fun erase_new_user/1, NewUsers),
    'ok'.

-spec erase_new_user(kz_term:ne_binary()) -> 'ok'.
erase_new_user(User) ->
    case binary:split(User, <<"@">>) of
        [UserId, AccountId] ->
            lager:debug("erasing associated cached user profile ~s@~s"
                       ,[UserId, AccountId]
                       ),
            kz_cache:erase_local(?CACHE_NAME, {UserId, AccountId});
        _Else -> 'ok'
    end.

-spec clear(kz_json:object()) -> 'ok'.
clear(Profile) ->
    EndpointId = kz_json:get_ne_binary_value(<<"User-ID">>, Profile),
    AccountId = kz_json:get_ne_binary_value(<<"Domain-Name">>, Profile),
    kz_directory_cache:clear(<<EndpointId/binary, "@", AccountId/binary>>).

-spec cache_origin(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) ->
          kz_cache:origin_tuples().
cache_origin(EndpointId, AccountId, JObj) ->
    AccountDb = kzs_util:format_account_db(AccountId),
    Routines = [fun(P) -> [{'db', AccountDb, EndpointId} | P] end
               ,fun(P) -> [{'db', AccountDb, AccountId} | P] end
               ,fun(P) -> maybe_cached_owner_id(P, JObj, AccountDb) end
               ,fun(P) -> maybe_cached_hotdesk_ids(P, JObj, AccountDb) end
               ],
    lists:foldl(fun(F, P) -> F(P) end, [], Routines).

-spec maybe_cached_owner_id(kz_cache:origin_tuples(), kz_json:object(), kz_term:ne_binary()) ->
          kz_cache:origin_tuples().
maybe_cached_owner_id(Props, JObj, AccountDb) ->
    case kz_json:get_ne_binary_value(<<"owner_id">>, JObj) of
        'undefined' -> Props;
        OwnerId -> [{'db', AccountDb, OwnerId}|Props]
    end.

-spec maybe_cached_hotdesk_ids(kz_cache:origin_tuples(), kz_json:object(), kz_term:ne_binary()) ->
          kz_cache:origin_tuples().
maybe_cached_hotdesk_ids(Props, JObj, AccountDb) ->
    case kz_json:get_keys([<<"hotdesk">>, <<"users">>], JObj) of
        [] -> Props;
        OwnerIds -> lists:foldl(fun(Id, P) -> [{'db', AccountDb, Id}|P] end, Props, OwnerIds)
    end.

-spec tags(kz_json:object()) -> kz_term:api_ne_objects().
tags(Endpoint) -> kzd_endpoint:tags(Endpoint).

-spec call_limit(kzd_endpoint:endpoint()) -> kz_term:api_integer().
call_limit(Endpoint) ->
    kzd_endpoint:call_limits(Endpoint).

-spec call_waiting(kzd_endpoint:endpoint()) -> kz_term:api_boolean().
call_waiting(Endpoint) ->
    case kzd_devices:call_waiting(Endpoint) of
        'undefined' -> 'undefined';
        CW -> kzd_call_waiting:enabled(CW)
    end.

-spec build(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), atom()) -> {'ok', kz_json:object()}.
build(EndpointId, AccountId, Endpoint, Options, Module) ->
    Context = #{endpoint_id => EndpointId
               ,account_id => AccountId
               ,endpoint => Endpoint
               ,options => Options
               ,module => Module
               ,endpoint_uri => list_to_binary([EndpointId, "@", AccountId])
               },
    build(Context).

-spec build(map()) -> {'ok', kz_json:object()}.
build(Context) ->
    Routines = [fun build_profile/1
               ,fun build_dial_string/1
               ],
    #{profile := Profile} = kz_maps:exec(Routines, Context),
    {'ok', Profile}.


build_dial_string(#{profile := Profile, endpoint := Endpoint} = Context) ->
    DialString = dial_string_by_type(Context, kzd_devices:device_type(Endpoint)),
    Context#{profile => kz_json:set_value(<<"Endpoint-Dial-String">>, DialString, Profile)}.

is_meta_dial_enabled(#{endpoint := Endpoint}) ->
    case kz_json:is_true([<<"call_settings">>, <<"directory">>, <<"metadial">>, <<"device">>], Endpoint, 'undefined') of
        'undefined' -> kz_app_config:is_true(?APP, <<"metadial.device">>, 'true');
        Override -> Override
    end.

meta_dial_string(#{endpoint_id := Id}, Default) ->
    list_to_binary(["${kz_meta_dialstring(", Id, " ", Default, ")}"]).

meta_dial_string(#{endpoint_id := Id}) ->
    list_to_binary(["${kz_meta_dialstring(", Id, ")}"]).

dial_string_by_type(Context, <<"meta">>) ->
    meta_dial_string(Context, ?NO_ENDPOINTS);
dial_string_by_type(Context, <<"application">>) ->
    app_dial_string(Context);
dial_string_by_type(Context, _Other) ->
    dial_string(Context).

app_dial_string(#{endpoint := Endpoint} = Context) ->
    case kz_json:get_ne_binary_value([<<"pvt_application">>, <<"dialstring">>], kz_doc:private_fields(Endpoint)) of
        'undefined' -> dial_string(Context);
        AppDialString -> AppDialString
    end.

dial_string(#{profile := Profile} = Context) ->
    case kz_json:get_ne_binary_value(<<"SIP-Invite-Route-URI">>, Profile) of
        'undefined' -> kz_dial_string(Context);
        Uri -> sip_dial_string(Context, Uri)
    end.

default_sip_interface() ->
    kz_app_config:get_ne_binary(?APP, <<"sip.default_interface">>, ?DEFAULT_SIP_PROFILE).

sip_dial_string(#{profile := Profile}, Uri) ->
    SIPInterface = kz_json:get_ne_binary_value(<<"SIP-Interface">>, Profile, default_sip_interface()),
    list_to_binary(["sofia/", SIPInterface, "/", Uri]).

kz_dial_string(Context) ->
    case is_meta_dial_enabled(Context) of
        'true' -> kz_binary:join([kz_contact(Context), meta_dial_string(Context)], <<",">>);
        'false' -> kz_contact(Context)
    end.

default_kz_contact_api() ->
    kz_app_config:get_ne_binary(?APP, <<"contact_api">>, <<"kz_proxy_contact">>).

kz_contact_api(#{endpoint := Endpoint}) ->
    kz_json:get_ne_binary_value([<<"settings">>, <<"directory">>, <<"contact_api">>], Endpoint, default_kz_contact_api()).

kz_contact(#{endpoint_uri := Uri} = Context) ->
    list_to_binary(["${", kz_contact_api(Context), "(", Uri, ")}"]).

build_profile(Context) ->
    #{endpoint_id := EndpointId
     ,account_id := AccountId
     ,endpoint := Endpoint
     ,options := Options
     ,module := Module
     } = Context,

    CCVs = generate_ccvs(EndpointId, AccountId, Endpoint, Options, Module),
    SIPHeaders = generate_sip_headers(EndpointId, AccountId, Endpoint, Options, Module),
    CRVs = generate_routing_ccvs(Endpoint, Options, Module),
    CAVs = kz_json:get_json_value(<<"default_cavs">>, Endpoint),
    CPVs = build_profile_vars(AccountId, EndpointId, Endpoint, CCVs),

    Profile = [{<<"Endpoint-Type">>, <<"device">>}
              ,{<<"Domain-Name">>, AccountId}
              ,{<<"User-ID">>, EndpointId}
              ,{<<"Account-ID">>, AccountId}
              ,{<<"Custom-Channel-Vars">>, CCVs}
              ,{<<"Custom-Application-Vars">>, CAVs}
              ,{<<"Custom-Profile-Vars">>, kz_json:from_list(CPVs)}
              ,{<<"Custom-Routing-Vars">>, CRVs}
              ,{<<"Custom-SIP-Headers">>, SIPHeaders}
              ,{<<"Codecs">>, Module:codecs(Endpoint)}
              ,{<<"SIP-Invite-Route-URI">>, Module:sip_route(Endpoint)}
              ,{<<"SIP-Proxy-Route-URI">>, Module:sip_route_uri(Endpoint)}
              ,{<<"SIP-Interface">>, Module:sip_interface(Endpoint)}
              ,{<<"CallForward">> , kz_directory_cfwd:call_forward(EndpointId, AccountId, Endpoint)}
              ,{<<"Failover">> , kz_directory_failover:failover(EndpointId, AccountId, Endpoint)}
              ,{<<"Expires">>, ?DIRECORY_CACHE_TIME_MS}
              ],
    Context#{profile => kz_json:from_list(Profile)}.

build_profile_vars(AccountId, EndpointId, Endpoint, CCVs) ->
    {CIDNumber, CIDName} = kz_attributes:get_endpoint_cid(<<"internal">>, Endpoint),
    {CEDNumber, CEDName} = kz_attributes:get_endpoint_cid(<<"external">>, Endpoint),

    [{<<"Internal-Caller-ID-Number">>, CIDNumber}
    ,{<<"Internal-Caller-ID-Name">>, CIDName}
    ,{<<"External-Caller-ID-Number">>, CEDNumber}
    ,{<<"External-Caller-ID-Name">>, CEDName}
    ,{<<"Account-ID">>, AccountId}
    ,{<<"Endpoint-ID">>, EndpointId}
    ,{<<"Endpoint-Type">>, <<"device">>}
    ,{<<"Endpoint-Device-Type">>, kzd_devices:device_type(Endpoint)}
    ,{<<"Endpoint-Application">>, kzd_devices:application_name(Endpoint)}
    ,{<<"Endpoint-Owner-ID">>, kzd_endpoint:owner_id(Endpoint)}
    ,{<<"Endpoint-Caller-ID-Number">>, CIDNumber}
    ,{<<"Endpoint-Caller-ID-Name">>, CIDName}
    ,{<<"Endpoint-Presence-ID">>, kz_json:get_ne_binary_value(<<"Presence-ID">>, CCVs)}
    ,{<<"Endpoint-Presence-Aliases">>, presence_aliases(Endpoint)}
    ,{<<"Endpoint-DND">>, dnd(Endpoint)}
    ,{<<"Endpoint-Tag-Rules">>, tags(Endpoint)}
    ,{<<"Endpoint-Call-Limit">>, call_limit(Endpoint)}
    ,{<<"Endpoint-Call-Waiting">>, call_waiting(Endpoint)}
    ].

-spec get_device_module(kz_json:object()) -> atom().
get_device_module(Endpoint) ->
    case get_endpoint_type(Endpoint) of
        <<"unknown">> -> 'undefined';
        Type -> ensure_device_module(Type)
    end.

-spec ensure_device_module(kz_term:ne_binary()) -> atom().
ensure_device_module(Name) ->
    Module = kz_term:to_atom(<<"kz_directory_device_", Name/binary>>, 'true'),
    case kz_module:has_behaviour(Module, 'kz_directory_device_spec') of
        'true' -> Module;
        'false' -> 'undefined'
    end.

-spec get_endpoint_type(kz_json:object()) -> kz_term:ne_binary().
get_endpoint_type(Endpoint) ->
    Routines = [fun maybe_endpoint_type_is_push/1
               ,fun get_endpoint_type_property/1
               ],
    Fun = fun(F, 'undefined') -> F(Endpoint);
             (_F, T) -> T
          end,
    Type = lists:foldl(Fun, 'undefined', Routines),
    case convert_endpoint_type(Type) of
        'undefined' -> maybe_guess_endpoint_type(Endpoint);
        Else -> Else
    end.

-spec maybe_endpoint_type_is_push(kz_json:object()) -> kz_term:api_ne_binary().
maybe_endpoint_type_is_push(Endpoint) ->
    case kz_json:is_empty(kz_json:get_json_value(<<"push">>, Endpoint, kz_json:new())) of
        'true' -> 'undefined';
        'false' -> <<"push">>
    end.

-spec get_endpoint_type_property(kz_json:object()) -> kz_term:api_ne_binary().
get_endpoint_type_property(Endpoint) ->
    kzd_devices:device_type(Endpoint, <<"sip_device">>).

-spec convert_endpoint_type(kz_term:ne_binary()) -> kz_term:api_ne_binary().
convert_endpoint_type(<<"push">>) -> <<"push">>;
convert_endpoint_type(<<"sip_", _/binary>>) -> <<"sip">>;
convert_endpoint_type(<<"sip">>) -> <<"sip">>;
convert_endpoint_type(<<"smartphone">>) -> <<"sip">>;
convert_endpoint_type(<<"softphone">>) -> <<"sip">>;
convert_endpoint_type(<<"cellphone">>) -> <<"sip">>;
convert_endpoint_type(<<"landline">>) -> <<"sip">>;
convert_endpoint_type(<<"fax">>) -> <<"sip">>;
convert_endpoint_type(<<"ata">>) -> <<"sip">>;
convert_endpoint_type(<<"mobile">>) -> <<"mobile">>;
convert_endpoint_type(<<"application">>) -> <<"sip">>;
convert_endpoint_type(<<"meta">>) -> <<"sip">>;
convert_endpoint_type(_Else) ->
    lager:info("unexpected endpoint type ~s", [_Else]),
    'undefined'.

-spec maybe_guess_endpoint_type(kz_json:object()) -> kz_term:ne_binary().
maybe_guess_endpoint_type(Endpoint) ->
    case kapps_config:get_is_true(?CONFIG_CAT, <<"restrict_to_known_types">>, 'false') of
        'false' -> guess_endpoint_type(Endpoint);
        'true' ->
            lager:info("unknown endpoint type and callflows restricted to known types"),
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

-spec is_calculate_presence_id_enabled(kz_json:object()) -> boolean().
is_calculate_presence_id_enabled(Endpoint) ->
    case kz_json:is_true([<<"call_settings">>, <<"directory">>, <<"presence_id">>, <<"calculate">>], Endpoint, 'undefined') of
        'undefined' -> kz_app_config:is_true(?APP, <<"presence_id.calculate">>, 'true');
        Override -> Override
    end.

-spec presence_id(kz_json:object(), kz_json:object()) -> kz_json:object().
presence_id(Endpoint, CCVs) ->
    presence_id(is_calculate_presence_id_enabled(Endpoint), Endpoint, CCVs).

-spec presence_id(boolean(), kz_json:object(), kz_json:object()) -> kz_json:object().
presence_id(true, Endpoint, CCVs) ->
    kz_json:set_value(<<"Presence-ID">>, calculate_presence_id(Endpoint), CCVs);
presence_id(false, Endpoint, CCVs) ->
    kz_json:set_value(<<"Presence-ID">>, presence_id(Endpoint), CCVs).

-spec calculate_presence_id(kz_json:object()) -> kz_term:api_ne_binary().
calculate_presence_id(Endpoint) ->
    case kzd_endpoint:presence_id(Endpoint) of
        'undefined' -> kzd_devices:calculate_presence_id(Endpoint);
        PresenceId -> maybe_fix_presence_id(Endpoint, PresenceId)
    end.

-spec presence_id(kz_json:object()) -> kz_term:api_ne_binary().
presence_id(Endpoint) ->
    maybe_fix_presence_id(Endpoint, kzd_endpoint:presence_id(Endpoint)).

-spec is_presence_id_ensure_realm_enabled(kz_json:object()) -> boolean().
is_presence_id_ensure_realm_enabled(Endpoint) ->
    case kz_json:is_true([<<"call_settings">>, <<"directory">>, <<"presence_id">>, <<"ensure_realm">>], Endpoint, 'undefined') of
        'undefined' -> kz_app_config:is_true(?APP, <<"presence_id.ensure_realm">>, true);
        Override -> Override
    end.

-spec maybe_fix_presence_id(kz_json:object(), kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
maybe_fix_presence_id(_Endpoint, 'undefined') ->
    'undefined';
maybe_fix_presence_id(Endpoint, PresenceId) ->
    case is_presence_id_ensure_realm_enabled(Endpoint) of
        'true' -> ensure_presence_id_realm(Endpoint, PresenceId);
        'false' -> PresenceId
    end.

ensure_presence_id_realm(Endpoint, PresenceId) ->
    case binary:match(PresenceId, <<"@">>) of
        'nomatch' -> fix_presence_id_realm(Endpoint, PresenceId);
        _Match -> PresenceId
    end.

-spec fix_presence_id_realm(kz_json:object(), kz_term:ne_binary()) -> kz_term:ne_binary().
fix_presence_id_realm(Endpoint, PresenceId) ->
    Realm = kz_json:get_ne_binary_value(<<"realm">>, Endpoint),
    <<PresenceId/binary, "@", Realm/binary>>.

-spec presence_aliases(kz_json:object()) -> kz_term:api_ne_binaries().
presence_aliases(Endpoint) ->
    kzd_endpoint:presence_aliases(Endpoint).

-spec hold_music(kz_json:object(), kz_json:object()) -> kz_json:object().
hold_music(Endpoint, CCVs) ->
    kz_json:set_value(<<"Hold-Media">>, kzd_endpoint:moh_url(Endpoint), CCVs).

-spec hold_music_options(kz_json:object(), kz_json:object()) -> kz_json:object().
hold_music_options(Endpoint, CCVs) ->
    kz_json:set_value(<<"Hold-Media-Options">>, kzd_endpoint:moh_options(Endpoint), CCVs).

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
                                      ]
                                     ,Endpoint
                                     ,Default
                                     ),
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

-spec ringtone(kz_json:object(), kz_term:ne_binary()) -> kz_term:api_ne_binary().
ringtone(Endpoint, Key) ->
    case kz_json:get_ne_binary_value([<<"ringtones">>, Key], Endpoint) of
        'undefined' -> 'undefined';
        RingTone -> <<"${first-of(alert_info|#", RingTone/binary, ")}">>
    end.

-spec ringtones(kz_json:object(), kz_term:ne_binaries()) -> kz_term:proplist().
ringtones(Endpoint, Keys) ->
    lists:foldl(ringtones_fold_fun(Endpoint), [], Keys).

-spec ringtones_fold_fun(kz_json:object()) -> fun((kz_term:ne_binary(), kz_term:proplist()) -> kz_term:proplist()).
ringtones_fold_fun(Endpoint) ->
    fun(Key, Acc) ->
            case ringtone(Endpoint, kz_term:to_lower_binary(Key)) of
                'undefined' -> Acc;
                RingTone -> [{[Key, <<"Alert-Info">>], RingTone} | Acc]
            end
    end.

-spec inception_context_keys() -> kz_term:ne_binaries().
inception_context_keys() -> [<<"Internal">>, <<"External">>].

-spec add_alert_info(kz_json:object(), kz_json:object()) -> kz_json:object().
add_alert_info(Endpoint, CCVs) ->
    case ringtones(Endpoint, inception_context_keys()) of
        [] -> CCVs;
        Values -> kz_json:set_values(Values, CCVs)
    end.

-spec generate_ccvs(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), module()) -> kz_json:object().
generate_ccvs(_EndpointId, AccountId, Endpoint, _Options, Module) ->
    Realm = kzd_devices:sip_realm(Endpoint, kz_json:get_ne_binary_value(<<"realm">>, Endpoint)),
    Props = [{<<"Account-ID">>, AccountId}
            ,{<<"Reseller-ID">>, kz_services_reseller:get_id(AccountId)}
            ,{<<"Realm">>, Realm}
            ,{<<"Username">>, kzd_devices:sip_username(Endpoint)}
            ,{<<"SIP-Invite-Domain">>, Realm}
            ],
    CCVs = kz_json:from_list(Props),

    CCVFuns = [{fun default_ccvs/2, Endpoint}
              ,{fun endpoint_id/2, Endpoint}
              ,{fun owner_id/2, Endpoint}
              ,{fun hold_music/2, Endpoint}
              ,{fun hold_music_options/2, Endpoint}
              ,{fun add_alert_info/2, Endpoint}
              ,{fun presence_id/2, Endpoint}
              ,{fun relay_id/2, Endpoint}
              ,{fun sip_auth/3, Module, Endpoint}
              ],
    kz_json:exec(CCVFuns, CCVs).

-spec generate_routing_ccvs(kz_json:object(), kz_term:proplist(), module()) -> kz_json:object().
generate_routing_ccvs(Endpoint, _Options, Module) ->
    CCVs = kz_json:new(),
    CCVFuns = [{fun rtcp_mux/2, Endpoint}
              ,{fun webrtc/2, Endpoint}
              ,{fun enable_fax/2, Endpoint}
              ,{fun enforce_security/2, Endpoint}
              ,{fun encryption_flags/2, Endpoint}
              ,{fun call_waiting/2, Endpoint}
              ,{fun progress_timeout/2, Endpoint}
              ,{fun ignore_early_media/3, Module, Endpoint}
              ,{fun bypass_media/3, Module, Endpoint}
              ,{fun ignore_completed_elsewhere/2, Endpoint}
              ,{fun invite_uri/3, Module, Endpoint}
              ,{fun routing_ccvs/3, Module, Endpoint}
              ],
    kz_json:exec(CCVFuns, CCVs).

-spec default_ccvs(kz_json:object(), kz_json:object()) -> kz_json:object().
default_ccvs(Endpoint, CCVs) ->
    case kz_json:get_json_value(<<"default_ccvs">>, Endpoint) of
        'undefined' -> CCVs;
        DefaultCCVs -> kz_json:merge(DefaultCCVs, CCVs)
    end.

-spec sip_auth(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
sip_auth(Mod, Endpoint, CCVs) ->
    case sip_auth(Endpoint) of
        'undefined' -> Mod:sip_auth(Endpoint, CCVs);
        SIPAuth -> kz_json:merge(CCVs, SIPAuth)
    end.

-spec sip_auth(kz_json:object()) -> kz_term:api_object().
sip_auth(Endpoint) ->
    case {kzd_devices:sip_username(Endpoint)
         ,kzd_devices:sip_password(Endpoint)
         }
    of
        {'undefined', _} -> 'undefined';
        {_, 'undefined'} -> 'undefined';
        {Username, Password} ->
            KVs = [{<<"Auth-User">>, Username}
                  ,{<<"Auth-Password">>, Password}
                  ],
            kz_json:set_values(KVs, kz_json:new())
    end.

-spec routing_ccvs(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
routing_ccvs(Mod, Endpoint, CCVs) ->
    Mod:routing_ccvs(Endpoint, CCVs).

-spec generate_sip_headers(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist(), module()) -> kz_json:object().
generate_sip_headers(_EndpointId, _AccountId, Endpoint, _Options, Module) ->
    HeaderFuns = [{fun add_routing_sip_headers/2, Endpoint}
                 ,{fun add_inbound_sip_headers/2, Endpoint}
                 ,{fun maybe_add_aor/2, Endpoint}
                 ,{fun maybe_add_invite_format/3, Module, Endpoint}
                 ,{fun maybe_add_specific_headers/3, Module, Endpoint}
                 ],
    kz_json:exec(HeaderFuns, kz_json:new()).

-spec add_routing_sip_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
add_routing_sip_headers(Endpoint, Headers) ->
    case kzd_devices:custom_sip_headers_routing(Endpoint) of
        'undefined' -> Headers;
        CustomHeaders -> kz_json:merge_jobjs(CustomHeaders, Headers)
    end.

-spec add_inbound_sip_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
add_inbound_sip_headers(Endpoint, Headers) ->
    case kzd_devices:custom_sip_headers_inbound(Endpoint) of
        'undefined' -> Headers;
        CustomHeaders -> kz_json:merge_jobjs(CustomHeaders, Headers)
    end.

-spec maybe_add_aor(kz_json:object(), kz_json:object()) -> kz_json:object().
maybe_add_aor(Endpoint, Headers) ->
    Username = kzd_devices:sip_username(Endpoint),
    maybe_add_aor(Username, Endpoint, Headers).

-spec maybe_add_aor(kz_term:api_binary(), kz_json:object(), kz_json:object()) -> kz_json:object().
maybe_add_aor('undefined', _Endpoint, Headers) -> Headers;
maybe_add_aor(Username, Endpoint, Headers) ->
    Realm = kzd_devices:sip_realm(Endpoint,  kz_json:get_ne_binary_value(<<"realm">>, Endpoint)),
    AOR = <<"sip:", Username/binary, "@", Realm/binary>>,
    kz_json:set_value(<<"X-KAZOO-AOR">>, AOR, Headers).

-spec maybe_add_invite_format(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
maybe_add_invite_format('undefined', _Endpoint, Headers) ->
    Headers;
maybe_add_invite_format(Module, Endpoint, Headers) ->
    Format = Module:invite_format(Endpoint),
    kz_json:set_value(<<"X-KAZOO-INVITE-FORMAT">>, Format, Headers).

-spec maybe_add_specific_headers(module(), kz_json:object(), kz_json:object()) -> kz_json:object().
maybe_add_specific_headers('undefined', _Endpoint, Headers) ->
    Headers;
maybe_add_specific_headers(Module, Endpoint, Headers) ->
    Module:sip_headers(Endpoint, Headers).

-spec dnd(kz_json:object()) -> boolean().
dnd(Endpoint) ->
    kz_json:is_true([<<"do_not_disturb">>, <<"enabled">>], Endpoint).

-spec relay_id(kz_json:object(), kz_json:object()) -> kz_json:object().
relay_id(Endpoint, CCVs) ->
    case kz_json:get_json_value([<<"Endpoint-Build-Options">>, <<"claims">>], Endpoint) of
        'undefined' -> CCVs;
        Claims -> relay_id_from_claims(Claims, CCVs)
    end.

relay_id_from_claims(Claims, CCVs) ->
    kz_json:set_value(<<"Relay-ID">>, id_claim(Claims), CCVs).

-spec id_claim(kz_json:object()) -> kz_json:json_term().
id_claim(Claims) ->
    kz_json:get_ne_binary_value(<<"id">>, Claims, 'null').
