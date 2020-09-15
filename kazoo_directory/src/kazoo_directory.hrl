-ifndef(KAZOO_DIRECTORY_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_numbers/include/knm_phone_number.hrl").
-include_lib("kazoo_caches/include/kazoo_caches.hrl").

-define(APP, 'kazoo_directory').
-define(APP_NAME, <<"kazoo_directory">>).
-define(APP_VERSION, kz_application:application_version(?APP)).

-define(CONFIG_CAT, ?APP_NAME).

-define(CACHE_NAME, 'kazoo_directory_cache').

-define(DIRECORY_CACHE_TIME_MS_KEY, <<"directory_cache_time_in_ms">>).
-define(DIRECORY_CACHE_TIME_MS, kz_app_config:get_integer(?APP, ?DIRECORY_CACHE_TIME_MS_KEY)).

-define(KAZOO_DIRECTORY_HRL, 'true').
-endif.
