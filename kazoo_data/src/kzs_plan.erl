%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc data plan
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzs_plan).

-export([plan/0, plan/1, plan/2, plan/3]).

-export([get_dataplan/2
        ,should_allow_validation_overrides/0
        ,allow_validation_overrides/0
        ,disallow_validation_overrides/0
        ]).

-export([init/0
        ,reload/0, reload/1, reload/2
        ,flush/0
        ]).

-export([reset_system_dataplan/0]).

-on_load(onload/0).

-include("kz_data.hrl").

-define(IS_JSON_GUARD(Obj), is_tuple(Obj)
        andalso is_list(element(1, Obj))
       ).

-define(NEW_CONNECTION_TIMEOUT, ?MILLISECONDS_IN_SECOND * 5).

-define(SYSTEM_DATAPLAN_ID, <<"system">>).
-define(TAG_LOCAL, <<"local">>).
-define(DATAPLAN_FILE_LOCATION, "defaults").

-define(CACHED_SYSTEM_DATAPLAN, fetch_cached_dataplan(?SYSTEM_DATAPLAN_ID, fun fetch_simple_dataplan/1)).
-define(CACHED_ACCOUNT_DATAPLAN(A), fetch_cached_dataplan(A, fun fetch_account_dataplan/1)).
-define(CACHED_STORAGE_DATAPLAN(A,B), fetch_cached_dataplan({A, B}, fun fetch_storage_dataplan/1)).

-define(KZS_PLAN_INIT_SLICE, 100).
-define(KZS_PLAN_INIT_VIEW, <<"storage/accounts">>).
-define(KZS_PLAN_ACCOUNT_VIEW, <<"storage/storage_by_account">>).

%% friendly name of the connection (default is "local")
-type connection_tag() :: kz_term:ne_binary().

-type dataplan() :: #{tag := kz_term:ne_binary()
                     ,server := server() | map() | {atom(), kz_data:connection()}
                     ,others => [{connection_tag(), server() | map()}]
                     ,secondary => [{connection_tag(), server() | map()}]
                     ,classification => atom()
                     ,account_id => kz_term:ne_binary()
                     ,att_handler => {atom(), map()}
                     }.

-export_type([dataplan/0]).

-spec should_allow_validation_overrides() -> boolean().
should_allow_validation_overrides() ->
    kapps_config:get_boolean(?KZ_DATA_DB, <<"allow_validation_overrides">>, 'false').

-spec allow_validation_overrides() -> 'true'.
allow_validation_overrides() ->
    {'ok', _} = kapps_config:set_default(?KZ_DATA_DB, <<"allow_validation_overrides">>, 'true'),
    'true'.

-spec disallow_validation_overrides() -> 'false'.
disallow_validation_overrides() ->
    {'ok', _} = kapps_config:set_default(?KZ_DATA_DB, <<"allow_validation_overrides">>, 'false'),
    'false'.

-spec plan() -> dataplan().
plan() ->
    system_dataplan().

-spec plan(kz_term:ne_binary()) -> dataplan().
plan(DBName) ->
    get_dataplan(DBName).

-spec plan(kz_term:ne_binary(), atom() | kz_term:ne_binary() | view_options() | kz_json:object()) -> map().
plan(DBName, <<DocType/binary>>) ->
    plan(DBName, DocType, 'undefined');
plan(DBName, Props) when is_list(Props) ->
    Type = props:get_value('doc_type', Props),
    OwnerId = props:get_first_defined(['storage_id', 'doc_owner'], Props),
    lager:info("plan from props db:~s type:~s owner:~s", [DBName, Type, OwnerId]),
    Plan = plan(DBName, Type, OwnerId),
    maybe_override_plan(Plan, props:get_value('plan_override', Props));
plan(DBName, Doc) when ?IS_JSON_GUARD(Doc) ->
    plan(DBName, kz_doc:type(Doc));
plan(DBName, 'undefined')  ->
    plan(DBName);
plan(DBName, DocType)
  when is_atom(DocType) ->
    plan(DBName, kz_term:to_binary(DocType)).

-spec plan(kz_term:ne_binary(), kz_term:api_binary(), kz_term:api_binary()) -> map().
plan(DBName, 'undefined', 'undefined') ->
    get_dataplan(DBName);
plan(DBName, DocType, 'undefined') ->
    get_dataplan(DBName, DocType);
plan(DBName, DocType, DocOwner) ->
    get_dataplan(DBName, DocType, DocOwner).

