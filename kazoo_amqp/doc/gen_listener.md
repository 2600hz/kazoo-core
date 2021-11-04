# `gen_listener`

An Erlang behaviour for creating AMQP consumers.

Abstracts away a good portion of the AMQP interactions (channel and queue creation, adding bindings, unpacking AMQP payloads), leading the implementing process to just handle the JSON payloads received from the requested bindings.


## Configuration

Create a new `gen_listener` process with:

-   `gen_listener:start_link(Module, Params, InitArgs [,Options])`
-   `gen_listener:start_link(Name, Module, Params, InitArgs [,Options])`

| Argument   | Type                                                                           | Description                                                                       |
|---------- |------------------------------------------------------------------------------ |--------------------------------------------------------------------------------- |
| `Name`     | `{'local', atom()} &#124; {'global', term()} &#124; {'via', module(), term()}` | mirrors a `gen_server` `ServerName` parameter for registering the process's name. |
| `Module`   | `module()`                                                                     | Callback module name                                                              |
| `Params`   | `gen_listener:start_params()`                                                  | Explained in next table                                                           |
| `InitArgs` | `[term()]`                                                                     | Passed as `Module:init(InitArgs)`                                                 |

The `Params` argument is where the calling process defines what AMQP messages to receive and how the process would like to handle those events.

