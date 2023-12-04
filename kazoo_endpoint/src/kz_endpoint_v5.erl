%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_endpoint_v5).

-export([get/1, get/2, get/3]).
-export([flush_account/1
        ,flush_account_local/1
        ,flush/2
        ,flush_local/2
        ]).
-export([build/2, build/3]).
-export([create_call_fwd_endpoint/3, create_call_fwd_endpoint/4
        ,create_sip_endpoint/3
        ,maybe_start_metaflow/2
        ,encryption_method_map/2
        ,get_sip_realm/2, get_sip_realm/3
        ,merge_call_recording/1
        ]).

-ifdef(TEST).
-export([attributes_keys/0
        ,merge_attribute/4
        ]).
-endif.

-include("kazoo_endpoint.hrl").
-include_lib("kazoo_amqp/include/kapi_conf.hrl").
-include_lib("kazoo_stdlib/include/kazoo_json.hrl").

-define(CONFIRM_FILE(Call)
       ,kapps_call:get_prompt(Call, <<"ivr-group_confirm">>)
       ).

-define(ENCRYPTION_MAP, [{<<"srtp">>, [{<<"RTP-Secure-Media">>, <<"true">>}]}
                        ,{<<"zrtp">>, [{<<"ZRTP-Secure-Media">>, <<"true">>}
                                      ,{<<"ZRTP-Enrollment">>, <<"true">>}
                                      ]}
                        ]).

-define(BUILD_METAFLOWS, kapps_config:get_boolean(?CONFIG_CAT, <<"build_metaflows">>, 'false')).

-type std_return() :: {'ok', kz_json:object()} |
                      {'error', 'invalid_endpoint_id'} |
                      kz_datamgr:data_error().
-export_type([std_return/0]).

%%------------------------------------------------------------------------------
%% @doc Fetches a endpoint definition from the database or cache
%% @end
%%------------------------------------------------------------------------------

-spec get(kapps_call:call()) -> std_return().
get(Call) -> get(kapps_call:authorizing_id(Call), Call).

-spec get(kz_term:api_ne_binary() | kz_json:object(), kz_term:ne_binary() | kapps_call:call()) -> std_return().
get('undefined', _Call) ->
    {'error', 'invalid_endpoint_id'};
get(<<EndpointId/binary>>, ?MATCH_ACCOUNT_RAW(AccountId)) ->
    get(EndpointId, kzs_util:format_account_db(AccountId));
get(<<EndpointId/binary>>, AccountDb) when is_binary(AccountDb) ->
    case cached_endpoint(EndpointId, AccountDb) of
        {'ok', _Endpoint}=Ok ->
            lager:debug("loading cached endpoint ~s: ~s", [EndpointId, kz_doc:revision(_Endpoint)]),
            Ok;
        {'error', 'not_found'} ->
            fetch_endpoint(EndpointId, AccountDb)
    end;
get(<<EndpointId/binary>>, Call) ->
    AccountDb = kapps_call:account_db(Call),
    get(EndpointId, AccountDb, get_options(Call));
get(Endpoint, Call) ->
    lager:info("checking endpoint ~s", [kz_doc:id(Endpoint)]),
    check_endpoint_type(Endpoint, kz_doc:id(Endpoint), kapps_call:account_db(Call), []).

get_options(Call) ->
    Routines = [{token, fun token_option/1}],
    lists:filtermap(get_option_fun(Call), Routines).

get_option_fun(Call) ->
    fun({Key, Fun}) ->
            case Fun(Call) of
                undefined -> false;
                Value -> {true, {Key, Value}}
            end
    end.

token_option(Call) ->
    case kapps_call:restricted_endpoint_token(Call) of
        undefined -> kapps_call:endpoint_token(Call);
        Token -> Token
    end.

-spec get(kz_term:api_binary(), kz_term:ne_binary() | kapps_call:call(), kz_term:proplist()) -> std_return().
get(EndpointId, ?MATCH_ACCOUNT_RAW(AccountId), Options) ->
    get(EndpointId, kzs_util:format_account_db(AccountId), Options);
get(EndpointId, AccountDb, Options) when is_binary(AccountDb) ->
    case cached_endpoint(EndpointId, AccountDb, Options) of
        {'ok', _Endpoint}=Ok ->
            lager:debug("loading cached endpoint ~s: ~s", [EndpointId, kz_doc:revision(_Endpoint)]),
            Ok;
        {'error', 'not_found'} ->
            fetch_endpoint(EndpointId, AccountDb, Options)
    end;
get(EndpointId, Call, Options) ->
    get(EndpointId, kapps_call:account_db(Call), Options).

cached_endpoint(EndpointId, AccountId) ->
    cached_endpoint(EndpointId, AccountId, []).

cached_endpoint(EndpointId, AccountId, Options) ->
    case props:is_defined('no_cache', Options) of
        true -> {'error', 'not_found'};
        false -> kz_cache:fetch_local(?CACHE_NAME, {?MODULE, AccountId, EndpointId})
    end.

