%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_conf_tests).

-include_lib("eunit/include/eunit.hrl").

%%------------------------------------------------------------------------------
%% @doc Test binding for and unbinding from pooled configuration events.
%% @end
%%------------------------------------------------------------------------------
bind_unbind_pooled_test_() ->
    {'setup'
    ,fun setup/0
    ,fun cleanup/1
    ,fun(_) ->
             meck:new('kz_events'),
             meck:expect('kz_events', 'bind_conf_changes', fun(_, _, _, _) -> 'ok' end),
             meck:expect('kz_events', 'unbind_conf_changes', fun(_, _, _, _) -> 'ok' end),

             Db = kz_binary:rand_hex(6),
             DocType = <<"user">>,
             Queue = <<"queue">>,
             Props1 = [{'db', Db}, {'doc_type', DocType}, 'pooled'],
             Props2 = [{'keys', [[{'doc_type', DocType}]]}, 'pooled'],
             kapi_conf:bind_q(Queue, Props1),
             kapi_conf:bind_q(Queue, Props2),
             kapi_conf:unbind_q(Queue, Props1),
             kapi_conf:unbind_q(Queue, Props2),

             [?_assert(meck:called('kz_events', 'bind_conf_changes', [<<"*">>, Db, DocType, <<"*">>]))
             ,?_assert(meck:called('kz_events', 'bind_conf_changes', [<<"*">>, <<"*">>, DocType, <<"*">>]))
             ,?_assert(meck:called('kz_events', 'unbind_conf_changes', [<<"*">>, Db, DocType, <<"*">>]))
             ,?_assert(meck:called('kz_events', 'unbind_conf_changes', [<<"*">>, <<"*">>, DocType, <<"*">>]))
             ]
     end
    }.

%%------------------------------------------------------------------------------
%% @doc Test binding for and unbinding from non-pooled configuration events.
%% @end
%%------------------------------------------------------------------------------
bind_unbind_non_pooled_test_() ->
    {'setup'
    ,fun setup/0
    ,fun cleanup/1
    ,fun(_) ->
             meck:new('kz_amqp_util', ['passthrough']),
             meck:expect('kz_amqp_util', 'bind_q_to_configuration', fun(_, _) -> 'ok' end),
             meck:expect('kz_amqp_util', 'unbind_q_from_configuration', fun(_, _) -> 'ok' end),
             meck:expect('kz_amqp_util', 'document_routing_key', fun(_, Db, Type, _) -> {Db, Type} end),

             Db = kz_binary:rand_hex(6),
             DocType1 = <<"user">>,
             DocType2 = <<"device">>,
             Queue = <<"queue">>,
             Props1 = [{'db', Db}, {'type', DocType1}],
             Props2 = [{'db', Db}, {'types', [DocType1, DocType2]}],
             kapi_conf:bind_q(Queue, Props1),
             kapi_conf:bind_q(Queue, Props2),
             kapi_conf:unbind_q(Queue, Props1),
             kapi_conf:unbind_q(Queue, Props2),

             [?_assertEqual(2, meck:num_calls('kz_amqp_util', 'bind_q_to_configuration', [Queue, {Db, DocType1}]))
             ,?_assert(meck:called('kz_amqp_util', 'bind_q_to_configuration', [Queue, {Db, DocType2}]))
             ,?_assertEqual(2, meck:num_calls('kz_amqp_util', 'unbind_q_from_configuration', [Queue, {Db, DocType1}]))
             ,?_assert(meck:called('kz_amqp_util', 'unbind_q_from_configuration', [Queue, {Db, DocType2}]))
             ]
     end
    }.

%%------------------------------------------------------------------------------
%% @doc Shared test setup.
%% @end
%%------------------------------------------------------------------------------
setup() ->
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Shared test cleanup.
%% @end
%%------------------------------------------------------------------------------
cleanup(_) ->
    meck:unload().