| Argument                                  | Type                                                   | Description                                                                                                      |
| `{'auto_ack', AutoAck}`                   | `AutoAck :: boolean()`                                 | Whether to auto-ack received messages; requires manual acking if 'false'                                         |
| `{'basic_qos', QoS}`                      | `QoS :: non_neg_integer()`                             | if QoS is being set on this queue (controls message prefetch amount                                              |
| `{'bindings', Bindings}`                  | `Bindings :: gen_listener:bindings()`                  | Defines how to bind to AMQP for desired messages                                                                 |
| `{'broker', Broker}`                      | `Broker :: kz_term:ne_binary()`                        | A specific broker's AMQP URI to use                                                                              |
| `{'broker_tag', BrokerTag}`               | `BrokerTag :: kz_term:ne_binary()`                     | Choose a broker based on user-defined tags on the broker config                                                  |
| `{'channel_flow', ChannelFlow}`           | `ChannelFlow :: boolean()`                             | Toggles flow control (back pressure)                                                                             |
| `{'consume_options', ConsumeOptions}`     | `ConsumeOptions :: gen_listener:consume_options()`     | AMQP consume options                                                                                             |
| `{'declare_exchanges', DeclareExchanges}` | `DeclareExchanges :: gen_listener:declare_exchanges()` | Predefined list of {ExchangeName, ExchangeType[, ExchangeOptions]} to declare on connection                      |
| `{'queue_name', QueueName}`               | `QueueName :: binary()`                                | If `<<>>` is used, a "random" queue name will be generated; otherwise try to declare an AMQP queue with the name |
| `{'queue_options', QueueOptions}`         | `QueueOptions :: gen_listener:queue_options()`         | AMQP queue options (like 'durable', 'exclusive', etc)                                                            |
| `{'responders', Responders}`              | `Responders :: gen_listener:responder_start_params()`  | Defines how to handle received messages (more defined in other table)                                            |
| `{'server_confirms', ServerConfirms}`     | `ServerConfirms :: boolean()`                          | Whether to have the broker confirm receipt of a published message                                                |
| `{'spawn_handle_event', ShouldSpawn}`     | `ShouldSpawn :: boolean()`                             | Whether to spawn the call to `handle_event` (and responder's callback) or in the `gen_listener`'s process space  |


### Bindings

In AMQP, a binding key links a queue with an exchange, effectively telling the exchange to put messages with a routing key that matches the binding key into the queue.

In KAZOO, that process is abstracted behind the `kapi_*` modules.

The `bindings` list is made up of the kapi module name (minus `kapi_`) as key and a list of arguments specific to that kapi module.

For instance, a callback module might define bindings as:

```erlang
{'bindings', [{'route', [{'types', [<<"audio">>, <<"video">>]}
                        ,{'restrict_to', ['account']}
                        ]
              }
             ,{'self', []}
             ,{'dialplan', []}
             ]
}
```

The keys 'route', 'self', and 'dialplan' map to `kapi_route.erl`, `kapi_self.erl`, and `kapi_dialplan.erl` respectively.

When setting up bindings, `gen_listener` will declare the queue and call the kapi module's `bind_q/2`, passing the 2nd element of the tuple as the second argument to `bind_q`.

Supposing `QueueName = <<"global_notices">>`, `gen_listener` would call `kapi_route:bind_q(<<"global_notices">>, [{'types',..},{'restrict_to', ...}])`, `kapi_self:bind_q(<<"global_notices">>, [])`, and `kapi_dialplan:bind_q(<<"global_notices">>, [])`. Each kapi module would be responsible for declaring the AMQP binding as appropriate.

Most kapi modules can be found in `core/kazoo_amqp/src/api/`.


#### Federated Bindings

KAZOO manages AMQP connections to all configured brokers, in the local zone and in remote zones.

While KAZOO strives to keep as much traffic in the local zone as possible, it is necessary to receive events from the remote zones in some cases (voice channel counts for limits, for instance).

If the callback module wishes to receive events from remote zones, the binding properties associated with the binding need only include `'federate'` to the properties:

```erlang
{'bindings', [{'foo', ['federate']}]}
```

In the above, `kapi_foo` bindings would be established on all remote brokers (in addition to the normal local broker).

When the binding is added to the `gen_listener`, federated bindings cause several things to happen:

1.  Fetch a list of all available remote, non-hidden brokers
2.  Start new "sub `gen_listener`" processes a. No responders are configured; the sub-process will relay received AMQP messages to the "parent" `gen_listener` b. The binding module + options, minus `'federate'` will be used c. The queue\_name will be appended with "-{ZONE}" where `{ZONE}` is the process' local zonename d. The `kz_amqp_federated_listeners_sup` starts a child `gen_listener` process to manage the bindings e. `listener_federator:handle_event/3` receives AMQP messages and relays them to the parent `gen_listener` via `gen_listener:federated_event/3`
3.  If there are existing `listener_federator` processes, they are informed of the new bindings to add


#### Pooled Bindings

If you want to use the `gen_listener` behaviour but also make use of [AMQP event pools](./event_pools.md), you can include the `'pooled'` parameter in your binding params:

```erlang
[{'call', [{'callid', CallId}, 'pooled']}]
```

This would bind your `gen_listener` process into the `kz_events` call event pool.

If all of your bindings are pooled, your process will not receive a `{'gen_listener', {'is_consuming', boolean()}}` casted message. You will, however, receive a `{'gen_listener', {'pooled_binding', 'call'}}` casted message for each pooled binding, which serves the same purpose of telling your handling module that the binding is ready (if you need to trigger functionality only after you're ready to receive the events you're interested in).

### Responders

Now that bindings are in place to instruct the AMQP broker to deliver messages to the process' queue, responders are used to configure how to process the received messages.

Taking the callflow app's `cf_shared_listener` as an example:

```erlang
{'responders', [{{'cf_util', 'presence_probe'}
                ,[{<<"presence">>, <<"probe">>}]
                }
               ,{{'cf_util', 'presence_mwi_query'}
                ,[{<<"presence">>, <<"mwi_query">>}]
                }
               ,{{'cf_util', 'notification_register'}
                ,[{<<"notification">>, <<"register">>}]
                }
               ,{'cf_route_resume', [{<<"callflow">>, <<"resume">>}]}
               ]
}
```

Each tuple in the `responders` list is composed of a key that maps a Module (with default function `handle_req` implied) or `{Module, Function}`. `Function` (or `handle_req`) is expected to be arity 2, 3, or 4. The value of the tuple is a list of `{EventCategory, EventName}` tuples. Either can be `<<"*">>` to match any event categories/names. Each message received on the queue is matched against these event category/name pairs and, if matched, the AMQP payload is passed to the `{Module, Function}` defined. The lowest arity defined in the module is used (so `Module:Function/2` is checked, then `/3`, then `/4`, if defined.

In the example above, if a message arrives with `EventCategory = <<"presence">>` and `EventName = <<"mwi_query">>`, gen\_listener effectively spawns a process to call `cf_util:presence_mwi_query(JObj, Options)`. `Options` will have any data from the process' return from the `handle_event/2` callback, plus base properties such as `{'server', pid()}` which is the PID of the gen\_listener process.


## `handle_event` callback

The implementing module acts as a `gen_server` with an additional callback: `handle_event`.

This callback can be in two arities:

-   `handle_event/2` receives the JSON object from AMQP and the process's state
-   `handle_event/3` receives the JSON object from AMQP, a proplist of basic info, and the process's state

Returns from `handle_event` can be:

| Function Return                                  | Description                                                                                                   |
| `'ignore'`                                       | stop processing the event and loop                                                                            |
| `{'ignore', NewModuleState}`                     | stop processing the event, update the process's state, and loop                                               |
| `{'ignore', NewModuleState, TimeoutOrHibernate}` | stop processing the event, update the process's state, and loop with `Timeout` milliseconds or `'hibernate'`. |
| `{'reply', AdditionalProps}`                     | Include `AdditionalProps` to basic info for the responder callback                                            |
| `{'reply', AdditionalProps, NewModuleState}`     | Include `AdditionalProps` to basic info for the responder callback, and update the process's state            |

If the process exits while running `handle_event`, a basic proplist will be returned and used by the responder callback.


## Startup

1.  Call `Module:init(InitArgs)` and keep the returned state as `ModuleState` for subsequent callback use.
2.  Request an AMQP channel
    1.  Checks the Params for a `'broker_tag'` or `'broker'` property a. If defined, tries to setup an AMQP connection to the broker (if none exists) b. Requests a channel on that broker connection once up
    2.  If no broker preference, uses the primary broker to associate an AMQP channel to the `gen_listener` process (called the consumer process) a. The channel/consumer assignment is tracked in `kz_amqp_assignments`
    3.  `kz_amqp_assignments` will pass the `gen_listener` process a message when the channel is ready for the `gen_listener`
3.  Prepare any `'responders'` a. For each responder defined, cast the `add_responder` message into `self()` for post-init setup
4.  If no `'queue_name'` or if it is an empty `<<>>`, generate a new queue name a. Roughly constructed as `node()-ModuleName-self()-kz_binary:rand_hex(4)` or `kazoo_apps@host.name-cf_shared_listener-<0.10.20>-abcd1234`
5.  Determine the callback module's `handle_event` arity for use when AMQP messages are received
6.  After gen\_listener:init/1 returns to the supervisor, the process will handle the `'add_responder'` messages it queued up in step 3. a. Check that the responder module exists (the kapi\_\*) b. Check that the module exports `init/0` and that the callback (`{kapi module, Function}`) hasn't already be initialized c. Calls `kapi_*:init()` if defined d. Associates each event category/name pair with the responder `M:F(A)` and adds it to the list of responders tracked
7.  When receiving the `'new_channel'` message from `kz_amqp_assignments`: a. Associate the channel `pid()` in the `gen_listener's` process dictionary b. If any `'declare_exchanges'` are defined, declare them c. If all get declared, start AMQP: declare the new AMQP queue, set QoS, and start consuming (`basic.consume`) d. If the queue is setup, initialize the `'bindings'`


## Callback Module

A module implementing the `gen_listener` behaviour will look a lot like a `gen_server` with `init/1`, `handle_call/3`, `handle_cast/2`, `handle_info/2`, `terminate/2`, and `code_change/3` callbacks.

The other callback to define is `handle_event/2` (see above for more).


### Status messages

The underlying `gen_listener` will send some internal messages to the callback module's `handle_cast/2` during startup and on AMQP dis-/re-connect scenarios:

| Message                                             | Description                                                                                                     |
| {gen\_listener,{created\_queue,QueueName}}          | Queue name assigned to the AMQP queue (or predefined in the options)                                            |
| {gen\_listener,{is\_consuming,IsConsuming}}         | Is the consumer ready? Messages be expected when 'true'                                                         |
| {gen\_listener,{federators\_consuming,IsConsuming}} | If bindings are federated, this message indicates when all remote brokers are being consumed from (when 'true') |
