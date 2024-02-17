-ifndef(KAZOO_EVENTS_HRL).

-define(APP_EVENTS, 'kazoo_events').
-define(KZ_EV_CONFIG_CAT, <<"kazoo_events">>).

-define(KZ_EXCHANGE(Name), list_to_binary(["kz_", Name, "_", kz_term:to_binary(node())])).
-define(KZ_CALL_EVENTS_EXCHANGE, ?KZ_EXCHANGE("call_events")).
-define(KZ_CONF_EVENTS_EXCHANGE, ?KZ_EXCHANGE("conf")).
-define(KZ_PRESENCE_EVENTS_EXCHANGE, ?KZ_EXCHANGE("presence")).

-type event_type() :: 'call_events' | 'conf' | 'presence'.

-define(KAZOO_EVENTS_HRL, 'true').
-endif.