-spec fetch_endpoint(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_endpoint(EndpointId, AccountDb) ->
    fetch_endpoint(EndpointId, AccountDb, []).

-spec fetch_endpoint(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_endpoint(EndpointId, AccountDb, Options) ->
    case fetch_endpoint_document(EndpointId, AccountDb, Options) of
        {'ok', JObj} ->
            lager:debug("fetched endpoint ~s: ~s", [EndpointId, kz_doc:revision(JObj)]),
            check_endpoint_type(JObj, EndpointId, AccountDb, Options);
        {'error', _} ->
            maybe_fetch_from_token(EndpointId, AccountDb, Options)
    end.

-spec fetch_endpoint_document(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_endpoint_document(EndpointId, AccountDb, Options) ->
    case props:is_defined('no_cache', Options) of
        true -> kz_datamgr:open_doc(AccountDb, EndpointId);
        false -> kz_datamgr:open_cache_doc(AccountDb, EndpointId)
    end.

-spec maybe_fetch_from_token(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
maybe_fetch_from_token(EndpointId, AccountDb, Options) ->
    case props:get_value('token', Options) of
        'undefined' -> {'error', 'not_found'};
        Token -> fetch_from_token(EndpointId, AccountDb, Options, kz_auth:validate_token(Token))
    end.

-type validate_token_result() :: {'ok', kz_json:object()} | {'error', any()}.

-spec fetch_from_token(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist(), validate_token_result()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_from_token(_EndpointId, _AccountDb, _Options, {'error', _Error} = Error) -> Error;
fetch_from_token(EndpointId, AccountDb, Options, {'ok', Claims}) ->
    lager:debug("fetching endpoint ~s / ~s from token", [EndpointId, AccountDb]),
    MetaId = kz_auth_claims:meta_id(Claims),
    Endpoint = token_endpoint(EndpointId, Claims),
    TokenOptions = props:set_values([{'claims', Claims}
                                    ,{'endpoint', Endpoint}
                                    ,{'meta_id', MetaId}
                                    ], Options),
    maybe_fetch_meta_endpoint(EndpointId, AccountDb, TokenOptions).

token_endpoint(EndpointId, Claims) ->
    SIPInfo = kz_json:normalize(kz_json:get_json_value(<<"SIP-Info">>, Claims)),
    Props = [{<<"_id">>, EndpointId}
            ,{<<"_rev">>, kz_auth_claims:identity_sig(Claims)}
            ,{<<"pvt_type">>, <<"device">>}
            ,{<<"device_type">>, <<"smartphone">>}
            ,{<<"owner_id">>, kz_auth_claims:owner_id(Claims)}
            ,{<<"sip">>, kz_json:from_list(kz_json:to_proplist(<<"user_agent">>, SIPInfo))}
            | kz_json:to_proplist(kz_json:normalize(kz_json:delete_keys([<<"user_agent">>], SIPInfo)))
            ],
    props:filter_undefined(Props).

-spec maybe_fetch_meta_endpoint(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
maybe_fetch_meta_endpoint(EndpointId, AccountDb, Options) ->
    case props:get_value('meta_id', Options) of
        'undefined' -> {'error', 'not_found'};
        MetaId -> fetch_meta_endpoint(MetaId, EndpointId, AccountDb, Options)
    end.

-spec fetch_meta_endpoint(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
fetch_meta_endpoint(MetaId, EndpointId, AccountDb, Options) ->
    lager:debug("fetching endpoint ~s / ~s from meta_id ~s ", [EndpointId, AccountDb, MetaId]),
    case fetch_endpoint_document(MetaId, AccountDb, Options) of
        {'error', _} = Error -> Error;
        {'ok', MetaJObj} ->
            lager:debug("fetched meta endpoint ~s: ~s", [MetaId, kz_doc:revision(MetaJObj)]),
            Endpoint = build_meta_endpoint(MetaJObj, Options),
            check_endpoint_type(Endpoint, EndpointId, AccountDb, Options)
    end.

-spec build_meta_endpoint(kz_json:object(), kz_term:proplist()) -> kz_json:object().
build_meta_endpoint(MetaJObj, Options) ->
    Funs = [fun meta_endpoint_owner_id/1],
    KVs = props:get_value('endpoint', Options, []),
    kz_json:set_values(KVs, kz_json:exec(Funs, MetaJObj)).

-spec meta_endpoint_owner_id(kz_json:object()) -> kz_json:object().
meta_endpoint_owner_id(MetaJObj) ->
    meta_endpoint_owner_id(MetaJObj, kz_doc:type(MetaJObj)).

-spec meta_endpoint_owner_id(kz_json:object(), kz_term:api_ne_binary()) -> kz_json:object().
meta_endpoint_owner_id(MetaJObj, <<"user">>) ->
    kzd_devices:set_owner_id(MetaJObj, kz_doc:id(MetaJObj));
meta_endpoint_owner_id(MetaJObj, _Other) -> MetaJObj.

-spec check_endpoint_type(kz_json:object(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
check_endpoint_type(JObj, EndpointId, AccountDb, Options) ->
    EndpointTypes = [<<"device">>, <<"user">>, <<"account">>],
    EndpointType = endpoint_type_as(kz_doc:type(JObj)),
    case lists:member(EndpointType, EndpointTypes) of
        'false' ->
            lager:info("endpoint module does not manage document type ~s", [EndpointType]),
            {'error', 'not_device_nor_user'};
        'true' ->
            check_endpoint_enabled(JObj, EndpointId, AccountDb, EndpointType, Options)
    end.

-spec endpoint_type_as(kz_term:api_binary()) -> kz_term:api_binary().
endpoint_type_as(<<"click2call">>) -> <<"device">>;
endpoint_type_as(<<"conference">>) -> <<"device">>;
endpoint_type_as(Type) -> Type.

-spec check_endpoint_enabled(kz_json:object(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()} |
          {'error', any()}.
check_endpoint_enabled(JObj, EndpointId, AccountDb, EndpointType, Options) ->
    case {kz_doc:is_soft_deleted(JObj)
          orelse kz_doc:is_deleted(JObj)
         ,is_endpoint_enabled(JObj, EndpointType)
         }
    of
        {'true', _} ->
            lager:info("not handling deleted endpoint ~s", [EndpointId]),
            {'error', 'endpoint_deleted'};
        {'false', 'false'} ->
            lager:info("not handling disabled endpoint ~s", [EndpointId]),
            {'error', 'endpoint_disabled'};
        {'false', 'true'} ->
            cache_store_endpoint(JObj, EndpointId, AccountDb, EndpointType, Options)
    end.

-spec is_endpoint_enabled(kz_json:object(), kz_term:ne_binary()) -> boolean().
is_endpoint_enabled(JObj, <<"account">>) ->
    kzd_accounts:is_enabled(JObj);
is_endpoint_enabled(JObj, <<"user">>) ->
    kzd_users:enabled(JObj);
is_endpoint_enabled(JObj, <<"device">>) ->
    kzd_devices:enabled(JObj);
is_endpoint_enabled(JObj, _) ->
    kz_json:is_true(<<"enabled">>, JObj, 'true').

-spec cache_store_endpoint(kz_json:object(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          {'ok', kz_json:object()}.
cache_store_endpoint(JObj, EndpointId, AccountDb, EndpointType, Options) ->
    Values = [{<<"Endpoint-ID">>, EndpointId}
             ,{<<"Endpoint-Type">>, EndpointType}
             ,{<<"Endpoint-Build-Options">>, cache_build_options(Options)}
             ],
    Endpoint = kz_json:set_values(Values, merge_attributes(JObj, EndpointType, Options)),
    CacheProps = [{'origin', cache_origin(JObj, EndpointId, AccountDb, Options)}],
    catch kz_cache:store_local_async(?CACHE_NAME, {?MODULE, AccountDb, EndpointId}, Endpoint, CacheProps),
    lager:debug("cached endpoint: ~s _rev: ~s", [EndpointId, kz_doc:revision(Endpoint)]),
    {'ok', Endpoint}.

cache_build_options(Options) ->
    case lists:filtermap(fun cache_option/1, Options) of
        [] -> 'null';
        Filtered -> kz_json:from_list(Filtered)
    end.

-spec cache_option(tuple()) -> {'true', {kz_json:key(), kz_json:object()}} | 'false'.
cache_option({'endpoint' = Key, Endpoint}) -> {'true', {kz_term:to_binary(Key), Endpoint}};
cache_option({'claims' = Key, Claims}) -> {'true', {kz_term:to_binary(Key), Claims}};
cache_option(_) -> 'false'.

-spec cache_origin(kz_json:object(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> list().
cache_origin(JObj, EndpointId, AccountDb, Options) ->
    Routines = [fun(P) -> maybe_owner_id_cache_origin(P, JObj, AccountDb) end
               ,fun(P) -> maybe_hotdesk_ids_cache_origin(P, JObj, AccountDb) end
               ,fun(P) -> maybe_options_cache_origin(P, JObj, AccountDb, Options) end
               ],
    lists:foldl(fun(F, P) -> F(P) end
               ,[{'db', AccountDb, kzs_util:format_account_id(AccountDb)}
                ,{'db', AccountDb, EndpointId}
                ]
               ,Routines
               ).

-spec maybe_owner_id_cache_origin(kz_term:proplist(), kz_json:object(), kz_term:ne_binary()) -> kz_term:proplist().
maybe_owner_id_cache_origin(Props, JObj, AccountDb) ->
    case kz_json:get_ne_binary_value(<<"owner_id">>, JObj) of
        'undefined' -> Props;
        OwnerId -> [{'db', AccountDb, OwnerId}|Props]
    end.

-spec maybe_hotdesk_ids_cache_origin(kz_term:proplist(), kz_json:object(), kz_term:ne_binary()) -> kz_term:proplist().
maybe_hotdesk_ids_cache_origin(Props, JObj, AccountDb) ->
    case kz_json:get_keys([<<"hotdesk">>, <<"users">>], JObj) of
        [] -> Props;
        OwnerIds -> hotdesk_ids_cache_origin(Props, AccountDb, OwnerIds)
    end.

-spec hotdesk_ids_cache_origin(kz_term:proplist(), kz_term:ne_binary(), kz_term:ne_binaries()) -> kz_term:proplist().
hotdesk_ids_cache_origin(Props, AccountDb, OwnerIds) ->
    lists:foldl(hotdesk_ids_cache_origin_fun(AccountDb), Props, OwnerIds).

-spec hotdesk_ids_cache_origin_fun(kz_term:ne_binary()) -> fun((kz_term:ne_binary(), kz_term:proplist()) -> kz_term:proplist()).
hotdesk_ids_cache_origin_fun(AccountDb) ->
    fun(Id, P) -> [{'db', AccountDb, Id}|P] end.

-spec maybe_options_cache_origin(kz_term:proplist(), kz_json:object(), kz_term:ne_binary(), kz_term:proplist()) -> kz_term:proplist().
maybe_options_cache_origin(Props, _JObj, AccountDb, Options) ->
    AltJObj = props:get_value('endpoint', Options),
    case kz_json:is_valid_json_object(AltJObj)
        andalso kz_json:get_ne_binary_value(<<"endpoint_meta_id">>, AltJObj)
    of
        'false' -> Props;
        'undefined' -> Props;
        EndpointMetaId -> [{'db', AccountDb, EndpointMetaId}|Props]
    end.

-spec maybe_format_endpoint(kz_json:object(), kz_term:api_object()) -> kz_json:object().
maybe_format_endpoint(Endpoint, 'undefined') ->
    Endpoint;
maybe_format_endpoint(Endpoint, Formatters) ->
    kz_formatters:apply(Endpoint, Formatters, 'outbound').

-spec merge_attributes(kz_json:object(), kz_term:ne_binary(), kz_term:proplist()) -> kz_json:object().
merge_attributes(Endpoint, Type, Options) ->
    merge_attributes(Endpoint, Type, Options, attributes_keys()).

account_keys() ->
    [<<"realm">>].

account_tree_keys() ->
    [<<"call_restriction">>].

-spec attributes_keys() -> kz_term:ne_binaries().
attributes_keys() ->
    [<<"addresses">>
    ,<<"call_failover">>
    ,<<"call_forward">>
    ,<<"call_limits">>
    ,<<"call_recording">>
    ,<<"call_restriction">>
    ,<<"call_settings">>
    ,<<"call_waiting">>
    ,<<"caller_id">>
    ,<<"caller_id_options">>
    ,<<"dial_plan">>
    ,<<"do_not_disturb">>
    ,<<"formatters">>
    ,<<"language">>
    ,<<"metaflows">>
    ,<<"mobile">>
    ,<<"music_on_hold">>
    ,<<"name">>
    ,<<"outbound_flags">>
    ,<<"presence_id">>
    ,<<"presence_aliases">>
    ,<<"record_call">>
    ,<<"ringtones">>
    ,<<"account_name">>
    ,<<"account_realm">>
    ,<<"default_cavs">>
    ,<<"default_ccvs">>
    ,?ATTR_LOWER_KEY
    ].

endpoint_account(undefined, _Options) ->
    kz_json:new();
endpoint_account(AccountId, Options) ->
    case fetch_endpoint_document(AccountId, ?KZ_ACCOUNTS_DB, Options) of
        {'ok', AccountDoc} -> AccountDoc;
        {'error', _} -> kz_json:new()
    end.

-spec merge_attributes(kz_json:object(), kz_term:ne_binary(), kz_term:proplist(), kz_term:ne_binaries()) -> kz_json:object().
merge_attributes(Owner, <<"user">>, Options, Keys) ->
    merge_attributes(Keys, Options, endpoint_account(kz_doc:account_id(Owner), Options), Owner, Owner);
merge_attributes(Device, <<"device">>, Options, Keys) ->
    Owner = get_user(kz_doc:account_db(Device), Device, Options),
    Endpoint = kz_json:set_value(<<"owner_id">>, kz_doc:id(Owner), Device),
    merge_attributes(Keys, Options, endpoint_account(kz_doc:account_id(Device), Options), Endpoint, Owner);
merge_attributes(AccountDoc, <<"account">>, Options, Keys) ->
    merge_attributes(Keys, Options, AccountDoc, kz_json:new(), kz_json:new());
merge_attributes(Endpoint, Type, _Keys, _Options) ->
    lager:debug("unhandled endpoint type on merge attributes : ~p : ~p", [Type, Endpoint]),
    kz_json:new().

-spec merge_attributes(kz_term:ne_binaries(), kz_term:proplist(), kz_json:object(), kz_term:api_object(), kz_term:api_object()) ->
          kz_json:object().
merge_attributes(Keys, _Options, AccountDoc, EndpointDoc, OwnerDoc) ->
    Account = merge_account_tree(AccountDoc),
    lists:foldl(fun(Key, EP) ->
                        merge_attribute(Key, Account, EP, OwnerDoc)
                end
               ,merge_account_keys(Account, EndpointDoc)
               ,Keys
               ).

-spec merge_account_keys(kz_json:object(), kz_json:object()) -> kz_json:object().
merge_account_keys(Account, Endpoint) ->
    Fun = fun(K, Acc) ->
                  kz_json:set_value(K, kz_json:get_value(K, Account), Acc)
          end,
    lists:foldl(Fun, Endpoint, account_keys()).

-spec merge_account_tree(kz_json:object()) -> kz_json:object().
merge_account_tree(Account) ->
    lists:foldl(fun merge_account_tree_fold/2, Account, kzd_accounts:tree(Account)).

-spec merge_account_tree_fold(kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
merge_account_tree_fold(AccountId, Account) ->
    case kzd_accounts:fetch(AccountId) of
        {'ok', Parent} -> merge_account_tree_attributes(Parent, Account);
        {'error', _} -> Account
    end.

-spec merge_account_tree_attributes(kz_json:object(), kz_json:object()) -> kz_json:object().
merge_account_tree_attributes(Parent, Account) ->
    lists:foldl(fun(Key, Acc) ->
                        kz_json:merge(Acc, kz_json:get_value(Key, Parent, kz_json:new()))
                end
               ,Account
               ,account_tree_keys()
               ).

-spec merge_attribute(kz_term:ne_binary(), kz_term:api_object(), kz_term:api_object(), kz_term:api_object()) -> kz_json:object().
merge_attribute(?ATTR_LOWER_KEY, _Account, Endpoint, Owner) ->
    FullKey = [?ATTR_LOWER_KEY, ?ATTR_UPPER_KEY],
    OwnerAttr = kz_json:get_integer_value(FullKey, Owner, 5),
    EndpointAttr = kz_json:get_integer_value(FullKey, Endpoint, 5),
    case EndpointAttr < OwnerAttr of
        'true' -> Endpoint;
        'false' -> kz_json:set_value(FullKey, OwnerAttr, Endpoint)
    end;
merge_attribute(<<"account_name">> = Key, Account, Endpoint, _Owner) ->
    kz_json:set_value(Key, kzd_accounts:name(Account), Endpoint);
merge_attribute(<<"account_realm">> = Key, Account, Endpoint, _Owner) ->
    kz_json:set_value(Key, kzd_accounts:realm(Account), Endpoint);
merge_attribute(<<"call_restriction">>, Account, Endpoint, Owner) ->
    Classifiers = kz_json:get_keys(knm_converters:available_classifiers()),
    merge_call_restrictions(Classifiers, Account, Endpoint, Owner);
merge_attribute(<<"name">> = Key, Account, Endpoint, Owner) ->
    Name = create_endpoint_name(kz_json:get_ne_value(<<"first_name">>, Owner)
                               ,kz_json:get_ne_value(<<"last_name">>, Owner)
                               ,kz_json:get_ne_value(Key, Endpoint)
                               ,kz_json:get_ne_value(Key, Account)
                               ),
    kz_json:set_value(Key, Name, Endpoint);
merge_attribute(<<"call_failover">> = Key, Account, Endpoint, Owner) ->
    EndpointAttr = kz_json:get_ne_value(Key, Endpoint, kz_json:new()),
    case kz_json:is_true(<<"enabled">>, EndpointAttr) of
        'true' -> Endpoint;
        'false' ->
            AccountAttr = kz_json:get_ne_value(Key, Account, kz_json:new()),
            OwnerAttr = kz_json:get_ne_value(Key, Owner, kz_json:new()),
            Merged = kz_json:merge([AccountAttr, EndpointAttr, OwnerAttr]),
            case kz_json:is_true(<<"enabled">>, Merged) of
                'true' -> kz_json:set_value(Key, Merged, Endpoint);
                'false' -> Endpoint
            end
    end;
merge_attribute(<<"call_forward">> = Key, Account, Endpoint, Owner) ->
    merge_call_forward(Key, Account, Endpoint, Owner);
merge_attribute(<<"call_settings">> = Key, Account, Endpoint, Owner) ->
    EndpointAttr = kz_json:get_json_value(Key, Endpoint, kz_json:new()),
    AccountAttr = kz_json:get_json_value(Key, Account, kz_json:new()),
    OwnerAttr = kz_json:get_json_value(Key, Owner, kz_json:new()),
    Merged = kz_json:merge([AccountAttr, OwnerAttr, EndpointAttr]),
    case kz_term:is_empty(Merged) of
        'true' -> Endpoint;
        'false' -> kz_json:set_value(Key, Merged, Endpoint)
    end;
merge_attribute(<<"call_waiting">> = Key, Account, Endpoint, Owner) ->
    AccountAttr = kz_json:get_ne_value(Key, Account, kz_json:new()),
    EndpointAttr = kz_json:get_ne_value(Key, Endpoint, kz_json:new()),
    OwnerAttr = kz_json:get_ne_value(Key, Owner, kz_json:new()),
    %% allow the device to override the owner preference (and vice versa) so
    %%  endpoints such as mobile device can disable call_waiting while sip phone
    %%  might still have it enabled
    Merged = kz_json:merge([AccountAttr, OwnerAttr, EndpointAttr]),
    kz_json:set_value(Key, Merged, Endpoint);
merge_attribute(<<"caller_id">> = Key, Account, Endpoint, Owner) ->
    AccountAttr = kz_json:get_ne_value(Key, Account, kz_json:new()),
    EndpointAttr = kz_json:get_ne_value(Key, Endpoint, kz_json:new()),
    OwnerAttr = caller_id_owner_attr(Owner),
    Merged = merge_attribute_caller_id(Account, AccountAttr, OwnerAttr, EndpointAttr),
    kz_json:set_value(Key, Merged, Endpoint);
merge_attribute(<<"do_not_disturb">> = Key, Account, Endpoint, Owner) ->
    L = [Key, <<"enabled">>],
    AccountAttr = kz_json:is_true(L, Account, 'false'),
    EndpointAttr = kz_json:is_true(L, Endpoint, 'false'),
    OwnerAttr = kz_json:is_true(L, Owner, 'false'),
    Dnd = AccountAttr
        orelse OwnerAttr
        orelse EndpointAttr,
    kz_json:set_value(L, Dnd, Endpoint);
merge_attribute(<<"language">> = Key, Account, Endpoint, Owner) ->
    merge_value(Key, Account, Endpoint, Owner);
merge_attribute(<<"presence_id">> = Key, Account, Endpoint, Owner) ->
    merge_value(Key, Account, Endpoint, Owner);
merge_attribute(<<"presence_aliases">> = Key, Account, Endpoint, Owner) ->
    Aliases = kzd_endpoint_aliases:merge([Account, Owner, Endpoint]),
    case kz_json:is_empty(Aliases) of
        true -> Endpoint;
        false -> kz_json:set_value(Key, Aliases, Endpoint)
    end;
merge_attribute(<<"record_call">> = Key, Account, Endpoint, Owner) ->
    EndpointAttr = get_record_call_properties(Endpoint),
    AccountAttr = get_record_call_properties(Account),
    OwnerAttr = get_record_call_properties(Owner),
    Merged = kz_json:merge([AccountAttr, OwnerAttr, EndpointAttr]),
    kz_json:set_value(Key, Merged, Endpoint);
merge_attribute(<<"call_recording">> = Key, Account, Endpoint, Owner) ->
    AccountAttr = get_account_record_call_properties(Account),
    OwnerAttr = get_user_record_call_properties(Owner),
    EndpointAttr = get_device_record_call_properties(Endpoint),
    case lists:filter(fun is_valid_call_recording_object/1, [AccountAttr, OwnerAttr, EndpointAttr]) of
        [] -> kz_json:delete_key(Key, Endpoint);
        JObjs -> kz_json:set_value(Key, kz_json:merge(JObjs), Endpoint)
    end;
merge_attribute(<<"outbound_flags">>, Account, Endpoint, Owner) ->
    Static = lists:flatten([kzd_devices:outbound_static_flags(Account)
                           ,kzd_devices:outbound_static_flags(Owner)
                           ,kzd_devices:outbound_static_flags(Endpoint)
                           ]),
    Dynamic = lists:flatten([kzd_devices:outbound_dynamic_flags(Account)
                            ,kzd_devices:outbound_dynamic_flags(Owner)
                            ,kzd_devices:outbound_dynamic_flags(Endpoint)
                            ]),
    kzd_devices:set_outbound_flags(Endpoint, Static, Dynamic);
merge_attribute(<<"call_limits">> = Key, Account, Endpoint, Owner) ->
    merge_call_limits(Key, Account, Endpoint, Owner);
merge_attribute(<<"default_cavs">> = Key, Account, Endpoint, Owner) ->
    merge_default_cavs(Key, Account, Endpoint, Owner);
merge_attribute(<<"default_ccvs">> = Key, Account, Endpoint, Owner) ->
    merge_default_ccvs(Key, Account, Endpoint, Owner);
merge_attribute(<<"addresses">> = _Key, Account, Endpoint, Owner) ->
    lists:foldl(fun(AddrType, Acc) -> merge_address_fold(AddrType, Account, Acc, Owner) end
               ,Endpoint
               ,[<<"emergency">>]
               );
merge_attribute(Key, Account, Endpoint, Owner) ->
    AccountAttr = kz_json:get_ne_value(Key, Account, kz_json:new()),
    EndpointAttr = kz_json:get_ne_value(Key, Endpoint, kz_json:new()),
    OwnerAttr = kz_json:get_ne_value(Key, Owner, kz_json:new()),
    Merged = kz_json:merge_recursive([AccountAttr, EndpointAttr, OwnerAttr]
                                    ,fun(_, V) -> not kz_term:is_empty(V) end
                                    ),
    kz_json:set_value(Key, Merged, Endpoint).

merge_call_forward(Key, Account, Endpoint, Owner) ->
    EndpointAttr = kzd_endpoint:call_forward(Endpoint, kz_json:new()),
    case kzd_call_forward:enabled(EndpointAttr) of
        'true' -> Endpoint;
        'false' ->
            AccountAttr = kzd_accounts:call_forward(Account, kz_json:new()),
            OwnerAttr = kzd_users:call_forward(Owner, kz_json:new()),
            Merged = kz_json:merge([AccountAttr, EndpointAttr, OwnerAttr]),
            case kzd_call_forward:enabled(Merged) of
                'true' -> kz_json:set_value(Key, Merged, Endpoint);
                'false' -> Endpoint
            end
    end.

%% @doc fetch unconditional call forward; if disabled, check selective call forwarding
unconditional_call_forward(Endpoint) ->
    Unconditional = get_unconditional_call_forward(Endpoint),
    case kzd_call_forward:enabled(Unconditional) of
        'true' ->
            lager:info("using unconditional call forwarding"),
            Unconditional;
        'false' ->
            kz_json:new()
    end.

get_unconditional_call_forward(Endpoint) ->
    kzd_call_forward:merged(kzd_endpoint:call_forward(Endpoint, kz_json:new())
                           ,fun kzd_call_forward:unconditional/1
                           ,kz_json:new()
                           ).

-spec merge_attribute_caller_id(kz_term:api_object(), kz_term:api_object(), kz_term:api_object(), kz_term:api_object()) -> kz_term:api_object().
merge_attribute_caller_id(AccountJObj, AccountJAttr, UserJAttr, EndpointJAttr) ->
    Merging =
        case kz_json:is_true(<<"prefer_device_caller_id">>, AccountJObj, 'false') of
            'true' -> [AccountJAttr, UserJAttr, EndpointJAttr];
            'false' -> [AccountJAttr, EndpointJAttr, UserJAttr]
        end,
    Merged = kz_json:merge_recursive(Merging, fun(_, V) -> not kz_term:is_empty(V) end),
    merge_attribute_caller_id_emergency(Merged, EndpointJAttr).

-spec merge_attribute_caller_id_emergency(kz_json:object(), kz_json:object()) -> kz_json:object().
merge_attribute_caller_id_emergency(Endpoint, EndpointAttr) ->
    Attributes = [<<"number">>, <<"name">>],
    Fun = fun(Attr, EP)->
                  merge_attribute_caller_id_emergency(Attr, EP, EndpointAttr)
          end,
    lists:foldl(Fun, Endpoint, Attributes).

-spec merge_attribute_caller_id_emergency(kz_term:ne_binary(), kz_json:object(), kz_json:object()) -> kz_json:object().
merge_attribute_caller_id_emergency(Attribute, Endpoint, EndpointAttr) ->
    Key = [<<"emergency">>, Attribute],
    case kz_json:get_ne_binary_value(Key, EndpointAttr) of
        'undefined' -> Endpoint;
        Value -> kz_json:set_value(Key, Value, Endpoint)
    end.

-spec merge_call_recording(kzd_call_recording:doc()) -> kzd_call_recording:doc().
merge_call_recording(RecordingSettings) ->
    AnyDirections = [<<"inbound">>, <<"outbound">>],
    AnyNets = [<<"onnet">>, <<"offnet">>],

    AnyDirectionSettings = kzd_call_recording:any(RecordingSettings, kz_json:new()),

    F1 = fun(Direction, RSAcc1) -> merge_call_recording_direction(Direction, RSAcc1, AnyDirectionSettings) end,
    RecordingSettings1 = lists:foldl(F1, kz_json:delete_key(<<"any">>, RecordingSettings), AnyDirections),

    F2 = fun(Direction, Networks, RSAcc2) -> merge_call_recording_networks(Direction, Networks, RSAcc2, AnyNets) end,
    kz_json:foldl(F2, RecordingSettings1, RecordingSettings1).

-spec is_valid_call_recording_object(kz_term:api_object()) -> boolean().
is_valid_call_recording_object('undefined') ->
    'false';
is_valid_call_recording_object(JObj) ->
    kz_json:is_json_object(JObj)
        andalso not kz_json:is_empty(JObj).

-spec merge_call_recording_direction(kz_term:ne_binary(), kzd_call_recording:doc(), kz_json:object()) -> kz_json:object().
merge_call_recording_direction(Direction, RecordingSettings, AnyDirectionSettings) ->
    case kz_json:get_json_value(Direction, RecordingSettings) of
        'undefined' -> kz_json:set_value(Direction, AnyDirectionSettings, RecordingSettings);
        V -> kz_json:set_value(Direction, kz_json:merge(AnyDirectionSettings, V), RecordingSettings)
    end.

-spec merge_call_recording_networks(kz_term:ne_binary(), kz_json:object(), kz_json:object(), kz_term:ne_binaries()) -> kz_json:object().
merge_call_recording_networks(Direction, NetworksJObj, RecordingSettings, AnyNetworks) ->
    AnyNetworkSettings = kzd_call_recording:any(NetworksJObj, kz_json:from_list([{<<"enabled">>, 'false'}])),
    Fun = fun(Network, NetworksAcc) -> merge_call_recording_direction(Network, NetworksAcc, AnyNetworkSettings) end,
    UpdatedNetworks = lists:foldl(Fun, kz_json:delete_key(<<"any">>, NetworksJObj), AnyNetworks),
    kz_json:set_value(Direction, UpdatedNetworks, RecordingSettings).

-spec get_account_record_call_properties(kzd_accounts:doc()) -> kz_json:object().
get_account_record_call_properties(AccountDoc) ->
    %% Type: account/endpoint
    kz_json:foldl(fun(Type, RecordingSettings, Acc) ->
                          kz_json:set_value(Type, merge_call_recording(RecordingSettings), Acc)
                  end
                 ,kz_json:new()
                 ,kzd_accounts:call_recording(AccountDoc, kz_json:new())
                 ).

-spec get_user_record_call_properties(kzd_users:doc()) -> kz_json:object().
get_user_record_call_properties(UserDoc) ->
    case kzd_users:call_recording(UserDoc) of
        'undefined' -> get_legacy_record_call_properties(UserDoc);
        CallRecording -> endpoint_recording(CallRecording)
    end.

-spec get_device_record_call_properties(kzd_devices:doc() | 'undefined') -> kz_json:object().
get_device_record_call_properties('undefined') -> kz_json:new();
get_device_record_call_properties(DeviceDoc) ->
    case kzd_devices:call_recording(DeviceDoc) of
        'undefined' -> get_legacy_record_call_properties(DeviceDoc);
        CallRecording -> endpoint_recording(CallRecording)
    end.

-spec get_legacy_record_call_properties(kz_json:object()) -> kz_json:object().
get_legacy_record_call_properties(EndpointDoc) ->
    Legacy = get_record_call_properties(EndpointDoc),
    case kz_json:is_true(<<"record_call">>, Legacy) of
        'false' -> kz_json:new();
        'true' ->
            lager:info("adding legacy record_call settings"),
            Settings = kz_json:set_value(<<"enabled">>, 'true', Legacy),
            AnyNet = kz_json:from_list([{<<"onnet">>, Settings}
                                       ,{<<"offnet">>, Settings}
                                       ]),
            RecordCall = kz_json:from_list([{<<"inbound">>, AnyNet}
                                           ,{<<"outbound">>, AnyNet}
                                           ]),
            endpoint_recording(RecordCall)
    end.

-spec endpoint_recording(kzd_call_recording:doc()) -> kz_json:object().
endpoint_recording(RecordCall) ->
    kz_json:from_list([{<<"endpoint">>, merge_call_recording(RecordCall)}]).

%% deprecated, to be removed
-spec get_record_call_properties(kz_json:object()) -> kz_json:object().
get_record_call_properties(JObj) ->
    RecordCall = kz_json:get_ne_value(<<"record_call">>, JObj),
    case kz_json:is_json_object(RecordCall) of
        'true' -> RecordCall;
        'false' ->
            case kz_term:is_true(RecordCall) of
                'false' -> kz_json:new();
                'true' ->
                    kz_json:from_list(
                      [{<<"action">>, <<"start">>}
                      ,{<<"record_call">>, 'true'}
                      ]
                     )
            end
    end.

-spec merge_value(kz_term:ne_binary(), kz_term:api_object(), kz_json:object(), kz_term:api_object()) ->
          kz_json:object().
merge_value(Key, Account, Endpoint, Owner) ->
    case kz_json:find(Key, [Owner, Endpoint, Account], 'undefined') of
        'undefined' -> Endpoint;
        Value -> kz_json:set_value(Key, Value, Endpoint)
    end.

-spec caller_id_owner_attr(kz_json:object()) -> kz_json:object().
caller_id_owner_attr(Owner) ->
    OwnerAttr = kz_json:get_json_value(<<"caller_id">>, Owner, kz_json:new()),
    L = [<<"internal">>, <<"name">>],
    case kz_json:get_ne_binary_value(L, OwnerAttr) of
        'undefined' ->
            Name = create_endpoint_name(kz_json:get_ne_binary_value(<<"first_name">>, Owner)
                                       ,kz_json:get_ne_binary_value(<<"last_name">>, Owner)
                                       ,'undefined'
                                       ,'undefined'
                                       ),
            kz_json:set_value(L, Name, OwnerAttr);
        _Else -> OwnerAttr
    end.

-spec merge_call_restrictions(kz_term:ne_binaries(), kz_json:object(), kz_json:object(), kz_json:object()) ->
          kz_json:object().
merge_call_restrictions([], _, Endpoint, _) -> Endpoint;
merge_call_restrictions([Classifier|Classifiers], Account, Endpoint, Owner) ->
    case is_classifier_denied(Classifier, [Account, Owner]) of
        'true' ->
            %% denied at the account or owner level
            Update = add_denied_classifier(Classifier, Endpoint),
            merge_call_restrictions(Classifiers, Account, Update, Owner);
        'false' ->
            case is_classifier_allowed(Classifier, [Owner]) of
                'true' ->
                    %% allowed at the owner level
                    Update = add_allowed_classifier(Classifier, Endpoint),
                    merge_call_restrictions(Classifiers, Account, Update, Owner);
                'false' ->
                    %% owner inherit or no owner, either way use the device restrictions
                    merge_call_restrictions(Classifiers, Account, Endpoint, Owner)
            end
    end.

-spec is_classifier_denied(kz_term:ne_binary(), kz_json:objects()) -> boolean().
is_classifier_denied(Classifier, JObjs) ->
    is_classifier_action_set(Classifier, JObjs, <<"deny">>).

-spec is_classifier_allowed(kz_term:ne_binary(), kz_json:objects()) -> boolean().
is_classifier_allowed(Classifier, JObjs) ->
    is_classifier_action_set(Classifier, JObjs, <<"allow">>).

-spec is_classifier_action_set(kz_term:ne_binary(), kz_json:objects(), kz_term:ne_binary()) -> boolean().
is_classifier_action_set(Classifier, JObjs, Action) ->
    Path = [<<"call_restriction">>, Classifier, <<"action">>],
    lists:any(fun(JObj) -> Action =:= kz_json:get_ne_binary_value(Path, JObj) end, JObjs).

-spec add_denied_classifier(kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
add_denied_classifier(Classifier, JObj) ->
    Path = [<<"call_restriction">>, Classifier, <<"action">>],
    kz_json:set_value(Path, <<"deny">>, JObj).

-spec add_allowed_classifier(kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
add_allowed_classifier(Classifier, JObj) ->
    Path = [<<"call_restriction">>, Classifier, <<"action">>],
    kz_json:set_value(Path, <<"allow">>, JObj).

-spec get_user(kz_term:ne_binary(), kz_term:api_binary() | kz_json:object(), kz_term:proplist()) -> kz_json:object().
get_user(_AccountDb, 'undefined', _Options) -> kz_json:new();
get_user(AccountDb, OwnerId, Options) when is_binary(OwnerId) ->
    case fetch_endpoint_document(OwnerId, AccountDb, Options) of
        {'ok', JObj} -> JObj;
        {'error', _R} ->
            lager:warning("failed to load endpoint owner ~s: ~p", [OwnerId, _R]),
            kz_json:new()
    end;
get_user(AccountDb, Endpoint, Options) ->
    case kz_json:get_keys([<<"hotdesk">>, <<"users">>], Endpoint) of
        [] ->
            get_user(AccountDb, kz_json:get_ne_binary_value(<<"owner_id">>, Endpoint), Options);
        [OwnerId] ->
            fix_user_restrictions(get_user(AccountDb, OwnerId, Options));
        [_|_]=OwnerIds->
            UserJObj = convert_to_single_user(get_users(AccountDb, OwnerIds, Options)),
            fix_user_restrictions(UserJObj)
    end.

-spec flush_users(kz_term:ne_binary(), kz_term:ne_binaries(), kz_term:proplist() | boolean()) -> 'ok'.
flush_users(AccountDb, OwnerIds, false) ->
    _ = kz_datamgr:open_cache_docs(AccountDb, OwnerIds),
    'ok';
flush_users(AccountDb, OwnerIds, true) ->
    _ = kz_datamgr:flush_cache_docs(AccountDb, OwnerIds),
    'ok';
flush_users(AccountDb, OwnerIds, Options) ->
    flush_users(AccountDb, OwnerIds, props:is_defined('no_cache', Options)).

-spec get_users(kz_term:ne_binary(), kz_term:ne_binaries(), kz_term:proplist()) -> kzd_users:docs().
get_users(AccountDb, OwnerIds, Options) ->
    flush_users(AccountDb, OwnerIds, Options),
    F = fun (UserId, UsersAcc) ->
                case fetch_endpoint_document(UserId, AccountDb, Options) of
                    {'ok', UserJObj} -> [UserJObj|UsersAcc];
                    {'error', _R} ->
                        lager:warning("failed to load endpoint owner ~s: ~p", [UserId, _R]),
                        UsersAcc
                end
        end,
    lists:foldl(F, [], OwnerIds).

-spec fix_user_restrictions(kzd_users:doc()) -> kzd_users:doc().
fix_user_restrictions(UserJObj) ->
    lists:foldl(fun(Classifier, User) ->
                        case kzd_users:classifier_restriction(User, Classifier) of
                            <<"deny">> -> User;
                            _Else ->
                                %% this ensures we override the device
                                %% but only when there is a user associated
                                kzd_users:set_classifier_restriction(User, Classifier, <<"allow">>)
                        end
                end
               ,UserJObj
               ,kz_json:get_keys(knm_converters:available_classifiers())
               ).

-spec convert_to_single_user(kzd_users:docs()) -> kzd_users:doc().
convert_to_single_user(UserJObjs) ->
    Routines = [fun singlfy_user_attr_keys/2
               ,fun singlfy_user_restrictions/2
               ],
    lists:foldl(fun(F, AccJObj) -> F(UserJObjs, AccJObj) end, kz_json:new(), Routines).

-spec singlfy_user_attr_keys(kzd_users:docs(), kzd_users:doc()) -> kzd_users:doc().
singlfy_user_attr_keys(UserJObjs, AccJObj) ->
    PrecedenceKey = [?ATTR_LOWER_KEY, ?ATTR_UPPER_KEY],
    Value = lists:foldl(fun(UserJObj, V1) ->
                                min(V1, kz_json:get_integer_value(PrecedenceKey, UserJObj, 5))
                        end
                       ,5
                       ,UserJObjs
                       ),
    kz_json:set_value(PrecedenceKey, Value, AccJObj).

-spec singlfy_user_restrictions(kzd_users:docs(), kzd_users:doc()) -> kzd_users:doc().
singlfy_user_restrictions(UserJObjs, AccJObj) ->
    lists:foldl(fun(Classifier, Acc) ->
                        Fun = fun(Elem) -> do_all_restrict(Classifier, Elem) end,
                        case lists:all(Fun, UserJObjs) of
                            'false' -> Acc;
                            'true' ->
                                kzd_users:set_classifier_restriction(Acc, Classifier, <<"deny">>)
                        end
                end
               ,AccJObj
               ,kz_json:get_keys(knm_converters:available_classifiers())
               ).

-spec do_all_restrict(kz_term:ne_binary(), kzd_users:doc()) -> boolean().
do_all_restrict(Classifier, UserJObj) ->
    <<"deny">> =:= kzd_users:classifier_restriction(UserJObj, Classifier).

-spec create_endpoint_name(kz_term:api_binary(), kz_term:api_binary(), kz_term:api_binary(), kz_term:api_binary()) -> kz_term:api_binary().
create_endpoint_name('undefined', 'undefined', 'undefined', Account) -> Account;
create_endpoint_name('undefined', 'undefined', Endpoint, _) -> Endpoint;
create_endpoint_name(First, 'undefined', _, _) -> First;
create_endpoint_name('undefined', Last, _, _) -> Last;
create_endpoint_name(First, Last, _, _) -> <<First/binary, " ", Last/binary>>.

%%------------------------------------------------------------------------------
%% @doc Flush the callflow cache
%% @end
%%------------------------------------------------------------------------------

-spec flush_account(kz_term:ne_binary()) -> 'ok'.
flush_account(AccountDb) ->
    do_flush_account(AccountDb, fun flush/2).

-spec flush_account_local(kz_term:ne_binary()) -> 'ok'.
flush_account_local(AccountDb) ->
    do_flush_account(AccountDb, fun flush_local/2).

-type flusher() :: fun((kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok').
-spec do_flush_account(kz_term:ne_binary(), flusher()) -> 'ok'.
do_flush_account(AccountDb, Flusher) ->
    ToRemove =
        kz_cache:filter_local(?CACHE_NAME, fun({?MODULE, Db, _Id}, _Value) ->
                                                   Db =:= AccountDb;
                                              (_, _) -> 'false'
                                           end),
    _ = [Flusher(Db, Id)|| {{?MODULE, Db, Id}, _} <- ToRemove],
    'ok'.

-spec flush(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
flush(Db, Id) ->
    flush_local(Db, Id),
    {'ok', Rev} = kz_datamgr:lookup_doc_rev(Db, Id),
    Props =
        [{<<"ID">>, Id}
        ,{<<"Database">>, Db}
        ,{<<"Rev">>, Rev}
        ,{<<"Type">>, kzd_devices:type()}
        | kz_api:default_headers(<<"configuration">>
                                ,?DOC_EDITED
                                ,?APP_NAME
                                ,?APP_VERSION
                                )
        ],
    Fun = fun(P) ->
                  kapi_conf:publish_doc_update('edited', Db, kzd_devices:type(), Id, P)
          end,

    'ok' = kz_amqp_worker:cast(Props, Fun).

-spec flush_local(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
flush_local(Db, Id) ->
    kz_cache:erase_local(?CACHE_NAME, {?MODULE, Db, Id}).

%%------------------------------------------------------------------------------
%% @doc Creates one or more kazoo API endpoints for use in a bridge string.
%% Takes into account settings on the callflow, the endpoint, call
%% forwarding, and ringtones.  More functionality to come, but as it is
%% added it will be implicit in all functions that 'ring an endpoint'
%% like devices, ring groups, and resources.
%% @end
%%------------------------------------------------------------------------------
-type build_errors() :: 'db_not_reachable' | 'endpoint_disabled'
                      | 'endpoint_called_self' | 'endpoint_id_undefined'
                      | 'invalid_endpoint_id' | 'not_found' | 'owner_called_self'
                      | 'do_not_disturb' | 'no_resource_type'.

-spec build(kz_term:api_ne_binary() | kz_json:object(), kapps_call:call()) ->
          {'ok', kz_json:objects()} |
          {'error', build_errors()}.
build(EndpointId, Call) ->
    build(EndpointId, kz_json:new(), Call).

-spec build(kz_term:api_ne_binary() | kz_json:object(), kz_term:api_object(), kapps_call:call()) ->
          {'ok', kz_json:objects()} |
          {'error', build_errors()}.
build('undefined', _Properties, _Call) ->
    {'error', 'endpoint_id_undefined'};
build(EndpointId, 'undefined', Call) when is_binary(EndpointId) ->
    build(EndpointId, kz_json:new(), Call);
build(EndpointId, Properties, Call) when is_binary(EndpointId) ->
    case get(EndpointId, Call) of
        {'ok', Endpoint} -> build_endpoint(Endpoint, Properties, Call);
        {'error', _}=E -> E
    end;
build(Endpoint, Properties, Call) ->
    build_endpoint(Endpoint, Properties, Call).

-spec build_endpoint(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          {'ok', kz_json:objects()} |
          {'error', build_errors()}.
build_endpoint(Endpoint, Properties, Call) ->
    lager:debug("attempting to build endpoint ~s", [kz_doc:id(Endpoint)]),
    case should_create_endpoint(Endpoint, Properties, Call) of
        'ok' -> create_endpoints(Endpoint, Properties, Call);
        {'error', _}=E -> E
    end.

-spec should_create_endpoint(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          'ok' | {'error', any()}.
should_create_endpoint(Endpoint, Properties, Call) ->
    case evaluate_rules_for_creation(Endpoint, Properties, Call) of
        {Endpoint, Properties, Call} -> 'ok';
        {'error', _}=Error -> Error
    end.

-spec evaluate_rules_for_creation(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          create_ep_acc().

evaluate_rules_for_creation(Endpoint, Properties, Call) ->
    Routines = [fun maybe_missing_resource_type/3
               ,fun maybe_owner_called_self/3
               ,fun maybe_endpoint_called_self/3
               ,fun maybe_endpoint_disabled/3
               ,fun maybe_do_not_disturb/3
               ,fun maybe_exclude_from_queues/3
               ],
    lists:foldl(fun should_create_endpoint_fold/2
               ,{Endpoint, Properties, Call}
               ,Routines
               ).

-type create_ep_acc() :: {kz_json:object(), kz_json:object(), kapps_call:call()} |
                         {'error', any()}.
-type ep_routine_v() :: fun((kz_json:object(), kz_json:object(), kapps_call:call()) -> 'ok' | _).

-spec should_create_endpoint_fold(ep_routine_v(), create_ep_acc()) -> create_ep_acc().
should_create_endpoint_fold(Routine, {Endpoint, Properties, Call}=Acc) when is_function(Routine, 3) ->
    try Routine(Endpoint, Properties, Call) of
        'ok' -> Acc;
        Error -> Error
    catch
        'throw':Error:ST ->
            kz_log:log_stacktrace(ST),
            Error;
        _E:_R:ST ->
            lager:debug("exception ~p:~p", [_E, _R]),
            kz_log:log_stacktrace(ST),
            {'error', 'exception'}
    end;
should_create_endpoint_fold(_Routine, Error) -> Error.

-spec maybe_missing_resource_type(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          'ok' |
          {'error', 'no_resource_type'}.
maybe_missing_resource_type(_Endpoint, _Properties, Call) ->
    maybe_missing_resource_type(kapps_call:resource_type(Call)).

-spec maybe_missing_resource_type(kz_term:api_binary()) ->
          'ok'.
maybe_missing_resource_type('undefined') ->
    lager:error("kapps_call resource type is undefined"),
    throw({'error', 'no_resource_type'});
maybe_missing_resource_type(_) -> 'ok'.

-spec maybe_owner_called_self(kz_json:object(), kz_json:object(),  kapps_call:call()) ->
          'ok' |
          {'error', 'owner_called_self'}.
maybe_owner_called_self(Endpoint, Properties, Call) ->
    maybe_owner_called_self(Endpoint, Properties, kapps_call:resource_type(Call), Call).

-spec maybe_owner_called_self(kz_json:object(), kz_json:object(), kz_term:api_binary(), kapps_call:call()) ->
          'ok' |
          {'error', 'owner_called_self'}.
maybe_owner_called_self(Endpoint, Properties, <<"audio">>, Call) ->
    CanCallSelf = kz_json:is_true(<<"can_call_self">>, Properties),
    EndpointOwnerId = endpoint_owner_id(Endpoint),
    OwnerId = kapps_call:owner_id(Call),
    case CanCallSelf
        orelse (not is_binary(OwnerId))
        orelse (not is_binary(EndpointOwnerId))
        orelse EndpointOwnerId =/= OwnerId
    of
        'true' -> 'ok';
        'false' ->
            lager:info("owner ~s stop calling your self...stop calling your self...", [OwnerId]),
            {'error', 'owner_called_self'}
    end;
maybe_owner_called_self(Endpoint, Properties, <<"sms">>, Call) ->
    AccountId = kapps_call:account_id(Call),
    DefTextSelf = kapps_account_config:get_global(AccountId, ?CONFIG_CAT, <<"default_can_text_self">>, 'true'),
    CanTextSelf = kz_json:is_true(<<"can_text_self">>, Properties, DefTextSelf),
    EndpointOwnerId = kz_json:get_ne_binary_value(<<"owner_id">>, Endpoint),
    OwnerId = kapps_call:owner_id(Call),
    case CanTextSelf
        orelse (not is_binary(OwnerId))
        orelse (not is_binary(EndpointOwnerId))
        orelse EndpointOwnerId =/= OwnerId
    of
        'true' -> 'ok';
        'false' ->
            lager:info("owner ~s stop texting your self...stop texting your self...", [OwnerId]),
            {'error', 'owner_called_self'}
    end.

-spec maybe_endpoint_called_self(kz_json:object(), kz_json:object(),  kapps_call:call()) ->
          'ok' |
          {'error', 'endpoint_called_self'}.
maybe_endpoint_called_self(Endpoint, Properties, Call) ->
    CanCallSelf = kz_json:is_true(<<"can_call_self">>, Properties),
    AuthorizingId = kapps_call:authorizing_id(Call),
    EndpointId = kz_doc:id(Endpoint),
    case CanCallSelf
        orelse (not is_binary(AuthorizingId))
        orelse (not is_binary(EndpointId))
        orelse AuthorizingId =/= EndpointId
    of
        'true' -> 'ok';
        'false' ->
            lager:info("endpoint ~s is calling self", [EndpointId]),
            {'error', 'endpoint_called_self'}
    end.

-spec maybe_endpoint_disabled(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          'ok' |
          {'error', 'endpoint_disabled'}.
maybe_endpoint_disabled(Endpoint, _Properties, _Call) ->
    case kz_json:is_false(<<"enabled">>, Endpoint) of
        'false' -> 'ok';
        'true' ->
            lager:info("endpoint ~s is disabled", [kz_doc:id(Endpoint)]),
            {'error', 'endpoint_disabled'}
    end.

-spec maybe_do_not_disturb(kz_json:object(), kz_json:object(),  kapps_call:call()) ->
          'ok' |
          {'error', 'do_not_disturb'}.
maybe_do_not_disturb(Endpoint, _Properties, _Call) ->
    DND = kz_json:get_json_value(<<"do_not_disturb">>, Endpoint, kz_json:new()),
    case kz_json:is_true(<<"enabled">>, DND) of
        'false' -> 'ok';
        'true' ->
            lager:info("do not disturb endpoint ~s", [kz_doc:id(Endpoint)]),
            {'error', 'do_not_disturb'}
    end.

-spec maybe_exclude_from_queues(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          'ok' |
          {'error', 'exclude_from_queues'}.
maybe_exclude_from_queues(Endpoint, _Properties, Call) ->
    case is_binary(kapps_call:custom_channel_var(<<"Queue-ID">>, Call))
        andalso kz_json:is_true(<<"exclude_from_queues">>, Endpoint)
    of
        'false' -> 'ok';
        'true' -> {'error', 'exclude_from_queues'}
    end.

%%------------------------------------------------------------------------------
%% @doc creates the actual endpoint json objects for use in the kazoo
%% bridge API.
%% @end
%%------------------------------------------------------------------------------
-spec create_endpoints(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          {'ok', kz_json:objects()} |
          {'error', 'no_endpoints'}.
create_endpoints(Endpoint, Properties, Call) ->
    Routines = [fun create_endpoint/3],
    Fun = fun(Routine, Endpoints) ->
                  try_create_endpoint(Routine, Endpoints, Endpoint, Properties, Call)
          end,
    case lists:foldl(Fun, [], Routines) of
        [] -> {'error', 'no_endpoints'};
        Endpoints -> {'ok', Endpoints}
    end.

-spec maybe_start_metaflow(kapps_call:call(), kz_json:object()) -> 'ok'.
maybe_start_metaflow(Call, Endpoint) ->
    case ?BUILD_METAFLOWS
        andalso kz_json:get_first_defined([<<"metaflows">>, <<"Metaflows">>], Endpoint)
    of
        'false' -> 'ok';
        'undefined' -> 'ok';
        ?EMPTY_JSON_OBJECT -> 'ok';
        Metaflow ->
            Id = kz_json:get_first_defined([<<"_id">>, <<"Endpoint-ID">>], Endpoint),
            API = props:filter_undefined(
                    [{<<"Endpoint-ID">>, Id}
                    ,{<<"Account-ID">>, kapps_call:account_id(Call)}
                    ,{<<"Call">>, kapps_call:to_json(Call)}
                    ,{<<"Numbers">>, kzd_metaflows:numbers(Metaflow)}
                    ,{<<"Patterns">>, kzd_metaflows:patterns(Metaflow)}
                    ,{<<"Binding-Digit">>, kzd_metaflows:binding_digit(Metaflow)}
                    ,{<<"Digit-Timeout">>, kzd_metaflows:digit_timeout(Metaflow)}
                    ,{<<"Listen-On">>, kzd_metaflows:listen_on(Metaflow, <<"self">>)}
                    | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
                    ]),
            lager:debug("sending metaflow for endpoint: ~s: ~s"
                       ,[Id, kzd_metaflows:listen_on(Metaflow, <<"self">>)]
                       ),
            kapi_metaflow:publish_binding(API)
    end.

-type ep_routine() :: fun((kz_json:object(), kz_json:object(), kapps_call:call()) ->
                                 {'error', _} | kz_json:object()).
-spec try_create_endpoint(ep_routine(), kz_json:objects(), kz_json:object(), kz_json:object(), kapps_call:call()) ->
          kz_json:objects().
try_create_endpoint(Routine, Endpoints, Endpoint, Properties, Call) when is_function(Routine, 3) ->
    try Routine(Endpoint, Properties, Call) of
        %% {'error', 'call_forward_not_appropriate'} -> Endpoints;
        %% {'error', 'call_forward_substitute'} -> Endpoints;
        {'error', _R} ->
            lager:warning("failed to create endpoint: ~p: ~p", [_R, Routine]),
            Endpoints;
        JObj ->
            lager:debug("created endpoint from ~s: ~p", [kz_doc:id(Endpoint), Routine]),
            [JObj|Endpoints]
    catch
        _E:_R:ST ->
            lager:warning("unable to build endpoint(~s): ~p", [_E, _R]),
            kz_log:log_stacktrace(ST),
            Endpoints
    end.


%%------------------------------------------------------------------------------
%% @doc Creates the kazoo API endpoint for a bridge call command. This
%% endpoint is comprised of the endpoint definition (commonly a
%% device) and the properties of this endpoint in the callflow.
%% @end
%%------------------------------------------------------------------------------
-record(clid, {caller_number :: kz_term:api_binary()
              ,caller_name :: kz_term:api_binary()
              ,callee_name :: kz_term:api_binary()
              ,callee_number :: kz_term:api_binary()
              ,hide_name :: 'undefined' | 'true'
              ,hide_number :: 'undefined' | 'true'
              }).
-type clid() :: #clid{}.

-spec get_clid(kz_json:object(), kz_json:object(), kapps_call:call()) -> clid().
get_clid(Endpoint, Properties, Call) ->
    get_clid(Endpoint, Properties, Call, kz_attributes:caller_id_type(Call)).

-spec get_clid(kz_json:object(), kz_json:object(), kapps_call:call(), kz_term:ne_binary()) -> clid().
get_clid(Endpoint, Properties, Call, Type) ->
    case kz_json:is_true(<<"suppress_clid">>, Properties) of
        'true' -> maybe_move_privacy(Endpoint, Properties, Call, #clid{});
        'false' ->
            {CallerNumber, CallerName} = kz_attributes:caller_id(Type, Call),
            {CalleeNumber, CalleeName} = kz_attributes:callee_id(Endpoint, Call),
            maybe_move_privacy(Endpoint
                              ,Properties
                              ,Call
                              ,#clid{caller_number=CallerNumber
                                    ,caller_name=CallerName
                                    ,callee_number=CalleeNumber
                                    ,callee_name=CalleeName
                                    }
                              )
    end.

-spec maybe_move_privacy(kz_json:object(), kz_json:object(), kapps_call:call(), clid()) -> clid().
maybe_move_privacy(Endpoint, _Properties, Call, Clid) ->
    CallForward = unconditional_call_forward(Endpoint),
    CCVs = kapps_call:custom_channel_vars(Call),
    RetainCID = kzd_call_forward:keep_caller_id(CallForward)
        orelse kz_json:is_true(<<"Retain-CID">>, CCVs),
    HideName = kz_privacy:should_hide_name(CCVs),
    HideNumber = kz_privacy:should_hide_number(CCVs),
    move_privacy(RetainCID, HideName, HideNumber, Clid).

-spec move_privacy(boolean(), boolean(), boolean(), clid()) -> clid().
move_privacy('false', _HideName, _HideNumber, Clid) ->
    Clid;
move_privacy('true', 'false', 'false', Clid) ->
    Clid;
move_privacy('true', 'false', 'true', Clid) ->
    Clid#clid{hide_number = 'true'};
move_privacy('true', 'true', 'false', Clid) ->
    Clid#clid{hide_name = 'true'};
move_privacy('true', 'true', 'true', Clid) ->
    Clid#clid{hide_name = 'true'
             ,hide_number = 'true'
             }.

-spec create_endpoint(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          kz_json:object().
create_endpoint(Endpoint, Properties, Call) ->
    Clid = get_clid(Endpoint, Properties, Call),
    create_endpoint(Endpoint, Properties, Clid, Call).

-spec create_endpoint(kz_json:object(), kz_json:object(), clid(), kapps_call:call()) ->
          kz_json:object().
create_endpoint(Endpoint, Properties, #clid{}=Clid, Call) ->
    SIPEndpoint = kz_json:from_list(
                    [{<<"Invite-Format">>, <<"endpoint">>}
                    ,{<<"Outbound-Caller-ID-Number">>, Clid#clid.caller_number}
                    ,{<<"Outbound-Caller-ID-Name">>, Clid#clid.caller_name}
                    ,{<<"Outbound-Callee-ID-Name">>, Clid#clid.callee_name}
                    ,{<<"Outbound-Callee-ID-Number">>, Clid#clid.callee_number}
                    ,{<<"Privacy-Hide-Name">>, Clid#clid.hide_name}
                    ,{<<"Privacy-Hide-Number">>, Clid#clid.hide_number}
                    ,{<<"Privacy-Method">>, kz_privacy:get_method(Endpoint)}
                    ,{<<"Endpoint-Timeout">>, get_timeout(Properties)}
                    ,{<<"Endpoint-Delay">>, get_delay(Properties)}
                    ,{<<"Account-ID">>, kapps_call:account_id(Call)}
                    ,{<<"Endpoint-ID">>, kzd_endpoint:id(Endpoint)}
                    ,{<<"Endpoint-URI">>, endpoint_uri(Endpoint, Call)}
                    ,{<<"Presence-ID">>, kz_attributes:presence_id(Endpoint, Call)}
                    ,{<<"Custom-Channel-Vars">>, generate_ccvs(Endpoint, Call)}
                    ,{<<"Custom-SIP-Headers">>, generate_sip_headers(Endpoint, <<"endpoint">>, Call)}
                    ,{<<"Flags">>, get_outbound_flags(Endpoint)}
                    ,{<<"Metaflows">>, kz_json:get_json_value(<<"metaflows">>, Endpoint)}
                    ,{<<"Endpoint-Actions">>, endpoint_actions(Endpoint, Call)}
                    | maybe_get_t38(Endpoint, Call)
                    ]),
    maybe_format_endpoint(SIPEndpoint, kz_json:get_json_value(<<"formatters">>, Endpoint)).

-spec maybe_get_t38(kz_json:object(), kapps_call:call()) -> kz_term:proplist().
maybe_get_t38(Endpoint, Call) ->
    Opt =
        case ?MODULE:get(Call) of
            {'ok', JObj} -> kz_json:is_true([<<"media">>, <<"fax_option">>], JObj);
            {'error', _} -> 'undefined'
        end,
    case kz_json:get_value(<<"device_type">>, Endpoint) of
        <<"fax">> ->
            HasOption = kz_json:is_true([<<"media">>, <<"fax_option">>], Endpoint),
            kapps_call_command:get_inbound_t38_settings(Opt, HasOption);
        _Type -> []
    end.

%%------------------------------------------------------------------------------
%% @doc Creates the Kazoo API endpoint for a bridge call command when
%% the device (or owner) has forwarded their phone.  This endpoint
%% is comprised of a route based on CallFwd, the relevant settings
%% from the actually endpoint, and the properties of this endpoint in
%% the callflow.
%% @end
%%------------------------------------------------------------------------------
-spec create_call_fwd_endpoint(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          kz_json:object().
create_call_fwd_endpoint(Endpoint, Properties, Call) ->
    create_call_fwd_endpoint(Endpoint, Properties, Call
                            ,unconditional_call_forward(Endpoint)
                            ).

-spec create_call_fwd_endpoint(kz_json:object(), kz_json:object(), kapps_call:call(), kzd_call_forward:doc()) ->
          kz_json:object().
create_call_fwd_endpoint(Endpoint, Properties, Call, CallForward) ->
    Route = kzd_call_forward:number(CallForward),
    ToDID = kz_json:get_value(<<"number">>, Endpoint, kapps_call:request_user(Call)),
    lager:info("call forwarding endpoint to ~s : ~s", [Route, ToDID]),
    IgnoreEarlyMedia = should_ignore_early_media(CallForward),

    kz_json:from_list(
      [{<<"Account-ID">>, kapps_call:account_id(Call)}
      ,{<<"Bypass-Media">>, <<"false">>}
      ,{<<"Custom-Channel-Vars">>, generate_ccvs(Endpoint, Call, CallForward)}
      ,{<<"Custom-SIP-Headers">>, generate_sip_headers(Endpoint, <<"forward">>, Call)}
      ,{<<"Endpoint-Delay">>, get_delay(Properties)}
      ,{<<"Endpoint-ID">>, kz_doc:id(Endpoint)}
      ,{<<"Endpoint-Progress-Timeout">>, get_progress_timeout(Endpoint)}
      ,{<<"Endpoint-Timeout">>, get_timeout(Properties)}
      ,{<<"Ignore-Early-Media">>, IgnoreEarlyMedia}
      ,{<<"Invite-Format">>, <<"loopback">>}
      ,{<<"Presence-ID">>, kz_attributes:presence_id(Endpoint, Call)}
      ,{<<"Privacy-Method">>, kz_privacy:get_method(Endpoint)}
      ,{<<"Route">>, Route}
      ,{<<"To-DID">>, ToDID}
      | call_forward_cid_properties(Endpoint, Properties, Call)
      ]).

should_ignore_early_media(CallForward) ->
    case kzd_call_forward:require_keypress(CallForward)
        orelse not kzd_call_forward:substitute(CallForward)
    of
        'true' -> <<"true">>;
        'false' -> kzd_call_forward:ignore_early_media(CallForward)
    end.

call_forward_cid_properties(Endpoint, Properties, Call) ->
    #clid{callee_name=CalleeName
         ,callee_number=CalleeNumber
         ,caller_name=CallerName
         ,caller_number=CallerNumber
         ,hide_name=HideName
         ,hide_number=HideNumber
         } =
        case kapps_call:inception(Call) of
            'undefined' -> get_clid(Endpoint, Properties, Call, <<"external">>);
            _Else -> maybe_move_privacy(Endpoint, Properties, Call, #clid{})
        end,
    [{<<"Outbound-Callee-ID-Name">>, CalleeName}
    ,{<<"Outbound-Callee-ID-Number">>, CalleeNumber}
    ,{<<"Outbound-Caller-ID-Name">>, CallerName}
    ,{<<"Outbound-Caller-ID-Number">>, CallerNumber}
    ,{<<"Privacy-Hide-Name">>, HideName}
    ,{<<"Privacy-Hide-Number">>, HideNumber}
    ].

-spec create_sip_endpoint(kz_json:object(), kz_json:object(), kapps_call:call()) ->
          kz_json:object().
create_sip_endpoint(Endpoint, Properties, Call) ->
    create_endpoint(Endpoint, Properties, Call).

%%------------------------------------------------------------------------------
%% @doc This function will return the sip headers that should be set for
%% the endpoint
%% @end
%%------------------------------------------------------------------------------
-spec generate_sip_headers(kz_json:object(), kz_term:ne_binary(), kapps_call:call()) ->
          kz_json:object().
generate_sip_headers(Endpoint, Type, Call) ->
    generate_sip_headers(Endpoint, Type, kz_json:new(), Call).

-spec generate_sip_headers(kz_json:object(), kz_term:ne_binary(), kz_json:object(), kapps_call:call()) ->
          kz_json:object().
generate_sip_headers(Endpoint, <<"forward">>, Acc, Call) ->
    Inception = kapps_call:inception(Call),

    HeaderFuns = [{fun add_sip_inbound_headers/2, Endpoint}
                 ,{fun add_sip_outbound_headers/2, Call}
                 ,{fun maybe_add_aor/3, Endpoint, Call}
                 ,{fun maybe_add_invite_format/3, Endpoint, Call}
                 ,{fun maybe_add_diversion/2, {Endpoint, Inception, Call}}
                 ],
    kz_json:exec_first(HeaderFuns, Acc);
generate_sip_headers(_Endpoint, <<"endpoint">>, Acc, Call) ->
    HeaderFuns = [{fun add_sip_outbound_headers/2, Call}
                 ,{fun maybe_add_alert_info/2, Call}
                 ],
    kz_json:exec_first(HeaderFuns, Acc).

-spec maybe_add_diversion(kz_json:object(), {kz_json:object(), kz_term:api_binary(), kapps_call:call()}) -> kz_json:object().
maybe_add_diversion(JObj, {Endpoint, _Inception, Call}) ->
    CallForward = unconditional_call_forward(Endpoint),
    ShouldAddDiversion = kapps_call:authorizing_id(Call) =:= 'undefined'
        andalso kzd_call_forward:keep_caller_id(CallForward, 'false')
        andalso kapps_config:get_is_true(?CONFIG_CAT, <<"should_add_diversion_header">>, 'false'),
    case ShouldAddDiversion of
        'false' -> JObj;
        'true' ->
            Diversion = list_to_binary(["<sip:", kapps_call:request(Call), ">", ";reason=unconditional"]),
            lager:debug("add diversion as ~s", [Diversion]),
            Diversions = kz_json:get_list_value(<<"Diversions">>, JObj, []),
            kz_json:set_value(<<"Diversions">>, [Diversion | Diversions], JObj)
    end.

-spec add_sip_inbound_headers(kz_json:object(), kz_json:object()) -> kz_json:object().
add_sip_inbound_headers(JObj, Endpoint) ->
    merge_custom_sip_headers(get_sip_inbound_headers(Endpoint), JObj).

-spec get_sip_inbound_headers(kz_json:object()) -> kz_term:api_object().
get_sip_inbound_headers(Endpoint) ->
    kzd_devices:custom_sip_headers_inbound(Endpoint).

-spec get_sip_outbound_headers(kapps_call:call()) -> kz_term:api_object().
get_sip_outbound_headers(Call) ->
    case ?MODULE:get(Call) of
        {'error', _E} -> 'undefined';
        {'ok', Endpoint} -> kzd_devices:custom_sip_headers_outbound(Endpoint)
    end.

-spec add_sip_outbound_headers(kz_json:object(), kapps_call:call()) -> kz_json:object().
add_sip_outbound_headers(JObj, Call) ->
    merge_custom_sip_headers(get_sip_outbound_headers(Call), JObj).

-spec merge_custom_sip_headers(kz_term:api_object(), kz_json:object()) -> kz_json:object().
merge_custom_sip_headers('undefined', JObj) -> JObj;
merge_custom_sip_headers(CustomHeaders, JObj) ->
    kz_json:merge_jobjs(CustomHeaders, JObj).

-spec maybe_add_alert_info(kz_json:object(), kapps_call:call()) -> kz_json:object().
maybe_add_alert_info(JObj, Call) ->
    case kapps_call:kvs_fetch(<<"Override-Ringtone">>, Call) of
        'undefined' -> JObj;
        Ringtone -> set_alert_info(Ringtone, JObj)
    end.

-spec set_alert_info(kz_term:ne_binary(), kz_json:object()) -> kz_json:object().
set_alert_info(Info, JObj) ->
    kz_json:set_value(<<"Alert-Info">>, Info, JObj).

-spec maybe_add_invite_format(kz_json:object(), kz_json:object(), kapps_call:call()) -> kz_json:object().
maybe_add_invite_format(JObj, Endpoint, Call) ->
    maybe_add_invite_format(JObj, Endpoint, Call, kzd_devices:sip_invite_format(Endpoint)).

-spec maybe_add_invite_format(kz_json:object(), kz_json:object(), kapps_call:call(), kz_term:ne_binary()) ->
          kz_json:object().
maybe_add_invite_format(JObj, _Endpoint, _Call, Format) ->
    case kzd_endpoint:type(JObj) of
        <<"device">> -> kz_json:set_value(<<"X-KAZOO-INVITE-FORMAT">>, Format, JObj);
        _Else -> JObj
    end.

-spec maybe_add_aor(kz_json:object(), kz_json:object(), kapps_call:call()) -> kz_json:object().
maybe_add_aor(JObj, Endpoint, Call) ->
    Realm = kzd_devices:sip_realm(Endpoint, kapps_call:account_realm(Call)),
    Username = kzd_devices:sip_username(Endpoint),
    maybe_add_aor(JObj, Endpoint, Username, Realm).

-spec maybe_add_aor(kz_json:object(), kz_json:object(), kz_term:api_binary(), kz_term:ne_binary()) -> kz_json:object().
maybe_add_aor(JObj, _, 'undefined', _Realm) -> JObj;
maybe_add_aor(JObj, _, Username, Realm) ->
    kz_json:set_value(<<"X-KAZOO-AOR">>, <<"sip:", Username/binary, "@", Realm/binary>> , JObj).

%%------------------------------------------------------------------------------
%% @doc This function will return the custom channel vars that should be
%% set for this endpoint depending on its settings, and the current
%% call.
%% @end
%%------------------------------------------------------------------------------

-spec generate_ccvs(kz_json:object(), kapps_call:call()) -> kz_json:object().
generate_ccvs(Endpoint, Call) ->
    generate_ccvs(Endpoint, Call, 'undefined').

-spec generate_ccvs(kz_json:object(), kapps_call:call(), kz_term:api_object()) -> kz_json:object().
generate_ccvs(Endpoint, Call, 'undefined' = CallFwd) ->
    CCVFuns = [fun maybe_auto_answer/1],
    Acc0 = {Endpoint, Call, CallFwd, kz_json:new()},
    {_Endpoint, _Call, _CallFwd, CCVs} = lists:foldr(fun(F, Acc) -> F(Acc) end, Acc0, CCVFuns),
    CCVs;
generate_ccvs(Endpoint, Call, CallFwd) ->
    CCVFuns = [fun maybe_retain_caller_id/1
              ,fun maybe_set_owner_id/1
              ,fun maybe_set_account_id/1
              ,fun maybe_set_call_forward/1
              ,fun maybe_set_confirm_properties/1
              ,fun set_sip_invite_domain/1
              ],
    Acc0 = {Endpoint, Call, CallFwd, kz_json:new()},
    {_Endpoint, _Call, _CallFwd, CCVs} = lists:foldr(fun(F, Acc) -> F(Acc) end, Acc0, CCVFuns),
    CCVs.

-type ccv_acc() :: {kz_json:object(), kapps_call:call(), kz_term:api_object(), kz_json:object()}.

-spec maybe_retain_caller_id(ccv_acc()) -> ccv_acc().
maybe_retain_caller_id({_Endpoint, _Call, 'undefined', _JObj}=Acc) ->
    Acc;
maybe_retain_caller_id({Endpoint, Call, CallFwd, CCVs}) ->
    {Endpoint, Call, CallFwd
    ,case kzd_call_forward:keep_caller_id(CallFwd) of
         'true' ->
             lager:info("call forwarding will retain caller id"),
             kz_json:set_value(<<"Retain-CID">>, <<"true">>, CCVs);
         'false' -> CCVs
     end
    }.

-spec maybe_set_owner_id(ccv_acc()) -> ccv_acc().
maybe_set_owner_id({Endpoint, Call, CallFwd, CCVs}) ->
    {Endpoint, Call, CallFwd
    ,case kzd_endpoint:owner_id(Endpoint) of
         'undefined' -> CCVs;
         OwnerId -> kz_json:set_value(<<"Owner-ID">>, OwnerId, CCVs)
     end
    }.

-spec maybe_set_account_id(ccv_acc()) -> ccv_acc().
maybe_set_account_id({Endpoint, Call, CallFwd, CCVs}) ->
    AccountId = kz_doc:account_id(Endpoint, kapps_call:account_id(Call)),
    {Endpoint, Call, CallFwd
    ,kz_json:set_value(<<"Account-ID">>, AccountId, CCVs)
    }.

-spec maybe_set_call_forward(ccv_acc()) -> ccv_acc().
maybe_set_call_forward({_Endpoint, _Call, 'undefined', _CCVs}=Acc) ->
    Acc;
maybe_set_call_forward({_Endpoint, _Call, CallFwd, _CCVs} = Acc) ->
    Number = kzd_call_forward:number(CallFwd),
    maybe_set_call_forward(Acc, Number).

-spec maybe_set_call_forward(ccv_acc(), kz_term:api_ne_binary()) -> ccv_acc().
maybe_set_call_forward(Acc, 'undefined') -> Acc;
maybe_set_call_forward({Endpoint, Call, CallFwd, CCVs}, Number) ->
    LoopbackURI = list_to_binary(["sip:", Number, "@", kapps_call:account_realm(Call)]),
    {Endpoint, Call, CallFwd
    ,kz_json:set_values([{<<"Call-Forward">>, <<"true">>}
                        ,{<<"Authorizing-Type">>, <<"device">>}
                        ,{<<"Authorizing-ID">>, kz_doc:id(Endpoint)}
                        ,{<<"Call-Forward-From">>, kapps_call:inception_type(Call)}
                        ,{<<"Call-Forward-For-UUID">>, kapps_call:other_leg_call_id(Call)}
                        ,{<<"Require-Ignore-Early-Media">>, <<"true">>}
                        ,{<<"Loopback-Request-URI">>, LoopbackURI}
                        ,{<<"Ignore-Early-Media">>, <<"true">>}
                        ]
                       ,CCVs
                       )
    }.

-spec maybe_auto_answer(ccv_acc()) -> ccv_acc().
maybe_auto_answer({Endpoint, Call, CallFwd, CCVs}=Acc) ->
    case kapps_call:custom_channel_var(<<"Auto-Answer-Loopback">>, Call) of
        'undefined' -> Acc;
        AutoAnswer ->
            {Endpoint, Call, CallFwd, kz_json:set_value(<<"Auto-Answer">>, AutoAnswer, CCVs)}
    end.

-spec maybe_set_confirm_properties(ccv_acc()) -> ccv_acc().
maybe_set_confirm_properties({Endpoint, Call, CallFwd, CCVs}=Acc) ->
    case kzd_call_forward:require_keypress(CallFwd) of
        'false' -> Acc;
        'true' ->
            lager:info("call forwarding configured to require key press"),
            Confirm = [{<<"Confirm-Key">>, <<"1">>}
                      ,{<<"Confirm-Cancel-Timeout">>, 'true'}
                      ,{<<"Confirm-Read-Timeout">>, kz_term:to_binary(7 * ?MILLISECONDS_IN_SECOND)}
                      ,{<<"Confirm-File">>, ?CONFIRM_FILE(Call)}
                      ,{<<"Require-Ignore-Early-Media">>, <<"true">>}
                      ,{<<"Require-Fail-On-Single-Reject">>, [<<"USER_BUSY">>
                                                             ,<<"CALL_REJECTED">>
                                                             ,<<"NO_ANSWER">>
                                                             ,<<"NORMAL_CLEARING">>
                                                             ,<<"PROGRESS_TIMEOUT">>
                                                             ]}
                      ],
            {Endpoint, Call, CallFwd
            ,kz_json:merge_jobjs(kz_json:from_list(Confirm), CCVs)
            }
    end.

-spec encryption_method_map(kz_term:api_object(), kz_term:api_binaries() | kz_json:object()) -> kz_term:api_object().
encryption_method_map(CCVs, []) -> CCVs;
encryption_method_map(CCVs, [Method|Methods]) ->
    case props:get_value(Method, ?ENCRYPTION_MAP, []) of
        [] -> encryption_method_map(CCVs, Methods);
        Values -> encryption_method_map(kz_json:set_values(Values, CCVs), Methods)
    end;
encryption_method_map(CCVs, Endpoint) ->
    encryption_method_map(CCVs
                         ,kz_json:get_value([<<"media">>
                                            ,<<"encryption">>
                                            ,<<"methods">>
                                            ]
                                           ,Endpoint
                                           ,[]
                                           )
                         ).


-spec set_sip_invite_domain(ccv_acc()) -> ccv_acc().
set_sip_invite_domain({Endpoint, Call, CallFwd, CCVs}) ->
    SipRealm = get_sip_realm(Endpoint, kapps_call:account_id(Call), kapps_call:request_realm(Call)),
    {Endpoint, Call, CallFwd
    ,kz_json:set_value(<<"SIP-Invite-Domain">>, SipRealm, CCVs)
    }.

-spec get_timeout(kz_json:object()) -> kz_term:api_binary().
get_timeout(JObj) ->
    case kz_json:get_integer_value(<<"timeout">>, JObj, 0) of
        Timeout when Timeout > 0 -> kz_term:to_binary(Timeout);
        _Else -> 'undefined'
    end.

-spec get_delay(kz_json:object()) -> kz_term:api_binary().
get_delay(JObj) ->
    case kz_json:get_integer_value(<<"delay">>, JObj, 0) of
        Delay when Delay > 0 -> kz_term:to_binary(Delay);
        _Else -> 'undefined'
    end.

-spec get_outbound_flags(kz_json:object()) -> kz_term:api_binary().
get_outbound_flags(JObj) ->
    kz_json:get_ne_value(<<"outbound_flags">>, JObj).

-spec get_progress_timeout(kz_json:object()) -> kz_term:api_binary().
get_progress_timeout(JObj) ->
    case kz_json:get_integer_value([<<"media">>, <<"progress_timeout">>], JObj, 0) of
        Timeout when Timeout > 0 -> kz_term:to_binary(Timeout);
        _Else -> 'undefined'
    end.

%%------------------------------------------------------------------------------
%% @doc Get the sip realm
%% @end
%%------------------------------------------------------------------------------
-spec get_sip_realm(kz_json:object(), kz_term:ne_binary()) -> kz_term:api_binary().
get_sip_realm(SIPJObj, AccountId) ->
    get_sip_realm(SIPJObj, AccountId, 'undefined').

-spec get_sip_realm(kz_json:object(), kz_term:ne_binary(), Default) -> Default | kz_term:ne_binary().
get_sip_realm(SIPJObj, AccountId, Default) ->
    case kzd_devices:sip_realm(SIPJObj) of
        'undefined' ->
            case kzd_accounts:fetch_realm(AccountId) of
                'undefined' -> Default;
                Realm -> Realm
            end;
        Realm -> Realm
    end.

%%------------------------------------------------------------------------------
%% @doc This function will return the custom channel vars that should be
%% set for this endpoint depending on its settings, and the current
%% call.
%% @end
%%------------------------------------------------------------------------------

-spec endpoint_actions(kz_json:object(), kapps_call:call()) -> kz_json:object().
endpoint_actions(Endpoint, Call) ->
    endpoint_actions(Endpoint, Call, 'undefined').

-spec endpoint_actions(kz_json:object(), kapps_call:call(), kz_term:api_object()) -> kz_json:object().
endpoint_actions(Endpoint, Call, CallFwd) ->
    Funs = [fun maybe_record_endpoint/1],
    Acc0 = {Endpoint, Call, CallFwd, kz_json:new()},
    {_Endpoint, _Call, _CallFwd, Actions} = lists:foldr(fun(F, Acc) -> F(Acc) end, Acc0, Funs),
    Actions.

-type actions_acc() :: {kz_json:object(), kapps_call:call(), kz_term:api_object(), kz_json:object()}.

-spec maybe_record_endpoint(actions_acc()) -> actions_acc().
maybe_record_endpoint({_Endpoint, Call, _CallFwd, _Actions} = Acc) ->
    ShouldNotCheck = kapps_call:call_id_direct(Call) =:= 'undefined',
    maybe_record_endpoint(Acc, ShouldNotCheck).

-spec maybe_record_endpoint(actions_acc(), boolean()) -> actions_acc().
maybe_record_endpoint(Acc, 'true') -> Acc;
maybe_record_endpoint({Endpoint, Call, CallFwd, Actions}=Acc, 'false') ->
    case kz_endpoint_recording:maybe_record_inbound(kapps_call:inception_type(Call), Endpoint, Call) of
        'false' -> Acc;
        {'true', {ActionKey, ActionApp}} ->
            NewActions = kz_json:set_value(ActionKey, ActionApp, Actions),
            {Endpoint, Call, CallFwd, NewActions}
    end.

-spec endpoint_uri(kz_json:object(), kapps_call:call()) -> kz_term:ne_binary().
endpoint_uri(Endpoint, Call) ->
    list_to_binary([kz_json:get_ne_binary_value(<<"Endpoint-ID">>, Endpoint), "@", kapps_call:account_id(Call)]).

endpoint_type(Endpoint) ->
    kz_json:get_ne_binary_value(<<"Endpoint-Type">>, Endpoint).

endpoint_owner_id(Endpoint) ->
    endpoint_owner_id(Endpoint, endpoint_type(Endpoint)).

endpoint_owner_id(Endpoint, <<"user">>) ->
    kz_json:get_ne_binary_value(<<"Endpoint-ID">>, Endpoint);
endpoint_owner_id(Endpoint, <<"device">>) ->
    kz_json:get_ne_binary_value(<<"owner_id">>, Endpoint);
endpoint_owner_id(_Endpoint,_) -> 'undefined'.

build_default_cav(Key, Value, JObj, Acc) ->
    case kz_json:get_value(Value, JObj) of
        'undefined' -> Acc;
        V -> kz_json:set_value(Key, V, Acc)
    end.

build_default_cav_fun(JObj) ->
    build_default_cav_fun(JObj, []).

build_default_cav_fun(JObj, Keys) ->
    fun(Key, Value, Acc) ->
            case kz_json:is_json_object(Value) of
                'true' -> kz_json:foldl(build_default_cav_fun(JObj, Keys ++ [Key]), Acc, Value);
                'false' -> build_default_cav(Keys ++ [Key], Value, JObj, Acc)
            end
    end.

build_default_cavs('undefined', _CAVs) -> 'undefined';
build_default_cavs(JObj, CAVs) ->
    case kz_json:get_json_value(kz_doc:type(JObj), CAVs) of
        'undefined' -> 'undefined';
        TypeCAVs -> kz_json:foldl(build_default_cav_fun(JObj), kz_json:new(), TypeCAVs)
    end.

system_default_cavs() ->
    kapps_config:get_json(?CONFIG_CAT, <<"default_cavs">>).

account_default_cavs(AccountJObj) ->
    case kz_json:get_json_value(<<"default_cavs">>, AccountJObj) of
        'undefined' -> system_default_cavs();
        CAVs -> kz_json:merge(lists:filter(fun kz_term:is_not_empty/1, [system_default_cavs(), CAVs]))
    end.

merge_default_cavs(Key, Account, Endpoint, Owner) ->
    merge_default_cavs(Key, Account, Endpoint, Owner, account_default_cavs(Account)).

merge_default_cavs(_Key, _Account, Endpoint, _Owner, 'undefined') -> Endpoint;
merge_default_cavs(Key, Account, Endpoint, Owner, CAVs) ->
    JObjs = [Account, Endpoint, Owner],
    JSON = merge_cavs([build_default_cavs(JObj, CAVs) || JObj <- JObjs]),
    case kz_json:is_json_object(JSON)
        andalso kz_json:is_not_empty(JSON)
    of
        'true' -> kz_json:set_value(Key, JSON, Endpoint);
        'false' -> Endpoint
    end.

merge_cavs([]) -> 'undefined';
merge_cavs(JSONs) ->
    case lists:filter(fun kz_term:is_not_empty/1, JSONs) of
        [] -> 'undefined';
        Filtered -> kz_json:merge(Filtered)
    end.

merge_default_ccvs(Key, Account, Endpoint, Owner) ->
    merge_default_ccvs(Key, Account, Endpoint, Owner, account_default_ccvs(Account)).

merge_default_ccvs(_Key, _Account, Endpoint, _Owner, 'undefined') -> Endpoint;
merge_default_ccvs(Key, Account, Endpoint, Owner, CCVs) ->
    DefaultCCVs = kz_json:filter(fun build_default_ccvs_filter/1, CCVs),
    JObjs = [Account, Endpoint, Owner],
    JSONs = [kz_json:get_json_value(kz_doc:type(JObj, <<"any">>), CCVs, DefaultCCVs) || JObj <- JObjs],
    JSON = merge_default_ccvs(JSONs),
    case kz_json:is_json_object(JSON)
        andalso kz_json:is_not_empty(JSON)
    of
        'true' -> kz_json:set_value(Key, JSON, Endpoint, #{keep_null => true});
        'false' -> kz_json:set_value(Key, null, Endpoint)
    end.

merge_default_ccvs(JSONs) ->
    case lists:filter(fun kz_term:is_not_empty/1, JSONs) of
        [] -> undefined;
        [OneJObj] -> OneJObj;
        Filtered -> kz_json:merge(Filtered,  #{keep_null => true})
    end.

build_default_ccvs_filter_types() ->
    [<<"account">>
    ,<<"user">>
    ,<<"device">>
    ].

build_default_ccvs_filter({Key, Value}) ->
    not (lists:member(Key, build_default_ccvs_filter_types())
         orelse kz_json:is_json_object(Value)).

system_default_ccvs() ->
    kapps_config:get_json(?CONFIG_CAT, <<"default_ccvs">>).

account_default_ccvs(AccountJObj) ->
    case kz_json:get_json_value(<<"default_ccvs">>, AccountJObj) of
        'undefined' -> system_default_ccvs();
        CCVs -> merge_default_ccvs([system_default_ccvs(), CCVs])
    end.

merge_call_limits(Key, Account, Endpoint, Owner) ->
    merge_call_limits(Key, Account, Endpoint, Owner, account_default_call_limits(Account)).

merge_call_limits(Key, Account, Endpoint, Owner, Limits) ->
    JObjs = [Account, Endpoint | merge_owner_call_limits(kz_doc:type(Endpoint), Owner)],
    JSON = build_call_limits(JObjs, Limits),
    case kz_json:is_json_object(JSON)
        andalso kz_json:is_not_empty(JSON)
    of
        'true' -> kz_json:set_value(Key, JSON, Endpoint);
        'false' -> kz_json:set_value(Key, 'null', Endpoint)
    end.

merge_owner_call_limits(<<"user">>, _Owner) -> [];
merge_owner_call_limits(_, Owner) -> [Owner].

account_default_call_limits(AccountJObj) ->
    case kz_json:get_json_value(<<"default_call_limits">>, AccountJObj) of
        'undefined' -> system_default_call_limits();
        Limits -> kz_json:merge(lists:filter(fun kz_term:is_not_empty/1, [system_default_call_limits(), Limits]))
    end.

system_default_call_limits() ->
    kapps_config:get_json(?CONFIG_CAT, <<"default_call_limits">>, kz_json:new()).

type_default_call_limits(JObj, DefaultLimits) ->
    case kz_json:get_json_value(kz_doc:type(JObj), DefaultLimits) of
        'undefined' -> 'undefined';
        TypeLimit -> {kz_doc:type(JObj), TypeLimit}
    end.

build_call_limits(JObjs, Limits) ->
    lists:foldl(build_call_limits_fold_fun(Limits), kz_json:new(), JObjs).

build_call_limits_fold_fun(Limits) ->
    fun('undefined', Acc) -> Acc;
       (JObj, Acc) ->
            case build_call_limit(JObj, Limits) of
                'undefined' -> Acc;
                {_, 'undefined'} -> Acc;
                {Key, Value} -> kz_json:set_value(Key, Value, Acc)
            end
    end.

build_call_limit(JObj, Limits) ->
    case kz_json:get_json_value(<<"call_limits">>, JObj) of
        'undefined' -> type_default_call_limits(JObj, Limits);
        TypeLimit -> {kz_doc:type(JObj), kzd_call_limits:max_concurrent(TypeLimit)}
    end.

%% Addresses {
-spec merge_address_fold(kz_term:ne_binary(), kz_json:object(), kz_json:object(), kz_json:object()) ->
          kz_json:object().
merge_address_fold(<<"emergency">>, Account, Endpoint, Owner) ->
    EmptyJObj = kz_json:new(),
    EndpointAddresses = kzd_endpoint:addresses(Endpoint, EmptyJObj),
    %% Precedence order: Endpoint > Owner (if any) > Account.
    AccountEmerAddr = kzd_addresses:emergency(kzd_accounts:addresses(Account, EmptyJObj), EmptyJObj),
    OwnerEmerAddr = kzd_addresses:emergency(kzd_users:addresses(Owner, EmptyJObj), AccountEmerAddr),
    EndpointEmerAddr = kzd_addresses:emergency(EndpointAddresses, OwnerEmerAddr),
    case kz_term:is_empty(EndpointEmerAddr) of
        'true' ->
            Endpoint;
        'false' ->
            NewAddresses = kzd_addresses:set_emergency(EndpointAddresses, EndpointEmerAddr),
            kzd_endpoint:set_addresses(Endpoint, NewAddresses)
    end;
merge_address_fold(_, _Account, Endpoint, _Owner) ->
    Endpoint.
%% }
