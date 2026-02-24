%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2026, 2600Hz
%%% @doc Behaviour for setting up an AMQP listener.
%%% Add/remove responders for `Event-Cat'/`Event-Name' pairs. Each responder
%%% corresponds to a module that has defined a `handle/1' function, receiving
%%% the {@link kz_json:object()} from the AMQP request.
%%%
%%% Options:
%%% <dl>
%%%   <dt>`{bindings, [{atom(), kz_term:proplist()}, ...]}'</dt>
%%%   <dd>The type of bindings, with optional properties to pass along.</dd>
%%%
%%%   <dt>`{responders, [{Responder, [{<<"event-category">>, <<"event-name">>}, ...]}]'</dt>
%%%   <dd>`Responder' is the module name to call `handle_req/2' on for those category/name combos. `Responder' can also be `{module, function}',
%%%       to call `module:function/2' instead of `handle_req/2'.
%%%       `Responder' can optionally define a `function/3' (or `handle_req/3') that will be called with the 3rd argument
%%%       consisting of the delivery options including exchange and routing key.
%%%   </dd>
%%%
%%%   <dt>`{queue_name, <<"some name">>}'</dt>
%%%   <dd>Optional, if you want a named queue.</dd>
%%%
%%%   <dt>`{queue_options, [{key, value}]}'</dt>
%%%   <dd>Optional, if the queue requires different parameters.</dd>
%%%
%%%   <dt>`{consume_options, [{key, value}]}'</dt>
%%%   <dd>Optional, if the consumption requires special parameters.</dd>
%%%
%%%   <dt>`{basic_qos, integer()}'</dt>
%%%   <dd>Optional, if QoS is being set on this queue.</dd>
%%%
%%%   <dt>`{broker | broker_tag, kz_term:ne_binary()}'</dt>
%%%   <dd>Optional, for binding to specific brokers.</dd>
%%%
%%%   <dt>`{declare_exchanges, declare_exchanges()}'</dt>
%%%   <dd>Optional, for declaring dynamic exchanges used only in this connection.</dd>
%%
%%%   <dt>`{kz_monitor, boolean()}'</dt>
%%%   <dd>Optional, defaults to 'true', toggles whether the process's mailbox/heap are tracked by kz_monitor.</dd>
%%% </dl>
%%%
%%% @author James Aimonetti
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(gen_listener).
-behaviour(gen_server).

-export([start_link/3
        ,start_link/4
        ,start_link/5
        ,stop/1
        ]).

-export([start_listener/2]).

-export([queue_name/1
        ,bindings/1
        ,responders/1
        ,federators/1, waiting_federators/1
        ,is_consuming/1, wait_until_consuming/2
        ,routing_key_used/1
        ]).

-export([add_queue/4
        ,other_queues/1
        ,rm_queue/2
        ]).

%% gen_server callbacks
-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_continue/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ,format_status/2
        ]).

%% gen_server API
-export([call/2
        ,call/3
        ,cast/2
        ,reply/2

        ,enter_loop/3, enter_loop/4, enter_loop/5
        ]).

%% gen_listener API
-export([add_responder/3
        ,rm_responder/2
        ,rm_responder/3
        ]).

-export([add_binding/2, add_binding/3
        ,b_add_binding/2, b_add_binding/3
        ,rm_binding/2, rm_binding/3
        ,b_rm_binding/2, b_rm_binding/3
        ]).

-export([ack/2, ack/3
        ,nack/2, nack/3, nack/4
        ,reject/2, reject/3
        ]).

-export([execute/4
        ,execute/3
        ,execute/2
        ]).

-export([federated_event/3
        ,notify_of_federator_listener/2
        ,notify_of_federator_consuming/3
        ]).
-export([delayed_cast/3]).
-export([distribute_event/3]).

-include("kz_amqp_util.hrl").
-include("listener_types.hrl").

-define(SERVER_RETRY_PERIOD, 30 * ?MILLISECONDS_IN_SECOND).
-define(TIMEOUT_RETRY_CONN, 5 * ?MILLISECONDS_IN_SECOND).
-define(CALLBACK_TIMEOUT_MSG, 'callback_timeout').

-define(BIND_WAIT, 100).
-define(DEFAULT_KZ_MONITOR, kz_config:get_boolean(?CONFIG_SECTION, <<"kz_monitor_listeners">>, 'true')).

-type module_state() :: any().

-type federator_listener() :: {kz_term:ne_binary(), {pid(), reference()}}.
-type federator_listeners() :: [federator_listener()].

%% {QueueName, {Bindings, QueueProps}}
-type other_queue() :: {kz_term:ne_binary(), {bindings(), kz_term:proplist()}}.
-type other_queues() :: [other_queue()].

-record(state, {queue :: kz_term:api_binary()
               ,is_consuming = 'false' :: boolean()
               ,consuming_requests = [] :: [{kz_term:pid_ref(), reference()}] % [{From, TRef}]
               ,responders = [] :: listener_utils:responders() % {{EvtCat, EvtName}, Module}
               ,bindings = [] :: bindings() % {authentication, [{key, value},...]}
               ,delayed_bindings = [] :: bindings() % for when AMQP channel isn't quite ready
               ,params = [] :: start_params()
               ,module :: module()
               ,module_state :: module_state()
               ,module_timeout_ref :: kz_term:api_reference() % when the client sets a timeout, gen_listener calls shouldn't negate it, only calls that pass through to the client
               ,other_queues = [] :: other_queues()
               ,federators = [] :: federator_listeners()
               ,waiting_federators = [] :: kz_term:ne_binaries() % list of brokers
               ,self = self() :: pid()
               ,consumer_key = kz_amqp_channel:consumer_pid()
               ,consumer_tags = [] :: kz_term:binaries()
               ,handle_event_mfa = 'undefined' :: mfa() | 'undefined'
               ,auto_ack = 'false' :: boolean()
               }).
-type state() :: #state{}.

-type content() :: {kz_term:api_binary(), kz_term:api_binary()}.

-type deliver() :: {basic_deliver(), amqp_basic()}.

-type callback_datum() :: {'server', pid()} |
                          {'queue', kz_term:api_binary()} |
                          {'other_queues', kz_term:ne_binaries()}.
-type callback_data() :: kz_term:proplist() |
                         [callback_datum()].

-export_type([handle_event_return/0
             ,binding/0
             ,bindings/0
             ,basic_deliver/0
             ,callback_data/0
             ,declare_exchanges/0
             ,start_params/0
             ]).

%%%=============================================================================
%%% API
%%%=============================================================================

-callback init(any()) -> {'ok', module_state()} |
                         {'ok', module_state(), timeout() | 'hibernate'} |
                         {'stop', any()} |
                         'ignore'.

-type handle_call_return() :: {'reply', any(), module_state()} |
                              {'reply', any(), module_state(), timeout() | 'hibernate'} |
                              {'noreply', module_state()} |
                              {'noreply', module_state(), timeout() | 'hibernate'} |
                              {'stop', any(), any(), module_state()} |
                              {'stop', any(), module_state()}.

-callback handle_call(any(), {pid(), any()}, module_state()) -> handle_call_return().

-type handle_cast_return() :: {'noreply', module_state()} |
                              {'noreply', module_state(), timeout() | 'hibernate'} |
                              {'stop', any(), module_state()}.

-callback handle_cast(any(), module_state()) -> handle_cast_return().

-type handle_info_return() :: {'noreply', module_state()} |
                              {'noreply', module_state(), timeout() | 'hibernate'} |
                              {'stop', any(), module_state()}.

-callback handle_info(timeout() | any(), module_state()) -> handle_info_return().


-type handle_event_return() :: 'ignore' |
                               {'ignore', module_state()} |
                               {'ignore', module_state(), timeout() | 'hibernate'} |
                               {'reply', kz_term:proplist()} |
                               {'reply', kz_term:proplist(), module_state()}.

-callback handle_event(kz_json:object(), module_state()) -> handle_event_return().
-callback handle_event(kz_json:object(), kz_term:proplist(), module_state()) -> handle_event_return().

-callback terminate('normal' | 'shutdown' | {'shutdown', any()} | any(), module_state()) ->
    any().
-callback code_change(any() | {'down', any()}, module_state(), any()) ->
    {'ok', module_state()} | {'error', any()}.

-optional_callbacks([handle_event/2, handle_event/3]).

-ifdef(TEST).
%% cause the server to crash
-export([crash/1]).
-spec crash(kz_types:server_ref()) -> 'ok'.
crash(Server) ->
    gen_server:cast(Server, 'crash').
-endif.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec start_link(module(), start_params(), list()) -> kz_types:startlink_ret().
start_link(Module, Params, InitArgs) when is_atom(Module),
                                          is_list(Params),
                                          is_list(InitArgs)
                                          ->
    start_link(Module, Params, InitArgs, []).

-spec start_link(module(), start_params(), list(), kz_types:gen_server_options()) -> kz_types:startlink_ret();
                (gen_server:server_name(), module(), start_params(), list()) -> kz_types:startlink_ret().
start_link(Module, Params, InitArgs, Options) when is_atom(Module),
                                                   is_list(Params),
                                                   is_list(InitArgs),
                                                   is_list(Options)
                                                   ->
    Options1 = add_default_options(Options),
    gen_server:start_link(?MODULE, {Module, Params, InitArgs}, Options1);
start_link(Name, Module, Params, InitArgs) when is_atom(Module),
                                                is_list(Params),
                                                is_list(InitArgs)
                                                ->
    start_link(Name, Module, Params, InitArgs, []).

-spec start_link(gen_server:server_name(), module(), start_params(), list(), kz_types:gen_server_options()) -> kz_types:startlink_ret().
start_link(Name, Module, Params, InitArgs, Options) when is_atom(Module),
                                                         is_list(Params),
                                                         is_list(InitArgs),
                                                         is_list(Options)
                                                         ->
    Options1 = add_default_options(Options),
    gen_server:start_link(Name, ?MODULE, {Module, Params, InitArgs}, Options1).

-spec stop(kz_types:server_ref()) -> 'ok'.
stop(Server) ->
    gen_server:stop(Server).

-spec start_listener(pid(), kz_term:proplist()) -> 'ok'.
start_listener(Srv, Params) ->
    gen_server:cast(Srv, {'start_listener', Params}).

-spec queue_name(kz_types:server_ref()) -> kz_term:api_ne_binary().
queue_name(Srv) -> gen_server:call(Srv, 'queue_name').

-spec is_consuming(kz_types:server_ref()) -> boolean().
is_consuming(Srv) -> gen_server:call(Srv, 'is_consuming').

%% @doc block caller until gen_listener is consuming from the bound queue(s)
-spec wait_until_consuming(kz_types:server_ref(), timeout()) -> 'ok' | {'error', 'timeout'}.
wait_until_consuming(Srv, Timeout) ->
    gen_server:call(Srv, {'wait_until_consuming', Timeout}, Timeout + ?MILLISECONDS_IN_SECOND).

-spec responders(kz_types:server_ref()) -> listener_utils:responders().
responders(Srv) -> gen_server:call(Srv, 'responders').

-spec bindings(kz_types:server_ref()) -> bindings().
bindings(Srv) -> gen_server:call(Srv, 'bindings').

-spec federators(kz_types:server_ref()) -> kz_term:pids().
federators(Srv) -> gen_server:call(Srv, 'federators').

%% @doc returns the remote AMQP brokers who don't have a federator yet
%% for this listener
-spec waiting_federators(kz_types:server_ref()) -> kz_term:ne_binaries().
waiting_federators(Srv) -> gen_server:call(Srv, 'waiting_federators').

-spec routing_key_used(basic_deliver()) -> kz_term:ne_binary().
routing_key_used(#'basic.deliver'{routing_key=RoutingKey}) ->
    kz_term:to_binary(RoutingKey).

-spec ack(kz_types:server_ref(), integer() | basic_deliver() | basic_ack()) -> 'ok'.
ack(Srv, Delivery) -> gen_server:cast(Srv, {'ack', Delivery}).

-spec ack(kz_types:server_ref(), integer() | basic_deliver(), boolean()) -> 'ok'.
ack(Srv, Delivery, Multiple) -> gen_server:cast(Srv, {'ack', Delivery, Multiple}).

-spec nack(kz_types:server_ref(), integer() | basic_deliver() | basic_nack()) -> 'ok'.
nack(Srv, Delivery) -> gen_server:cast(Srv, {'nack', Delivery}).

-spec nack(kz_types:server_ref(), integer() | basic_deliver(), boolean()) -> 'ok'.
nack(Srv, Delivery, Requeue) -> gen_server:cast(Srv, {'nack', Delivery, Requeue}).

-spec nack(kz_types:server_ref(), integer() | basic_deliver(), boolean(), boolean()) -> 'ok'.
nack(Srv, Delivery, Requeue, Multiple) -> gen_server:cast(Srv, {'nack', Delivery, Requeue, Multiple}).

-spec reject(kz_types:server_ref(), integer() | basic_deliver()) -> 'ok'.
reject(Srv, Delivery) -> gen_server:cast(Srv, {'reject', Delivery}).

-spec reject(kz_types:server_ref(), integer() | basic_deliver(), boolean()) -> 'ok'.
reject(Srv, Delivery, Requeue) -> gen_server:cast(Srv, {'reject', Delivery, Requeue}).

%%------------------------------------------------------------------------------
%% @doc API functions that mirror `gen_server:call,cast,reply'.
%% @end
%%------------------------------------------------------------------------------
-spec call(kz_types:server_ref(), any()) -> any().
call(Name, Request) -> gen_server:call(Name, {'$client_call', Request}).

