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

-export([maybe_deny_access/2]).
-export([scope_rules_doc_id/1]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_deny_access(AuthDoc::kz_json:object(), Options::kz_term:proplist()) -> boolean().
maybe_deny_access(AuthDoc, Options) ->
    Scopes = kz_auth_scope:split(kz_json:get_binary_value(<<"scope">>, AuthDoc, <<>>)),
    Transport = props:get_value('transport', Options),
    maybe_deny_access(AuthDoc, Options, Scopes, Transport).

maybe_deny_access(_, _, [], _) ->
    'false';
maybe_deny_access(_, _, _, 'undefined') ->
    lager:warning("scope transport is undefined"),
    'false';
maybe_deny_access(AuthDoc, Options, Scopes, Transport) ->
    case kz_module:is_exported(Transport, 'maybe_deny_scopes', 3) of
        'true' ->
            call_transport(AuthDoc, Options, Scopes, Transport);
        'false' ->
            lager:debug("invalid scope transport ~s", [Transport]),
            'false'
    end.

call_transport(AuthDoc, Options, Scopes, Transport) ->
    ScopeRestrcitionIds = [scope_rules_doc_id(Scope) || Scope <- Scopes],
    State = #{auth_doc => kz_json:to_map(AuthDoc)
             ,scopes => Scopes
             ,restrcition_ids => ScopeRestrcitionIds
             ,transport => Transport
             ,options => maps:from_list(Options)
             },
    Funs = [fun fetch_system_restrictions/1
           ,fun fetch_reseller_restrictions/1
           ,fun fetch_account_restrictions/1
           ],
    maybe_deny_scopes(Funs, State).

maybe_deny_scopes([], #{}) ->
    'false';
maybe_deny_scopes([FetchFun | FetchFuns], #{transport := Transport} = State) ->
    Restrictions = FetchFun(State),
    case kz_term:is_not_empty(Restrictions)
        andalso Transport:maybe_deny_scopes(Restrictions, State)
    of
        'true' -> 'true';
        'false' -> maybe_deny_scopes(FetchFuns, State)
    end.

fetch_system_restrictions(State) -> fetch_restrictions(?SCOPES_CAT, State).

fetch_reseller_restrictions(#{auth_doc := #{account_id := AccountId}}=State) ->
    case kz_services_reseller:is_reseller(AccountId) of
        'true' -> [];
        'false' ->
            case kz_services_reseller:get_id(AccountId) of
                'undefined' -> [];
                ResellerId -> fetch_restrictions(ResellerId, State)
            end
    end.

fetch_account_restrictions(#{auth_doc := #{account_id := AccountId}}=State) ->
    fetch_restrictions(AccountId, State).

fetch_restrictions(Db, #{restrcition_ids := DocIds}) ->
    case kz_datamgr:open_docs(Db, DocIds) of
        {'ok', JObjs} ->
            [Doc || JObj <- JObjs,
                    Doc <- [kz_json:get_ne_json_value(<<"doc">>, JObj)],
                    Doc =/= 'undefined'
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
