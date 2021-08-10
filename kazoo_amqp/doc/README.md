# Kazoo AMQP

1. Maintaining connections to brokers
2. Creating exchanges, queues, bindings
3. Publishing messages
4. gen_listener behaviour for message reception

## Erlang App Architecture

The application's main supervisor, `kz_amqp_sup` starts the following children:

```erlang
    [?WORKER('kz_amqp_connections')
    ,?SUPER('kz_amqp_connection_sup')
    ,?SUPER('kz_amqp_federated_listeners_sup')
    ,?WORKER('kz_amqp_assignments')
    ,?WORKER('kz_amqp_bootstrap')
    ]
```

### `kz_amqp_connections`

Maintains an ETS table for AMQP connections.

### `kz_amqp_connection_sup`

Supervisor for processes that manage a single AMQP connection.

#### `kz_amqp_connection`

Starts a connection process.

On init, assumes the connection is disconnected.

##### When disconnecting

1. If the connection is available, flags the connection as unavailable in `kz_amqp_connections`
2. If the connection has a channel reference (a monitor ref to the amqp_client's channel process), demonitor the ref
3. If the connection has a channel process (the amqp_client channel process), send that PID a `close` message
4. If the connection has a connection reference (a monitor ref tot he amqp_client's connection process), demonitor the ref
5. If the connection has a connection process (the amqp_client connection process, close the connection
6. If the connection pre-initializes channels, set to false (not pre-initialized yet)
7. Spawn and monitor a reconnect PID to send a `connect` message to the `kz_amqp_connection` process.

##### When connecting

1. If the connection is not available, try to start (via `amqp_connection:start/1`) the AMQP connection.
  a. If a failure occurs, go to `disconnected/2` (see `When Disconnecting`)
2. Monitor the amqp_client connection PID
3. Register as the blocked handler (for `connection.blocked` and `connection.unblocked` messages)
4. Cancel the reconnect ref (see `When disconnecting #7`)
5. Create the control channel
   a. set self as the default consumer of the channel
   b. monitor the amqp_client channel PID
6. Declare any pre-defined AMQP exchanges
7. Mark connection as available in `kz_amqp_connections`
8. Initialize pre-channels
   a. Add each channel to `kz_amqp_assignments`

### `kz_amqp_federated_listeners_sup`

Manages `listener_federator` processes (which are `gen_listeners`) that connect to federated (non-local) brokers.

### `kz_amqp_assignments`

Creates an ETS table to track AMQP channel assignments.

An assignment tracks:
- The timstamp of the assignment
- The consumer PID (typically the KAZOO PID, like a `gen_listener` process)
- The KAZOO application of the consumer PID (if possible)
- The `type` of channel
  - `float` channels will be created on whichever broker is available at the time
  - `sticky` channels will only be created on the specified broker when it is available
- The `amqp_client` channel PID
- The `amqp_client` connection PID
- The `broker` URI
- The `assigned` timestamp
- `reconnect` boolean if reconnecting the assignment
- `watchers` - set of consumer processes waiting on a channel, notified when they get assigned a channel

### `kz_amqp_bootstrap`

1. Reads AMQP config from config.ini
2. For each {Zone, Brokers} section, ask `kz_amqp_connections` to add `{Broker, Zone}` connections
3. Block in `init/1` until `kz_amqp_connections:wait_for_available/0` returns
  a. This waits until a primary broker (zone = 'local') is connected
4. Create the `targeted` exchange
