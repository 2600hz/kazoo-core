%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2026, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_entitlements).

-export([capabilities/0
        ,update_capabilities/1, update_capability/2
        ]).
-export([update_enrollments/2, update_enrollments/3
        ,is_enrolled/2, is_enrolled/3
        ]).
-export([entitlements/0, entitlements/1, entitlements/2
        ,delete_entitlements/0, delete_capability/1
        ]).

-export([entitlements_id/0]).

-ifdef(TEST).
-export([calculate_entitlements/2]).

-include_lib("eunit/include/eunit.hrl").
-endif.

-include("services.hrl").

%% {ResellerId, ChildId}
-type overlay_account() :: {kz_term:ne_binary(), kz_term:ne_binary()}.

-export_type([overlay_account/0]).

-define(ID_ENTITLEMENTS, <<"entitlements">>).

-spec entitlements_id() -> kz_term:ne_binary().
entitlements_id() ->
    ?ID_ENTITLEMENTS.

-spec entitlements_id(kz_term:ne_binary()) -> kz_term:ne_binary().
entitlements_id(<<UserId/binary>>) ->
    <<UserId/binary, "-", ?ID_ENTITLEMENTS/binary>>.

-spec entitlements() -> kzd_entitlements:doc().
entitlements() ->
    system_entitlements().

-spec entitlements(kzd_accounts:doc() | kz_term:ne_binary() | overlay_account()) -> kzd_entitlements:doc().
entitlements(<<AccountId/binary>>) ->
    %% to future readers:
    %% the top-level capabilities are defined in the master account,
    %% thus we don't need to calculate the enrollments (as there are
    %% none).
    AccountEntitlements = overlay_entitlements(AccountId),

    ResellerTree = tl(kzd_accounts:tree(AccountId)) ++ [AccountEntitlements], % ancestor -> parent -> account

    calculate_entitlements(ResellerTree);
entitlements({ResellerId, AccountId}) ->
    AccountEntitlements = overlay_entitlements({ResellerId, AccountId}),
    ResellerTree = tl(kzd_accounts:tree(AccountId)) ++ [AccountEntitlements], % ancestor -> parent -> account+overlay
    calculate_entitlements(ResellerTree);
entitlements(AccountDoc) ->
    entitlements(kz_doc:id(AccountDoc)).

overlay_entitlements(<<AccountId/binary>>) ->
    ResellerId = kz_services_reseller:get_id(AccountId),
    overlay_entitlements({ResellerId, AccountId});
overlay_entitlements({ResellerId, ResellerId}) ->
    open_entitlements(ResellerId);
overlay_entitlements({ResellerId, AccountId}) ->
    OverlayEntitlements = kz_doc:public_fields(open_entitlements(ResellerId, entitlements_id(AccountId)), 'false'),
    AcctEntitlements = open_entitlements(AccountId),

    lager:debug("calc overlay from reseller: ~s for acct: ~s", [ResellerId, AccountId]),
    lager:debug("overlay ~p", [OverlayEntitlements]),
    lager:debug("acct ~p", [AcctEntitlements]),
    lager:debug("acct overlay ~p", [kz_json:merge(AcctEntitlements, OverlayEntitlements)]),

    kz_json:merge(AcctEntitlements, OverlayEntitlements).

-spec entitlements(kz_term:ne_binary() | overlay_account(), kz_term:api_ne_binary()) -> kzd_entitlements:doc().
entitlements(AccountId, 'undefined') ->
    entitlements(AccountId);
entitlements(<<AccountId/binary>>, <<UserId/binary>>) ->
    lager:info("calc account ~s user ~s", [AccountId, UserId]),
    AccountEntitlements = overlay_entitlements(AccountId),
    UserEntitlements = open_entitlements(AccountId, entitlements_id(UserId)),

    lager:debug("user ents: ~p", [UserEntitlements]),

    ResellerTree = tl(kzd_accounts:tree(AccountId)) ++ [AccountEntitlements, UserEntitlements], % ancestor -> parent -> account -> user

    calculate_entitlements(ResellerTree);
