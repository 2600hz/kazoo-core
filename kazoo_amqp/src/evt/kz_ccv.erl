%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2025, 2600Hz
%%% @doc FreeSWITCH json
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_ccv).

-export([account_id/1, account_id/2
        ,account_billing/1, account_billing/2
        ,account_trunk_usage/1, account_trunk_usage/2
        ,authorizing_id/1, authorizing_id/2
        ,authorizing_type/1, authorizing_type/2
        ,ccvs/1, ccv/2, ccv/3
        ,set_ccv/3, set_ccvs/2
        ,channel_authorized/1, channel_authorized/2
        ,is_consuming_global_resource/1, is_consuming_global_resource/2
        ,media_recorder/1, media_recorder/2
        ,outbound_flags/1, outbound_flags/2
        ,reseller_id/1, reseller_id/2
        ,reseller_billing/1, reseller_billing/2
        ,reseller_trunk_usage/1, reseller_trunk_usage/2
        ,resource_id/1, resource_id/2
        ]).

-type payload() :: kz_json:object().
-export_type([payload/0]).

-define(CCVs, <<"Custom-Channel-Vars">>).


-spec channel_authorized(payload()) -> kz_term:api_binary().
channel_authorized(JObj) ->
    channel_authorized(JObj, 'undefined').

-spec channel_authorized(payload(), Default) -> kz_term:ne_binary()  | Default.
channel_authorized(JObj, Default) ->
    ccv(JObj, <<"Channel-Authorized">>, Default).

-spec outbound_flags(payload()) -> kz_term:api_binary() | kz_term:ne_binaries().
outbound_flags(JObj) ->
    outbound_flags(JObj, 'undefined').

-spec outbound_flags(payload(), Default) -> kz_term:ne_binary() | kz_term:ne_binaries() | Default.
outbound_flags(JObj, Default) ->
    ccv(JObj, <<"Outbound-Flags">>, Default).

-spec is_consuming_global_resource(payload()) -> kz_term:api_boolean().
is_consuming_global_resource(JObj) ->
    is_consuming_global_resource(JObj, 'undefined').

-spec is_consuming_global_resource(payload(), kz_term:api_boolean()) -> kz_term:api_boolean().
is_consuming_global_resource(JObj, Default) ->
    kz_term:is_true(ccv(JObj, <<"Global-Resource">>, Default)).

-spec resource_id(payload()) -> kz_term:api_binary().
resource_id(JObj) ->
    resource_id(JObj, 'undefined').

-spec resource_id(payload(), Default) -> kz_term:ne_binary() | Default.
resource_id(JObj, Default) ->
    ccv(JObj, <<"Resource-ID">>, Default).

-spec authorizing_id(payload()) -> kz_term:api_binary().
authorizing_id(JObj) ->
    authorizing_id(JObj, 'undefined').

-spec authorizing_id(payload(), Default) -> kz_term:ne_binary() | Default.
authorizing_id(JObj, Default) ->
    ccv(JObj, <<"Authorizing-ID">>, Default).

-spec authorizing_type(payload()) -> kz_term:api_binary().
authorizing_type(JObj) ->
    authorizing_type(JObj, 'undefined').

-spec authorizing_type(payload(), Default) -> kz_term:ne_binary() | Default.
authorizing_type(JObj, Default) ->
    ccv(JObj, <<"Authorizing-Type">>, Default).

-spec account_id(payload()) -> kz_term:api_binary().
account_id(JObj) ->
    account_id(JObj, 'undefined').

-spec account_id(payload(), Default) -> kz_term:ne_binary() | Default.
account_id(JObj, Default) ->
    ccv(JObj, <<"Account-ID">>, Default).

-spec account_billing(payload()) -> kz_term:api_binary().
account_billing(JObj) ->
    account_billing(JObj, 'undefined').

-spec account_billing(payload(), Default) -> kz_term:ne_binary() | Default.
account_billing(JObj, Default) ->
    ccv(JObj, <<"Account-Billing">>, Default).

-spec account_trunk_usage(payload()) -> kz_term:api_binary().
account_trunk_usage(JObj) ->
    account_trunk_usage(JObj, 'undefined').

-spec account_trunk_usage(payload(), Default) -> kz_term:ne_binary() | Default.
account_trunk_usage(JObj, Default) ->
    ccv(JObj, <<"Account-Trunk-Usage">>, Default).

-spec reseller_id(payload()) -> kz_term:api_binary().
reseller_id(JObj) ->
    reseller_id(JObj, 'undefined').

-spec reseller_id(payload(), Default) -> kz_term:ne_binary() | Default.
reseller_id(JObj, Default) ->
    ccv(JObj, <<"Reseller-ID">>, Default).

-spec reseller_billing(payload()) -> kz_term:api_binary().
reseller_billing(JObj) ->
    reseller_billing(JObj, 'undefined').

-spec reseller_billing(payload(), Default) -> kz_term:ne_binary() | Default.
reseller_billing(JObj, Default) ->
    ccv(JObj, <<"Reseller-Billing">>, Default).

-spec reseller_trunk_usage(payload()) -> kz_term:api_binary().
reseller_trunk_usage(JObj) ->
    reseller_trunk_usage(JObj, 'undefined').

-spec reseller_trunk_usage(payload(), Default) -> kz_term:ne_binary() | Default.
reseller_trunk_usage(JObj, Default) ->
    ccv(JObj, <<"Reseller-Trunk-Usage">>, Default).

-spec media_recorder(payload()) -> kz_term:api_binary().
media_recorder(JObj) ->
    media_recorder(JObj, 'undefined').

-spec media_recorder(payload(), Default) -> kz_term:ne_binary() | Default.
media_recorder(JObj, Default) ->
    ccv(JObj, <<"Media-Recorder">>, Default).

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
