%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope_restrictions).

-include("kazoo_auth.hrl").

-export([maybe_deny/2]).

-define(SCOPE_RESTRICTION_PREFIX, <<"scope:">>).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_deny(AuthDoc::kz_json:object(), Options::kz_term:proplist()) ->
          {'ok', AuthDoc::kz_json:object()} |
          {'error', any()}.
maybe_deny(AuthDoc, Options) ->
    Scopes = kz_auth_scope:split(kz_json:get_binary_value(<<"scope">>, AuthDoc, <<>>)),
    Transport = props:get_value('transport', Options),
    maybe_deny(AuthDoc, Options, Scopes, Transport).

maybe_deny(_, _, [], _) ->
    'false';
maybe_deny(_, _, _, 'undefined') ->
    lager:warning("scope transport is undefined"),
    'false';
maybe_deny(AuthDoc, Options, Scopes, Transport) ->
    case kz_module:is_exported(Transport, 'maybe_deny_scopes', 3) of
        'true' ->
            call_transport(AuthDoc, Options, Scopes, Transport);
        'false' ->
            lager:debug("invalid scope transport ~s", [Transport]),
            'false'
    end.

call_transport(AuthDoc, Options, Scopes, Transport) ->
    ScopeRestrcitionIds = [doc_id(Scope) || Scope <- Scopes],
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

doc_id(Scope) -> <<(?SCOPE_RESTRICTION_PREFIX)/binary, Scope/binary>>.

fetch_system_restrictions(State) -> fetch(?KZ_AUTH_DB, State).

fetch_reseller_restrictions(#{auth_doc := #{account_id := AccountId}}=State) ->
    case kz_services_reseller:is_reseller(AccountId) of
        'true' -> [];
        'false' ->
            case kz_services_reseller:get_id(AccountId) of
                'undefined' -> [];
                ResellerId -> fetch(ResellerId, State)
            end
    end.

fetch_account_restrictions(#{auth_doc := #{account_id := AccountId}}=State) ->
    fetch(AccountId, State).

fetch(Db, #{restrcition_ids := DocIds}) ->
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