entitlements({ResellerId, AccountId}, <<UserId/binary>>) ->
    lager:info("calc overlay account ~s user ~s", [AccountId, UserId]),
    AccountEntitlements = overlay_entitlements({ResellerId, AccountId}),
    UserEntitlements = open_entitlements(AccountId, entitlements_id(UserId)),

    lager:debug("user ents: ~p", [UserEntitlements]),

    ResellerTree = tl(kzd_accounts:tree(AccountId)) ++ [AccountEntitlements, UserEntitlements], % ancestor -> parent -> account+overlay -> user
    calculate_entitlements(ResellerTree).

-spec calculate_entitlements([kzd_entitlements:doc()] | kz_term:ne_binaries()) -> kzd_entitlements:doc().
calculate_entitlements(AncestryEntitlements) ->
    calculate_entitlements(AncestryEntitlements, capabilities()).

calculate_entitlements(AncestryEntitlements, SystemCapabilities) ->
    lager:debug("ancestry: ~p", [AncestryEntitlements]),

    AllEntitlements = [hydrate_ancestor_entitlements(Ancestor)
                       || Ancestor <- AncestryEntitlements
                      ],

    lager:debug("hydrated: ~p", [AllEntitlements]),
    %% what capabilities are available to the account, based on
    [AccountEntitlements | _]=_Res
        = lists:foldl(fun filter_capabilities/2
                      %% since the system doesn't have enrollments, we use the capabilties'
                      %% enabled flags to be enrollments' enabled flags took
                     ,[kzd_entitlements:create(SystemCapabilities, SystemCapabilities)]
                     ,AllEntitlements
                     ),
    lager:info("pre filter disabled: ~p", [AccountEntitlements]),
    kzd_entitlements:filter_disabled(AccountEntitlements).

hydrate_ancestor_entitlements(<<AccountId/binary>>) ->
    overlay_entitlements(AccountId);
hydrate_ancestor_entitlements(EntitlementsJObj) ->
    EntitlementsJObj.

filter_capabilities(AcctEntitlementsJObj
                   ,[ParentEntitlements | _]=Acc
                   ) ->
    %% TODO: consider when a reseller configures an account's
    %% enrollment itself (vs the account enrolling itself) Maybe track
    %% account_id in Acc so we could fetch entitlements-{ACCOUNT_ID}
    %% in parent db?


    %% TODO: include service plan entitlements object in calculating entitlements

    ParentCapabilities = kzd_entitlements:capabilities(ParentEntitlements),
    lager:info("parent caps: ~p", [ParentCapabilities]),

    %% TODO: check account entitlements for custom capabliites and merge onto parent capabilities

    {AccountEntitlements, _}
        = kz_json:foldl(fun filter_by_enrollment/3
                        %% computed parent capabilities become start for account capabilities
                       ,{kzd_entitlements:set_capabilities(AcctEntitlementsJObj, ParentCapabilities)
                        ,ParentEntitlements
                        }
                       ,ParentCapabilities
                       ),
    lager:info("calc acct ents: ~p", [AccountEntitlements]),
    [AccountEntitlements | Acc].

%% current account's enrollment data
%% updates Acc based on parent data
%% end of fold will be account's calculated capabilities and enrollments
filter_by_enrollment(CapabilityId, ParentCapabilityData
                    ,{AccountEntitlements, ParentEntitlements}
                    ) ->
    case kzd_capability:enabled(ParentCapabilityData, 'false')
        andalso kzd_enrollment:enabled(kzd_entitlements:enrollment(ParentEntitlements, CapabilityId), 'false')
    of
        'false' ->
            lager:debug("parent ~s cap/enroll is false, account ~s matching"
                       ,[kz_doc:account_id(ParentEntitlements), kz_doc:account_id(AccountEntitlements)]
                       ),
            %% if parent capability or enrollment is disabled, both for account is disabled too
            WithoutCap = kzd_entitlements:set_capability_disabled(AccountEntitlements, CapabilityId),
            {kzd_entitlements:set_enrollment_disabled(WithoutCap, CapabilityId)
            ,ParentEntitlements
            };
        'true' ->
            filter_by_account_enrollment(CapabilityId, AccountEntitlements, ParentEntitlements)
    end.

