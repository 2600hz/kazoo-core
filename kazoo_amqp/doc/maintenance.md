## SUP-able functions

| Function | Arguments | Description |
| -------- | --------- | ----------- |
| `add_broker/1` | `(Broker)` | |
| `add_broker/2` | `(Broker,Zone)` | |
| `add_connection/1` | `(Broker)` | |
| `add_connection/2` | `(Broker,Zone)` | |
| `broker_summary/0` |  | |
| `channel_summary/0` |  | |
| `connection_summary/0` |  | |
| `consumer_details/0` |  | |
| `consumer_details/1` | `(ProcessUpper)` | |
| `consumer_details/3` | `(NodeNumber,ProcessUpper,ProcessLower)` | |
| `event_pools/0` | | List running AMQP event pools |
| `gc_pool/1` | `(Pool) | (PoolBin)` | |
| `primary_broker/0` |  | |
| `remove_broker/1` | `(Broker)` | |
| `validate_assignments/0` |  | |

### `event_pools/0`

Prints the event type, supervisor PID, and worker PIDs of running listeners:

```bash
sup kazoo_events_maintenance event_pools
Event Type      | Supervisor   | Worker PIDs
call_events     | <0.9541.0>   | <0.9543.0>, <0.9550.0>, <0.9557.0>, <0.9564.0>, <0.9570.0>
presence        | <0.10094.0>  | <0.10096.0>, <0.10102.0>, <0.10109.0>, <0.10115.0>, <0.10122.0>
```
