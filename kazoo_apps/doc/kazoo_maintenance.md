## SUP-able functions

| Function                 | Arguments  | Description                                                            |
| --------                 | ---------  | -----------                                                            |
| `console_level/1`        | `(Level)`  | Set the console (Erlang VM's console) log level                        |
| `crash/0`                |            | Creates a debug dump file and halts the VM                             |
| `debug_dump/0`           |            | Created a debug dump file in /tmp/{NODE}_{TIMESTAMP}                   |
| `error_level/1`          | `(Level)`  | Set the error log file's log level                                     |
| `ets_info/0`             |            | Prints information about the system's ETS tables                       |
| `gc_all/0`               |            | Garbage collects all running processes (500ms pause between each proc) |
| `gc_pids/1`              | `(Ps)`     | Garbage collect a list of PIDs                                         |
| `gc_top_mem_consumers/0` |            | Garbage collect the top 10 memory consuming PIDs                       |
| `gc_top_mem_consumers/1` | `(N)`      | Garbage collect the top N memory consuming PIDs                        |
| `hotload/1`              | `(Module)` | Hotload a the corresponding {MODULE}.beam file                         |
| `hotload_app/1`          | `(App)`    | Hotload all listed modules in the {APP}.app                            |
| `mem_info/0`             |            | Prints information about memory usage in the VM                        |
| `mem_info/1`             | `(TopN)`   | Prints information about memory usage in the VM and top N applications |
| `syslog_level/1`         | `(Level)`  | Set the syslog log level                                               |
| `top_mem_consumers/0`    |            | Print the top 10 memory consuming processes                            |
| `top_mem_consumers/1`    | `(Len)`    | Print the top N memory consuming processes                             |

### `mem_info/0` and `mem_info/1`

Reports the memory usage for the Erlang VM and per-Erlang-application:

```
kazoo_maintenance:mem_info().
 VM Memory Info:
  total           :   261M
  processes       :   116M
  processes_used  :   116M
  system          :   144M
  atom            :     3M
  atom_used       :     3M
  binary          :     3M
  code            :    89M
  ets             :     7M

 App Memory Info:
Application     | Memory | Procs  | BigPid
kernel          |     1M |    158 | <0.7138.0> 932K
stdlib          |     1M |    181 | <0.3654.0> 813K
amqp_client     |   993K |    788 | <0.3864.0> 32K
kazoo_apps      |   468K |    151 | <0.4948.0> 4K
rabbit_common   |   421K |    795 | <0.3863.0> 5K
trunkstore      |   387K |    152 | <0.6876.0> 5K
lager           |   360K |      9 | <0.3786.0> 356K
ecallmgr        |   278K |     36 | <0.7309.0> 56K
```

In the above, the reader can see that 36 processes associated with `ecallmgr` use 271K memory with PID `0.7309.0` being the largest of those at 56K memory usage.
