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
-module(kz_directory_user).

-export([profile/2, profile/3]).

-include("kazoo_directory.hrl").

-spec profile(kz_term:ne_binary(), kz_term:ne_binary()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId) ->
    profile(EndpointId, AccountId, []).

-spec profile(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> {'ok', kz_json:object()} | {'error', any()}.
profile(EndpointId, AccountId, Options) ->
    case kz_cache:fetch_local(?CACHE_NAME, {EndpointId, AccountId}) of
        {'ok', Profile} -> {'ok', Profile};
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
    Members = kz_json:get_ne_binaries(<<"Members">>, Profile, []),
    AccountDb = kzs_util:format_account_db(AccountId),
    Routines = [fun(P) -> [{'db', AccountDb, EndpointId} | P] end
               ,fun(P) -> [{'db', AccountDb, AccountId} | P] end
               ,fun(P) -> lists:foldl(fun(M, A) -> [{'db', AccountDb, M} | A] end, P, Members) end
               ],
    lists:foldl(fun(F, P) -> F(P) end, [], Routines).

-spec build(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object(), kz_term:proplist()) -> {'ok', kz_json:object()}.
build(EndpointId, AccountId, Endpoint, Options) ->
    Context = #{endpoint_id => EndpointId
               ,account_id => AccountId
               ,endpoint => Endpoint
               ,options => Options
               ,endpoint_uri => list_to_binary([EndpointId, "@", AccountId])
               },
    build(Context).

-spec build(map()) -> {'ok', kz_json:object()}.
build(Context) ->
    Routines = [fun build_profile/1
               ,fun dial_string/1
               ],
    #{profile := Profile} = kz_maps:exec(Routines, Context),
    {'ok', Profile}.

dial_string(#{profile := Profile} = Context) ->
    DialString = dial_string(Context, dial_members(Context), is_meta_dial_enabled(Context)),
    Context#{profile => kz_json:set_value(<<"Endpoint-Dial-String">>, DialString, Profile)}.

dial_members(#{profile := Profile}) ->
    kz_json:get_ne_binaries(<<"Members">>, Profile, []).

is_meta_dial_enabled(#{endpoint := Endpoint}) ->
    kz_json:is_true([<<"call_settings">>, <<"directory">>, <<"metadial">>, <<"user">>], Endpoint)
        orelse kz_app_config:is_true(?APP, <<"metadial.user">>).

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
     ,options := _Options
     } = Context,

    CCVs = generate_ccvs(EndpointId, AccountId, Endpoint),
    SIPHeaders = generate_sip_headers(EndpointId, AccountId, Endpoint),
    CAVs = kz_json:get_json_value(<<"default_cavs">>, Endpoint),
    CPVs = build_profile_vars(AccountId, EndpointId, Endpoint, CCVs),
    Endpoints = owned_by_query(EndpointId, AccountId),

    Profile = [{<<"Endpoint-Type">>, <<"user">>}
              ,{<<"Domain-Name">>, AccountId}
              ,{<<"User-ID">>, EndpointId}
              ,{<<"Members">>, Endpoints}
              ,{<<"Custom-Channel-Vars">>, CCVs}
              ,{<<"Custom-Application-Vars">>, CAVs}
              ,{<<"Custom-Profile-Vars">>, kz_json:from_list(CPVs)}
              ,{<<"Custom-SIP-Headers">>, SIPHeaders}
              ,{<<"CallForward">> , kz_directory_cfwd:call_forward(EndpointId, AccountId, Endpoint)}
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
    ,{<<"Endpoint-Type">>, <<"user">>}
    ,{<<"Endpoint-Caller-ID-Number">>, CIDNumber}
    ,{<<"Endpoint-Caller-ID-Name">>, CIDName}
    ,{<<"Endpoint-Presence-ID">>, kz_json:get_ne_binary_value(<<"Presence-ID">>, CCVs)}
    ,{<<"Endpoint-DND">>, dnd(Endpoint)}
    ].

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
              ,{fun hold_music_options/2, Endpoint}
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
    kz_json:set_value(<<"Hold-Media">>, kzd_endpoint:moh_url(Endpoint), CCVs).

-spec hold_music_options(kz_json:object(), kz_json:object()) -> kz_json:object().
hold_music_options(Endpoint, CCVs) ->
    kz_json:set_value(<<"Hold-Media-Options">>, kzd_endpoint:moh_options(Endpoint), CCVs).

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

-spec dnd(kz_json:object()) -> boolean().
dnd(Endpoint) ->
    kz_json:is_true([<<"do_not_disturb">>, <<"enabled">>], Endpoint).