filter_by_account_enrollment(CapabilityId, AccountEntitlements, ParentEntitlements) ->
    %% parent capability is allowed and enrolled
    %% check if current account has enrolled
    case kzd_entitlements:is_enrolled(AccountEntitlements, CapabilityId, 'undefined') of
        'undefined' ->
            lager:debug("parent ~s cap/enroll is true, account ~s with cap / undef enroll"
                       ,[kz_doc:account_id(ParentEntitlements), kz_doc:account_id(AccountEntitlements)]
                       ),
            WithCap = kzd_entitlements:set_capability_enabled(AccountEntitlements, CapabilityId),
            {kzd_entitlements:set_enrollment_disabled(WithCap, CapabilityId)
            ,ParentEntitlements
            };
        'false' ->
            lager:debug("parent ~s cap/enroll is true, account ~s with cap / unenrolled"
                       ,[kz_doc:account_id(ParentEntitlements), kz_doc:account_id(AccountEntitlements)]
                       ),
            %% if the enrollment is disabled, remove from capabilities available
            {kzd_entitlements:set_capability_enabled(AccountEntitlements, CapabilityId)
            ,ParentEntitlements
            };
        'true' ->
            lager:debug("parent ~s cap/enroll is true, account ~s with cap / enrolled"
                       ,[kz_doc:account_id(ParentEntitlements), kz_doc:account_id(AccountEntitlements)]
                       ),
            %% if the account's enrollment is active, nothing
            %% to update for next iteration
            {kzd_entitlements:set_capability_enabled(AccountEntitlements, CapabilityId)
            ,ParentEntitlements
            }
    end.

%% return system capabilities from the system entitlements doc
-spec capabilities() -> kz_json:object(kz_term:ne_binary(), kzd_capability:doc()).
capabilities() ->
    Capabilities = system_capabilities(),
    capabilities_enabled(Capabilities, <<"system">>).

-spec update_capabilities(kz_json:object(kz_term:ne_binary(), kzd_capability:doc())) ->
          {'ok', kzd_entitlements:doc()} |
          kz_datamgr:data_error().
update_capabilities(Capabilities) ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),

    Updates = [{kzd_entitlements:path_capabilities() ++ Path, Value}
               || {Path, Value} <- kz_json:to_proplist(kz_json:flatten(Capabilities))
              ],

    Update = [{'update', Updates}
             ,{'ensure_saved', 'true'}
             ],
    SaveAttempt = kz_datamgr:update_doc(MasterAccountId, entitlements_id(), Update),
    handle_update(SaveAttempt).

-spec update_capability(kz_term:ne_binary(), kzd_capability:doc() | 'null') ->
          {'ok', kzd_entitlements:doc()} |
          kz_datamgr:data_error().
update_capability(CapabilityId, Settings) ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),

    Updates = [{kzd_entitlements:path_capabilities() ++ [CapabilityId], Settings}],
    Update = [{'update', Updates}
             ,{'ensure_saved', 'true'}
             ],
    SaveAttempt = kz_datamgr:update_doc(MasterAccountId, entitlements_id(), Update),
    handle_update(SaveAttempt).


-spec is_enrolled(kz_term:ne_binary(), kz_term:ne_binary()) -> boolean().
is_enrolled(CapabilityId, AccountId) ->
    Entitlements = open_entitlements(AccountId),
    Enrollment = kzd_entitlements:enrollment(Entitlements, CapabilityId, kz_json:new()),
    kzd_enrollment:enabled(Enrollment, 'false').

-spec is_enrolled(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_ne_binary()) -> boolean().
is_enrolled(CapabilityId, AccountId, 'undefined') ->
    is_enrolled(CapabilityId, AccountId);
is_enrolled(CapabilityId, AccountId, UserId) ->
    Entitlements = open_entitlements(AccountId, entitlements_id(UserId)),
    Enrollment = kzd_entitlements:enrollment(Entitlements, CapabilityId, kz_json:new()),
    kzd_enrollment:enabled(Enrollment, 'false').

