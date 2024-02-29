%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2024, 2600Hz
%%% @doc Configuration updates (like DB doc changes) can be communicated across
%%% the AMQP bus so WhApps can flush cache entries, update settings, etc.
%%%
%%%
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_conf).

-export([api_definitions/0, api_definition/1]).

-export([doc_update/1
        ,doc_update_v/1
        ,publish_doc_update/5
        ,publish_doc_update/6
        ]).

-export([bind_q/2, unbind_q/2
        ,declare_exchanges/0

        ,publish_db_update/3, publish_db_update/4

        ,get_database/1
        ,get_account_id/1, get_account_db/1
        ,get_type/1, get_doc/1, get_id/1, get_rev/1
        ,get_action/1, get_is_soft_deleted/1
        ,get_routing_keys/1, get_routing_keys/2
        ]).

-type action() :: 'created' | 'edited' | 'deleted'.
-type action_binary() :: kz_term:ne_binary().
-type doc() :: kz_json:object().
%% {Action, Db, Type, Id}
-type doc_update_props() :: {action_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()}.
-export_type([action/0
             ,action_binary/0
             ,doc/0
             ]).

-include_lib("kz_amqp_util.hrl").
-include_lib("kazoo_amqp/include/kapi_conf.hrl").

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [doc_update_definition()].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(<<"doc_update">>) ->
    doc_update_definition().

