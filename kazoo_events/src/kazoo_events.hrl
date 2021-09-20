-ifndef(KAZOO_EVENTS_HRL).

-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_amqp/include/kz_amqp.hrl").

-define(APP_NAME, <<"kazoo_events">>).
-define(APP_VERSION, <<"5.0.0">>).
-define(APP, 'kazoo_events').
-define(CONFIG_CAT, <<"kazoo_events">>).

-define(KZ_CALL_EVENTS_EXCHANGE, list_to_binary(["kz_events_", kz_term:to_binary(node())])).

-type event_type() :: 'call_events' | 'presence'.

-define(KAZOO_EVENTS_HRL, 'true').
-endif.
