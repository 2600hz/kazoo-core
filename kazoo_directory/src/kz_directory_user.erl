%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2026, 2600Hz
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

-type user_context() ::
        #{endpoint_id   := kz_term:ne_binary(),
          account_id    := kz_term:ne_binary(),
          endpoint      := kz_json:object(),
          options       := kz_term:proplist(),
          endpoint_uri  := kz_term:ne_binary(),
          %% populated by the build pipeline
          profile       => kz_json:object(),
          no_cache      => boolean()
         }.

-spec profile(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId) ->
    profile(EndpointId, AccountId, []).

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId, Options) ->
    case kz_cache:fetch_local(?CACHE_NAME, {EndpointId, AccountId}) of
        {'ok', {Profile, _Options}} -> {'ok', Profile};
        {'error', 'not_found'} -> fetch_profile(EndpointId, AccountId, Options)
    end.

-spec fetch_profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> {'ok', kz_json:object()} | {'error', any()}.
fetch_profile(EndpointId, AccountId, Options) ->
    case kz_endpoint:get(EndpointId, AccountId) of
        {'ok', Endpoint} -> fetch_profile(EndpointId, AccountId, Endpoint, Options);
        Error -> Error
    end.

-spec fetch_profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
fetch_profile(EndpointId, AccountId, Endpoint, Options) ->
    case kz_json:get_ne_binary_value(<<"Endpoint-Type">>, Endpoint) of
        <<"user">> -> build_and_cache(EndpointId, AccountId, Endpoint, Options);
        _ -> {'error', 'not_user'}
    end.

