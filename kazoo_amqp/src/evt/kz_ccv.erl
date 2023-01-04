%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2023, 2600Hz
%%% @doc FreeSWITCH json
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_ccv).

-export([account_id/1
        ,account_billing/1
        ,account_trunk_usage/1
        ,authorizing_id/1
        ,authorizing_type/1
        ,ccvs/1, ccv/2, ccv/3
        ,set_ccv/3, set_ccvs/2
        ,channel_authorized/1
        ,is_consuming_global_resource/1, is_consuming_global_resource/2
        ,media_recorder/1
        ,outbound_flags/1
        ,reseller_id/1, reseller_billing/1, reseller_trunk_usage/1
        ,resource_id/1
        ]).

-type payload() :: kz_json:object().
-export_type([payload/0]).

-define(CCVs, <<"Custom-Channel-Vars">>).


-spec channel_authorized(payload()) -> kz_term:api_binary().
channel_authorized(JObj) ->
    ccv(JObj, <<"Channel-Authorized">>).

-spec outbound_flags(payload()) -> kz_term:api_binary() | kz_term:ne_binaries().
outbound_flags(JObj) ->
    ccv(JObj, <<"Outbound-Flags">>).

-spec is_consuming_global_resource(payload()) -> kz_term:api_boolean().
is_consuming_global_resource(JObj) ->
    is_consuming_global_resource(JObj, 'undefined').

-spec is_consuming_global_resource(payload(), kz_term:api_boolean()) -> kz_term:api_boolean().
is_consuming_global_resource(JObj, Default) ->
    kz_term:is_true(ccv(JObj, <<"Global-Resource">>, Default)).

-spec resource_id(payload()) -> kz_term:api_binary().
resource_id(JObj) ->
    ccv(JObj, <<"Resource-ID">>).

-spec authorizing_id(payload()) -> kz_term:api_binary().
authorizing_id(JObj) ->
    ccv(JObj, <<"Authorizing-ID">>).

-spec authorizing_type(payload()) -> kz_term:api_binary().
authorizing_type(JObj) ->
    ccv(JObj, <<"Authorizing-Type">>).

-spec account_id(payload()) -> kz_term:api_binary().
account_id(JObj) ->
    ccv(JObj, <<"Account-ID">>).

-spec account_billing(payload()) -> kz_term:api_binary().
account_billing(JObj) ->
    ccv(JObj, <<"Account-Billing">>).

-spec account_trunk_usage(payload()) -> kz_term:api_binary().
account_trunk_usage(JObj) ->
    ccv(JObj, <<"Account-Trunk-Usage">>).

-spec reseller_id(payload()) -> kz_term:api_binary().
reseller_id(JObj) ->
    ccv(JObj, <<"Reseller-ID">>).

-spec reseller_billing(payload()) -> kz_term:api_binary().
reseller_billing(JObj) ->
    ccv(JObj, <<"Reseller-Billing">>).

-spec reseller_trunk_usage(payload()) -> kz_term:api_binary().
reseller_trunk_usage(JObj) ->
    ccv(JObj, <<"Reseller-Trunk-Usage">>).

-spec media_recorder(payload()) -> kz_term:api_binary().
media_recorder(JObj) -> ccv(JObj, <<"Media-Recorder">>).

-spec ccv(payload(), kz_term:ne_binary()) -> kz_term:api_binary() | kz_term:ne_binaries().
ccv(JObj, Key) ->
    ccv(JObj, Key, 'undefined').

-spec ccv(payload(), kz_term:ne_binary(), Default) -> kz_term:ne_binary() | kz_term:ne_binaries() | Default.
ccv(JObj, Key, Default) ->
    kz_json:get_ne_binary_value(Key, ccvs(JObj), Default).

-spec set_ccv(payload(), kz_term:ne_binary(), term()) -> payload().
set_ccv(JObj, Key, Value) ->
    kz_json:set_value([?CCVs, Key], JObj, Value).

-spec set_ccvs(payload(), [tuple()]) -> payload().
set_ccvs(JObj, Values) ->
    kz_json:set_values([{[?CCVs, Key], Value} || {Key, Value} <- Values], JObj).

%% Extract custom channel variables to include in the event
-spec ccvs(payload()) -> payload().
ccvs(JObj) ->
    kz_json:get_json_value(<<"Custom-Channel-Vars">>, JObj, kz_json:new()).
