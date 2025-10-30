-module(kz_entitlements_tests).

-include_lib("eunit/include/eunit.hrl").

account_entitlements_test_() ->
    CapabilityId = kz_binary:rand_hex(5),
    SystemEntitlements = system_entitlements(CapabilityId),

    ResellerEntitlements = account_enrollment(CapabilityId, 'true'),

    AccountEntitlements = kz_json:new(),

    AncestryEntitlements = [ResellerEntitlements, AccountEntitlements],

    AcctCalculatedEntitlements = kz_entitlements:calculate_entitlements(AncestryEntitlements
                                                                       ,kzd_entitlements:capabilities(SystemEntitlements)
                                                                       ),
    ResellerCalculatedEntitlements = kz_entitlements:calculate_entitlements([ResellerEntitlements]
                                                                           ,kzd_entitlements:capabilities(SystemEntitlements)
                                                                           ),

    %% account entitlements
    [{"account has capability", ?_assert(kzd_capability:enabled(kzd_entitlements:capability(AcctCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"account has not enrolled", ?_assert(not kzd_enrollment:enabled(kzd_entitlements:enrollment(AcctCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"account capability is provided by system", ?_assertEqual(<<"system">>, kzd_capability:provided_by(kzd_entitlements:capability(AcctCalculatedEntitlements, CapabilityId)))}

    ,{"reseller has capability", ?_assert(kzd_capability:enabled(kzd_entitlements:capability(ResellerCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"reseller has enrollment", ?_assert(kzd_enrollment:enabled(kzd_entitlements:enrollment(ResellerCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"reseller capability is provided by system", ?_assertEqual(<<"system">>, kzd_capability:provided_by(kzd_entitlements:capability(ResellerCalculatedEntitlements, CapabilityId)))}
    ].

disabled_capability_test_() ->
    CapabilityId = kz_binary:rand_hex(5),
    SystemEntitlements = system_entitlements(CapabilityId, 'false'),

    ResellerEntitlements = account_enrollment(CapabilityId, 'true'),

    AccountEntitlements = kz_json:new(),

    AncestryEntitlements = [ResellerEntitlements, AccountEntitlements],

    AcctCalculatedEntitlements = kz_entitlements:calculate_entitlements(AncestryEntitlements
                                                                       ,kzd_entitlements:capabilities(SystemEntitlements)
                                                                       ),

    ResellerCalculatedEntitlements = kz_entitlements:calculate_entitlements([ResellerEntitlements]
                                                                           ,kzd_entitlements:capabilities(SystemEntitlements)
                                                                           ),

    %% account entitlements
    [{"account has no capability", ?_assert(not kzd_capability:enabled(kzd_entitlements:capability(AcctCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"account has no enrollment", ?_assert(not kzd_enrollment:enabled(kzd_entitlements:enrollment(AcctCalculatedEntitlements, CapabilityId), 'false'))}

    ,{"reseller has no capability", ?_assert(not kzd_capability:enabled(kzd_entitlements:capability(ResellerCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"reseller has no enrollment", ?_assert(not kzd_enrollment:enabled(kzd_entitlements:enrollment(ResellerCalculatedEntitlements, CapabilityId), 'false'))}
    ].

reseller_disabled_entitlements_test_() ->
    CapabilityId = kz_binary:rand_hex(5),
    SystemEntitlements = system_entitlements(CapabilityId),

    ResellerEntitlements = account_enrollment(CapabilityId, 'false'),

    AccountEntitlements = kz_json:new(),

    AncestryEntitlements = [ResellerEntitlements, AccountEntitlements],

    AcctCalculatedEntitlements = kz_entitlements:calculate_entitlements(AncestryEntitlements
                                                                       ,kzd_entitlements:capabilities(SystemEntitlements)
                                                                       ),

    ResellerCalculatedEntitlements = kz_entitlements:calculate_entitlements([ResellerEntitlements]
                                                                           ,kzd_entitlements:capabilities(SystemEntitlements)
                                                                           ),
    %% account entitlements
    [{"account has no capability", ?_assert(not kzd_capability:enabled(kzd_entitlements:capability(AcctCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"account has no enrollment", ?_assert(not kzd_enrollment:enabled(kzd_entitlements:enrollment(AcctCalculatedEntitlements, CapabilityId), 'false'))}

    ,{"reseller has capability", ?_assert(kzd_capability:enabled(kzd_entitlements:capability(ResellerCalculatedEntitlements, CapabilityId), 'false'))}
    ,{"reseller has no enrollment", ?_assert(not kzd_enrollment:enabled(kzd_entitlements:enrollment(ResellerCalculatedEntitlements, CapabilityId), 'false'))}
    ].

system_entitlements(CapabilityId) ->
    system_entitlements(CapabilityId, 'true').

system_entitlements(CapabilityId, Enabled) ->
    kz_json:set_values([{[<<"capabilities">>, CapabilityId, <<"enabled">>], Enabled}
                       ,{[<<"capabilities">>, CapabilityId, <<"provided_by">>], <<"system">>}
                       ]
                      ,kz_json:new()
                      ).

account_enrollment(CapabilityId, Enrolled) ->
    kz_json:set_value([<<"enrollments">>, CapabilityId, <<"enabled">>], Enrolled, kz_json:new()).
