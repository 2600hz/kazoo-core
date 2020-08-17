-ifndef(KAZOO_DIRECTORY_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_numbers/include/knm_phone_number.hrl").

-define(APP, kazoo_directory).
-define(APP_NAME, <<"kazoo_directory">>).
-define(APP_VERSION, <<"5.0">>).
-define(CONFIG_CAT, <<"kazoo_directory">>).

-define(DIRECORY_CACHE_TIME_MS_KEY, <<"directory_cache_time_in_ms">>).
-define(DIRECORY_CACHE_TIME_MS, kz_app_config:get_integer(?APP, ?DIRECORY_CACHE_TIME_MS_KEY)).

-define(KAZOO_DIRECTORY_HRL, 'true').
-endif.