-spec doc_update_definition() -> kapi_definition:api().
doc_update_definition() ->
    EventName = <<"doc_update">>,
    Category = ?KAPI_CONF_CATEGORY,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Document Change">>}
              ,{fun kapi_definition:set_description/2
               ,<<"Format a call event from the switch for the listener">>
               }
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun doc_update/1}
              ,{fun kapi_definition:set_validate_fun/2, fun doc_update_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_doc_update/5}
              ,{fun kapi_definition:set_required_headers/2, [<<"ID">>
                                                            ,<<"Database">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Account-ID">>
                                                            ,<<"Date-Created">>
                                                            ,<<"Date-Modified">>
                                                            ,<<"Doc">>
                                                            ,<<"Is-Soft-Deleted">>
                                                            ,<<"Rev">>
                                                            ,<<"Type">>
                                                            ,<<"Version">>
                                                            ,<<"Origin-Cache">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category
                                                  ,[?DOC_EDITED
                                                   ,?DOC_CREATED
                                                   ,?DOC_DELETED
                                                   ,?DB_EDITED
                                                   ,?DB_CREATED
                                                   ,?DB_DELETED
                                                   ]
                                                  )
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"ID">>, fun is_binary/1}
                ,{<<"Rev">>, fun is_binary/1}
                ,{<<"Is-Soft-Deleted">>, fun kz_term:is_boolean/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec get_account_id(kz_term:api_terms()) -> kz_term:api_binary().
get_account_id(API) ->
    get_value(API, <<"Account-ID">>).

-spec get_action(kz_term:api_terms()) -> kz_term:api_binary().
get_action(API) ->
    get_value(API, <<"Action">>).

-spec get_account_db(kz_term:api_terms()) -> kz_term:api_binary().
get_account_db(API) ->
    get_value(API, <<"Account-DB">>).

-spec get_database(kz_term:api_terms()) -> kz_term:ne_binary().
get_database(API) ->
    get_value(API, <<"Database">>).

%% returns the public fields of the document
-spec get_doc(kz_term:api_terms()) -> kz_term:api_object().
get_doc(API) ->
    get_value(API, <<"Doc">>).

-spec get_id(kz_term:api_terms()) -> kz_term:api_binary().
get_id(API) ->
    get_value(API, <<"ID">>).

-spec get_rev(kz_term:api_terms()) -> kz_term:api_ne_binary().
get_rev(API) ->
    get_value(API, <<"Rev">>).

%% returns the pvt_type field
-spec get_type(kz_term:api_terms()) -> kz_term:api_binary().
get_type(API) ->
    get_value(API, <<"Type">>).

-spec get_is_soft_deleted(kz_term:api_terms()) -> boolean().
get_is_soft_deleted(API) ->
    kz_term:is_true(get_value(API, <<"Is-Soft-Deleted">>)).

-spec get_value(kz_term:api_terms(), kz_term:ne_binary()) -> any().
get_value(Prop, Key) when is_list(Prop) ->
    props:get_value(Key, Prop);
get_value(JObj, Key) ->
    kz_json:get_value(Key, JObj).

%%------------------------------------------------------------------------------
%% @doc Format a call event from the switch for the listener.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec doc_update(kz_term:api_terms()) -> kz_api:api_formatter_return().
doc_update(Req) ->
    kapi_definition:build_message(Req, doc_update_definition()).

-spec doc_update_v(kz_term:api_terms()) -> boolean().
doc_update_v(Req) ->
    kapi_definition:validate(Req, doc_update_definition()).

-spec publish_doc_update(action(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_doc_update(Action, Db, Type, Id, JObj) ->
    publish_doc_update(Action, Db, Type, Id, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_doc_update(action(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_doc_update(Action, Db, Type, Id, Change, ContentType) ->
    Definition = doc_update_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Change
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:document_change_publish(Action, Db, Type, Id, Payload, ContentType).

-spec bind_q(binary(), kz_term:proplist()) -> 'ok'.
bind_q(Q, Props) ->
    RestrictTo = props:get_value('restrict_to', Props, ['doc_updates']),
    bind_q(Q, Props, RestrictTo, props:is_true('pooled', Props, 'false')).

-spec bind_q(binary(), kz_term:proplist(), kz_term:api_atoms(), boolean()) -> 'ok'.
bind_q(Q, Props, RestrictTo, 'false') ->
    bind_q(Q, Props, RestrictTo);
bind_q(Q, Props, RestrictTo, 'true') ->
    case lists:all(fun is_pooled_event_filter/1, RestrictTo) of
        'true' ->
            bind_q(Q, Props, RestrictTo);
        'false' ->
            lager:error("using the pooled flag with a mix of pooled and "
                        "non-pooled event filters is not allowed"
                       ),
            throw({'error', 'badarg'})
    end.

-spec bind_q(binary(), kz_term:proplist(), kz_term:atoms()) -> 'ok'.
bind_q(Q, Props, ['doc_updates'|Restrict]) ->
    bind_for_doc_changes(Q, Props),
    bind_q(Q, Props, Restrict);
bind_q(Q, Props, [_|Restrict]) ->
    bind_q(Q, Props, Restrict);
bind_q(_Q, _Props, []) -> 'ok'.

-spec bind_for_doc_changes(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_for_doc_changes(Q, Props) ->
    bind_for_doc_changes(Q
                        ,Props
                        ,props:get_value('pooled', Props, 'false')
                        ,props:get_value('keys', Props)
                        ).

-spec bind_for_doc_changes(kz_term:ne_binary(), kz_term:proplist(), boolean(), kz_term:api_proplist()) -> 'ok'.
bind_for_doc_changes(_Q, Props, 'true', 'undefined') ->
    bind_for_doc_changes_pooled(Props);
bind_for_doc_changes(_Q, _Props, 'true', Keys) ->
    _ = [bind_for_doc_changes_pooled(KeyProps) || KeyProps <- Keys],
    'ok';
bind_for_doc_changes(Q, Props, 'false', 'undefined') ->
    bind_for_doc_changes_non_pooled(Q, Props);
bind_for_doc_changes(Q, _Props, 'false', Keys) ->
    _ = [bind_for_doc_changes_non_pooled(Q, KeyProps) || KeyProps <- Keys],
    'ok'.

-spec bind_for_doc_changes_pooled(kz_term:proplist()) -> 'ok'.
bind_for_doc_changes_pooled(Props) ->
    _ = [kz_events:bind_conf_changes(Action, Db, DocType, DocId)
         || {Action, Db, DocType, DocId} <- doc_update_props(Props)
        ],
    'ok'.

-spec bind_for_doc_changes_non_pooled(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_for_doc_changes_non_pooled(Q, Props) ->
    _ = [kz_amqp_util:bind_q_to_configuration(Q, RKs)
         || RKs <- get_routing_keys(Props)
        ],
    'ok'.

-spec unbind_q(binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Q, Props) ->
    unbind_q(Q, Props, props:get_value('restrict_to', Props, ['doc_updates'])).

-spec unbind_q(binary(), kz_term:proplist(), kz_term:atoms()) -> 'ok'.
unbind_q(Q, Props, ['doc_updates'|Restrict]) ->
    unbind_for_doc_changes(Q, Props),
    unbind_q(Q, Props, Restrict);
unbind_q(Q, Props, [_|Restrict]) ->
    unbind_q(Q, Props, Restrict);
unbind_q(_Q, _Props, []) -> 'ok'.

-spec unbind_for_doc_changes(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_for_doc_changes(Q, Props) ->
    unbind_for_doc_changes(Q
                          ,Props
                          ,props:get_value('pooled', Props, 'false')
                          ,props:get_value('keys', Props)
                          ).

-spec unbind_for_doc_changes(kz_term:ne_binary(), kz_term:proplist(), boolean(), kz_term:api_proplist()) -> 'ok'.
unbind_for_doc_changes(_Q, Props, 'true', 'undefined') ->
    unbind_for_doc_changes_pooled(Props);
unbind_for_doc_changes(_Q, _Props, 'true', Keys) ->
    _ = [unbind_for_doc_changes_pooled(KeyProps) || KeyProps <- Keys],
    'ok';
unbind_for_doc_changes(Q, Props, 'false', 'undefined') ->
    unbind_for_doc_changes_non_pooled(Q, Props);
unbind_for_doc_changes(Q, _Props, 'false', Keys) ->
    _ = [unbind_for_doc_changes_non_pooled(Q, KeyProps) || KeyProps <- Keys],
    'ok'.

-spec unbind_for_doc_changes_pooled(kz_term:proplist()) -> 'ok'.
unbind_for_doc_changes_pooled(Props) ->
    _ = [kz_events:unbind_conf_changes(Action, Db, DocType, DocId)
         || {Action, Db, DocType, DocId} <- doc_update_props(Props)
        ],
    'ok'.

-spec unbind_for_doc_changes_non_pooled(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_for_doc_changes_non_pooled(Q, Props) ->
    _ = [kz_amqp_util:unbind_q_from_configuration(Q, RKs)
         || RKs <- get_routing_keys(Props)
        ],
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:configuration_exchange().

-spec get_routing_keys(kz_term:proplist()) -> kz_term:ne_binaries().
get_routing_keys(Props) ->
    get_routing_keys(Props, 'true').

%%------------------------------------------------------------------------------
%% @doc Create routing keys
%%
%% Set second arg to 'false' to get the 4-segment routing key for the local
%% bindings server
%% @end
%%------------------------------------------------------------------------------
-spec get_routing_keys(kz_term:proplist(), boolean()) -> kz_term:ne_binaries().
get_routing_keys(Props, IsAMQPBinding) ->
    [get_routing_key(DocUpdateProps, IsAMQPBinding) || DocUpdateProps <- doc_update_props(Props)].

-spec get_routing_key(doc_update_props(), boolean()) -> kz_term:ne_binary().
get_routing_key({Action, Db, Type, Id}, IsAMQPBinding) ->
    case kz_amqp_util:document_routing_key(Action, Db, Type, Id) of
        <<"*.*.*.*">> when IsAMQPBinding -> <<"#">>;
        RK -> RK
    end.

%%------------------------------------------------------------------------------
%% @doc Get/normalize the props used for routing a doc update event.
%% @end
%%------------------------------------------------------------------------------
-spec doc_update_props(kz_term:proplist()) -> [doc_update_props()].
doc_update_props(Props) ->
    case props:get_value('types', Props) of
        'undefined' ->
            Type = props:get_binary_value(
                     'doc_type', Props, props:get_value('type', Props, <<"*">>)
                    ),
            [doc_update_props(Props, Type)];
        Types ->
            [doc_update_props(Props, Type) || Type <- Types]
    end.

-spec doc_update_props(kz_term:proplist(), kz_term:ne_binary()) -> doc_update_props().
doc_update_props(Props, Type) ->
    kz_amqp_util:document_routing_props(
      props:get_binary_value('action', Props, <<"*">>)
     ,props:get_binary_value('db', Props, <<"*">>)
     ,Type
     ,props:get_binary_value('doc_id', Props, props:get_value('id', Props, <<"*">>))
     ).

-spec publish_db_update(action(), kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_db_update(Action, Db, JObj) ->
    publish_db_update(Action, Db, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_db_update(action(), kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_db_update(Action, Db, Change, ContentType) ->
    Definition = doc_update_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Change
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:document_change_publish(Action, Db, <<"database">>, Db, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Check if an event is supported for pooled bindings.
%% @end
%%------------------------------------------------------------------------------
-spec is_pooled_event_filter(atom()) -> boolean().
is_pooled_event_filter('doc_updates') -> 'true';
is_pooled_event_filter(_Event) -> 'false'.
