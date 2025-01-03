-ifndef(KZ_SERVICE_HRL).

-define(SERVICES_BOM, <<"services_bom">>).
-define(SERVICES_EOM, <<"services_eom">>).

-define(KZ_SERVICE_STORE_MASTER_AUDIT
       ,kapps_config:get_is_true(<<"services">>, <<"should_save_master_audit_logs">>, 'false')
       ).

-define(KZ_SERVICE_ENFORCE_GOOD_STANDING
       ,kapps_config:get_is_true(<<"services">>, <<"enforce_good_standing">>, 'false')
       ).

-define(TOPUP_CONFIG, <<"topup">>).

-define(KZ_SERVICE_HRL, 'true').
-endif.
