%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc Crossbar listings view accessors.
%%%
%%% Here is a list mapping the old view name to the new name:
%%%
%%% * apps_store/crossbar_listing --> crossbar_listings/by_type_name
%%% * attributes/endpoints_lookup --> crossbar_listings/endpoints_lookup
%%% * attributes/groups --> crossbar_listings/by_type_id
%%% * attributes/hotdesk_id --> crossbar_listings/by_type_id
%%% * attributes/hotdesk_users --> crossbar_listings/by_type_ownerid
%%% * attributes/mailbox_number --> crossbar_listings/by_type_number
%%% * attributes/owned --> crossbar_listings/by_ownerid_type
%%% * attributes/owner --> crossbar_listings/owners_by_docid_type
%%% * attributes/sip_username --> crossbar_listings/by_sip_usernames
%%% * attributes/temporal_rules --> crossbar_listings/by_type_id
%%% * auth/providers_by_type --> crossbar_listings/auth_providers_type
%%% * blacklists/crossbar_listing --> crossbar_listings/by_type_id
%%% * callflows/crossbar_listing --> crossbar_listings/by_type_id
%%% * callflows/listing_by_number --> crossbar_listings/by_type_number
%%% * callflows/listing_by_pattern --> crossbar_listings/flow_patterns
%%% * callflows/msisdn --> crossbar_listings/flow_msisdn
%%% * click2call/crossbar_listing --> crossbar_listings/by_type_id
%%% * conference/listing_by_number --> crossbar_listings/by_type_number
%%% * conferences/crossbar_listing --> crossbar_listings/by_type_id
%%% * contact_list/excluded --> crossbar_listings/contact_list_excluded
%%% * contact_list/extensions --> crossbar_listings/contact_list_extensions
%%% * contact_list/names --> crossbar_listings/contact_list_names
%%% * devices/crossbar_listing --> crossbar_listings/by_type_id
%%% * devices/listing_by_macaddress --> crossbar_listings/device_mac_addresses
%%% * devices/listing_by_owner --> crossbar_listings/by_type_ownerid
%%% * devices/listing_by_presence_id --> crossbar_listings/device_presence_ids
%%% * devices/sip_credentials --> crossbar_listings/by_sip_credentials
%%% * directories/crossbar_listing --> crossbar_listings/by_type_id
%%% * directories/users_listing --> crossbar_listings/owners_by_docid_type
%%% * faxbox/crossbar_listing --> crossbar_listings/by_type_id
%%% * faxbox/email_permissions --> crossbar_listings/faxbox_email_permissions
%%% * faxbox/list_by_ownerid --> crossbar_listings/by_type_ownerid
%%% * groups/crossbar_listing --> crossbar_listings/by_type_id
%%% * groups/crossbar_listing_by_user --> crossbar_listings/by_type_ownerid
%%% * hotdesks/crossbar_listing --> crossbar_listings/by_type_ownerid
%%% * lists/crossbar_listing --> crossbar_listings/by_type_id
%%% * lists/entries --> crossbar_listings/list_entries
%%% * lists/match_prefix_in_list --> crossbar_listings/list_prefixes
%%% * lists/regexps_in_list --> crossbar_listings/list_patterns
%%% * menus/crossbar_listing --> crossbar_listings/by_type_id
%%% * message/crossbar_listing --> crossbar_listings/by_type_id
%%% * message/listing_by_number --> crossbar_listings/by_type_number
%%% * message/listing_by_pattern --> crossbar_listings/flow_patterns
%%% * message/msisdn --> crossbar_listings/flow_msisdn
%%% * metaflows/crossbar_listing --> crossbar_listings/by_type_id
%%% * mobile/listing_by_mdn --> crossbar_listings/mobile_mdns
%%% * notifications/crossbar_listing --> crossbar_listings/by_type_name
%%% * parking/parked_call --> crossbar_listings/by_type_id
%%% * parking/parked_calls --> crossbar_listings/by_type_id
%%% * phone_numbers/crossbar_listing --> crossbar_listings/by_type_id
%%% * rate_limits/crossbar_listing --> crossbar_listings/rate_limits
%%% * rate_limits/list_by_owner --> crossbar_listings/by_type_ownerid
%%% * resources/crossbar_listing --> crossbar_listings/by_type_id
%%% * resources/listing_by_id --> crossbar_listings/by_type_id
%%% * resources/resource_templates --> crossbar_listings/by_type_id
%%% * service_plans/crossbar_listing --> crossbar_listings/by_type_id
%%% * temporal_rules_sets/crossbar_listing --> crossbar_listings/by_type_id
%%% * temporal_rules/crossbar_listing --> crossbar_listings/by_type_id
%%% * trunkstore/crossbar_listing --> crossbar_listings/by_type_id
%%% * trunkstore/lookup_did --> crossbar_listings/by_type_number
%%% * users/creds_by_md5 --> crossbar_listings/user_creds_md5
%%% * users/creds_by_sha --> crossbar_listings/user_creds_sha1
%%% * users/crossbar_listing --> crossbar_listings/by_type_name
%%% * users/list_by_email --> crossbar_listings/user_emails
%%% * users/list_by_hotdesk_id --> crossbar_listings/by_type_id
%%% * users/list_by_id --> crossbar_listings/by_type_id
%%% * users/list_by_username --> crossbar_listings/user_usernames
%%% * vmboxes/crossbar_listing --> crossbar_listings/by_type_name
%%% * vmboxes/listing_by_mailbox --> crossbar_listings/by_type_number
%%%
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzc_account_crossbar_listings).

-export([metadata/0, metadata/1, metadata/2
        ,has_view/1
        ]).