-spec call(kz_types:server_ref(), any(), timeout()) -> any().
call(Name, Request, Timeout) -> gen_server:call(Name, {'$client_call', Request}, Timeout).

-spec cast(kz_types:server_ref(), any()) -> 'ok'.
cast(Name, Request) -> gen_server:cast(Name, {'$client_cast', Request}).

-spec delayed_cast(kz_types:server_ref(), any(), pos_integer()) -> 'ok'.
delayed_cast(Name, Request, Wait) when is_integer(Wait), Wait > 0 ->
    _P = kz_process:spawn(
           fun() ->
                   kz_log:put_callid(?MODULE),
                   timer:sleep(Wait),
                   gen_server:cast(Name, Request)
           end),
    'ok'.

-spec reply(kz_term:pid_ref(), any()) -> any().
reply(From, Msg) -> gen_server:reply(From, Msg).

-spec enter_loop(module(), start_params(), any()) -> no_return().
enter_loop(Module, Options, ModuleState) ->
    enter_loop(Module, Options, ModuleState, self(), 'infinity').

-spec enter_loop(module(), start_params(), any(), timeout() | gen_server:server_name()) -> no_return().
enter_loop(Module, Options, ModuleState, ServerName) when is_tuple(ServerName) ->
    enter_loop(Module, Options, ModuleState, ServerName, 'infinity');
enter_loop(Module, Options, ModuleState, Timeout) ->
    enter_loop(Module, Options, ModuleState, self(), Timeout).

-spec enter_loop(module(), start_params(), any(), gen_server:server_name() | pid(), timeout()) -> no_return().
enter_loop(Module, Options, ModuleState, ServerName, Timeout) ->
    {'ok', MyState} = init_state(Module, Options, ModuleState),
    gen_server:enter_loop(?MODULE, [], MyState, ServerName, Timeout).

-spec add_responder(kz_types:server_ref(), responder_callback(), responder_callback_mapping() | responder_callback_mappings()) -> 'ok'.
add_responder(Srv, Responder, {_,_}=Key) ->
    add_responder(Srv, Responder, [Key]);
add_responder(Srv, Responder, [{_,_}|_] = Keys) ->
    gen_server:cast(Srv, {'add_responder', Responder, Keys}).

%%------------------------------------------------------------------------------
%% @doc Removes responder from queue.
%% Empty list removes all.
%% @end
%%------------------------------------------------------------------------------
-spec rm_responder(kz_types:server_ref(), responder_callback()) -> 'ok'.
rm_responder(Srv, Responder) -> rm_responder(Srv, Responder, []).

-spec rm_responder(kz_types:server_ref(), responder_callback(), responder_callback_mappings()) -> 'ok'.
rm_responder(Srv, Responder, {_,_}=Key) ->
    rm_responder(Srv, Responder, [Key]);
rm_responder(Srv, Responder, Keys) ->
    gen_server:cast(Srv, {'rm_responder', Responder, Keys}).

-spec add_binding(kz_types:server_ref(), binding() | kz_term:ne_binary() | atom()) -> 'ok'.
add_binding(Srv, {Binding, Props}) when is_list(Props)
                                        andalso (is_atom(Binding)
                                                 orelse is_binary(Binding)
                                                ) ->
    gen_server:cast(Srv, {'add_binding', kz_term:to_binary(Binding), Props});
add_binding(Srv, Binding) when is_binary(Binding)
                               orelse is_atom(Binding) ->
    gen_server:cast(Srv, {'add_binding', kz_term:to_binary(Binding), []}).

-spec add_binding(kz_types:server_ref(), kz_term:ne_binary() | atom(), kz_term:proplist()) -> 'ok'.
add_binding(Srv, Binding, Props) when is_binary(Binding)
                                      orelse is_atom(Binding) ->
    gen_server:cast(Srv, {'add_binding', kz_term:to_binary(Binding), Props}).

-spec b_add_binding(kz_types:server_ref(), binding() | kz_term:ne_binary() | atom()) -> 'ok'.
b_add_binding(Srv, {Binding, Props}) when is_list(Props)
                                          ,(is_atom(Binding)
                                            orelse is_binary(Binding)
                                           ) ->
    gen_server:call(Srv, {'add_binding', kz_term:to_binary(Binding), Props});
b_add_binding(Srv, Binding) when is_binary(Binding)
                                 orelse is_atom(Binding) ->
    gen_server:call(Srv, {'add_binding', kz_term:to_binary(Binding), []}).

-spec b_add_binding(kz_types:server_ref(), kz_term:ne_binary() | atom(), kz_term:proplist()) -> 'ok'.
b_add_binding(Srv, Binding, Props) when is_binary(Binding)
                                        orelse is_atom(Binding) ->
    gen_server:call(Srv, {'add_binding', kz_term:to_binary(Binding), Props}).

%%------------------------------------------------------------------------------
%% @doc Add responder to a queue.
%% It is expected that responders have been set up already, prior to
%% binding the new queue.
%% @end
%%------------------------------------------------------------------------------
-spec add_queue(kz_types:server_ref(), binary(), kz_term:proplist(), binding() | bindings()) ->
          {'ok', kz_term:ne_binary()} |
          {'error', any()}.
add_queue(Srv, QueueName, QueueProps, {_Type, _Props}=Binding) ->
    add_queue(Srv, QueueName, QueueProps, [Binding]);
add_queue(Srv, QueueName, QueueProps, [{_,_}|_]=Bindings) ->
    gen_server:call(Srv, {'add_queue', QueueName, QueueProps, Bindings}).

-spec rm_queue(kz_types:server_ref(), kz_term:ne_binary()) -> 'ok'.
rm_queue(Srv, ?NE_BINARY = QueueName) ->
    gen_server:cast(Srv, {'rm_queue', QueueName}).

-spec other_queues(kz_types:server_ref()) -> kz_term:ne_binaries().
other_queues(Srv) -> gen_server:call(Srv, 'other_queues').

-spec rm_binding(kz_types:server_ref(), binding()) -> 'ok'.
rm_binding(Srv, {Binding, Props}) ->
    rm_binding(Srv, Binding, Props).

-spec rm_binding(kz_types:server_ref(), kz_term:ne_binary() | atom(), kz_term:proplist()) -> 'ok'.
rm_binding(Srv, Binding, Props) ->
    gen_server:cast(Srv, {'rm_binding', kz_term:to_binary(Binding), Props}).

-spec b_rm_binding(kz_types:server_ref(), binding() | kz_term:ne_binary() | atom()) -> 'ok'.
b_rm_binding(Srv, {Binding, Props}) when is_list(Props)
                                         ,(is_atom(Binding)
                                           orelse is_binary(Binding)
                                          ) ->
    gen_server:call(Srv, {'rm_binding', kz_term:to_binary(Binding), Props});
b_rm_binding(Srv, Binding) when is_binary(Binding)
                                orelse is_atom(Binding) ->
    gen_server:call(Srv, {'rm_binding', kz_term:to_binary(Binding), []}).

-spec b_rm_binding(kz_types:server_ref(), kz_term:ne_binary() | atom(), kz_term:proplist()) -> 'ok'.
b_rm_binding(Srv, Binding, Props) when is_binary(Binding)
                                       orelse is_atom(Binding) ->
    gen_server:call(Srv, {'rm_binding', kz_term:to_binary(Binding), Props}).

-spec federated_event(kz_types:server_ref(), kz_json:object(), kz_term:proplist()) -> 'ok'.
federated_event(Srv, JObj, Props) ->
    gen_server:cast(Srv, {'federated_event', JObj, Props}).

-spec notify_of_federator_listener(pid(), {kz_term:ne_binary(), pid()}) -> 'ok'.
notify_of_federator_listener(Srv, {_Broker, _Pid}=Child) ->
    gen_server:cast(Srv, {'federator_listener', Child}).

