%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc Listener for authn_req, reg_success, and reg_query AMQP requests
%%% @author James Aimonetti
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_listener).
-behaviour(gen_listener).

-export([start_link/0]).

-export([handle_query/2]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,handle_event/2
        ,terminate/2
        ,code_change/3
        ]).

-include("kazoo_auth.hrl").

-type state() :: #{}.

-define(SERVER, ?MODULE).

-define(RESPONDERS, [{{?MODULE, 'handle_query'}, [{<<"jwt.keys">>, <<"query">>}]}]).
-define(BINDINGS, [{'keys', [{'restrict_to', ['query']}]}]).
-define(QUEUE_NAME, <<"jwt.keys">>).
-define(QUEUE_OPTIONS, [{'exclusive', 'false'}]).
-define(CONSUME_OPTIONS, [{'exclusive', 'false'}]).

%%==============================================================================
%% API
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server.
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_listener:start_link(?SERVER
                           ,[{'responders', ?RESPONDERS}
                            ,{'bindings', ?BINDINGS}
                            ,{'queue_name', ?QUEUE_NAME}
                            ,{'queue_options', ?QUEUE_OPTIONS}
                            ,{'consume_options', ?CONSUME_OPTIONS}
                            ]
                           ,[]
                           ).

%%==============================================================================
%% gen_listener responder
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_query(kz_json:object(), kz_term:proplist()) -> 'ok'.
handle_query(JObj, _Props) ->
    true = kapi_keys:query_v(JObj),
    Node = kz_api:node(JObj),
    IssuerRequested = kapi_keys:request_issuer(JObj),
    lager:info("received jwt.keys query from ~s : ~s", [Node, IssuerRequested]),
    Reply = [{<<"Keys">>, kz_json:from_list(fetch_keys())}
            ,{<<"Issuer">>, fetch_node_key(Node, IssuerRequested)}
            ,{<<"Msg-ID">>, kz_api:msg_reply_id(JObj)}
            | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
            ],
    kapi_keys:publish_reply(kz_api:server_id(JObj), props:filter_undefined(Reply)).


%%==============================================================================
%% gen_listener callbacks
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server.
%% @end
%%------------------------------------------------------------------------------
-spec init([]) -> {'ok', state()}.
init([]) ->
    lager:debug("starting new kazoo auth shared queue server"),
    {'ok', #{}}.

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call(_Msg, _From, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast(_Msg, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info(_Info, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling AMQP event objects
%% @end
%%------------------------------------------------------------------------------
-spec handle_event(kz_json:object(), kz_term:proplist()) -> gen_listener:handle_event_return().
handle_event(_JObj, _State) ->
    {'reply', []}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_listener' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_listener' terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), any()) -> 'ok'.
terminate(_Reason, _) ->
    lager:debug("kazoo auth shared queue server ~p termination", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%==============================================================================
%% Internal functions
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
fetch_keys() ->
    KeyId = ?SYSTEM_KEY_ID,
    PublicKey = kz_auth_keys:public_key(KeyId),
    [{KeyId, kz_auth_keys:to_pem(PublicKey, 'export')}].

fetch_node_key(_Node, false) -> undefined;
fetch_node_key(Node, true) ->
    Query = list_to_binary(["metadata.node eq \"", Node, "\""]),
    case kz_auth_keys:search(Query) of
        {ok, []} ->
            create_node_key(Node);
        {ok, [{KeyId, PrivateKey}]} ->
            node_key(Node, KeyId, PrivateKey);
        {ok, [{KeyId, PrivateKey} | _]} ->
            lager:warning("node ~s has multiple issuer keys, returning first"),
            node_key(Node, KeyId, PrivateKey);
        {error, _Error} ->
            lager:warning("error querying jwt keys => ~p", [_Error]),
            undefined
    end.

create_node_key(Node) ->
    KeyData = [{<<"node">>, Node}],
    Metadata = [{<<"metadata">>, kz_json:from_list(KeyData)}],
    KeyId = kz_binary:rand_hex(16),
    {ok, PrivateKey} = kz_auth_keys:gen_private_key(),
    {ok, PrivateKey} = kz_auth_keys:new_private_key(KeyId, PrivateKey, Metadata),
    node_key(Node, KeyId, PrivateKey).

-spec node_key(kz_term:ne_binary(), kz_term:ne_binary(), kz_auth_keys:rsa_key()) -> kz_json:object().
node_key(Node, KeyId, PrivateKey) ->
    PublicKey = kz_auth_keys:get_public_key_from_private_key(PrivateKey),
    PEM = [{<<"id">>, KeyId}
          ,{<<"public">>, kz_auth_keys:to_pem(PublicKey, 'export')}
          ,{<<"private">>, kz_auth_keys:to_pem(PrivateKey, 'export')}
          ,{<<"issuer">>, <<"kazoo">>}
          ,{<<"aud">>, Node}
          ,{<<"scope">>, <<"sip:call">>}
          ],
    kz_json:from_list(PEM).
