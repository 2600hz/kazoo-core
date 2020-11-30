%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_trunkstore).

-export([new/0]).
-export([account/1, account/2, set_account/2]).
-export([account_auth_realm/1, account_auth_realm/2, set_account_auth_realm/2]).
-export([account_caller_id/1, account_caller_id/2, set_account_caller_id/2]).
-export([account_caller_id_cid_name/1, account_caller_id_cid_name/2, set_account_caller_id_cid_name/2]).
-export([account_caller_id_cid_number/1, account_caller_id_cid_number/2, set_account_caller_id_cid_number/2]).
-export([account_credits/1, account_credits/2, set_account_credits/2]).
-export([account_credits_prepay/1, account_credits_prepay/2, set_account_credits_prepay/2]).
-export([account_emergency_caller_id/1, account_emergency_caller_id/2, set_account_emergency_caller_id/2]).
-export([account_emergency_caller_id_cid_name/1, account_emergency_caller_id_cid_name/2, set_account_emergency_caller_id_cid_name/2]).
-export([account_emergency_caller_id_cid_number/1, account_emergency_caller_id_cid_number/2, set_account_emergency_caller_id_cid_number/2]).
-export([account_trunks/1, account_trunks/2, set_account_trunks/2]).
-export([call_restriction/1, call_restriction/2, set_call_restriction/2]).
-export([name/1, name/2, set_name/2]).
-export([servers/1, servers/2, set_servers/2]).
-export([type/1, type/2, set_type/2]).

-export([needs_migration/1]).
-export([save/1]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"trunkstore">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec account(doc()) -> kz_term:api_object().
account(Doc) ->
    account(Doc, 'undefined').

-spec account(doc(), Default) -> kz_json:object() | Default.
account(Doc, Default) ->
    kz_json:get_json_value([<<"account">>], Doc, Default).

-spec set_account(doc(), kz_json:object()) -> doc().
set_account(Doc, Account) ->
    kz_json:set_value([<<"account">>], Account, Doc).

-spec account_auth_realm(doc()) -> kz_term:api_ne_binary().
account_auth_realm(Doc) ->
    account_auth_realm(Doc, 'undefined').

-spec account_auth_realm(doc(), Default) -> kz_term:ne_binary() | Default.
account_auth_realm(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"account">>, <<"auth_realm">>], Doc, Default).

-spec set_account_auth_realm(doc(), kz_term:ne_binary()) -> doc().
set_account_auth_realm(Doc, AccountAuthenticationRealm) ->
    kz_json:set_value([<<"account">>, <<"auth_realm">>], AccountAuthenticationRealm, Doc).

-spec account_caller_id(doc()) -> kz_term:api_object().
account_caller_id(Doc) ->
    account_caller_id(Doc, 'undefined').

-spec account_caller_id(doc(), Default) -> kz_json:object() | Default.
account_caller_id(Doc, Default) ->
    kz_json:get_json_value([<<"account">>, <<"caller_id">>], Doc, Default).

-spec set_account_caller_id(doc(), kz_json:object()) -> doc().
set_account_caller_id(Doc, AccountCallerId) ->
    kz_json:set_value([<<"account">>, <<"caller_id">>], AccountCallerId, Doc).

-spec account_caller_id_cid_name(doc()) -> kz_term:api_ne_binary().
account_caller_id_cid_name(Doc) ->
    account_caller_id_cid_name(Doc, 'undefined').

-spec account_caller_id_cid_name(doc(), Default) -> kz_term:ne_binary() | Default.
account_caller_id_cid_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"account">>, <<"caller_id">>, <<"cid_name">>], Doc, Default).

-spec set_account_caller_id_cid_name(doc(), kz_term:ne_binary()) -> doc().
set_account_caller_id_cid_name(Doc, AccountCallerIdCidName) ->
    kz_json:set_value([<<"account">>, <<"caller_id">>, <<"cid_name">>], AccountCallerIdCidName, Doc).

-spec account_caller_id_cid_number(doc()) -> kz_term:api_ne_binary().
account_caller_id_cid_number(Doc) ->
    account_caller_id_cid_number(Doc, 'undefined').

