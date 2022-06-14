%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
%%% @doc call detail record amqp definitions.
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_cdr).

-export([api_definitions/0, api_definition/1]).

-export([report/1
        ,report_v/1
        ,publish_report/1
        ]).

-export([bind_q/2, unbind_q/2
        ,declare_exchanges/0
        ]).

-export([account_id/1
        ,call_id/1
        ,timestamp/1
        ,interaction_id/1
        ,interaction_key/1
        ,interaction_timestamp/1
        ,interaction_is_root/1
        ]).

-include_lib("kz_amqp_util.hrl").

-define(CDR_EXCHANGE, <<"cdr">>).

-define(CDR_REPORT_REQUIRED_HEADERS
       ,[<<"Account-ID">>
        ,<<"Call-ID">>
        ,<<"Event-Category">>
        ,<<"Event-Name">>
        ]).

-define(CDR_REPORT_OPTIONAL_HEADERS
       ,[<<"Billing-Seconds">>
        ,<<"Call-Control">>
        ,<<"Call-Debug">>
        ,<<"Call-Direction">>
        ,<<"Call-Interaction">>
        ,<<"Callee-ID-Name">>
        ,<<"Callee-ID-Number">>
        ,<<"Caller-Context">>
        ,<<"Caller-Destination-Number">>
        ,<<"Caller-Dialplan">>
        ,<<"Caller-ID-Name">>
        ,<<"Caller-ID-Number">>
        ,<<"Caller-Profile">>
        ,<<"Channel-Answer-State">>
        ,<<"Channel-Call-State">>
        ,<<"Channel-Created-Time">>
        ,<<"Channel-Name">>
        ,<<"Channel-State">>
        ,<<"Custom-Application-Vars">>
        ,<<"Custom-Channel-Vars">>
        ,<<"Custom-SIP-Headers">>
        ,<<"Disposition">>
        ,<<"Duration-Seconds">>
        ,<<"Extended-Data">>
        ,<<"From">>
        ,<<"From-Tag">>
        ,<<"From-URI">>
        ,<<"Hangup-Cause">>
        ,<<"Hangup-Code">>
        ,<<"Local-SDP">>
        ,<<"Media-Server">>
        ,<<"Originated-Legs">>
        ,<<"Originating-Leg-UUID">>
        ,<<"Other-Leg">>
        ,<<"Other-Leg-Call-ID">>
        ,<<"Other-Leg-Caller-ID-Name">>
        ,<<"Other-Leg-Caller-ID-Number">>
        ,<<"Other-Leg-Destination-Number">>
        ,<<"Other-Leg-Direction">>
        ,<<"Presence-ID">>
        ,<<"Remote-SDP">>
        ,<<"Request">>
        ,<<"Ringing-Seconds">>
        ,<<"Switch-Hostname">>
        ,<<"Switch-Nodename">>
        ,<<"Switch-URI">>
        ,<<"Switch-URL">>
        ,<<"Timestamp">>
        ,<<"To">>
        ,<<"To-Tag">>
        ,<<"To-URI">>
        ,<<"Transfer-History">>
        ,<<"User-Agent">>
        ]).


%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [report_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(<<"report">>) ->
    report_definition().

-spec report_definition() -> kapi_definition:api().
report_definition() ->
    EventName = <<"report">>,
    Category = <<"cdr">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"CDR Report">>}
              ,{fun kapi_definition:set_description/2, <<"CDR Report">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun report/1}
              ,{fun kapi_definition:set_validate_fun/2, fun report_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_report/1}
              ,{fun kapi_definition:set_required_headers/2, ?CDR_REPORT_REQUIRED_HEADERS}
              ,{fun kapi_definition:set_optional_headers/2, ?CDR_REPORT_OPTIONAL_HEADERS}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Billing-Seconds">>, fun erlang:is_integer/1}
                ,{<<"Custom-Application-Vars">>, fun kz_json:is_json_object/1}
                ,{<<"Custom-Channel-Vars">>, fun kz_json:is_json_object/1}
                ,{<<"Custom-SIP-Headers">>, fun kz_json:is_json_object/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Report
%% @end
%%------------------------------------------------------------------------------
-spec report(kz_term:api_terms()) -> kz_api:api_formatter_return().
report(Req) ->
    kapi_definition:build_message(Req, report_definition()).

-spec report_v(kz_term:api_terms()) -> boolean().
report_v(Req) ->
    kapi_definition:validate(Req, report_definition()).

-spec publish_report(kz_term:api_terms()) -> 'ok'.
publish_report(API) ->
    Definition = report_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    RK = list_to_binary(["cdr.report."
                        ,account_id(API)
                        ,"."
                        ,kz_amqp_util:encode(call_id(API))
                        ]),
    kz_amqp_util:basic_publish(?CDR_EXCHANGE, RK, Payload).

%%------------------------------------------------------------------------------
%% @doc Bind
%% @end
%%------------------------------------------------------------------------------
-spec bind_q(binary(), kz_term:proplist()) -> 'ok'.
bind_q(Q, Props) ->
    bind_q(Q, Props, props:get_value('restrict_to', Props)).

-spec bind_q(binary(), kz_term:proplist(), kz_term:api_atoms()) -> 'ok'.
bind_q(Q, _Props, 'undefined') ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q, <<"cdr.report.*.*">>, ?CDR_EXCHANGE);
bind_q(Q, Props, ['report'|Restrict]) ->
    'ok' = kz_amqp_util:bind_q_to_exchange(Q, <<"cdr.report.*.*">>, ?CDR_EXCHANGE),
    bind_q(Q, Props, Restrict);
