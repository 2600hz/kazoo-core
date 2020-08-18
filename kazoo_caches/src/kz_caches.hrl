-ifndef(KZ_CACHES_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_caches/include/kazoo_caches.hrl").

-define(APP_NAME, <<"kazoo_caches">>).
-define(APP_VERSION, <<"4.0.0">>).

-define(EXPIRES, ?SECONDS_IN_HOUR).
-define(EXPIRE_PERIOD_MS, 10 * ?MILLISECONDS_IN_SECOND).
-define(EXPIRE_PERIOD_MSG, 'expire_cache_objects').

-define(DEFAULT_WAIT_TIMEOUT_MS, 5 * ?MILLISECONDS_IN_SECOND).

-define(MITIGATION, 'stampede_mitigation').

-define(KZ_CACHES_HRL, 'true').
-endif.