-spec account_caller_id_cid_number(doc(), Default) -> kz_term:ne_binary() | Default.
account_caller_id_cid_number(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"account">>, <<"caller_id">>, <<"cid_number">>], Doc, Default).

-spec set_account_caller_id_cid_number(doc(), kz_term:ne_binary()) -> doc().
set_account_caller_id_cid_number(Doc, AccountCallerIdCidNumber) ->
    kz_json:set_value([<<"account">>, <<"caller_id">>, <<"cid_number">>], AccountCallerIdCidNumber, Doc).

-spec account_credits(doc()) -> kz_term:api_object().
account_credits(Doc) ->
    account_credits(Doc, 'undefined').

-spec account_credits(doc(), Default) -> kz_json:object() | Default.
account_credits(Doc, Default) ->
    kz_json:get_json_value([<<"account">>, <<"credits">>], Doc, Default).

-spec set_account_credits(doc(), kz_json:object()) -> doc().
set_account_credits(Doc, AccountCredits) ->
    kz_json:set_value([<<"account">>, <<"credits">>], AccountCredits, Doc).

-spec account_credits_prepay(doc()) -> kz_term:api_number().
account_credits_prepay(Doc) ->
    account_credits_prepay(Doc, 'undefined').

-spec account_credits_prepay(doc(), Default) -> number() | Default.
account_credits_prepay(Doc, Default) ->
    kz_json:get_float_value([<<"account">>, <<"credits">>, <<"prepay">>], Doc, Default).

-spec set_account_credits_prepay(doc(), number()) -> doc().
set_account_credits_prepay(Doc, AccountCreditsPrepay) ->
    kz_json:set_value([<<"account">>, <<"credits">>, <<"prepay">>], AccountCreditsPrepay, Doc).

-spec account_emergency_caller_id(doc()) -> kz_term:api_object().
account_emergency_caller_id(Doc) ->
    account_emergency_caller_id(Doc, 'undefined').

-spec account_emergency_caller_id(doc(), Default) -> kz_json:object() | Default.
account_emergency_caller_id(Doc, Default) ->
    kz_json:get_json_value([<<"account">>, <<"emergency_caller_id">>], Doc, Default).

-spec set_account_emergency_caller_id(doc(), kz_json:object()) -> doc().
set_account_emergency_caller_id(Doc, AccountEmergencyCallerId) ->
    kz_json:set_value([<<"account">>, <<"emergency_caller_id">>], AccountEmergencyCallerId, Doc).

-spec account_emergency_caller_id_cid_name(doc()) -> kz_term:api_ne_binary().
account_emergency_caller_id_cid_name(Doc) ->
    account_emergency_caller_id_cid_name(Doc, 'undefined').

-spec account_emergency_caller_id_cid_name(doc(), Default) -> kz_term:ne_binary() | Default.
account_emergency_caller_id_cid_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"account">>, <<"emergency_caller_id">>, <<"cid_name">>], Doc, Default).

-spec set_account_emergency_caller_id_cid_name(doc(), kz_term:ne_binary()) -> doc().
set_account_emergency_caller_id_cid_name(Doc, AccountEmergencyCallerIdCidName) ->
    kz_json:set_value([<<"account">>, <<"emergency_caller_id">>, <<"cid_name">>], AccountEmergencyCallerIdCidName, Doc).

-spec account_emergency_caller_id_cid_number(doc()) -> kz_term:api_ne_binary().
account_emergency_caller_id_cid_number(Doc) ->
    account_emergency_caller_id_cid_number(Doc, 'undefined').

-spec account_emergency_caller_id_cid_number(doc(), Default) -> kz_term:ne_binary() | Default.
account_emergency_caller_id_cid_number(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"account">>, <<"emergency_caller_id">>, <<"cid_number">>], Doc, Default).

-spec set_account_emergency_caller_id_cid_number(doc(), kz_term:ne_binary()) -> doc().
set_account_emergency_caller_id_cid_number(Doc, AccountEmergencyCallerIdCidNumber) ->
    kz_json:set_value([<<"account">>, <<"emergency_caller_id">>, <<"cid_number">>], AccountEmergencyCallerIdCidNumber, Doc).