-spec notify_of_federator_consuming(pid(), kz_term:ne_binary(), boolean()) -> 'ok'.
notify_of_federator_consuming(Srv, <<Broker/binary>>, IsConsuming)
  when is_pid(Srv),
       is_boolean(IsConsuming)
       ->
    gen_server:cast(Srv, {'federator_is_consuming', self(), Broker, IsConsuming}).

-spec execute(kz_types:server_ref(), module(), atom(), [any()]) -> 'ok'.
execute(Srv, Module, Function, Args) ->
    gen_server:cast(Srv, {'$execute', Module, Function, Args}).

-spec execute(kz_types:server_ref(), atom(), [any()]) -> 'ok'.
execute(Srv, Function, Args) ->
    gen_server:cast(Srv, {'$execute', Function, Args}).

-spec execute(kz_types:server_ref(), function()) -> 'ok'.
execute(Srv, Function) when is_function(Function) ->
    gen_server:cast(Srv, {'$execute', Function}).

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-type init_args() :: {module(), start_params(), list()}.

-spec init(init_args()) -> {'ok', 'null', {'continue', init_args()}}.
init(Args) ->
    {'ok', 'null', {'continue', Args}}.

%%------------------------------------------------------------------------------
%% @doc Takes an existing process and turns it into a `gen_listener'.
%% @end
%%------------------------------------------------------------------------------
-spec init_state(module(), start_params(), module_state()) -> {'ok', state()} | {'stop', any()} | 'ignore'.
init_state(Module, Params, ModuleState) ->
    process_flag('trap_exit', 'true'),
    kz_log:put_callid(Module),

    Application = kz_process:get_application(),
    kz_process:put_application(Application),

    lager:debug("continuing as a gen_listener proc : ~s ~s", [Application, Module]),
    init(Module, Params, ModuleState, 'undefined').

-spec do_init(init_args()) -> {'ok', state()} | {'stop', any()} | 'ignore'.
do_init({Module, Params, InitArgs}) ->
    process_flag('trap_exit', 'true'),
    kz_log:put_callid(Module),

    Application = kz_process:get_application(),
    kz_process:put_application(Application),

    lager:debug("starting new gen_listener proc : ~s ~s"
               ,[Application, Module]
               ),

    'true' = erlang:function_exported(Module, 'init', 1),
    case Module:init(InitArgs) of
        {'ok', MS} -> init(Module, Params, MS, 'undefined');
        {'ok', MS, 'hibernate'} -> init(Module, Params, MS, 'undefined');
        {'ok', MS, Timeout} -> init(Module, Params, MS, start_timer(Timeout));
        {'stop', _R} = STOP -> STOP;
        'ignore' -> 'ignore'
    end.

-spec init(module(), start_params(), module_state(), kz_term:api_reference()) -> {'ok', state()}.
init(Module, Params, ModuleState, TimeoutRef) ->
    _ = [add_responder(self(), Mod, Events)
         || {Mod, Events} <- props:get_value('responders', Params, [])
        ],
    State = #state{module=Module
                  ,module_state=ModuleState
                  ,module_timeout_ref=TimeoutRef
                  ,params=maybe_set_queue_name(Module, Params)
                  ,handle_event_mfa = listener_utils:responder_mfa(Module, 'handle_event')
                  ,auto_ack = props:is_true('auto_ack', Params, 'false')
                  },
    maybe_monitor_me(Params),
    {'ok', start_initial_bindings(State)}.

%% if true, add self() to kz_monitor to keep tabs on how self()'s
%% process mailbox and heap grow. Will alert when thresholds are hit
maybe_monitor_me(Params) ->
    case props:get_value('kz_monitor', Params, ?DEFAULT_KZ_MONITOR) of
        'false' -> 'ok';
        V ->
            monitor_me(V),
            lager:info("process monitoring initiated")
    end.

-spec monitor_me('true' | kz_monitor:proc_thresholds()) -> 'ok'.
monitor_me('true') -> kz_monitor:track_me();
monitor_me(ProcThresholds) -> kz_monitor:track_me(ProcThresholds).

-spec maybe_set_queue_name(module(), start_params()) -> start_params().
maybe_set_queue_name(Module, Params) ->
    case props:is_false('queue_name_always_generate', Params, 'true')
        andalso props:get_value('queue_name', Params) =:= <<>>
    of
        'false' -> Params;
        'true' -> props:set_value('queue_name', kz_amqp_util:new_queue_name(Module), Params)
    end.

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) -> handle_call_return().
handle_call({'add_queue', QueueName, QueueProps, Bindings}, _From, State) ->
    {Q, S} = add_other_queue(QueueName, QueueProps, Bindings, State),
    {'reply', {'ok', Q}, S};
handle_call('other_queues', _From, #state{other_queues=OtherQueues}=State) ->
    {'reply', props:get_keys(OtherQueues), State};
handle_call('queue_name', _From, #state{queue=Q}=State) ->
    {'reply', Q, State};
handle_call('responders', _From, #state{responders=Rs}=State) ->
    {'reply', Rs, State};
handle_call('bindings', _From, #state{bindings=Bs}=State) ->
    {'reply', Bs, State};
handle_call('federators', _From, #state{federators=Fs}=State) ->
    {'reply', [Pid || {_QueueN, {Pid, _Ref}} <- Fs], State};
handle_call('waiting_federators', _From, #state{waiting_federators=WaitingFederators}=State) ->
    {'reply', WaitingFederators, State};
handle_call('is_consuming', _From, #state{is_consuming=IsC}=State) ->
    {'reply', IsC, State};
handle_call({'$client_call', Request}, From, State) ->
    handle_module_call(Request, From, State);
handle_call({'add_binding', _Binding, _Props}=AddBinding, _From, State) ->
    case handle_cast(AddBinding, State) of
        {'noreply', State1} -> {'reply', 'ok', State1};
        {'stop', _Reason, _State1}=Stop -> Stop
    end;
handle_call({'rm_binding', _Binding, _Props}=RmBinding, _From, State) ->
    case handle_cast(RmBinding, State) of
        {'noreply', State1} -> {'reply', 'ok', State1};
        {'stop', _Reason, _State1}=Stop -> Stop
    end;
handle_call({'wait_until_consuming', _Timeout}, _From, #state{is_consuming='true'}=State) ->
    lager:info("consuming from AMQP, telling ~p", [_From]),
    {'reply', 'ok', State};
handle_call({'wait_until_consuming', Timeout}
           ,From
           ,#state{is_consuming='false'
                  ,consuming_requests=Requests
                  }=State
           ) ->
    lager:info("waiting for consumption on AMQP for ~p(~p)", [From, Timeout]),
    TRef = erlang:send_after(Timeout, self(), {'request_timeout', From}),
    {'noreply', State#state{consuming_requests=[{From, TRef} | Requests]}};
handle_call(Request, From, State) ->
    handle_module_call(Request, From, State).

-spec handle_continue(init_args(), 'null') -> {'noreply', state()} | {'stop', any(), 'null'}.
handle_continue(Args, 'null') ->
    case do_init(Args) of
        {'ok', State} -> {'noreply', State};
        {'stop', Reason} -> {'stop', Reason, 'null'};
        'ignore' -> {'stop', 'normal', 'null'}
    end.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> handle_cast_return().
handle_cast({'ack', Delivery}, State) ->
    _A = (catch kz_amqp_util:basic_ack(Delivery)),
    {'noreply', State};
handle_cast({'ack', Delivery, Multiple}, State) ->
    _A = (catch kz_amqp_util:basic_ack(Delivery, Multiple)),
    {'noreply', State};
handle_cast({'nack', Delivery}, State) ->
    _N = (catch kz_amqp_util:basic_nack(Delivery)),
    {'noreply', State};
handle_cast({'nack', Delivery, Requeue}, State) ->
    _N = (catch kz_amqp_util:basic_nack(Delivery, Requeue)),
    {'noreply', State};
handle_cast({'nack', Delivery, Requeue, Multiple}, State) ->
    _N = (catch kz_amqp_util:basic_nack(Delivery, Requeue, Multiple)),
    {'noreply', State};
handle_cast({'reject', Delivery}, State) ->
    _A = (catch kz_amqp_util:basic_reject(Delivery)),
    {'noreply', State};
handle_cast({'reject', Delivery, Requeue}, State) ->
    _A = (catch kz_amqp_util:basic_reject(Delivery, Requeue)),
    {'noreply', State};
handle_cast({'add_queue', QueueName, QueueProps, Bindings}, State) ->
    {_, S} = add_other_queue(QueueName, QueueProps, Bindings, State),
    {'noreply', S};
handle_cast({'rm_queue', QueueName}, #state{other_queues=OtherQueues}=State) ->
    _ = [remove_binding(Binding, Props, QueueName)
         || {Binding, Props} <- props:get_value(QueueName, OtherQueues, [])
        ],
    {'noreply', State#state{other_queues=props:delete(QueueName, OtherQueues)}};
handle_cast({'add_responder', Responder, Keys}, #state{responders=Responders}=State) ->
    {'noreply'
    ,State#state{responders=listener_utils:add_responder(Responders, Responder, Keys)}
    };
handle_cast({'rm_responder', Responder, Keys}, #state{responders=Responders}=State) ->
    {'noreply'
    ,State#state{responders=listener_utils:rm_responder(Responders, Responder, Keys)}
    };
handle_cast({'add_binding', Binding, Props}, State) ->
    {'noreply', handle_add_binding(Binding, Props, State)};
handle_cast({'rm_binding', Binding, Props}, State) ->
    {'noreply', handle_rm_binding(Binding, Props, State)};
handle_cast({'federated_event', JObj, Props}, #state{params=Params}=State) ->
    Deliver = props:get_value('deliver', Props),
    Basic = props:get_value('basic', Props),
    case props:is_true('spawn_handle_event', Params, 'false') of
        'true'  ->
            kz_process:spawn(fun distribute_event/3, [JObj, {Deliver, Basic}, State]),
            {'noreply', State};
        'false' -> distribute_event(JObj, {Deliver, Basic}, State)
    end;

handle_cast({'$execute', _Module, _Function, _Args}=ExecMsg
           ,#state{federators=Federators}=State
           ) ->
    _ = exec_mfa(ExecMsg, Federators),
    {'noreply', State};
handle_cast({'$execute', _Function, _Args}=ExecMsg
           ,#state{federators=Federators}=State
           ) ->
    _ = exec_mfa(ExecMsg, Federators),
    {'noreply', State};
handle_cast({'$execute', _Function}=ExecMsg
           ,#state{federators=Federators}=State
           ) ->
    _ = exec_mfa(ExecMsg, Federators),
    {'noreply', State};

handle_cast({'$client_cast', Message}, State) ->
    handle_module_cast(Message, State);
handle_cast({'start_listener', Params}
           ,#state{queue='undefined'
                  ,is_consuming='false'
                  ,responders=[]
                  ,bindings=[]
                  ,params=[]
                  ,module=Module
                  ,module_state=ModuleState
                  ,module_timeout_ref=TimeoutRef
                  }
           ) ->
    {'ok', #state{}=NewState} = init(Module, Params, ModuleState, TimeoutRef),
    {'noreply', NewState};
handle_cast({'start_listener', _Params}, State) ->
    lager:debug("gen listener asked to start listener but it is already initialized"),
    {'noreply', State};
handle_cast({'pause_consumers'}, #state{is_consuming='true', consumer_tags=Tags}=State) ->
    lists:foreach(fun kz_amqp_util:basic_cancel/1, Tags),
    {'noreply', State};

handle_cast({'resume_consumers'}, #state{queue='undefined'}=State) ->
    {'noreply', State};
handle_cast({'resume_consumers'}
           ,#state{is_consuming='false'
                  ,params=Params
                  ,queue=Q
                  ,other_queues=OtherQueues
                  ,auto_ack=AutoAck
                  }=State
           ) ->

    resume_consumers([{Q, {[], Params}} | OtherQueues], AutoAck),
    {'noreply', State};

handle_cast({'federator_is_consuming', FederatorPid, Broker, IsConsuming}, State) ->
    handle_federator_is_consuming(FederatorPid, Broker, IsConsuming, State);
handle_cast({'federator_listener', {Broker, FederatorPid}}, State) ->
    handle_federator_started(FederatorPid, Broker, State);
handle_cast('crash', _State) ->
    exit('crash');
handle_cast(Message, State) ->
    handle_module_cast(Message, State).

-spec maybe_remove_binding(binding(), binding_module(), kz_term:proplist(), kz_term:ne_binary()) -> boolean().
maybe_remove_binding({B, P}, B, P, Q) ->
    lager:debug("removing ~s: ~p", [B, P]),
    remove_binding(B, P, Q),
    'false';
maybe_remove_binding(_BP, _B, _P, _Q) -> 'true'.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret().
handle_info('retry', State) ->
    {'noreply', handle_amqp_channel_available(State, 'true')};
handle_info({'kz_amqp_assignment', {'new_channel', Reconnected, Channel}}, State) ->
    lager:debug("acquired channel"),
    _ = kz_amqp_channel:consumer_channel(Channel),
    {'noreply', handle_amqp_channel_available(State, Reconnected)};
handle_info({'kz_amqp_assignment', 'lost_channel'}
           ,#state{bindings=ExistingBindings
                  ,params=Params
                  }=State
           ) ->
    lager:debug("lost channel assignment"),
    kz_amqp_channel:remove_consumer_channel(),
    gen_server:cast(self(), {?MODULE, {'is_consuming', 'false'}}),
    %% if there's an error before the start consume
    %% we can potentially have initial Params
    %% set to empty array and therefore loose the bindings
    ParamBindings = props:get_value('bindings', Params, []),
    NewParams = lists:usort(ParamBindings ++ ExistingBindings),
    {'noreply', State#state{is_consuming='false'
                           ,consumer_tags=[]
                           ,bindings=[]
                           ,params=props:set_value('bindings', NewParams, Params)
                           }};
handle_info({#'basic.deliver'{}=BD
            ,#amqp_msg{props=#'P_basic'{content_type=CT
                                       ,content_encoding=CE
                                       }=Basic
                      ,payload=Payload
                      }
            }
           ,#state{params=Params, auto_ack=AutoAck}=State
           ) ->

    maybe_autoack(AutoAck, BD),

    case props:is_true('spawn_handle_event', Params, 'false') of
        'false' ->
            CallId = kz_log:get_callid(),
            Reply = handle_event(binary:copy(Payload), {CT, CE}, {BD, Basic}, State),
            kz_log:put_callid(CallId),
            Reply;
        'true'  ->
            kz_process:spawn(fun handle_event/4, [Payload, {CT, CE}, {BD, Basic}, State]),
            {'noreply', State}
    end;
handle_info({#'basic.return'{}=BR
            ,#amqp_msg{props=#'P_basic'{content_type=CT
                                       ,content_encoding=CE
                                       }
                      ,payload=Payload
                      }
            }
           ,State
           ) ->
    handle_return(binary:copy(Payload), {CT, CE}, BR, State);
handle_info(#'basic.consume_ok'{consumer_tag=CTag}
           ,#state{queue='undefined'}=State
           ) ->
    lager:debug("received consume ok (~s) for abandoned queue", [CTag]),
    {'noreply', State};
handle_info(#'basic.consume_ok'{consumer_tag=CTag}
           ,#state{consuming_requests=Requests
                  ,consumer_tags=CTags
                  ,delayed_bindings=DelayedBindings
                  }=State
           ) ->
    lager:debug("received consume ok (~s) for queue : ~p", [CTag, CTags]),
    gen_server:cast(self(), {?MODULE, {'is_consuming', 'true'}}),

    handle_consuming_requests(Requests),
    handle_delayed_bindings(DelayedBindings),

    {'noreply', State#state{is_consuming='true'
                           ,consuming_requests=[]
                           ,consumer_tags=[CTag | CTags]
                           ,delayed_bindings=[]
                           }};
handle_info(#'basic.cancel_ok'{consumer_tag=CTag}, #state{consumer_tags=CTags}=State) ->
    lager:debug("recv a basic.cancel_ok for tag ~s", [CTag]),
    gen_server:cast(self(), {?MODULE, {'is_consuming', 'false'}}),
    {'noreply', State#state{is_consuming='false'
                           ,consumer_tags=lists:delete(CTag, CTags)
                           }};
handle_info(#'basic.ack'{}=Ack, #state{}=State) ->
    lager:debug("recv a basic.ack ~p", [Ack]),
    handle_confirm(Ack, State);
handle_info(#'basic.nack'{}=Nack, #state{}=State) ->
    lager:debug("recv a basic.nack ~p", [Nack]),
    handle_confirm(Nack, State);
handle_info(#'channel.flow'{active=Active}, State) ->
    lager:debug("received channel flow (~s)", [Active]),
    kz_amqp_util:flow_control_reply(Active),
    gen_server:cast(self(), {?MODULE,{'channel_flow_control', Active}}),
    {'noreply', State};
handle_info({'$server_confirms', ServerConfirms}, State) ->
    gen_server:cast(self(), {?MODULE,{'server_confirms',ServerConfirms}}),
    {'noreply', State};
handle_info({'$channel_flow', Active}, State) ->
    gen_server:cast(self(), {?MODULE,{'channel_flow', Active}}),
    {'noreply', State};
handle_info({'kz_amqp_channel', {Client, Ref, 'consumer_tags'}}, #state{consumer_tags=CTags}=State) ->
    Client ! {?MODULE, Ref, CTags},
    {'noreply', State};
handle_info(?CALLBACK_TIMEOUT_MSG, State) ->
    handle_callback_info('timeout', State);
handle_info({'DOWN', Ref, 'process', Pid, Reason}, State) ->
    handle_down({Pid, Ref}, Reason, State);
handle_info({'request_timeout', From}, #state{consuming_requests=Requests}=State) ->
    lager:info("timed out waiting for request ~p", [From]),
    _ = reply(From, {'error', 'timeout'}),
    {'noreply', State#state{consuming_requests=lists:keydelete(From, 1, Requests)}};
handle_info({'kapi'
            ,{{_Exchange, _RK, {#'P_basic'{content_type=CT
                                          ,content_encoding=CE
                                          }=Basic
                               ,Deliver
                               }
              }
             ,{_EventCategory, _EventName}
             ,Payload
             }
            }
           ,State
           ) ->
    handle_event(Payload, {CT, CE}, {Deliver, Basic}, State);
handle_info(Message, State) ->
    handle_callback_info(Message, State).

%%------------------------------------------------------------------------------
%% @doc Handles the AMQP messages prior to the spawning a handler.
%% Allows listeners to pass options to handlers.
%% @end
%%------------------------------------------------------------------------------
-spec handle_event(kz_term:ne_binary() | kz_json:object(), content(), deliver(), state()) ->
          kz_types:handle_info_ret().
handle_event(<<Payload/binary>>, {<<"application/json">>, <<"gzip">>}, Deliver, State) ->
    JObj = kz_json:decode(zlib:gunzip(Payload)),
    _ = kz_log:put_callid(JObj),
    deliver_event(JObj, Deliver, State);
handle_event(<<Payload/binary>>, {<<"application/json">>, _}, Deliver, State) ->
    JObj = kz_json:decode(Payload),
    _ = kz_log:put_callid(JObj),
    deliver_event(JObj, Deliver, State);
handle_event(<<Payload/binary>>, {<<"application/erlang">>, <<"gzip">>}, Deliver, State) ->
    JObj = binary_to_term(zlib:gunzip(Payload)),
    _ = kz_log:put_callid(JObj),
    distribute_event(JObj, Deliver, State);
handle_event(<<Payload/binary>>, {<<"application/erlang">>, _}, Deliver, State) ->
    JObj = binary_to_term(Payload),
    _ = kz_log:put_callid(JObj),
    distribute_event(JObj, Deliver, State);
handle_event(JObj, {<<"application/json">>, _}, Deliver, State) ->
    kz_log:put_callid(JObj),
    deliver_event(JObj, Deliver, State).

%%------------------------------------------------------------------------------
%% @doc Handles the AMQP messages prior to the spawning a handler.
%% Allows listeners to pass options to handlers.
%% @end
%%------------------------------------------------------------------------------
-spec handle_return(kz_term:ne_binary(), content(), basic_return(), state()) ->  handle_cast_return().
handle_return(Payload, {<<"application/json">>, <<"gzip">>}, BR, State) ->
    JObj = kz_json:decode(zlib:gunzip(Payload)),
    _ = kz_log:put_callid(JObj),
    handle_return(JObj, BR, State);
handle_return(Payload, {<<"application/json">>, _}, BR, State) ->
    JObj = kz_json:decode(Payload),
    _ = kz_log:put_callid(JObj),
    handle_return(JObj, BR, State);
handle_return(Payload, {<<"application/erlang">>, <<"gzip">>}, BR, State) ->
    JObj = binary_to_term(zlib:gunzip(Payload)),
    _ = kz_log:put_callid(JObj),
    handle_return(JObj, BR, State);
handle_return(Payload, {<<"application/erlang">>, _}, BR, State) ->
    JObj = binary_to_term(Payload),
    _ = kz_log:put_callid(JObj),
    handle_return(JObj, BR, State).

-spec handle_return(kz_json:object(), basic_return(), state()) -> handle_cast_return().
handle_return(JObj, BR, State) ->
    Msg = {?MODULE, {'return', JObj, basic_return_to_jobj(BR)}},
    handle_module_cast(Msg, State).

-spec basic_return_to_jobj(basic_return()) -> kz_json:object().
basic_return_to_jobj(#'basic.return'{reply_code=Code
                                    ,reply_text=Msg
                                    ,exchange=Exchange
                                    ,routing_key=RoutingKey
                                    }) ->
    kz_json:from_list([{<<"code">>, Code}
                      ,{<<"message">>, kz_term:to_binary(Msg)}
                      ,{<<"exchange">>, kz_term:to_binary(Exchange)}
                      ,{<<"routing_key">>, kz_term:to_binary(RoutingKey)}
                      ]).

-spec handle_confirm(basic_ack() | basic_nack(), state()) -> handle_cast_return().
handle_confirm(Confirm, State) ->
    Msg = {?MODULE, {'confirm', Confirm}},
    handle_module_cast(Msg, State).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state() | 'null') -> 'ok'.
terminate(_Reason, 'null') -> 'ok';
terminate(Reason, #state{module=Module
                        ,module_state=ModuleState
                        ,federators=Fs
                        ,consumer_tags=Tags
                        }) ->
    Terminated = (catch Module:terminate(Reason, ModuleState)),
    kz_amqp_assignments:release_consumer(Tags),
    _ = [catch listener_federator:stop(F) || {_Broker, {F, _Ref}} <- Fs],
    maybe_log_module_terminate(Module, Reason, Terminated).

-spec maybe_log_module_terminate(module(), any(), any()) -> 'ok'.
maybe_log_module_terminate(_Module, _Reason, 'ok') -> 'ok';
maybe_log_module_terminate(Module, Reason, Terminated) ->
    lager:debug("~s terminated (~p): ~p", [Module, Reason, Terminated]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVersion, State, _Extra) ->
    {'ok', State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Add default `gen_server' options to those passed for starting this
