# Kazoo Events

Provides a way for the KAZOO node to bind for common AMQP events and distribute locally versus every app or process bindings for them.

For instance, call events are used by many apps, each of which may be running on the same VM together. Rather than having a `CHANNEL_CREATE` delivered N times to the node, have it be delivered once from the broker and use internal Erlang messaging (via gproc) to distribute the payload.

This limits using up AMQP channels, which have a hard-coded limit of 2047, by allowing apps to not instantiate dynamic `gen_listener` processes (say per-call or per-agent) which would approach the limit.

## Erlang Architecture

### Runtime

```
kazoo_events_sup
      |
      --> kz_event_listeners_sup
                 |
                 --> [kz_event_listener_sup
                              |
                              --> [kz_event_listener,...]
                     ]
```

Simple supervisor tree where the `kz_event_listeners_sup` starts as a SOFO supervisor with `kz_event_listener_sup` as its childspec. Once a KAZOO app (or process) uses a `kz_events:bind*` function, the `kz_events_listeners_sup` will start a `kz_event_listener_sup` supervisor to then start the `gen_listener` pool.

Apps can programmatically start the pool of listeners at startup as well.
