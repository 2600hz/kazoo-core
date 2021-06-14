%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope_rule).

-include("kz_auth_scope.hrl").

-export([fetch_system/2]).
-export([fetch_reseller/3]).
-export([fetch_account/3]).

-type app() :: atom() | kz_term:ne_binary().

%%------------------------------------------------------------------------------
%% @doc
%% @end
%------------------------------------------------------------------------------
-spec fetch_system(app(), kz_term:ne_binaries()) -> kz_json:objects().
fetch_system(Application, Scopes) ->
    fetch_rules(Application, ?SCOPES_CAT, Scopes).

-spec fetch_reseller(app(), kz_term:ne_binary(), kz_term:ne_binaries()) -> kz_json:objects().
fetch_reseller(Application, AccountId, Scopes) ->
    case kz_services_reseller:is_reseller(AccountId) of
        'true' -> [];
        'false' ->
            case kz_services_reseller:get_id(AccountId) of
                'undefined' -> [];
                ResellerId -> fetch_rules(Application, ResellerId, Scopes)
            end
    end.

-spec fetch_account(app(), kz_term:ne_binary(), kz_term:ne_binaries()) -> kz_json:objects().
fetch_account(Application, AccountId, Scopes) ->
    fetch_rules(Application, AccountId, Scopes).

fetch_rules(App, Db, Scopes) ->
    Application = kz_term:to_binary(App),
    DocIds = [scope_rules_doc_id(Scope) || Scope <- Scopes],
    case kz_datamgr:open_cache_docs(Db, DocIds) of
        {'ok', JObjs} ->
            [Doc || JObj <- JObjs,
                    Doc <- [kz_json:get_ne_json_value(<<"doc">>, JObj)],
                    Doc =/= 'undefined'
                        andalso Application =:= kzd_scope_rules:application(Doc)
            ];
        {'error', _Reason} ->
            lager:debug("failed to fetch scope restrictions from ~s: ~p", [Db, _Reason]),
            []
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec scope_rules_doc_id(kz_term:ne_binary()) -> kz_term:ne_binary().
scope_rules_doc_id(<<?SCOPE_RULE_DOC_ID_PREFIX, _/binary>> = Id) ->
    kz_auth_scope:normalize_doc_id(Id);
scope_rules_doc_id(Scope) ->
    kz_auth_scope:normalize_doc_id(<<?SCOPE_RULE_DOC_ID_PREFIX, Scope/binary>>).