-spec update_enrollments(kz_json:object(kz_term:ne_binary(), kzd_enrollment:doc()), kz_term:ne_binary() | overlay_account()) ->
          {'ok', kzd_entitlements:doc()} |
          kz_datamgr:data_error().
update_enrollments(Enrollments, AccountId) ->
    do_update_enrollments(Enrollments, AccountId, entitlements_id()).

-spec update_enrollments(kz_json:object(kz_term:ne_binary(), kzd_enrollment:doc()), kz_term:ne_binary() | overlay_account(), kz_term:api_ne_binary()) ->
          {'ok', kzd_entitlements:doc()} |
          kz_datamgr:data_error().
update_enrollments(Enrollments, AccountId, 'undefined') ->
    update_enrollments(Enrollments, AccountId);
update_enrollments(Enrollments, {_, AccountId}, UserId) ->
    do_update_enrollments(Enrollments, AccountId, entitlements_id(UserId));
update_enrollments(Enrollments, AccountId, UserId) ->
    do_update_enrollments(Enrollments, AccountId, entitlements_id(UserId)).

do_update_enrollments(NewEnrollments, {ResellerId, AccountId}, _EntitlementsId) ->
    lager:info("updating overlay enrollments for account ~s in account ~s", [AccountId, ResellerId]),
    do_update_enrollments(NewEnrollments, ResellerId, entitlements_id(AccountId));
do_update_enrollments(NewEnrollments, AccountId, EntitlementsId) ->
    [Key] = kzd_entitlements:path_enrollments(),

    FlatProps = kz_json:to_proplist(kz_json:flatten(NewEnrollments)),

    UpdateEnrollments = [{[Key | Keys], Enrollment}
                         || {Keys, Enrollment} <- FlatProps
                        ],

    Update = [{'update', UpdateEnrollments}
             ,{'ensure_saved', 'true'}
             ],
    SaveAttempt = kz_datamgr:update_doc(AccountId, EntitlementsId, Update),
    handle_update(SaveAttempt).

handle_update({'ok', EntitlementsDoc}) ->
    {'ok', kz_doc:public_fields(EntitlementsDoc, 'false')}; % don't include doc id
handle_update(Error) -> Error.

system_capabilities() ->
    EntitlementsDoc = system_entitlements(),
    kzd_entitlements:capabilities(EntitlementsDoc, kz_json:new()).

system_entitlements() ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),
    open_entitlements(MasterAccountId).

-spec delete_entitlements() ->
          {'ok', kz_json:object()} |
          kz_datamgr:data_error().
delete_entitlements() ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),
    handle_update(kz_datamgr:del_doc(MasterAccountId, ?ID_ENTITLEMENTS)).

-spec delete_capability(kz_term:ne_binary()) -> kzd_entitlements:doc().
delete_capability(CapabilityId) ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),

    Updates = [{[<<"capabilities">>, CapabilityId], 'null'}],
    Update = [{'update', Updates}
             ,{'ensure_saved', 'true'}
             ],
    SaveAttempt = kz_datamgr:update_doc(MasterAccountId, entitlements_id(), Update),
    lager:debug("deleting capability ~s: ~p", [CapabilityId, SaveAttempt]),
    handle_update(SaveAttempt).

open_entitlements(AccountId) ->
    open_entitlements(AccountId, ?ID_ENTITLEMENTS).

open_entitlements(AccountId, EntitlementsId) ->
    case kz_datamgr:open_cache_doc(AccountId, EntitlementsId) of
        {'ok', EntitlementsDoc} -> kz_doc:set_account_id(EntitlementsDoc, AccountId);
        {'error', 'not_found'} ->  kz_doc:set_account_id(kz_json:new(), AccountId)
    end.

capabilities_enabled(Capabilities, ProvidedBy) ->
    kz_json:filtermap(fun(CapabilityId, Settings) ->
                              case kzd_capability:enabled(Settings, 'false') of
                                  'false' -> 'false';
                                  'true' ->
                                      {'true'
                                      ,{CapabilityId
                                       ,kzd_capability:set_provided_by(Settings, ProvidedBy)
                                       }
                                      }
                              end
                      end
                     ,Capabilities
                     ).