bind_q(Q, Props, [_|Restrict]) ->
    bind_q(Q, Props, Restrict);
bind_q(_Q, _Props, []) -> 'ok'.

%%------------------------------------------------------------------------------
%% @doc Unbind
%% @end
%%------------------------------------------------------------------------------
-spec unbind_q(binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Q, Props) ->
    unbind_q(Q, Props, props:get_value('restrict_to', Props)).

-spec unbind_q(binary(), kz_term:proplist(), kz_term:api_atoms()) -> 'ok'.
unbind_q(Q, _Props, 'undefined') ->
    kz_amqp_util:unbind_q_from_exchange(Q, <<"cdr.report.*.*">>, ?CDR_EXCHANGE);
unbind_q(Q, Props, ['report'|Restrict]) ->
    _ = kz_amqp_util:unbind_q_from_exchange(Q, <<"cdr.report.*.*">>, ?CDR_EXCHANGE),
    unbind_q(Q, Props, Restrict);
unbind_q(Q, Props, [_|Restrict]) ->
    unbind_q(Q, Props, Restrict);
unbind_q(_Q, _Props, []) -> 'ok'.

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:new_exchange(?CDR_EXCHANGE, <<"topic">>).

%%------------------------------------------------------------------------------
%% @doc Helpers.
%% @end
%%------------------------------------------------------------------------------
-spec account_id(kz_term:api_terms()) -> kz_term:ne_binary().
account_id(Props)
  when is_list(Props) ->
    props:get_ne_binary_value(<<"Account-ID">>, Props);
account_id(JObj) ->
    kz_json:get_ne_binary_value(<<"Account-ID">>, JObj).

-spec call_id(kz_term:api_terms()) -> kz_term:ne_binary().
call_id(Props)
  when is_list(Props) ->
    props:get_ne_binary_value(<<"Call-ID">>, Props);
call_id(JObj) ->
    kz_json:get_ne_binary_value(<<"Call-ID">>, JObj).

-spec timestamp(kz_term:api_terms()) -> kz_time:gregorian_seconds().
timestamp(Props)
  when is_list(Props) ->
    props:get_integer_value(<<"Timestamp">>, Props);
timestamp(JObj) ->
    kz_json:get_integer_value(<<"Timestamp">>, JObj).

-spec interaction_id(kz_term:api_terms()) -> kz_term:ne_binary().
interaction_id(Props)
  when is_list(Props) ->
    interaction_id(kz_json:from_list(Props));
interaction_id(JObj) ->
    kz_json:get_ne_binary_value([<<"Call-Interaction">>, <<"Id">>], JObj).

-spec interaction_key(kz_term:api_terms()) -> kz_term:ne_binary().
interaction_key(Props)
  when is_list(Props) ->
    interaction_key(kz_json:from_list(Props));
interaction_key(JObj) ->
    kz_json:get_ne_binary_value([<<"Call-Interaction">>, <<"Key">>], JObj).

-spec interaction_timestamp(kz_term:api_terms()) -> kz_time:gregorian_seconds().
interaction_timestamp(Props)
  when is_list(Props) ->
    interaction_timestamp(kz_json:from_list(Props));
interaction_timestamp(JObj) ->
    kz_json:get_integer_value([<<"Call-Interaction">>, <<"Timestamp">>], JObj).

-spec interaction_is_root(kz_term:api_terms()) -> boolean().
interaction_is_root(Props)
  when is_list(Props) ->
    interaction_is_root(kz_json:from_list(Props));
interaction_is_root(JObj) ->
    kz_json:get_boolean_value([<<"Call-Interaction">>, <<"Is-Root">>], JObj).