-spec build_and_cache(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
build_and_cache(EndpointId, AccountId, Endpoint, Options) ->
    {'ok', #{} = Context} = build(EndpointId, AccountId, Endpoint, Options),
    cache(EndpointId, AccountId, Context, Options).

-spec cache(kz_term:ne_binary(), kz_term:ne_binary(), user_context(), kz_term:proplist()) -> {'ok', kz_json:object()}.
cache(_EndpointId, _AccountId, #{profile := Profile, no_cache := true}, _Options) ->
    {ok, Profile};
cache(EndpointId, AccountId, #{profile := Profile}, Options) ->
    Origins = cache_origin(EndpointId, AccountId, Profile),
    CacheProps = [{'origin', Origins}
                 ,{'callback', fun cache_callback/3}
                 ,{'expires', kz_directory_cache:cache_lifetime()}
                 ],
    kz_cache:store_local_async(?CACHE_NAME, {EndpointId, AccountId}, {Profile, Options}, CacheProps),
    {'ok', Profile}.

-spec cache_callback(tuple(), kz_json:object(), callback_msg()) -> 'ok'.
cache_callback({EndpointId, AccountId}, {CachedValue, Options}, 'erase') ->
    lager:debug("directory cache erased key (~s / ~s)", [EndpointId, AccountId]),
    case kz_endpoint:get(EndpointId, AccountId, props:set_value('no_cache', Options)) of
        {'ok', Endpoint} ->
            {'ok', #{} = Context} = build(EndpointId, AccountId, Endpoint, Options),
            _ = maybe_notify(EndpointId, AccountId, Context, CachedValue),
            _ = cache(EndpointId, AccountId, Context, Options),
            ok;
        _Error ->
            notify(EndpointId, AccountId)
    end;
cache_callback(_, _, _) -> 'ok'.

maybe_notify(EndpointId, AccountId, #{profile := Profile}, CachedValue) ->
    case kz_json:are_equal(Profile, CachedValue) of
        true -> lager:debug("directory cache erased key hasn't changed (~s / ~s)", [EndpointId, AccountId]);
        false -> notify(EndpointId, AccountId)
    end.

notify(EndpointId, AccountId) ->
    kz_directory_cache:clear(<<EndpointId/binary, "@", AccountId/binary>>),
    lager:debug("directory cache erased key changed (~s / ~s)", [EndpointId, AccountId]).

-spec cache_origin(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> list().
cache_origin(EndpointId, AccountId, Profile) ->
    Members = kz_json:get_ne_binaries(<<"Members">>, Profile, []),
    AccountDb = kzs_util:format_account_db(AccountId),
    Routines = [fun(P) -> [{'db', AccountDb, EndpointId} | P] end
               ,fun(P) -> [{'db', AccountDb, AccountId} | P] end
               ,fun(P) -> lists:foldl(fun(M, A) -> [{'db', AccountDb, M} | A] end, P, Members) end
               ],
    lists:foldl(fun(F, P) -> F(P) end, [], Routines).

-spec tags(kz_json:object()) -> kz_term:api_ne_objects().
tags(Endpoint) -> kzd_endpoint:tags(Endpoint).

-spec call_limit(kzd_endpoint:endpoint()) -> kz_term:api_integer().
call_limit(Endpoint) ->
    kzd_endpoint:call_limits(Endpoint).

-spec call_waiting(kzd_endpoint:endpoint()) -> kz_term:api_boolean().
call_waiting(Endpoint) ->
    case kzd_users:call_waiting(Endpoint) of
        'undefined' -> 'undefined';
        CW -> kzd_call_waiting:enabled(CW)
    end.

-spec build(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', user_context()}.
build(EndpointId, AccountId, Endpoint, Options) ->
    Context = #{endpoint_id => EndpointId
               ,account_id => AccountId
               ,endpoint => Endpoint
               ,options => Options
               ,endpoint_uri => list_to_binary([EndpointId, "@", AccountId])
               },
    build(Context).

-spec build(map()) -> {'ok', user_context()}.
build(Context) ->
    Routines = [fun build_profile/1
               ,fun dial_string/1
               ,fun no_cache_check/1
               ],
    {'ok', kz_maps:exec(Routines, Context)}.

no_cache_check(#{endpoint_id := OwnerId, account_id := AccountId, profile := Profile} = Context) ->
    case kz_json:get_ne_binary_value(<<"Endpoint-Dial-String">>, Profile) =:= ?NO_ENDPOINTS
        andalso kz_json:get_ne_json_value(<<"CallForward">>, Profile) =:= undefined
        andalso kz_json:get_ne_json_value(<<"Failover">>, Profile) =:= undefined
    of
        false -> Context;
        true ->
            lager:warning("user ~s from account ~s has no devices, no callfwd or failover and no metadial enabled", [OwnerId, AccountId]),
            Context#{no_cache => true}
    end.

dial_string(#{profile := Profile} = Context) ->
    DialString = dial_string(Context, dial_members(Context), is_meta_dial_enabled(Context)),
    Context#{profile => kz_json:set_value(<<"Endpoint-Dial-String">>, DialString, Profile)}.

dial_members(#{profile := Profile}) ->
    kz_json:get_ne_binaries(<<"Members">>, Profile, []).

is_meta_dial_enabled(#{endpoint := Endpoint}) ->
    case kz_json:is_true([<<"call_settings">>, <<"directory">>, <<"metadial">>, <<"user">>], Endpoint, undefined) of
        undefined -> kz_app_config:is_true(?APP, <<"metadial.user">>, false);
        Override -> Override
    end.

meta_dial_string(#{endpoint_id := Id}, Default) ->
    list_to_binary(["${kz_meta_dialstring(", Id, " ", Default, ")}"]).

meta_dial_string(#{endpoint_id := Id}) ->
    list_to_binary(["${kz_meta_dialstring(", Id, ")}"]).

dial_string(_Context, [], false) ->
    ?NO_ENDPOINTS;
dial_string(Context, [], true) ->
    meta_dial_string(Context, ?NO_ENDPOINTS);
dial_string(Context, Members, true) ->
    kz_binary:join(kz_dial_string(Context, Members) ++ [meta_dial_string(Context)], <<",">>);
dial_string(Context, Members, false) ->
    kz_binary:join(kz_dial_string(Context, Members), <<",">>).

kz_dial_string(#{account_id := AccountId}, Members) ->
    [list_to_binary(["kz/", Member, "@", AccountId]) || Member <- Members].

build_profile(Context) ->
    #{endpoint_id := EndpointId
     ,account_id := AccountId
     ,endpoint := Endpoint
     ,options := Options
     } = Context,

    CCVs = generate_ccvs(EndpointId, AccountId, Endpoint, Options),
    SIPHeaders = generate_sip_headers(EndpointId, AccountId, Endpoint, Options),
    CAVs = kz_json:get_json_value(<<"default_cavs">>, Endpoint),
    CPVs = build_profile_vars(AccountId, EndpointId, Endpoint, CCVs),
    {ok, Endpoints} = owned_by_query(EndpointId, AccountId),

    Profile = [{<<"Endpoint-Type">>, <<"user">>}
              ,{<<"Domain-Name">>, AccountId}
              ,{<<"User-ID">>, EndpointId}
              ,{<<"Members">>, Endpoints}
              ,{<<"Custom-Channel-Vars">>, CCVs}
              ,{<<"Custom-Application-Vars">>, CAVs}
              ,{<<"Custom-Profile-Vars">>, kz_json:from_list(CPVs)}
              ,{<<"Custom-SIP-Headers">>, SIPHeaders}
              ,{<<"CallForward">> , kz_directory_cfwd:call_forward(EndpointId, AccountId, Endpoint)}
              ,{<<"Failover">> , kz_directory_failover:failover(EndpointId, AccountId, Endpoint)}
              ,{<<"Expires">>, ?DIRECORY_CACHE_TIME_MS}
              ,{<<"Revision">>, kz_doc:revision(Endpoint)}
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
    ,{<<"Endpoint-Type">>, <<"user">>}
    ,{<<"Endpoint-Caller-ID-Number">>, CIDNumber}
    ,{<<"Endpoint-Caller-ID-Name">>, CIDName}
    ,{<<"Endpoint-Presence-ID">>, kz_json:get_ne_binary_value(<<"Presence-ID">>, CCVs)}
    ,{<<"Endpoint-Presence-Aliases">>, presence_aliases(Endpoint)}
    ,{<<"Endpoint-DND">>, dnd(Endpoint)}
    ,{<<"Endpoint-Tag-Rules">>, tags(Endpoint)}
    ,{<<"Endpoint-Call-Limit">>, call_limit(Endpoint)}
    ,{<<"Endpoint-Call-Waiting">>, call_waiting(Endpoint)}
    ].

-spec generate_ccvs(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> kz_json:object().
generate_ccvs(_EndpointId, AccountId, Endpoint, _Options) ->
    Realm = kz_json:get_ne_binary_value(<<"realm">>, Endpoint),
    Props = [{<<"Account-ID">>, AccountId}
            ,{<<"Reseller-ID">>, kz_services_reseller:get_id(AccountId)}
            ,{<<"Realm">>, Realm}
            ,{<<"Username">>, kzd_devices:sip_username(Endpoint)}
            ,{<<"SIP-Invite-Domain">>, Realm}
            ,{<<"Ignore-Early-Media">>, 'true'}
            ,{<<"Endpoint-Mark-Ring-Ready">>, true}
            ],
    CCVs = kz_json:from_list(Props),

    CCVFuns = [{fun default_ccvs/2, Endpoint}
              ,{fun owner_id/2, Endpoint}
              ,{fun presence_id/2, Endpoint}
              ,{fun hold_music/2, Endpoint}
              ,{fun hold_music_options/2, Endpoint}
              ,{fun relay_id/2, Endpoint}
              ],
    kz_json:exec(CCVFuns, CCVs).

-spec default_ccvs(kz_json:object(), kz_json:object()) -> kz_json:object().
default_ccvs(Endpoint, CCVs) ->
    case kz_json:get_json_value(<<"default_ccvs">>, Endpoint) of
        'undefined' -> CCVs;
        DefaultCCVs -> merge_default_ccvs(DefaultCCVs, CCVs)
    end.

-spec merge_default_ccvs(kz_json:object(), kz_json:object()) -> kz_json:object().
merge_default_ccvs(DefaultCCVs, CCVs) ->
    SetCCVs = kz_json:filter(fun default_ccvs_set/1, DefaultCCVs),
    UnsetCCVs = kz_json:filter(fun default_ccvs_unset/1, DefaultCCVs),
    kz_json:merge([SetCCVs, CCVs, UnsetCCVs]).

-spec default_ccvs_unset(kz_json:json_kv()) -> boolean().
default_ccvs_unset({_, null}) -> true;
default_ccvs_unset(_) -> false.

-spec default_ccvs_set(kz_json:json_kv()) -> boolean().
default_ccvs_set({_, null}) -> false;
default_ccvs_set(_) -> true.

-spec presence_id(kz_json:object(), kz_json:object()) -> kz_json:object().
presence_id(Endpoint, CCVs) ->
    kz_json:set_value(<<"Presence-ID">>, presence_id(Endpoint), CCVs).

-spec presence_id(kz_json:object()) -> kz_term:api_ne_binary().
presence_id(Endpoint) ->
    maybe_fix_presence_id(Endpoint, kzd_endpoint:presence_id(Endpoint)).

-spec is_presence_id_ensure_realm_enabled(kz_json:object()) -> boolean().
is_presence_id_ensure_realm_enabled(Endpoint) ->
    case kz_json:is_true([<<"call_settings">>, <<"directory">>, <<"presence_id">>, <<"ensure_realm">>], Endpoint, undefined) of
        undefined -> kz_app_config:is_true(?APP, <<"presence_id.ensure_realm">>, true);
        Override -> Override
    end.

-spec maybe_fix_presence_id(kz_json:object(), kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
maybe_fix_presence_id(_Endpoint, undefined) ->
    undefined;
maybe_fix_presence_id(Endpoint, PresenceId) ->
    case is_presence_id_ensure_realm_enabled(Endpoint) of
        true -> ensure_presence_id_realm(Endpoint, PresenceId);
        false -> PresenceId
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
    kzd_endpoint:presence_publishing_aliases(Endpoint).

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
    kz_json:set_value(<<"Hold-Media">>, kzd_endpoint:moh_url(Endpoint), CCVs).

-spec hold_music_options(kz_json:object(), kz_json:object()) -> kz_json:object().
hold_music_options(Endpoint, CCVs) ->
    kz_json:set_value(<<"Hold-Media-Options">>, kzd_endpoint:moh_options(Endpoint), CCVs).

-spec generate_sip_headers(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> kz_json:object().
generate_sip_headers(_EndpointId, _AccountId, Endpoint, _Options) ->
    Headers = kz_json:new(),
    HeaderFuns = [{fun add_sip_headers/2, Endpoint}],
    kz_json:exec(HeaderFuns, Headers).

-spec add_sip_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
add_sip_headers(Endpoint, Headers) ->
    case kzd_devices:custom_sip_headers_inbound(Endpoint) of
        'undefined' -> Headers;
        CustomHeaders -> kz_json:merge_jobjs(CustomHeaders, Headers)
    end.

-spec owned_by_query(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', kz_term:ne_binaries()} | kz_datamgr:data_error().
owned_by_query(OwnerId, AccountId) ->
    ViewOptions = [{'key', [OwnerId, <<"device">>]}],
    kz_datamgr:get_result_ids(AccountId, <<"attributes/owned">>, ViewOptions).

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
