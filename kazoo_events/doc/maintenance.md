## SUP-able functions

| Function | Arguments | Description |
| -------- | --------- | ----------- |
| `running_listeners/0` |  | |

### `running_listeners/0`

Prints the event type, supervisor PID, and worker PIDs of running listeners:

```bash
sup kazoo_events_maintenance running_listeners
Event Type      | Supervisor   | Worker PIDs
call_events     | <0.9541.0>   | <0.9543.0>, <0.9550.0>, <0.9557.0>, <0.9564.0>, <0.9570.0>
presence        | <0.10094.0>  | <0.10096.0>, <0.10102.0>, <0.10109.0>, <0.10115.0>, <0.10122.0>
```