-include("../kz_couch.hrl").

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec has_view(kz_term:ne_binary()) -> boolean().
has_view(View) -> lists:member(View, metadata('views')).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec metadata(any()) -> any().
metadata('views') ->
    maps:keys(metadata()).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec metadata('options' | 'query_fields', kz_term:ne_binary()) -> any().
metadata('build_key_fun', View) ->
    %% Function to build custom range key
    %% see {@link kz_couch_view:build_key_fun()} type
    maps:get('build_key_fun', maps:get(View, metadata()), 'undefined');
metadata('databases_fun', View) ->
    %% Function to build databases
    %% see {@link kz_couch_view:databases_fun()} type
    maps:get('databases_fun', maps:get(View, metadata()), 'undefined');
metadata('options', View) ->
    %% A list of options to merge with user's options
    maps:get('options', maps:get(View, metadata()), []);
metadata('query_fields', View) ->
    %% A list of queryable fields
    maps:get('query_fields', maps:get(View, metadata())).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec metadata() -> map().
metadata() ->
    #{<<"auth_providers_type">> =>
          #{'query_fields' => [<<"provider_type">>, <<"doc_id">>]
           ,'doc_types' => [<<"provider">>]
           }
     ,<<"by_ownerid_type">> =>
          #{'query_fields' => [<<"owner_id">>, <<"doc_type">>]
           ,'doc_types' => []
           }
     ,<<"by_sip_credentials">> =>
          #{'query_fields' => <<"username">>
           ,'doc_types' => []
           }
     ,<<"by_sip_usernames">> =>
          #{'query_fields' => <<"username">>
           ,'doc_types' => []
           }
     ,<<"by_type_id">> =>
          #{'query_fields' => [<<"doc_type">>, <<"id">>]
           ,'doc_types' => []
           }
     ,<<"by_type_name">> =>
          #{'query_fields' => [<<"doc_type">>, <<"name">>]
           ,'doc_types' => []
           }
     ,<<"by_type_number">> =>
          #{'query_fields' => [<<"doc_type">>, <<"number">>]
           ,'doc_types' => []
           }
     ,<<"by_type_ownerid">> =>
          #{'query_fields' => [<<"doc_type">>, <<"owner_id">>]
           ,'doc_types' => []
           }
     ,<<"contact_list_excluded">> =>
          #{'query_fields' => <<"doc_id">>
           ,'doc_types' => []
           }
     ,<<"contact_list_extensions">> =>
          #{'query_fields' => <<"extension_type">>
           ,'doc_types' => [<<"callflow">>]
           }
     ,<<"contact_list_names">> =>
          #{'query_fields' => 'null'
           ,'doc_types' => [<<"conference">>, <<"device">>, <<"directory">>, <<"menu">>, <<"user">>, <<"vmbox">>]
           }
     ,<<"device_mac_addresses">> =>
          #{'query_fields' => <<"mac_address">>
           ,'doc_types' => [<<"device">>]
           }
     ,<<"device_presence_ids">> =>
          #{'query_fields' => <<"presence_id">>
           ,'doc_types' => [<<"device">>]
           }
     ,<<"endpoints_lookup">> =>
          #{'query_fields' => [<<"caller_id_number">>, <<"caller_id_type">>]
           ,'doc_types' => []
           }
     ,<<"faxbox_email_permissions">> =>
          #{'query_fields' => <<"permission_tag">>
           ,'doc_types' => [<<"faxbox">>]
           }
     ,<<"flow_msisdn">> =>
          #{'query_fields' => [<<"doc_type">>, <<"module">>, <<"data_id">>, <<"number">>]
           ,'doc_types' => [<<"callflow">>, <<"textflow">>]
           }
     ,<<"flow_patterns">> =>
          #{'query_fields' => [<<"doc_type">>, <<"pattern">>]
           ,'doc_types' => [<<"callflow">>, <<"textflow">>]
           }
     ,<<"list_entries">> =>
          #{'query_fields' => <<"list_id">>
           ,'doc_types' => [<<"list">>, <<"list_entry">>]
           }
     ,<<"list_patterns">> =>
          #{'query_fields' => <<"list_id">>
           ,'doc_types' => [<<"list_entry">>]
           }
     ,<<"list_prefixes">> =>
          #{'query_fields' => [<<"list_id">>, <<"prefix">>]
           ,'doc_types' => [<<"list_entry">>]
           }
     ,<<"mobile_mdns">> =>
          #{'query_fields' => <<"mdn">>
           ,'doc_types' => [<<"device">>]
           }
     ,<<"owners_by_docid_type">> =>
          #{'query_fields' => [<<"doc_id">>, <<"doc_type">>]
           ,'doc_types' => []
           }
     ,<<"rate_limits">> =>
          #{'query_fields' => [<<"name">>, <<"sip_method">>]
           ,'doc_types' => [<<"rate_limits">>]
           }
     ,<<"trunkstore_lookup_user_flags">> =>
          #{'query_fields' => [<<"auth_realm">>, <<"auth_user">>]
           ,'doc_types' => [<<"sys_info">>]
           }
     ,<<"user_creds_md5">> =>
          #{'query_fields' => <<"cred">>
           ,'doc_types' => [<<"user">>]
           }
     ,<<"user_creds_sha1">> =>
          #{'query_fields' => <<"cred">>
           ,'doc_types' => [<<"user">>]
           }
     ,<<"user_emails">> =>
          #{'query_fields' => <<"email">>
           ,'doc_types' => [<<"user">>]
           }
     ,<<"user_usernames">> =>
          #{'query_fields' => <<"username">>
           ,'doc_types' => [<<"user">>]
           }
     }.