%% listener.
%% @end
%%------------------------------------------------------------------------------
-spec add_default_options(kz_types:gen_server_options()) -> kz_types:gen_server_options().
add_default_options(Options) ->
    SpawnOptions = props:get_value('spawn_opt', Options, []),
    SpawnOptions1 = props:insert_value('message_queue_data', 'off_heap', SpawnOptions),
    props:set_value('spawn_opt', SpawnOptions1, Options).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_down(kz_term:pid_ref(), any(), state()) ->
          {'noreply', state()}.
handle_down({Pid, Ref}, Reason, #state{federators=Fs}=State) ->
    case lists:keytake({Pid, Ref}, 2, Fs) of
        'false' -> handle_callback_info({'DOWN', Ref, 'process', Pid, Reason}, State);
        {'value', {Broker, _PidRef}, UpdatedFs} ->
            lager:warning("federator ~p to ~s down: ~p", [_PidRef, Broker, Reason]),
            {'noreply', State#state{federators=UpdatedFs}}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_callback_info(any(), state()) -> handle_info_return().
handle_callback_info(Message
                    ,#state{module=Module
                           ,module_state=ModuleState
                           ,module_timeout_ref=OldRef
                           }=State
                    ) ->
    _ = stop_timer(OldRef),
    try Module:handle_info(Message, ModuleState) of
        {'noreply', ModuleState1} ->
            {'noreply', State#state{module_state=ModuleState1}};
        {'noreply', ModuleState1, 'hibernate'} ->
            {'noreply', State#state{module_state=ModuleState1}, 'hibernate'};
        {'noreply', ModuleState1, Timeout} ->
            Ref = start_timer(Timeout),
            {'noreply', State#state{module_state=ModuleState1
                                   ,module_timeout_ref=Ref
                                   }
            };
        {'stop', Reason, ModuleState1} ->
            {'stop', Reason, State#state{module_state=ModuleState1}}
    catch
        ?STACKTRACE(_E, R, ST)
        lager:debug("handle_info exception: ~s: ~p", [_E, R]),
        kz_log:log_stacktrace(ST),
        {'stop', R, State}
        end.

-spec format_status('normal' | 'terminate', [kz_term:proplist() | state()]) -> any().
format_status(_Opt
             ,[_PDict
              ,#state{module=Module
                     ,module_state=ModuleState
                     }=State
              ]) ->
    case erlang:function_exported(Module, 'format_status', 2) of
        'true' -> Module:format_status(_Opt, [_PDict, ModuleState]);
        'false' ->
            [{'data', [{"Module State", ModuleState}
                      ,{"Module", Module}
                      ,{"Listener State", State}
                      ]
             }]
    end.

-spec deliver_event(kz_json:object(), deliver(), state()) ->  kz_types:handle_info_ret().
deliver_event(JObj, {_ , #'P_basic'{headers='undefined'}}=BasicDeliver, State) ->
    distribute_event(JObj, BasicDeliver, State);
deliver_event(JObj, {_ , Basic}=BasicDeliver, State) ->
    case kz_amqp_basic:header_value(Basic, ?KEY_AMQP_ZONE) of
        'undefined' -> distribute_event(JObj, BasicDeliver, State);
        Zone -> distribute_event(kz_json:set_value(?KEY_AMQP_ZONE, Zone, JObj), BasicDeliver, State)
    end.

-spec distribute_event(kz_json:object(), deliver(), state()) ->  kz_types:handle_info_ret().
distribute_event(JObj, {_ , #'P_basic'{headers='undefined'}}=BasicDeliver, State) ->
    case callback_handle_event(JObj, BasicDeliver, State) of
        'ignore' -> {'noreply', State};
        {'ignore', ModuleState} -> {'noreply', State#state{module_state=ModuleState}};
        {'ignore', ModuleState, 'hibernate'} -> {'noreply', State#state{module_state=ModuleState}, 'hibernate'};
        {'ignore', ModuleState, Timeout} -> {'noreply', State#state{module_state=ModuleState}, Timeout};
        {CallbackData, ModuleState} -> distribute_event(CallbackData, JObj, BasicDeliver, State#state{module_state=ModuleState});
        CallbackData -> distribute_event(CallbackData, JObj, BasicDeliver, State)
    end;
distribute_event(JObj, {Deliver,Basic}=BasicDeliver, State) ->
    case kz_amqp_basic:header_value(Basic, ?KEY_DELIVER_TO_PID) of
        'undefined' ->
            case callback_handle_event(JObj, BasicDeliver, State) of
                'ignore' -> {'noreply', State};
                {'ignore', ModuleState} -> {'noreply', State#state{module_state=ModuleState}};
                {'ignore', ModuleState, 'hibernate'} -> {'noreply', State#state{module_state=ModuleState}, 'hibernate'};
                {'ignore', ModuleState, Timeout} -> {'noreply', State#state{module_state=ModuleState}, Timeout};
                {CallbackData, ModuleState} -> distribute_event(CallbackData, JObj, BasicDeliver, State#state{module_state=ModuleState});
                CallbackData -> distribute_event(CallbackData, JObj, BasicDeliver, State)
            end;
        Pid ->
            Props = [{'basic', Basic}
                    ,{'deliver', Deliver}
                    ],
            Msg = kapi:delivery_message(JObj, Props),
            {{Exchange, RK, _}, {Category, Event}, _} = Msg,
            lager:debug("delivering ~s/~s ~s/~s to pid ~s", [Exchange, RK, Category, Event, Pid]),
            kz_term:to_pid(Pid) ! {'kapi', Msg},
            {'noreply', State}
    end.

-spec distribute_event(callback_data(), kz_json:object(), deliver(), state()) -> {'noreply', state()}.
distribute_event(CallbackData, JObj, Deliver, #state{responders=Responders
                                                    ,consumer_key=ConsumerKey
                                                    }=State) ->
    Key = kz_api:event_type(JObj),
    Channel = kz_amqp_channel:consumer_channel(),
    _ = [kz_process:spawn(fun client_handle_event/6, [JObj
                                                     ,Channel
                                                     ,ConsumerKey
                                                     ,Callback
                                                     ,CallbackData
                                                     ,Deliver
                                                     ])
         || {Evt, Callback} <- Responders,
            maybe_event_matches_key(Key, Evt)
        ],
    {'noreply', State}.

-spec client_handle_event(kz_json:object(), kz_term:api_pid() | kz_amqp_channel:consumer_channel(), kz_amqp_channel:consumer_pid(), responder_mfa(), callback_data(), deliver()) -> any().
client_handle_event(JObj, 'undefined', ConsumerKey, Callback, CallbackData, Deliver) ->
    lager:warning("no consumer channel to provide to spawned process"),
    _ = kz_log:put_callid(JObj),
    _ = kz_amqp_channel:consumer_pid(ConsumerKey),
    client_handle_event(JObj, Callback, CallbackData, Deliver);
client_handle_event(JObj, #kz_amqp_assignment{channel=Channel}, ConsumerKey, Callback, CallbackData, Deliver)
  when is_pid(Channel)->
    _ = kz_log:put_callid(JObj),
    _ = kz_amqp_channel:consumer_pid(ConsumerKey),
    _ = is_process_alive(Channel)
        andalso kz_amqp_channel:consumer_channel(Channel),
    client_handle_event(JObj, Callback, CallbackData, Deliver);
client_handle_event(JObj, Channel, ConsumerKey, Callback, CallbackData, Deliver)
  when is_pid(Channel) ->
    _ = kz_log:put_callid(JObj),
    _ = kz_amqp_channel:consumer_pid(ConsumerKey),
    _ = is_process_alive(Channel)
        andalso kz_amqp_channel:consumer_channel(Channel),
    client_handle_event(JObj, Callback, CallbackData, Deliver);
client_handle_event(JObj, _Channel, ConsumerKey, Callback, CallbackData, Deliver) ->
    lager:warning("no usable consumer channel to provide to spawned process"),
    _ = kz_log:put_callid(JObj),
    _ = kz_amqp_channel:consumer_pid(ConsumerKey),
    client_handle_event(JObj, Callback, CallbackData, Deliver).

-spec client_handle_event(kz_json:object(), responder_mfa(), callback_data(), deliver()) -> any().
client_handle_event(JObj, {Fun, 4}, CallbackData, {BasicDeliver, Basic}) ->
    Fun(JObj, CallbackData, BasicDeliver, Basic);
client_handle_event(JObj, {Fun, 3}, CallbackData, {BasicDeliver, _Basic}) ->
    Fun(JObj, CallbackData, BasicDeliver);
client_handle_event(JObj, {Fun, 2}, CallbackData, _Deliver) ->
    Fun(JObj, CallbackData);
client_handle_event(JObj, {Module, Fun, 4}, CallbackData, {BasicDeliver, Basic}) ->
    Module:Fun(JObj, CallbackData, BasicDeliver, Basic);
client_handle_event(JObj, {Module, Fun, 3}, CallbackData, {BasicDeliver, _Basic}) ->
    Module:Fun(JObj, CallbackData, BasicDeliver);
client_handle_event(JObj, {Module, Fun, 2}, CallbackData, _Deliver) ->
    Module:Fun(JObj, CallbackData).

-spec callback_handle_event(kz_json:object(), deliver(), state()) ->
          'ignore' |
          {'ignore', module_state()} |
          {'ignore', module_state(), 'hibernate' | timeout()} |
          callback_data() |
          {callback_data(), module_state()}.
callback_handle_event(_JObj
                     ,{Deliver, Basic}
                     ,#state{module_state=ModuleState
                            ,queue=Queue
                            ,other_queues=OtherQueues
                            ,self=Self
                            ,handle_event_mfa='undefined'
                            }
                     ) ->
    [{'server', Self}
    ,{'queue', Queue}
    ,{'basic', Basic}
    ,{'deliver', Deliver}
    ,{'other_queues', props:get_keys(OtherQueues)}
    ,{'state', ModuleState}
    ];

callback_handle_event(JObj
                     ,{Deliver, Basic}
                     ,#state{module_state=ModuleState
                            ,queue=Queue
                            ,other_queues=OtherQueues
                            ,self=Self
                            ,handle_event_mfa=MFA
                            }=_State
                     ) ->
    Props = [{'queue', Queue}
            ,{'basic', Basic}
            ,{'deliver', Deliver}
            ,{'other_queues', props:get_keys(OtherQueues)}
            ],

    case callback_handle_event(JObj, Props, MFA, ModuleState) of
        'ignore' -> 'ignore';
        {'ignore', _NewModuleState} = Reply -> Reply;
        {'ignore', _NewModuleState, _TimeoutOrHibernate} = Reply -> Reply;
        {'reply', NewProps} when is_list(NewProps) ->
            [{'server', Self}
            ,{'queue', Queue}
            ,{'basic', Basic}
            ,{'deliver', Deliver}
            ,{'other_queues', props:get_keys(OtherQueues)}
            | NewProps
            ];
        {'reply', NewProps, NewModuleState} when is_list(Props) ->
            {[{'server', Self}
             ,{'queue', Queue}
             ,{'basic', Basic}
             ,{'deliver', Deliver}
             ,{'other_queues', props:get_keys(OtherQueues)}
             | NewProps
             ]
            ,NewModuleState
            };
        {'EXIT', Why} ->
            lager:error("CRASH in handle_event ~p : ~p", [Why, _State]),
            [{'server', Self}
            ,{'queue', Queue}
            ,{'basic', Basic}
            ,{'deliver', Deliver}
            ,{'other_queues', props:get_keys(OtherQueues)}
            ,{'state', ModuleState}
            ]
    end.

-spec callback_handle_event(kz_json:object(), kz_term:proplist(), mfa(), module_state()) ->
          handle_event_return() |
          {'EXIT', any()}.
callback_handle_event(JObj, _, {Module, Fun, 2}, ModuleState) ->
    catch Module:Fun(JObj, ModuleState);
callback_handle_event(JObj, Props, {Module, Fun, 3}, ModuleState) ->
    catch Module:Fun(JObj, Props, ModuleState);
callback_handle_event(_, _, _, _) ->
    {'EXIT', 'not_exported'}.

%% allow wildcard (<<"*">>) in the Key to match either (or both) Category and Name
-spec maybe_event_matches_key(responder_callback_mapping(), responder_callback_mapping()) -> boolean().
maybe_event_matches_key(Evt, Evt) -> 'true';
maybe_event_matches_key({_,_}, {<<"*">>, <<"*">>}) -> 'true';
maybe_event_matches_key({_, Name}, {<<"*">>, Name}) -> 'true';
maybe_event_matches_key({Cat, _}, {Cat, <<"*">>}) -> 'true';
maybe_event_matches_key(_A, _B) -> 'false'.

-spec start_amqp(kz_term:proplist(), boolean()) ->
          {'ok', binary()} |
          {'error', _}.
start_amqp(Props, AutoAck) ->
    QueueProps = props:get_value('queue_options', Props, []),
    QueueName0 = props:get_value('queue_name', Props, <<>>),
    ConsumeOptions = props:get_value('consume_options', Props, []),

    case kz_amqp_util:new_queue(QueueName0, QueueProps) of
        {'error', _}=E -> E;
        QueueName1 ->
            set_qos(QueueName0, props:get_value('basic_qos', Props)),
            case start_consumer(QueueName1, maybe_configure_auto_ack(ConsumeOptions, AutoAck)) of
                'ok' ->
                    lager:debug("queue started: ~s", [QueueName1]),
                    {'ok', QueueName1};
                {'error', _}=E -> E
            end
    end.

-spec set_qos(binary(), 'undefined' | non_neg_integer()) -> 'ok'.
set_qos(<<>>, 'undefined') ->
    case kz_config:get_integer(?CONFIG_SECTION, <<"prefetch">>) of
        [N] when is_integer(N) ->
            lager:debug("random queue getting config.ini QoS settings(~p) applied", [N]),
            set_qos(N);
        _ ->
            lager:debug("random queue getting default QoS settings(1) applied"),
            set_qos(?DEFAULT_PREFETCH)
    end;
set_qos(_QueueName, 'undefined') ->
    lager:debug("named queue has no QoS settings");
set_qos(_QueueName, N) when is_integer(N), N >= 0 ->
    lager:debug("applying QoS prefetch of ~p", [N]),
    set_qos(N).

-spec set_qos(non_neg_integer()) -> 'ok'.
set_qos(N) ->
    catch(kz_amqp_util:basic_qos(N)),
    'ok'.

-spec start_consumer(kz_term:ne_binary(), kz_term:api_proplist()) -> command_ret().
start_consumer(Q, 'undefined') ->
    start_consumer(Q, []);
start_consumer(Q, ConsumeProps) ->
    try
        kz_amqp_util:basic_consume(Q, ConsumeProps)
    catch
        Exc:Msg:_ST ->
            lager:warning("error starting consumer: ~p / ~p", [Exc, Msg]),
            {'error', Msg}
    end.

resume_consumers(Queues, AutoAck) ->
    _ = [resume_consumer(Queue, props:get_value('consume_options', Params, []), AutoAck)
         || {Queue, {_Bindings, Params}} <- Queues
        ],
    lager:info("resumed consumers for queues").

resume_consumer(Queue, ConsumeOptions, AutoAck) ->
    start_consumer(Queue, maybe_configure_auto_ack(ConsumeOptions, AutoAck)).

-spec remove_binding(binding_module(), kz_term:proplist(), kz_term:api_binary()) -> 'ok'.
remove_binding(Binding, Props, Q) ->
    Wapi = list_to_binary([<<"kapi_">>, kz_term:to_binary(Binding)]),
    lager:debug("trying to remove bindings with ~s:unbind_q(~s, ~p)", [Wapi, Q, Props]),
    try (kz_term:to_atom(Wapi, 'true')):unbind_q(Q, Props)
    catch
        'error':'undef' ->
            erlang:error({'api_module_undefined', Wapi})
    end.

-spec create_binding(kz_term:ne_binary(), kz_term:proplist(), kz_term:api_ne_binary()) -> any().
create_binding(Binding, Props, QueueName) when not is_binary(Binding) ->
    create_binding(kz_term:to_binary(Binding), Props, QueueName);
create_binding(Binding, Props, QueueName) ->
    APIModule = kz_term:to_atom(<<"kapi_", Binding/binary>>, 'true'),
    declare_binding_exchanges(APIModule),
    'true' = kz_module:is_exported(APIModule, 'bind_q', 2),
    APIModule:bind_q(QueueName, Props).

-spec declare_binding_exchanges(module()) -> 'ok'.
declare_binding_exchanges(APIModule) ->
    case kz_module:is_exported(APIModule, 'declare_exchanges', 0) of
        'true' -> APIModule:declare_exchanges();
        'false' -> 'ok'
    end.

-spec stop_timer(kz_term:api_reference()) -> non_neg_integer() | 'false'.
stop_timer('undefined') -> 'false';
stop_timer(Ref) when is_reference(Ref) -> erlang:cancel_timer(Ref).

-spec start_timer(timeout()) -> kz_term:api_reference().
start_timer(0) ->
    self() ! ?CALLBACK_TIMEOUT_MSG,
    'undefined';
start_timer(Timeout) when is_integer(Timeout)
                          andalso Timeout >= 0 ->
    erlang:send_after(Timeout, self(), ?CALLBACK_TIMEOUT_MSG);
start_timer(_) -> 'undefined'.

-spec add_other_queue(binary(), kz_term:proplist(), kz_term:proplist(), state()) -> {kz_term:ne_binary(), state()}.
add_other_queue(<<>>, QueueProps, Bindings, #state{other_queues=OtherQueues, auto_ack=AutoAck}=State) ->
    {'ok', Q} = start_amqp(QueueProps, AutoAck),
    gen_server:cast(self(), {?MODULE, {'created_queue', Q}}),

    _ = [create_binding(Type, BindProps, Q) || {Type, BindProps} <- Bindings],
    {Q, State#state{other_queues=[{Q, {Bindings, QueueProps}}|OtherQueues]}};
add_other_queue(QueueName, QueueProps, Bindings, #state{other_queues=OtherQueues, auto_ack=AutoAck}=State) ->
    {'ok', Q} = start_amqp([{'queue_name', QueueName} | QueueProps], AutoAck),
    gen_server:cast(self(), {?MODULE, {'created_queue', Q}}),
    _ = [create_binding(Type, BindProps, Q) || {Type, BindProps} <- Bindings],
    case props:get_value(QueueName, OtherQueues) of
        'undefined' ->
            {Q, State#state{other_queues=[{Q, {Bindings, QueueProps}}|OtherQueues]}};
        OldBindings ->
            {Q, State#state{other_queues=[{Q, {Bindings ++ OldBindings, QueueProps}}
                                         | props:delete(QueueName, OtherQueues)
                                         ]}}
    end.

-spec handle_module_call(any(), kz_term:pid_ref(), state()) -> handle_call_return().
handle_module_call(Request, From, #state{module=Module
                                        ,module_state=ModuleState
                                        ,module_timeout_ref=OldRef
                                        }=State) ->
    _ = stop_timer(OldRef),
    try Module:handle_call(Request, From, ModuleState) of
        {'reply', Reply, ModuleState1} ->
            {'reply'
            ,Reply
            ,State#state{module_state=ModuleState1
                        ,module_timeout_ref='undefined'
                        }
            };
        {'reply', Reply, ModuleState1, 'hibernate'} ->
            {'reply'
            ,Reply
            ,State#state{module_state=ModuleState1
                        ,module_timeout_ref='undefined'
                        }
            ,'hibernate'
            };
        {'reply', Reply, ModuleState1, Timeout} ->
            {'reply', Reply
            ,State#state{module_state=ModuleState1
                        ,module_timeout_ref=start_timer(Timeout)
                        }
            };
        {'noreply', ModuleState1} ->
            {'noreply', State#state{module_state=ModuleState1}};
        {'noreply', ModuleState1, 'hibernate'} ->
            {'noreply', State#state{module_state=ModuleState1}, 'hibernate'};
        {'noreply', ModuleState1, Timeout} ->
            {'noreply'
            ,State#state{module_state=ModuleState1
                        ,module_timeout_ref=start_timer(Timeout)
                        }
            };
        {'stop', Reason, ModuleState1} ->
            {'stop', Reason, State#state{module_state=ModuleState1}};
        {'stop', Reason, Reply, ModuleState1} ->
            {'stop', Reason, Reply, State#state{module_state=ModuleState1}}
    catch
        ?STACKTRACE(_E, R, ST)
        lager:debug("handle_call exception: ~s: ~p", [_E, R]),
        kz_log:log_stacktrace(ST),
        {'stop', R, State}
        end.

-spec handle_module_cast(any(), state()) -> handle_cast_return().
handle_module_cast(Msg, #state{module=Module
                              ,module_state=ModuleState
                              ,module_timeout_ref=OldRef
                              }=State) ->
    _ = stop_timer(OldRef),
    try Module:handle_cast(Msg, ModuleState) of
        {'noreply', ModuleState1} ->
            {'noreply', State#state{module_state=ModuleState1}};
        {'noreply', ModuleState1, 'hibernate'} ->
            {'noreply', State#state{module_state=ModuleState1}, 'hibernate'};
        {'noreply', ModuleState1, Timeout} ->
            Ref = start_timer(Timeout),
            {'noreply', State#state{module_state=ModuleState1
                                   ,module_timeout_ref=Ref
                                   }
            };
        {'stop', Reason, ModuleState1} ->
            {'stop', Reason, State#state{module_state=ModuleState1}}
    catch
        ?STACKTRACE(_E, R, ST)
        lager:debug("handle_cast exception: ~s: ~p", [_E, R]),
        kz_log:log_stacktrace(ST),
        {'stop', R, State}
        end.

-spec handle_rm_binding(binding(), kz_term:proplist(), state()) -> state().
handle_rm_binding(Binding, Props, #state{queue=Q
                                        ,bindings=Bs
                                        }=State) ->
    KeepBs = [BP || BP <- Bs,
                    maybe_remove_binding(BP
                                        ,kz_term:to_binary(Binding)
                                        ,Props
                                        ,Q
                                        )],
    maybe_remove_federated_binding(Binding, Props, State),
    State#state{bindings=KeepBs}.

-spec handle_add_binding(binding_module(), kz_term:proplist(), state()) ->
          state().
handle_add_binding(Binding, Props, #state{is_consuming='false'}=State) ->
    lager:info("not consuming yet, checking binding for pooled flag"),
    handle_add_binding_not_consuming(Binding, Props, State, kz_amqp_channel:has_channel());
handle_add_binding(Binding, Props, #state{queue=QueueName
                                         ,bindings=Bindings
                                         }=State) ->
    case lists:keyfind(Binding, 1, Bindings) of
        'false' ->
            lager:debug("creating new binding: '~s'", [Binding]),
            create_binding(Binding, Props, QueueName),
            maybe_update_federated_bindings(State#state{bindings=[{Binding, Props}|Bindings]});
        {Binding, ExistingProps} ->
            handle_existing_binding(Binding, Props, State, QueueName, ExistingProps, Bindings)
    end.

handle_add_binding_not_consuming(Binding, Props, State, 'false') ->
    handle_add_binding_pooled(Binding, Props, State, props:is_true('pooled', Props, 'false'));
handle_add_binding_not_consuming(Binding, Props, State, 'true') ->
    lager:info("have channel, not consuming yet, delaying binding ~p", [Binding]),
    delayed_add_binding(Binding, Props, State).

handle_add_binding_pooled(Binding, Props, #state{params=Params}=State, 'false') ->
    lager:info("binding ~p is not pooled: ~p", [Binding, Props]),
    _ = channel_requisition(Params),
    delayed_add_binding(Binding, Props, State);
handle_add_binding_pooled(Binding, Props, State, 'true') ->
    lager:info("creating pooled binding in ~p: ~p", [Binding, Props]),
    create_binding(Binding, Props, 'undefined'),
    gen_server:cast(self(), {?MODULE, {'pooled_binding', kz_term:to_atom(Binding)}}),
    State.

delayed_add_binding(Binding, Props, #state{delayed_bindings=DelayedBindings}=State) ->
    lager:debug("not consuming yet, delaying binding ~p", [Binding]),
    State#state{delayed_bindings=[{Binding, Props} | DelayedBindings]}.

-spec handle_delayed_bindings(bindings()) -> 'ok'.
handle_delayed_bindings(DelayedBindings) ->
    _ = [add_binding(self(), Binding, Props) || {Binding, Props} <- DelayedBindings],
    'ok'.

-spec handle_existing_binding(binding_module(), kz_term:proplist(), state(), kz_term:ne_binary(), kz_term:proplist(), bindings()) ->
          state().
handle_existing_binding(Binding, Props, State, Q, ExistingProps, Bs) ->
    case binding_props_match(Props, ExistingProps) of
        'true' ->
            lager:debug("binding ~s with the same properties exists", [Binding]),
            State#state{bindings=Bs};
        'false' ->
            lager:debug("creating existing binding '~s' with new props: ~p", [Binding, Props]),
            create_binding(Binding, Props, Q),
            maybe_update_federated_bindings(State#state{bindings=[{Binding, Props}|Bs]})
    end.

-spec binding_props_match(kz_term:proplist(), kz_term:proplist()) -> boolean().
binding_props_match([], []) -> 'true';
binding_props_match([_|_], []) -> 'false';
binding_props_match([], [_|_]) -> 'false';
binding_props_match([{K, V} | Props], ExistingProps) ->
    case props:take_value(K, ExistingProps) of
        {V, EProps} -> binding_props_match(Props, EProps);
        _ -> 'false'
    end;
binding_props_match([K | Props], ExistingProps) ->
    case props:take_value(K, ExistingProps) of
        {'true', EProps} -> binding_props_match(Props, EProps);
        _ -> 'false'
    end.

-spec maybe_update_federated_bindings(state()) -> state().
maybe_update_federated_bindings(#state{bindings=[{_Binding, Props}|_]}=State) ->
    case is_federated_binding(Props) of
        'false' -> State;
        'true' -> update_federated_bindings(State)
    end.

-spec is_federated_binding(binding() | binding_properties()) -> boolean().
is_federated_binding({_BindingModule, Props}) ->
    props:get_value('federate', Props) =:= 'true';
is_federated_binding(Props) ->
    props:get_value('federate', Props) =:= 'true'.

-spec update_federated_bindings(state()) -> state().
update_federated_bindings(#state{}=State) ->
    update_federated_bindings(State, kz_amqp_connections:federated_brokers()).

update_federated_bindings(#state{bindings=[{Binding, _Props}|_]}=State, []) ->
    lager:debug("no federated brokers to connect to, skipping federating binding '~s'", [Binding]),
    State;
update_federated_bindings(#state{bindings=[{Binding, Props}|_]
                                ,federators=ExistingFederators
                                ,waiting_federators=WaitingFederators
                                }=State
                         ,FederatedBrokers
                         ) ->
    NonFederatedProps = props:delete('federate', Props),
    {_Existing, NewBrokers} = broker_connections(ExistingFederators, FederatedBrokers),

    {'ok', NewListeners} = start_new_listeners(NewBrokers, State),

    UpdatedFederators = lists:usort(NewListeners ++ ExistingFederators),
    'ok' = update_existing_listeners_bindings(UpdatedFederators, Binding, NonFederatedProps),

    State#state{federators=UpdatedFederators
               ,waiting_federators=lists:usort(NewBrokers ++ WaitingFederators)
               }.

-spec maybe_remove_federated_binding(binding(), kz_term:proplist(), state()) -> 'ok'.
maybe_remove_federated_binding(Binding, Props, State) ->
    maybe_remove_federated_binding(is_federated_binding(Props), Binding, Props, State).

-spec maybe_remove_federated_binding(boolean(), binding(), kz_term:proplist(), state()) -> 'ok'.
maybe_remove_federated_binding(_Flag, _Binding, _Props, #state{federators=[]}) -> 'ok';
maybe_remove_federated_binding('true', Binding, Props, #state{federators=Fs}) ->
    NonFederatedProps = props:delete('federate', Props),
    remove_federated_binding(Fs, Binding, NonFederatedProps);
maybe_remove_federated_binding(_Flag, _Binging, _Props, _State) -> 'ok'.

-spec broker_connections(federator_listeners(), kz_term:ne_binaries()) ->
          {kz_term:ne_binaries(), kz_term:ne_binaries()}.
broker_connections(Listeners, Brokers) ->
    lists:partition(fun(Broker) ->
                            props:get_value(Broker, Listeners) =/= 'undefined'
                    end
                   ,Brokers
                   ).

-spec start_new_listeners(kz_term:ne_binaries(), state()) ->
          {'ok', federator_listeners()}.
start_new_listeners(Brokers, State) ->
    {'ok', [start_new_listener(Broker, State)
            || Broker <- Brokers
           ]}.

-spec start_new_listener(kz_term:ne_binary(), state()) -> federator_listener().
start_new_listener(Broker, #state{params=StartParams}) ->
    FederateParams = create_federated_params(StartParams),
    {'ok', Pid} = kz_amqp_federated_listeners_sup:start_child(self(), Broker, FederateParams),
    Ref = monitor('process', Pid),
    lager:debug("started federated listener on broker ~s: ~p(~p)", [Broker, Pid, Ref]),
    {Broker, {Pid, Ref}}.

-spec remove_federated_binding(federator_listeners(), binding_module(), kz_term:proplist()) -> 'ok'.
remove_federated_binding(Listeners, Binding, Props) ->
    _ = [?MODULE:rm_binding(Pid, Binding, Props)
         || {_Broker, {Pid, _Ref}} <- Listeners
        ],
    'ok'.

-spec update_existing_listeners_bindings(federator_listeners(), binding_module(), kz_term:proplist()) -> 'ok'.
update_existing_listeners_bindings(Listeners, Binding, Props) ->
    _ = [update_existing_listener_bindings(Listener, Binding, Props)
         || Listener <- Listeners
        ],
    'ok'.

-spec update_existing_listener_bindings(federator_listener(), binding_module(), kz_term:proplist()) -> 'ok'.
update_existing_listener_bindings({_Broker, {Pid, _Ref}}, Binding, Props) ->
    lager:debug("updating listener ~p with ~s", [Pid, Binding]),
    ?MODULE:add_binding(Pid, Binding, Props).

-spec create_federated_params(start_params()) ->
          kz_term:proplist().
create_federated_params(StartParams) ->
    QueueOptions = props:get_value('queue_options', StartParams, []),

    [{'responders', []}
    ,{'bindings', []}
    ,{'queue_name', props:get_value('queue_name', StartParams, <<>>)}
    ,{'queue_options', QueueOptions}
    ,{'consume_options', props:get_value('consume_options', StartParams, [])}
    ,{'calling_application', kz_process:get_application()}
    ].


handle_federator_is_consuming(FederatorPid, Broker, true, #state{waiting_federators = []} = State) ->
    lager:warning("received federator is consuming but we're not waiting for any => ~p / ~s", [FederatorPid, Broker]),
    handle_module_cast({?MODULE, {'federators_consuming', 'true'}}, State);
handle_federator_is_consuming(FederatorPid, Broker, true, #state{waiting_federators = Waiting} = State) ->
    case lists:subtract(Waiting, [Broker]) of
        [] ->
            lager:info("federator ~p for ~s is consuming, all waiting federators are available!", [FederatorPid, Broker]),
            handle_module_cast({?MODULE, {'federators_consuming', 'true'}}, State#state{waiting_federators=[]});
        Remaining ->
            lager:info("federator ~p for ~s is consuming, still waiting for federators: ~p", [FederatorPid, Broker, Remaining]),
            {'noreply', State#state{waiting_federators = Remaining}}
    end;
handle_federator_is_consuming(_FederatorPid, Broker, false, #state{waiting_federators=Waiting}=State) ->
    lager:info("federator ~p on broker ~s is no longer consuming", [_FederatorPid, Broker]),
    handle_module_cast({?MODULE, {'federators_consuming', 'false'}}, State#state{waiting_federators = lists:uniq([Broker | Waiting])}).

is_known_federator(Pid, Broker, Federators) ->
    [P || {B, {P, _}} <- Federators, B=:=Broker, P=:=Pid] =/= [].

update_federated_listener_binding_fun(FederatedListenerRef) ->
    fun({Binding, Props}) ->
            update_existing_listener_bindings(FederatedListenerRef, Binding, props:delete('federate', Props))
    end.

update_federated_listener_bindings(FederatedListenerRef, #state{bindings = Bindings}) ->
    FederatedBindings = lists:filter(fun is_federated_binding/1, Bindings),
    lists:foreach(update_federated_listener_binding_fun(FederatedListenerRef), FederatedBindings).

handle_federator_started(Pid, Broker, #state{federators=Federators, waiting_federators = WaitingFederators} = State) ->
    case is_known_federator(Pid, Broker, Federators) of
        true ->
            {noreply, State};
        false ->
            Ref = monitor('process', Pid),
            lager:info("federator ~p(~p) on broker ~s started", [Pid, Ref, Broker]),
            update_federated_listener_bindings({Broker, {Pid, Ref}}, State),
            NewFederators = [{Broker, {Pid, Ref}} | Federators],
            NewWaitingFederators = lists:uniq([Broker | WaitingFederators]),
            {'noreply', State#state{federators = NewFederators, waiting_federators = NewWaitingFederators}}
    end.

-spec handle_amqp_channel_available(state(), boolean()) -> state().
handle_amqp_channel_available(#state{params=Params}=State, Reconnected) ->
    log_channel_status(Reconnected),

    case maybe_declare_exchanges(props:get_value('declare_exchanges', Params, [])) of
        'ok' ->
            handle_exchanges_ready(State);
        {'error', _E} ->
            lager:debug("error declaring exchanges : ~p", [_E]),
            handle_amqp_errored(State)
    end.

-spec maybe_retry(boolean()) -> reference() | 'ok'.
maybe_retry('true') ->
    erlang:send_after(?SERVER_RETRY_PERIOD, self(), 'retry');
maybe_retry('false') ->
    'ok'.

log_channel_status('true') ->
    lager:debug("channel restarted, let's re-connect");
log_channel_status('false') ->
    lager:debug("channel started, let's connect").

-spec handle_exchanges_ready(state()) -> state().
handle_exchanges_ready(#state{params=Params
                             ,auto_ack=AutoAck
                             }=State
                      ) ->
    case start_amqp(Params, AutoAck) of
        {'ok', QueueName} ->
            %% part of starting the consumer is that
            %% basic.consume is sent and basic.consume_ok is
            %% received (blocking call) so we know we are consuming

            handle_amqp_started(State#state{is_consuming='true'
                                           ,queue=QueueName
                                           }
                               );
        {'error', Reason} ->
            lager:warning("start amqp error ~p", [Reason]),
            handle_amqp_errored(State)
    end.

-spec maybe_start_other_queues(state()) -> state().
maybe_start_other_queues(#state{other_queues=[]}=State) ->
    lager:debug("no other queues to start"),
    State;
maybe_start_other_queues(#state{other_queues=Queues}=State) ->
    lists:foldl(fun start_other_queue_fold/2
               ,State#state{other_queues=[]}
               ,Queues
               ).

start_other_queue_fold({QueueName, {Bindings, QueueParams}}, State) ->
    {_Q, State1} = add_other_queue(QueueName, QueueParams, Bindings, State),
    lager:debug("started other queue ~s as ~s", [QueueName, _Q]),
    State1.

-spec handle_amqp_started(state()) -> state().
handle_amqp_started(#state{params=Params
                          ,queue=QueueName
                          }=State) ->
    try
        State1 = start_initial_bindings(State),
        maybe_server_confirms(props:get_value('server_confirms', Params, 'false')),
        maybe_channel_flow(props:get_value('channel_flow', Params, 'false')),
        gen_server:cast(self(), {?MODULE, {'created_queue', QueueName}}),
        maybe_start_other_queues(State1)
    catch
        Exc:Msg:_ST ->
            lager:warning("error handling amqp started: ~p / ~p", [Exc, Msg]),
            handle_amqp_errored(State)
    end.

-spec handle_amqp_errored(state()) -> state().
handle_amqp_errored(State) ->
    _ = maybe_retry(kz_amqp_channel:is_consumer_channel_valid()),
    State#state{is_consuming='false'}.

-spec maybe_server_confirms(boolean()) -> 'ok'.
maybe_server_confirms('true') ->
    kz_amqp_util:confirm_select();
maybe_server_confirms(_) -> 'ok'.

-spec maybe_channel_flow(boolean()) -> 'ok'.
maybe_channel_flow('true') ->
    kz_amqp_util:flow_control();
maybe_channel_flow(_) -> 'ok'.

-spec maybe_declare_exchanges(declare_exchanges()) ->
          command_ret().
maybe_declare_exchanges([]) -> 'ok';
maybe_declare_exchanges(Exchanges) ->
    lists:foldl(fun maybe_declare_exchange/2, 'ok', Exchanges).

-spec maybe_declare_exchange(declare_exchange(), command_ret()) -> command_ret().
maybe_declare_exchange(Exchange, {'ok', _}) ->
    declare_exchange(Exchange);
maybe_declare_exchange(Exchange, 'ok') ->
    declare_exchange(Exchange);
maybe_declare_exchange(_Exchange, Error) ->
    Error.

-spec declare_exchange(declare_exchange()) -> command_ret().
declare_exchange({Ex, Type, Opts}) ->
    ExchangeCmd = kz_amqp_util:declare_exchange(Ex, Type, Opts),
    kz_amqp_channel:command(ExchangeCmd);
declare_exchange({Ex, Type}) ->
    ExchangeCmd = kz_amqp_util:declare_exchange(Ex, Type),
    kz_amqp_channel:command(ExchangeCmd).

-spec start_initial_bindings(state()) -> state().
start_initial_bindings(#state{params=Params}=State) ->
    lists:foldl(fun({Binding, Props}, StateAcc) ->
                        handle_add_binding(kz_term:to_binary(Binding), Props, StateAcc)
                end
               ,State
               ,props:get_value('bindings', Params, [])
               ).

-spec channel_requisition(start_params()) -> boolean().
channel_requisition([]) -> 'false';
channel_requisition(Params) ->
    case props:get_value('broker_tag', Params) of
        'undefined' ->
            case props:get_value('broker', Params) of
                'undefined' -> kz_amqp_channel:requisition();
                Broker -> maybe_add_broker_connection(Broker)
            end;
        Tag ->
            case kz_amqp_connections:broker_with_tag(Tag) of
                'undefined' -> kz_amqp_channel:requisition();
                Broker -> maybe_add_broker_connection(Broker)
            end
    end.

-spec maybe_add_broker_connection(binary()) -> 'ok'.
maybe_add_broker_connection(Broker) ->
    _ = kz_amqp_channel:consumer_broker(Broker),
    Count = kz_amqp_connections:broker_connections(Broker),
    maybe_add_broker_connection(Broker, Count).

-spec maybe_add_broker_connection(binary(), non_neg_integer()) -> 'ok'.
maybe_add_broker_connection(Broker, Count) when Count =:= 0 ->
    _Connection = kz_amqp_connections:add(Broker, kz_binary:rand_hex(6), [<<"hidden">>]),
    kz_amqp_channel:requisition(self(), Broker);
maybe_add_broker_connection(Broker, _Count) ->
    kz_amqp_channel:requisition(self(), Broker).

maybe_configure_auto_ack(Props, 'false') -> Props;
maybe_configure_auto_ack(Props, 'true') ->
    [{'no_ack', 'false'} | props:delete('no_ack', Props)].

-spec exec_mfa(tuple(), federator_listeners()) -> ['ok'].
exec_mfa({'$execute', Function}=ExecMsg, Federators) ->
    Function(),
    cast_mfa(ExecMsg, Federators);
exec_mfa({'$execute', Function, Args}=ExecMsg, Federators) ->
    erlang:apply(Function, Args),
    cast_mfa(ExecMsg, Federators);
exec_mfa({'$execute', Module, Function, Args}=ExecMsg, Federators) ->
    erlang:apply(Module, Function, Args),
    cast_mfa(ExecMsg, Federators).

-spec cast_mfa(tuple(), federator_listeners()) -> ['ok'].
cast_mfa(ExecMsg, Federators) ->
    [?MODULE:cast(Federator, ExecMsg)
     || {_Broker, {Federator, _Ref}} <- Federators
    ].

-spec maybe_autoack(boolean(), basic_deliver()) -> 'ok'.
maybe_autoack('true', BD) -> catch kz_amqp_util:basic_ack(BD), 'ok';
maybe_autoack('false', _BD) -> 'ok'.

-spec handle_consuming_requests([{kz_term:pid_ref(), reference()}]) -> 'ok'.
handle_consuming_requests(Requests) ->
    _ = [reply_to_request(Request) || Request <- Requests],
    'ok'.

-spec reply_to_request({kz_term:pid_ref(), reference()}) -> 'ok'.
reply_to_request({From, TRef}) ->
    _ = reply(From, 'ok'),
    'ok' = erlang:cancel_timer(TRef, [{'async', 'true'}, {'info', 'false'}]).
