-ifndef(KAZOO_ENDPOINT_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_numbers/include/knm_phone_number.hrl").

-define(APP_NAME, <<"kazoo_endpoint">>).
-define(APP_VERSION, kz_application:application_version('kazoo_endpoint')).
-define(CONFIG_CAT, <<"kazoo_endpoint">>).

-define(CACHE_NAME, 'kazoo_endpoint_cache').

-define(ATTR_LOWER_KEY, <<109,108,112,112>>).
-define(ATTR_UPPER_KEY, <<109,097,120,095,112,114,101,099,101,100,101,110,099,101>>).

-ifdef(TEST).
-define(MODNAME,'kz_endpoint_v4').
-else.
-define(MODNAME,kapps_config:get_atom(?CONFIG_CAT, <<"endpoint_module">>, 'kz_endpoint_v5')).
-endif.

-ifdef(TEST).
-define(MODVERSION,<<"v4">>).
-define(MODVERSION(_V),<<"v4">>).
-else.
-define(MODVERSION,kapps_config:get_ne_binary(?CONFIG_CAT, <<"endpoint_module_version">>, <<"v5">>)).
-define(MODVERSION(V),kz_json:get_ne_binary_value(<<"endpoint_module_version">>, V, kapps_config:get_ne_binary(?CONFIG_CAT, <<"endpoint_module_version">>, <<"v5">>))).
-endif.

-define(EPVERSION, list_to_binary([?MODULE_STRING, "_", ?MODVERSION])).
-define(EPVERSION(V), list_to_binary([?MODULE_STRING, "_", ?MODVERSION(V)])).
-define(EPMODVERSION, kz_term:to_atom(?EPVERSION)).
-define(EPMODVERSION(V), kz_term:to_atom(?EPVERSION(V))).

-define(MOD,(?EPMODVERSION)).
-define(MOD(V),(?EPMODVERSION(V))).

-define(KAZOO_ENDPOINT_HRL, 'true').
-endif.