-spec account_trunks(doc()) -> kz_term:api_integer().
account_trunks(Doc) ->
    account_trunks(Doc, 'undefined').

-spec account_trunks(doc(), Default) -> integer() | Default.
account_trunks(Doc, Default) ->
    kz_json:get_integer_value([<<"account">>, <<"trunks">>], Doc, Default).

-spec set_account_trunks(doc(), integer()) -> doc().
set_account_trunks(Doc, AccountTrunks) ->
    kz_json:set_value([<<"account">>, <<"trunks">>], AccountTrunks, Doc).

-spec call_restriction(doc()) -> kz_json:object().
call_restriction(Doc) ->
    call_restriction(Doc, kz_json:new()).

-spec call_restriction(doc(), Default) -> kz_json:object() | Default.
call_restriction(Doc, Default) ->
    kz_json:get_json_value([<<"call_restriction">>], Doc, Default).

-spec set_call_restriction(doc(), kz_json:object()) -> doc().
set_call_restriction(Doc, CallRestriction) ->
    kz_json:set_value([<<"call_restriction">>], CallRestriction, Doc).

-spec name(doc()) -> kz_term:api_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> binary() | Default.
name(Doc, Default) ->
    kz_json:get_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

-spec servers(doc()) -> kz_json:objects().
servers(Doc) ->
    servers(Doc, []).

-spec servers(doc(), Default) -> kz_json:objects() | Default.
servers(Doc, Default) ->
    kz_json:get_list_value([<<"servers">>], Doc, Default).

-spec set_servers(doc(), kz_json:objects()) -> doc().
set_servers(Doc, Servers) ->
    kz_json:set_value([<<"servers">>], Servers, Doc).

-spec type(doc()) -> kz_term:api_binary().
type(Doc) ->
    type(Doc, 'undefined').

-spec type(doc(), Default) -> binary() | Default.
type(Doc, Default) ->
    kz_json:get_binary_value([<<"type">>], Doc, Default).

-spec set_type(doc(), binary()) -> doc().
set_type(Doc, Type) ->
    kz_json:set_value([<<"type">>], Type, Doc).

server_has_id(Server) ->
    kz_doc:id(Server) =/= undefined.

-spec needs_migration(doc()) -> boolean().
needs_migration(Doc) ->
    lists:any(fun(S) -> not server_has_id(S) end, servers(Doc)).

-spec ensure_server_ids(doc()) -> doc().
ensure_server_ids(Doc) ->
    set_servers(Doc, lists:foldr(fun ensure_server_id/2, [], servers(Doc))).

-spec ensure_server_id(kz_json:object(), kz_json:objects()) -> kz_json:objects().
ensure_server_id(Server, Acc) ->
    case kz_json:get_ne_binary_value(<<"server_id">>, Server) of
        undefined -> [kz_json:set_value(<<"server_id">>, kz_binary:rand_hex(16), Server) | Acc];
        _Id -> [Server | Acc]
    end.

-spec save(doc()) -> doc().
save(Doc) ->
    _ = remove_trunk_servers(Doc),
    case kz_datamgr:save_doc(kz_doc:account_id(Doc), ensure_server_ids(Doc)) of
        {error, _} = Error ->
            Error;
        {ok, Saved} = OK ->
            save_trunk_servers(Saved),
            OK
    end.

remove_trunk_servers(Doc) ->
    remove_trunk_servers(kz_doc:id(Doc), Doc).

remove_trunk_servers(undefined, _Doc) -> ok;
remove_trunk_servers(Id, Doc) ->
    _ = kzd_trunkserver:delete(kz_doc:account_id(Doc), Id),
    _ = kz_datamgr:del_doc(?KZ_SIP_DB, Id),
    ok.

save_trunk_servers(Doc) ->
    Servers = servers(Doc),
    lists:foreach(fun(Server) -> kzd_trunkserver:save(Server, Doc) end, Servers).
