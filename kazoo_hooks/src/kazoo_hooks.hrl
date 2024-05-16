-ifndef(KAZOO_HOOKS_HRL).

-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").

-include("kz_hooks.hrl").

-define(APP_NAME, <<"kazoo_hooks">>).
-define(APP_VERSION, <<"5.0.0">>).
-define(APP, 'kazoo_hooks').
-define(CONFIG_CAT, <<"kazoo_hooks">>).

-type bind_fun() :: kz_events:handler().

-define(KAZOO_HOOKS_HRL, 'true').
-endif.