maybe_override_plan(Plan, 'undefined') -> Plan;
maybe_override_plan(Plan, #{}=Map) ->
    maps:merge(Plan, Map).

get_dataplan(DBName) ->
    Database = kzs_util:to_database(DBName),
    case kzs_util:db_classification(Database) of
        'modb' -> account_modb_dataplan(kzs_util:raw_account_modb(DBName));
        'yodb' -> account_yodb_dataplan(kzs_util:raw_account_yodb(DBName));
        'account' -> account_dataplan(Database);
        'resource_selectors' -> account_dataplan(Database);
        'aggregate' -> aggregate_dataplan(Database);
        'messaging' -> account_modb_dataplan(DBName);
        Else -> system_dataplan(Database, Else)
    end.

-spec get_dataplan(kz_term:ne_binary(), kz_term:api_ne_binary()) -> dataplan().
get_dataplan(DBName, 'undefined') ->
    get_dataplan(DBName);
get_dataplan(DBName, DocType) ->
    Database = kzs_util:to_database(DBName),
    case kzs_util:db_classification(Database) of
        'modb' -> account_modb_dataplan(kzs_util:raw_account_modb(DBName), DocType);
        'yodb' -> account_yodb_dataplan(kzs_util:raw_account_yodb(DBName), DocType);
        'account' -> account_dataplan(Database, DocType);
        'resource_selectors' -> account_dataplan(Database, DocType);
        'aggregate' -> aggregate_dataplan(Database, DocType);
        'messaging' -> account_modb_dataplan(DBName);
        Else -> system_dataplan(Database, Else)
    end.

get_dataplan(DBName, DocType, 'undefined') ->
    get_dataplan(DBName, DocType);
get_dataplan(DBName, DocType, DocOwner) ->
    Database = kzs_util:to_database(DBName),
    case kzs_util:db_classification(Database) of
        'modb' -> account_modb_dataplan(kzs_util:raw_account_modb(DBName), DocType, DocOwner);
        'yodb' -> account_yodb_dataplan(kzs_util:raw_account_yodb(DBName), DocType, DocOwner);
        'account' -> account_dataplan(Database, DocType, DocOwner);
        'resource_selectors' -> account_dataplan(Database, DocType, DocOwner);
        'messaging' -> account_modb_dataplan(DBName);
        Else -> system_dataplan(Database, Else)
    end.

-spec system_dataplan() -> dataplan().
system_dataplan() ->
    #{<<"connections_map">> := Connections} = ?CACHED_SYSTEM_DATAPLAN,
    lager:info("loaded system dataplan: ~p", [Connections]),
    SysTag = ?TAG_LOCAL,
    #{tag => SysTag
     ,server => maps:get(SysTag, Connections, #{})
     ,others => [{Tag, #{server => S}} || {Tag, S} <- maps:to_list(Connections), Tag =/= SysTag]
     }.

system_dataplan(DBName, _Classification)
  when DBName == ?KZ_CONFIG_DB;
       DBName == ?KZ_DATA_DB;
       DBName == ?KZ_SERVICES_DB ->
    SysTag = ?TAG_LOCAL,
    #{tag => SysTag, server => kz_dataconnections:get_server(SysTag)};
system_dataplan(_DBName, 'numbers') ->
    Plan = ?CACHED_SYSTEM_DATAPLAN,
    dataplan_type_match(?SYSTEM_DATAPLAN_ID, <<"numbers">>, Plan);
system_dataplan(DBName, _Classification) ->
    Plan = ?CACHED_SYSTEM_DATAPLAN,
    dataplan_type_match(?SYSTEM_DATAPLAN_ID, DBName, Plan).

account_dataplan(AccountDb) ->
    AccountId = kzs_util:format_account_id(AccountDb),
    Plan = ?CACHED_ACCOUNT_DATAPLAN(AccountId),
    lager:info("account plan: ~p", [Plan]),
    dataplan_match(<<"account">>, Plan, AccountId).

account_dataplan(AccountDb, 'undefined') ->
    account_dataplan(AccountDb);
account_dataplan(AccountDb, DocType) ->
    AccountId = kzs_util:format_account_id(AccountDb),
    Plan = ?CACHED_ACCOUNT_DATAPLAN(AccountId),
    dataplan_type_match(<<"account">>, DocType, Plan, AccountId).

account_dataplan(AccountDb, DocType, 'undefined') ->
    account_dataplan(AccountDb, DocType);
account_dataplan(AccountDb, DocType, StorageId) ->
    AccountId = kzs_util:format_account_id(AccountDb),
    Plan = ?CACHED_STORAGE_DATAPLAN(AccountId, StorageId),
    dataplan_type_match(<<"account">>, DocType, Plan, AccountId).

aggregate_dataplan(DBName) ->
    Plan = ?CACHED_SYSTEM_DATAPLAN,
    case dataplan_match(<<"aggregate">>, Plan, DBName) of
        {'error', 'no_plan'} ->
            system_dataplan(DBName, 'aggregate');
        Dataplan -> Dataplan
    end.

aggregate_dataplan(DBName, DocType) ->
    Plan = ?CACHED_SYSTEM_DATAPLAN,
    case dataplan_type_match(<<"aggregate">>, DocType, Plan, DBName) of
        {'error', 'no_plan'} ->
            system_dataplan(DBName, DocType);
        Dataplan -> Dataplan
    end.

account_modb_dataplan(AccountMODB) ->
    AccountId = kzs_util:format_account_id(AccountMODB),
    Plan = ?CACHED_ACCOUNT_DATAPLAN(AccountId),
    dataplan_match(<<"modb">>, Plan, AccountMODB).

account_modb_dataplan(AccountMODB, 'undefined') ->
    account_modb_dataplan(AccountMODB);
account_modb_dataplan(AccountMODB, DocType) ->
    AccountId = kzs_util:format_account_id(AccountMODB),
    Plan = ?CACHED_ACCOUNT_DATAPLAN(AccountId),
    dataplan_type_match(<<"modb">>, DocType, Plan, AccountMODB).

account_modb_dataplan(AccountMODB, DocType, 'undefined') ->
    account_modb_dataplan(AccountMODB, DocType);
account_modb_dataplan(AccountMODB, DocType, StorageId) ->
    AccountId = kzs_util:format_account_id(AccountMODB),
    Plan = ?CACHED_STORAGE_DATAPLAN(AccountId, StorageId),
    dataplan_type_match(<<"modb">>, DocType, Plan, AccountMODB).

account_yodb_dataplan(AccountYODB) ->
    AccountId = kzs_util:format_account_id(AccountYODB),
    Plan = ?CACHED_ACCOUNT_DATAPLAN(AccountId),
    dataplan_match(<<"yodb">>, Plan, AccountYODB).

account_yodb_dataplan(AccountYODB, 'undefined') ->
    account_yodb_dataplan(AccountYODB);
account_yodb_dataplan(AccountYODB, DocType) ->
    AccountId = kzs_util:format_account_id(AccountYODB),
    Plan = ?CACHED_ACCOUNT_DATAPLAN(AccountId),
    dataplan_type_match(<<"yodb">>, DocType, Plan, AccountYODB).

account_yodb_dataplan(AccountYODB, DocType, 'undefined') ->
    account_yodb_dataplan(AccountYODB, DocType);
account_yodb_dataplan(AccountYODB, DocType, StorageId) ->
    AccountId = kzs_util:format_account_id(AccountYODB),
    Plan = ?CACHED_STORAGE_DATAPLAN(AccountId, StorageId),
    dataplan_type_match(<<"yodb">>, DocType, Plan, AccountYODB).

-spec dataplan_connections(map()) -> [{kz_term:ne_binary(), server()}].
dataplan_connections(#{<<"plan">> := _
                      ,<<"connections">> := Connections
                      }) ->
    dataplan_connections(Connections);
dataplan_connections(Connections) ->
    [maybe_start_connection(Tag, maps:get(Tag, Connections, #{}))
     || {Tag, _} <- maps:to_list(Connections)
    ].

-spec dataplan_match(kz_term:ne_binary(), map(), kz_term:api_binary()) ->
          map() | {'error', 'no_plan'}.
dataplan_match(Classification, #{<<"plan">> := Plans}=Plan, AccountId) ->
    lager:info("matching classification ~s to account ~s", [Classification, AccountId]),
    dataplan_match_by_classification(Classification, Plan, AccountId, maps:get(Classification, Plans, 'undefined')).

-spec dataplan_match_by_classification(kz_term:ne_binary(), map(), kz_term:api_binary(), 'undefined' | map()) ->
          map() | {'error', 'no_plan'}.
dataplan_match_by_classification(_Classification, _Plan, _AccountId, 'undefined') ->
    lager:info("no plan matched"),
    {'error', 'no_plan'};

%% check for specific database names in the plan
dataplan_match_by_classification(Classification, Plan, DBName, #{<<"database">> := #{<<"names">> := [_|_]=DBNames}=DBProperties}=ClassificationPlan) ->
    case lists:member(DBName, DBNames) of
        'false' ->
            lager:info("no dbs in classification plan ~s matched ~s", [Classification, DBName]),
            {'error', 'no_plan'};
        'true' ->
            dataplan_match_by_classification(Classification, Plan, DBName
                                            ,ClassificationPlan#{<<"database">> => maps:remove(<<"names">>, DBProperties)}
                                            )
    end;

%% check if dbname matches a regex
dataplan_match_by_classification(Classification, Plan, DBName, #{<<"regex">> := RegExes}=ClassificationPlan) ->
    case dataplan_regex(Classification, DBName, RegExes) of
        'undefined' ->
            dataplan_match_by_classification(Classification, Plan, DBName, maps:without([<<"regex">>], ClassificationPlan));
        #{} = Map ->
            ToMerge = maps:with([<<"connection">>, <<"attachments">>], ClassificationPlan),
            Merged = maps:without([<<"regex">>], kz_maps:merge(ToMerge, Map)),
            dataplan_match_by_classification(Classification, Plan, DBName, Merged)
    end;

%% check if dbname is within a date range
dataplan_match_by_classification(Classification, Plan, DBName, #{<<"range">> := Ranges}=ClassificationPlan) ->
    case dataplan_range(Classification, db_range_index(DBName), Ranges) of
        'undefined' ->
            dataplan_match_by_classification(Classification, Plan, DBName, maps:without([<<"range">>], ClassificationPlan));
        #{} = Map ->
            ToMerge = maps:with([<<"connection">>, <<"attachments">>], ClassificationPlan),
            Merged = maps:without([<<"range">>], kz_maps:merge(ToMerge, Map)),
            dataplan_match_by_classification(Classification, Plan, DBName, Merged)
    end;

%% check if classification
dataplan_match_by_classification(Classification
                                ,#{<<"connections">> := Connections
                                  ,<<"connections_map">> := ConnectionsMap
                                  ,<<"attachments">> := Attachments
                                  }
                                ,DBName
                                ,#{}=ClassificationPlan
                                ) ->
    AccountId = kzs_util:format_account_id(DBName),
    ClassificationTag = plan_connection(ClassificationPlan),
    ClassificationAttachments = plan_attachments(ClassificationPlan),

    %% list of connection UUIDs configured for this db classification
    ClassificationConns = plan_secondary_conns(ClassificationPlan),

    lager:info("conn map: ~p", [ConnectionsMap]),

    %% [{ConnectionUUID, #{server => {Driver, #server{}}}}]
    SecondaryConnections = [{UUID, #{server => {Driver, Srv}}}
                            || UUID <- ClassificationConns,

                               %% ConnectionsMap = #{{UUID => {kazoo_couch, #server{}}}}
                               {Driver, Srv} <- [maps:get(UUID, ConnectionsMap, 'undefined')]
                           ],
    lager:info("secondary conns for classification ~s: ~p", [Classification, SecondaryConnections]),

    Server = maps:get(ClassificationTag, ConnectionsMap, #{}),

    BasePlan = #{tag => ClassificationTag
                ,server => Server
                ,classification => Classification
                ,account_id => AccountId
                ,secondary => SecondaryConnections
                },

    Plan = case plan_types(ClassificationPlan) of
               'undefined' -> BasePlan;
               DocTypes ->
                   Others = [{ConnectionId, #{server => maps:get(ConnectionId, ConnectionsMap, #{})}}
                             || {_DocType, #{<<"connection">> := ConnectionId}} <- lists:usort(maps:to_list(DocTypes)),
                                ConnectionId =/= ClassificationTag,
                                'undefined' =/= maps:get(ConnectionId, Connections, 'undefined')
                            ],
                   lager:info("adding other conns: ~p", [Others]),
                   BasePlan#{others => Others}
           end,

    case attachment_handler(ClassificationAttachments) of
        'undefined' -> Plan;
        AttachmentConnection ->
            add_attachment_proxy(Plan, Attachments, ClassificationAttachments, AttachmentConnection)
    end.

attachment_handler(#{<<"handler">> := Handler}) -> Handler;
attachment_handler(_Attachments) -> 'undefined'.

add_attachment_proxy(BasePlan, RootAttachments, ClassificationAttachments, AttachmentConnection) ->
    #{AttachmentConnection := #{<<"handler">> := AttachmentHandlerBin
                               ,<<"settings">> := AttachmentSettings
                               }
     } = RootAttachments,
    AttachmentHandler = kz_term:to_atom(<<"kz_att_", AttachmentHandlerBin/binary>>, 'true'),
    Params = maps:merge(AttachmentSettings, maps:get(<<"params">>, ClassificationAttachments, #{})),

    BasePlan#{att_proxy => 'true'
             ,att_post_handler => att_post_handler(ClassificationAttachments)
             ,att_handler => {AttachmentHandler, kz_maps:keys_to_atoms(Params)}
             ,att_handler_id => AttachmentConnection
             }.

-spec dataplan_type_match(kz_term:ne_binary(), kz_term:ne_binary(), map()) ->
          map() | {'error', 'no_plan'}.
dataplan_type_match(Classification, DocType, Plan) ->
    dataplan_type_match(Classification, DocType, Plan, 'undefined').

-spec dataplan_type_match(kz_term:ne_binary(), kz_term:ne_binary(), map(), kz_term:api_binary()) ->
          map() | {'error', 'no_plan'}.
dataplan_type_match(Classification, DocType, #{<<"plan">> := Plans}=Plan, AccountId) ->
    dataplan_type_match_by_classification(Classification, DocType, Plan, AccountId, maps:get(Classification, Plans, 'undefined')).

plan_types(#{<<"types">> := DocTypes}) -> DocTypes;
plan_types(_Plan) -> 'undefined'.

plan_doctype_map(DocType, DocTypes) when is_map(DocTypes) ->
    maps:get(DocType, DocTypes, #{});
plan_doctype_map(_Type, _Types) -> #{}.

-spec plan_connection(map()) -> kz_term:ne_binary().
plan_connection(Plan) ->
    plan_connection(Plan, ?TAG_LOCAL).

-spec plan_connection(map(), Default) -> kz_term:ne_binary() | Default.
plan_connection(#{<<"connection">> := <<Conn/binary>>}, _Default) -> Conn;
plan_connection(_Plan, Default) -> Default.

plan_attachments(Map) -> plan_attachments(Map, 'undefined').

plan_attachments(#{<<"attachments">> := Att}, _Default) -> Att;
plan_attachments(_Plan, Default) -> Default.

plan_secondary_conns(#{<<"secondary_connections">> := Conns}) -> Conns;
plan_secondary_conns(_Plan) -> [].

-spec dataplan_type_match_by_classification(kz_term:ne_binary(), kz_term:ne_binary(), map(), kz_term:api_binary(), map() | 'undefined') ->
          map() | {'error', 'no_plan'}.
dataplan_type_match_by_classification(_Classification, _DocType, _Plan, _AccountId, 'undefined') ->
    {'error', 'no_plan'};

dataplan_type_match_by_classification(Classification, DocType, Plan, DBName, #{<<"database">> := #{<<"names">> := [_|_]=DBNames}=DBProperties}=ClassificationPlan) ->
    case lists:member(DBName, DBNames) of
        'false' ->
            {'error', 'no_plan'};
        'true' ->
            dataplan_type_match_by_classification(Classification, DocType, Plan, DBName
                                                 ,ClassificationPlan#{<<"database">> => maps:remove(<<"names">>, DBProperties)}
                                                 )
    end;

dataplan_type_match_by_classification(Classification, DocType, Plan, DBName, #{<<"regex">> := RegExes}=ClassificationPlan) ->
    case dataplan_regex(Classification, DBName, RegExes) of
        'undefined' ->
            dataplan_type_match_by_classification(Classification, DocType, Plan, DBName, maps:without([<<"regex">>], ClassificationPlan));
        #{} = Map ->
            ToMerge = maps:with([<<"connection">>, <<"attachments">>, <<"types">>], ClassificationPlan),
            Merged = maps:without([<<"regex">>], kz_maps:merge(ToMerge, Map)),
            dataplan_type_match_by_classification(Classification, DocType, Plan, DBName, Merged)
    end;

dataplan_type_match_by_classification(Classification, DocType, Plan, DBName, #{<<"range">> := Ranges}=ClassificationPlan) ->
    case dataplan_range(Classification, db_range_index(DBName), Ranges) of
        'undefined' ->
            dataplan_type_match_by_classification(Classification, DocType, Plan, DBName, maps:without([<<"range">>], ClassificationPlan));
        #{} = Map ->
            ToMerge = maps:with([<<"connection">>, <<"attachments">>, <<"types">>], ClassificationPlan),
            Merged = maps:without([<<"range">>], kz_maps:merge(ToMerge, Map)),
            dataplan_type_match_by_classification(Classification, DocType, Plan, DBName, Merged)
    end;

dataplan_type_match_by_classification(Classification
                                     ,DocType
                                     ,#{<<"connections_map">> := ConnectionsMap
                                       ,<<"attachments">> := Attachments
                                       }=_Plan
                                     ,DBName
                                     ,ClassificationPlan
                                     ) ->
    AccountId = kzs_util:format_account_id(DBName),

    DocTypes = plan_types(ClassificationPlan),
    lager:info("plan types for ~s: ~p", [DocType, DocTypes]),

    ClassificationConnection = plan_connection(ClassificationPlan),
    ClassificationAttachments = plan_attachments(ClassificationPlan, #{}),

    %% list of connection UUIDs configured for this db classification
    ClassificationConns = plan_secondary_conns(ClassificationPlan),

    lager:info("conn map by type:~s(db:~s): ~p", [DocType, DBName, ConnectionsMap]),

    lager:info("UUIDs: ~p", [ClassificationConns]),

    %% [{ConnectionUUID, #{server => {Driver, #server{}}}}]
    SecondaryConnections = [{UUID, #{server => {Driver, Srv}}}
                            || UUID <- ClassificationConns,

                               %% ConnectionsMap = #{{UUID => {kazoo_couch, #server{}}}}
                               {Driver, Srv} <- [maps:get(UUID, ConnectionsMap, 'undefined')]
                           ],
    lager:info("secondary conns for classification ~s type ~s: ~p"
              ,[Classification, DocType, SecondaryConnections]
              ),

    TypeMap = plan_doctype_map(DocType, DocTypes),
    lager:info("type map for ~s: ~p", [DocType, TypeMap]),

    ClassificationTag = plan_connection(TypeMap, ClassificationConnection),
    Server = maps:get(ClassificationTag, ConnectionsMap, #{}),

    TypeAttMap = maps:merge(ClassificationAttachments, plan_attachments(TypeMap, #{})),

    case attachment_handler(TypeAttMap) of
        'undefined' ->
            #{tag => ClassificationTag
             ,server => Server
             ,classification => Classification
             ,doc_type => DocType
             ,account_id => AccountId
             ,secondary => SecondaryConnections
             };
        AttachmentConnection ->
            #{AttachmentConnection := #{<<"handler">> := AttachmentHandlerBin
                                       ,<<"settings">> := AttachmentSettings
                                       }
             } = Attachments,
            AttachmentHandler = kz_term:to_atom(<<"kz_att_", AttachmentHandlerBin/binary>>,'true'),
            Params = maps:merge(AttachmentSettings, maps:get(<<"params">>, TypeAttMap, #{})),
            #{tag => ClassificationTag
             ,server => Server
             ,att_proxy => 'true'
             ,att_post_handler => att_post_handler(TypeAttMap)
             ,att_handler => {AttachmentHandler, kz_maps:keys_to_atoms(Params)}
             ,att_handler_id => AttachmentConnection
             ,classification => Classification
             ,doc_type => DocType
             ,account_id => AccountId
             ,secondary => SecondaryConnections
             }
    end.

-spec att_post_handler(map()) -> 'stub' | 'external'.
att_post_handler(#{<<"stub">> := 'true'}) -> 'stub';
att_post_handler(#{}) -> 'external'.

-type fetch_dataplan_ret() :: kz_json:object() | 'invalid'.

-spec fetch_cached_dataplan(storage_key(), fun()) -> map().
fetch_cached_dataplan({AccountId, _StorageId} = Key, _Fun) ->
    case kz_cache:fetch_local(?KAZOO_DATA_PLAN_CACHE, {'plan', Key}) of
        {'ok', Plan} -> Plan;
        {'error', 'not_found'} -> ?CACHED_ACCOUNT_DATAPLAN(AccountId)
    end;
fetch_cached_dataplan(?SYSTEM_DATAPLAN_ID = Key, Fun) ->
    case kz_cache:fetch_local(?KAZOO_DATA_PLAN_CACHE, {'plan', Key}) of
        {'ok', Plan} -> Plan;
        {'error', 'not_found'} -> load_dataplan(Key, Fun)
    end;
fetch_cached_dataplan(Key, _Fun) ->
    case kz_cache:fetch_local(?KAZOO_DATA_PLAN_CACHE, {'plan', Key}) of
        {'ok', Plan} -> Plan;
        {'error', 'not_found'} -> ?CACHED_SYSTEM_DATAPLAN
    end.

-type storage_key() :: kz_term:ne_binary() | {kz_term:ne_binary(), kz_term:ne_binary()}.

-spec load_dataplan(storage_key(), fun()) -> map() | 'ok'.
load_dataplan(Key, Fun) ->
    case Fun(Key) of
        'invalid' ->
            lager:debug("dataplan key '~p' could not be loaded", [Key]);
        PlanJObj ->
            lager:debug("caching dataplan key '~p'", [Key]),
            cache_dataplan(Key, PlanJObj)
    end.

-spec cache_dataplan(storage_key(), kz_json:object()) -> map().
cache_dataplan(?SYSTEM_DATAPLAN_ID=Key, PlanJObj) ->
    Plan = kz_json:to_map(PlanJObj),
    Connections = dataplan_connections(Plan),
    Plan2 = maps:merge(Plan, #{<<"connections_map">> => maps:from_list(Connections)}),
    CacheProps = [{'expires','infinity'}],
    kz_cache:store_local(?KAZOO_DATA_PLAN_CACHE, {'plan', Key}, Plan2, CacheProps),
    Plan2;
cache_dataplan({_AccountId, StorageId} = Key, PlanJObj) ->
    Plan = kz_json:to_map(PlanJObj),
    Connections = dataplan_connections(Plan),
    Plan2 = maps:merge(Plan, #{<<"connections_map">> => maps:from_list(Connections)}),
    CacheProps = [{'origin', [{'db', ?KZ_DATA_DB, StorageId}]}
                 ,{'expires','infinity'}
                 ,{'callback', fun cache_callback/3}
                 ],
    kz_cache:store_local_async(?KAZOO_DATA_PLAN_CACHE, {'plan', Key}, Plan2, CacheProps),
    Plan2;
cache_dataplan(Key, PlanJObj) ->
    Plan = kz_json:to_map(PlanJObj),
    Connections = dataplan_connections(Plan),
    Plan2 = maps:merge(Plan, #{<<"connections_map">> => maps:from_list(Connections)}),
    CacheProps = [{'origin', [{'db', ?KZ_DATA_DB, Key}]}
                 ,{'expires','infinity'}
                 ,{'callback', fun cache_callback/3}
                 ],
    kz_cache:store_local_async(?KAZOO_DATA_PLAN_CACHE, {'plan', Key}, Plan2, CacheProps),
    Plan2.

-spec cache_callback({'plan', kz_term:ne_binary()} | 'system', map(), atom()) -> 'ok'.
cache_callback('system', _V, 'erase') ->
    lager:warning("received dataplan cache update for system plan document"),
    reload();
%% cache_callback({'plan', ?SYSTEM_DATAPLAN_ID}, _V, 'erase') ->
%%     lager:warning("received dataplan cache update for system plan"),
%%     reload();
cache_callback({'plan', {AccountId, StorageId}}, _V, _Type) ->
    lager:warning("received dataplan cache '~s' for account ~s/~s", [_Type, AccountId, StorageId]),
    _ = load_dataplan({AccountId, StorageId}, fun fetch_storage_dataplan/1),
    'ok';
cache_callback({'plan', AccountId}, _V, _Type) ->
    lager:warning("received dataplan cache '~s' for account ~s", [_Type, AccountId]),
    load_account(AccountId);
cache_callback('system', _V, 'flush') ->
    lager:warning("received dataplan cache update for system plan document"),
    reload();
%% cache_callback({'plan', ?SYSTEM_DATAPLAN_ID}, _V, 'flush') ->
%%     lager:warning("received flush dataplan cache for system plan"),
%%     reload();
cache_callback(_Key, _V, _Action) ->
    lager:warning("unhandled cache callback : ~p , ~p , ~p", [_Key, _V, _Action]).

-spec fetch_simple_dataplan(kz_term:ne_binary()) -> fetch_dataplan_ret().
fetch_simple_dataplan(?SYSTEM_DATAPLAN_ID) ->
    fetch_system_dataplan();
fetch_simple_dataplan(Id) ->
    fetch_dataplan(Id).

-spec cache_system_dataplan() -> kz_json:object().
cache_system_dataplan() ->
    JObj = load_system_dataplan(),
    CacheProps = [{'origin', [{'db', ?KZ_DATA_DB, ?SYSTEM_DATAPLAN_ID}]}
                 ,{'expires', 'infinity'}
                 ,{'callback', fun cache_callback/3}
                 ],
    kz_cache:store_local(?KAZOO_DATA_PLAN_CACHE, 'system', JObj, CacheProps),
    JObj.

-spec fetch_system_dataplan() -> fetch_dataplan_ret().
fetch_system_dataplan() ->
    case kz_cache:fetch_local(?KAZOO_DATA_PLAN_CACHE, 'system') of
        {'ok', JObj} -> JObj;
        {'error', 'not_found'} -> cache_system_dataplan()
    end.

-spec load_system_dataplan() -> fetch_dataplan_ret().
load_system_dataplan() ->
    case fetch_dataplan(?SYSTEM_DATAPLAN_ID) of
        'undefined' -> default_dataplan();
        JObj -> default_dataplan(JObj)
    end.

-spec fetch_account_dataplan(storage_key()) -> fetch_dataplan_ret().
fetch_account_dataplan(AccountId) ->
    case fetch_dataplan(AccountId) of
        'undefined' -> 'invalid';
        JObj -> fetch_account_dataplan_merged(JObj)
    end.

-spec fetch_account_dataplan_merged(kz_json:object()) -> fetch_dataplan_ret().
fetch_account_dataplan_merged(AccountJObj) ->
    SystemJObj = fetch_system_dataplan(),
    case kz_json:get_ne_binary_value(<<"pvt_plan_id">>, AccountJObj) of
        'undefined' ->
            kz_json:merge_recursive(SystemJObj, AccountJObj);
        PlanId ->
            account_dataplan_merged(SystemJObj, fetch_dataplan(PlanId), AccountJObj)
    end.

-spec account_dataplan_merged(kz_json:object(), kz_term:api_object(), kz_json:object()) -> kz_json:object().
account_dataplan_merged(SystemJObj, 'undefined', AccountJObj) ->
    kz_json:merge_recursive(SystemJObj, AccountJObj);
account_dataplan_merged(SystemJObj, Dataplan, AccountJObj) ->
    kz_json:merge_recursive([SystemJObj, Dataplan, AccountJObj]).

-spec fetch_storage_dataplan(storage_key()) -> fetch_dataplan_ret().
fetch_storage_dataplan({AccountId, StorageId}) ->
    case fetch_dataplan(StorageId) of
        'undefined' -> 'invalid';
        StoragePlan -> fetch_storage_dataplan_merged(AccountId, StoragePlan)
    end.

-spec fetch_storage_dataplan_merged(kz_term:ne_binary(), kz_json:object()) -> fetch_dataplan_ret().
fetch_storage_dataplan_merged(AccountId, StoragePlan) ->
    AccountPlan = case fetch_account_dataplan(AccountId) of
                      'invalid' -> fetch_system_dataplan();
                      P -> P
                  end,
    kz_json:merge_recursive(AccountPlan, StoragePlan).

-spec fetch_dataplan(storage_key()) -> kz_term:api_object().
fetch_dataplan(Id) ->
    case kz_datamgr:open_doc(?KZ_DATA_DB, Id) of
        {'ok', JObj} -> JObj;
        {'error', _ERR} -> 'undefined'
    end.

-spec fetch_dataplan_from_file(kz_term:ne_binary()) -> kz_json:object().
fetch_dataplan_from_file(Id) ->
    lager:info("~p: loading from ~p/~p", [self(), ?DATAPLAN_FILE_LOCATION, [Id, ".json"]]),
    kz_json:load_fixture_from_file(?APP, ?DATAPLAN_FILE_LOCATION, [Id, ".json"]).

-spec default_dataplan() -> kz_json:object().
default_dataplan() ->
    default_dataplan(kz_json:new()).

-spec default_dataplan(kz_json:object()) -> kz_json:object().
default_dataplan(JObj) ->
    DefaultJObj = fetch_dataplan_from_file(?SYSTEM_DATAPLAN_ID),
    SystemJObj = kz_json:merge_recursive(DefaultJObj, JObj),
    'ok' = kzs_cache:add_to_doc_cache(?KZ_DATA_DB, ?SYSTEM_DATAPLAN_ID, SystemJObj),
    SystemJObj.

-spec maybe_start_connection(kz_term:ne_binary(), map()) -> {kz_term:ne_binary(), server()}.
maybe_start_connection(Tag, Params) ->
    case kz_dataconnections:get_server(Tag) of
        'undefined' -> start_connection(Tag, Params);
        Server -> {Tag, Server}
    end.

-spec start_connection(kz_term:ne_binary(), map()) -> {kz_term:ne_binary(), server()}.
start_connection(Tag, Params) ->
    Connection = kz_dataconfig:connection(kz_maps:keys_to_atoms(Params#{tag => Tag})),
    kz_dataconnections:add(Connection),
    case kz_dataconnections:wait_for_connection(Tag, ?NEW_CONNECTION_TIMEOUT) of
        'no_connection' ->
            lager:critical("connection ~s unavailable, check for connection errors", [Tag]),
            {Tag, {'kazoo_dataconnection_error', #{}}};
        'ok' -> {Tag, kz_dataconnections:get_server(Tag)}
    end.

-spec init() -> 'ok'.
init() ->
    lager:debug("initializing plans"),
    kazoo_bindings:flush_mod(?MODULE),
    reload(),
    bind().

-spec onload() -> 'ok'.
onload() ->
    onload(persistent_term:get('kz_datamgr_bootstrap', 'false')).

-spec onload(boolean()) -> 'ok'.
onload('false') -> 'ok';
onload('true') ->
    _P = kz_process:spawn(fun init/0),
    lager:debug("module ~s reloaded", [?MODULE_STRING]).

-spec bind() -> 'ok'.
-ifdef(TEST).
bind() -> 'ok'.
-else.
bind() ->
    Bindings = [{<<"doc_created">>, fun handle_created/1}
               ,{<<"doc_deleted">>, fun handle_deleted/1}
               ],
    lists:foreach(fun bind_for/1, Bindings).

bind_for({Type, Fun}) ->
    RK = kz_binary:join([<<"kapi.conf">>
                        ,kz_term:to_binary(?KAZOO_DATA_PLAN_CACHE)
                        ,?KZ_DATA_DB
                        ,<<"storage">>
                        ,Type
                        ,<<"*">>
                        ]
                       ,<<".">>
                       ),
    lager:debug("binding for storage doc events: ~s", [RK]),
    kazoo_bindings:bind(RK, ?MODULE, Fun).

-spec handle_created(kz_term:api_ne_binary() | kz_json:object() | kz_json:objects()) -> 'ok'.
handle_created('undefined') -> 'ok';
handle_created(<<Id/binary>>) ->
    lager:warning("received new storage '~s'", [Id]),
    case kz_datamgr:open_doc(?KZ_DATA_DB, Id) of
        {'ok', Doc} -> load_account_or_storage(kz_doc:account_id(Doc), Id);
        {'error', _ERR} -> lager:error("error fetching storage doc '~s'", [Id])
    end;
handle_created([JObj]) ->
    handle_created(JObj);
handle_created(JObj) ->
    case kz_doc:type(JObj) of
        <<"storage">> -> load_account_or_storage(kz_doc:account_id(JObj), kz_doc:id(JObj));
        _Type -> handle_created(kz_json:get_ne_binary_value(<<"ID">>, JObj))
    end.

-spec load_account_or_storage(kz_term:api_ne_binary(), kz_term:ne_binary()) -> 'ok'.
load_account_or_storage(AccountId, AccountId) ->
    load_account(AccountId);
load_account_or_storage(AccountId, StorageId) ->
    load_storage(AccountId, StorageId).

-spec handle_deleted(kz_term:api_ne_binary() | kz_json:object() | kz_json:objects()) -> 'ok'.
handle_deleted('undefined') -> 'ok';
handle_deleted(<<Id/binary>>) ->
    kz_cache:erase_local(?KAZOO_DATA_PLAN_CACHE, {'plan', Id});
handle_deleted([JObj]) ->
    handle_deleted(JObj);
handle_deleted(JObj) ->
    case kz_doc:type(JObj) of
        <<"storage">> -> handle_deleted(kz_doc:id(JObj));
        _Type -> handle_deleted(kz_json:get_ne_binary_value(<<"ID">>, JObj))
    end.

-endif.

-spec flush() -> 'ok'.
flush() ->
    kz_cache:flush_local(?KAZOO_DATA_PLAN_CACHE).

-spec reload() -> 'ok'.
reload() ->
    _ = load_dataplan(?SYSTEM_DATAPLAN_ID, fun fetch_simple_dataplan/1),
    case kz_datamgr:get_result_ids(?KZ_DATA_DB, ?KZS_PLAN_INIT_VIEW, []) of
        {'ok', []} -> lager:info("no account dataplans to load");
        {'ok', Accounts} -> load_accounts(Accounts);
        Error -> lager:error("error reloading account dataplans ~p", [Error])
    end.

-spec reset_system_dataplan() -> 'ok'.
reset_system_dataplan() ->
    _D =  kz_datamgr:del_doc(?KZ_DATA_DB, ?SYSTEM_DATAPLAN_ID),
    reload().

-spec reload(kz_term:ne_binary()) -> 'ok'.
reload(AccountId) ->
    case kz_cache:peek_local(?KAZOO_DATA_PLAN_CACHE, {'plan', AccountId}) of
        {'ok', _Plan} -> kz_cache:erase_local(?KAZOO_DATA_PLAN_CACHE, {'plan', AccountId});
        _Else -> load_account(AccountId)
    end.

-spec reload(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
reload(AccountId, StorageId) ->
    case kz_cache:peek_local(?KAZOO_DATA_PLAN_CACHE, {'plan', {AccountId, StorageId}}) of
        {'ok', _Plan} -> kz_cache:erase_local(?KAZOO_DATA_PLAN_CACHE, {'plan', {AccountId, StorageId}});
        _Else -> load_storage(AccountId, StorageId)
    end.

-spec load_accounts(kz_term:ne_binaries()) -> 'ok'.
load_accounts(Accounts)
  when length(Accounts) > ?KZS_PLAN_INIT_SLICE ->
    {A, B} = lists:split(?KZS_PLAN_INIT_SLICE, Accounts),
    _ = kz_process:spawn(fun load_accounts/1, [B]),
    load_accounts(A);
load_accounts(Accounts) ->
    lists:foreach(fun load_account/1, Accounts).

-spec load_account(kz_term:ne_binary()) -> 'ok'.
load_account(AccountId) ->
    _ = load_dataplan(AccountId, fun fetch_account_dataplan/1),
    load_account_storage(AccountId).

-spec load_account_storage(kz_term:ne_binary()) -> 'ok'.
load_account_storage(AccountId) ->
    case kz_datamgr:get_result_ids(?KZ_DATA_DB, ?KZS_PLAN_ACCOUNT_VIEW, [{'key', AccountId}]) of
        {'ok', []} -> 'ok';
        {'ok', StorageIds} -> load_account_storage(AccountId, StorageIds);
        Error -> lager:error("error reloading account ~s dataplan: ~p", [AccountId, Error])
    end.

-spec load_account_storage(kz_term:ne_binary(), kz_term:ne_binaries()) -> 'ok'.
load_account_storage(AccountId, StorageIds) ->
    lists:foreach(fun(StorageId) -> load_storage(AccountId, StorageId) end, StorageIds).

-spec load_storage(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
load_storage('undefined', ?SYSTEM_DATAPLAN_ID) ->
    load_dataplan(?SYSTEM_DATAPLAN_ID, fun fetch_simple_dataplan/1);
load_storage(AccountId, StorageId) ->
    _ = load_dataplan({AccountId, StorageId}, fun fetch_storage_dataplan/1),
    'ok'.

dataplan_regex(_Classification, _DBName, 'none') -> 'undefined';
dataplan_regex(_Classification, _DBName, Regexes)
  when is_map(Regexes), map_size(Regexes) =:= 0 -> 'undefined';
dataplan_regex(Classification, DBName, Regexes)
  when is_map(Regexes) ->
    dataplan_regex(Classification, DBName, maps:next(maps:iterator(Regexes)));
dataplan_regex(Classification, DBName, {Regex, Map, Iterator}) ->
    case re:run(DBName, Regex) of
        'nomatch' -> dataplan_regex(Classification, DBName, maps:next(Iterator));
        _Match -> Map
    end.

dataplan_range(_Classification, 0, _Range) -> 'undefined';
dataplan_range(_Classification, _DBRangeIndex, 'none') -> 'undefined';
dataplan_range(_Classification, _DBRangeIndex, Ranges)
  when is_map(Ranges), map_size(Ranges) =:= 0 -> 'undefined';
dataplan_range(Classification, DBRangeIndex, Ranges)
  when is_map(Ranges) ->
    dataplan_range(Classification, DBRangeIndex, maps:next(maps:iterator(Ranges)));
dataplan_range(Classification, DBRangeIndex, {<<Lower:6/binary, "-", Upper:6/binary>>, #{} = Map, Iterator}) ->
    case DBRangeIndex >= kz_term:to_integer(Lower)
        andalso DBRangeIndex =< kz_term:to_integer(Upper)
    of
        'false' -> dataplan_range(Classification, DBRangeIndex, maps:next(Iterator));
        'true' -> Map
    end;
dataplan_range(Classification, DBRangeIndex, {_Key, _Map, Iterator}) ->
    dataplan_range(Classification, DBRangeIndex, maps:next(Iterator)).

db_range_index(?MATCH_MODB_SUFFIX_RAW(_Account, Year, Month)) ->
    kz_term:to_integer(list_to_binary([Year, Month]));
db_range_index(?MATCH_MODB_SUFFIX_UNENCODED(_Account, Year, Month)) ->
    kz_term:to_integer(list_to_binary([Year, Month]));
db_range_index(?MATCH_MODB_SUFFIX_ENCODED(_Account, Year, Month)) ->
    kz_term:to_integer(list_to_binary([Year, Month]));
db_range_index(_) -> 0.
