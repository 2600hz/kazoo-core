%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc Common functions for interacting with the 2600Hz phonebook service
%%% @author Sean Wysor
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_phonebook).

-export([maybe_create_port_in/2
        ,maybe_add_comment/3
        ,lnp_lookup/2

        ,should_send_to_phonebook/1
        ]).

-define(MOD_CONFIG_CAT, <<"crossbar.phonebook">>).

-type phonebook_options() :: [{'auth_token', kz_term:ne_binary()} | %% Crossbar auth token
                              {'port_authority_id', kz_term:ne_binary()} |
                              {'master_account_id', kz_term:ne_binary()} |
                              %% Crossbar User-Agent header, to check if request is from project phonebook or not.
                              {'user_agent', kz_term:ne_binary()}
                             ].


-type req_type() :: 'add_comment' | 'port_in' | 'lnp_lookup'.
-type reason() :: 'bad_phonebook' | 'bad_http'.

-type errors() :: #{code => non_neg_integer()
                   ,req_type := req_type()
                   ,payload := kz_json:object()
                   ,reason := reason()
                   }.

-type response() :: {'ok', kz_json:object() | 'disabled'} |
                    {'error', errors()}.

-export_type([errors/0
             ,response/0
             ]).

%%------------------------------------------------------------------------------
%% @doc exported functions
%% @end
%%------------------------------------------------------------------------------
-spec maybe_create_port_in(kz_json:object(), phonebook_options()) -> response().
maybe_create_port_in(JObj, Options) ->
    case should_send_to_phonebook(Options) of
        'true' ->
            create_port_in(JObj, props:get_value('auth_token', Options));
        'false' -> {'ok', 'disabled'}
    end.

-spec maybe_add_comment(kz_json:object(), kz_json:objects(), phonebook_options()) -> response().
maybe_add_comment(JObj, Comments, Options) ->
    case should_send_to_phonebook(Options) of
        'true' ->
            add_comment(JObj, props:get_value('auth_token', Options), Comments);
        'false' -> {'ok', 'disabled'}
    end.

-spec lnp_lookup(kz_json:object(), phonebook_options()) -> response().
lnp_lookup(JObj, Options) ->
    case kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"enabled">>, 'false')
        andalso props:get_value('user_agent', Options) =/= <<"phonebook">>
    of
        'true' ->
            lnp_lookup_req(JObj, props:get_value('auth_token', Options));
        'false' -> {'ok', 'disabled'}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec should_send_to_phonebook(phonebook_options()) -> boolean().
should_send_to_phonebook(Options) ->
    kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"enabled">>, 'false')
        andalso props:get_value('port_authority_id', Options) =:= props:get_value('master_account_id', Options)
        andalso props:get_value('user_agent', Options) =/= <<"phonebook">>.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec create_port_in(kz_json:object(), kz_term:ne_binary()) -> response().
create_port_in(JObj, AuthToken) ->
    Url = phonebook_uri([<<"accounts">>, kz_doc:account_id(JObj), <<"ports">>, <<"in">>]),
    Data = kz_json:from_list([{<<"data">>, kz_doc:public_fields(JObj)}]),
    lager:debug("sending request to phonebook for creating/updating port ~s", [kz_doc:id(JObj)]),
    make_request('port_in', AuthToken, Url, Data).

-spec add_comment(kz_json:object(), kz_term:ne_binary(), kz_json:objects()) -> response().
add_comment(JObj, AuthToken, Comment) ->
    Url = phonebook_uri([<<"accounts">>, kz_doc:account_id(JObj), <<"ports">>, <<"in">>, kz_doc:id(JObj), <<"notes">>]),
    Data = kz_json:set_value(<<"data">>, Comment, kz_json:new()),
    lager:debug("sending request to phonebook to add comment port ~s", [kz_doc:id(JObj)]),
    make_request('add_comment', AuthToken, Url, Data).

-spec lnp_lookup_req(kz_json:object(), kz_term:ne_binary()) -> response().
lnp_lookup_req(JObj, AuthToken) ->
    Url = phonebook_uri([<<"lnp">>, <<"lookup">>]),
    Data = kz_json:from_list([{<<"data">>, kz_doc:public_fields(JObj)}]),

    _Length = length(kz_json:get_list_value(<<"numbers">>, JObj, [])),
    lager:debug("sending request to phonebook to lnp lookup for ~b number(s)", [_Length]),
    Response = kz_http:post(Url, req_headers(AuthToken), kz_json:encode(Data)),
    handle_resp('lnp_lookup', Response).

-spec make_request(req_type(), kz_term:ne_binary(), string(), kz_json:object()) -> response().
make_request(Type, AuthToken, URL, Data) ->
    Response = kz_http:put(URL, req_headers(AuthToken), kz_json:encode(Data)),
    handle_resp(Type, Response).

-spec handle_resp(req_type(), kz_http:ret()) -> response().
handle_resp(Type, {'ok', 200, _, Resp}) ->
    RespJObj = try kz_json:decode(Resp)
               catch
                   _:_ ->
                       kz_json:from_list(
                         [{<<"message">>, Resp}
                         ,{<<"reason">>, <<"phonebook_non_json_repsonse">>}
                         ]
                        )
               end,
    case kz_json:get_ne_binary_value(<<"status">>, RespJObj) of
        'undefined' ->
            lager:error("phonebook responding without status: ~p", [Resp]),
            {'error', #{code => 500
                       ,req_type => Type
                       ,payload => RespJObj
                       ,reason => 'bad_phonebook'
                       }
            };
        <<"error">> ->
            lager:error("phonebook responding 200 with status error: ~p", [Resp]),
            {'error', #{code => 400
                       ,req_type => Type
                       ,payload => RespJObj
                       ,reason => 'bad_phonebook'
                       }
            };
        <<"success">> -> {'ok', RespJObj}
    end;
handle_resp(Type, {'ok', Code, _, Resp}) ->
    lager:warning("phonebook responding with code ~b and response: ~p", [Code, Resp]),
    RespJObj = try kz_json:decode(Resp)
               catch
                   _:_ ->
                       kz_json:from_list(
                         [{<<"message">>, Resp}
                         ,{<<"reason">>, <<"phonebook_non_json_repsonse">>}
                         ]
                        )
               end,
    {'error', #{code => Code
               ,req_type => Type
               ,payload => RespJObj
               ,reason => 'bad_phonebook'
               }
    };
handle_resp(Type, Error) ->
    lager:debug("failed to make http request to phonebook server: ~p", [Error]),
    {'error', #{code => 500
               ,req_type => Type
               ,payload => kz_json:from_list([{<<"message">>, <<"failed to connect to port automation system">>}
                                             ,{<<"reason">>, kz_term:to_binary(io_lib:format("~p", [Error]))}
                                             ])
               ,reason => 'bad_http'
               }
    }.

-spec phonebook_uri(iolist()) -> string().
phonebook_uri(ExplodedPath) ->
    Url = kapps_config:get_binary(?MOD_CONFIG_CAT, <<"phonebook_url">>),
    Uri = kz_http_util:uri(Url, ExplodedPath),
    kz_term:to_list(Uri).

-spec req_headers(kz_term:ne_binary()) -> kz_term:proplist().
req_headers(Token) ->
    props:filter_undefined(
      [{"Content-Type", "application/json"}
      ,{"X-Auth-Token", kz_term:to_list(Token)}
      ,{"X-Kazoo-Cluster-ID", kzd_cluster:id()}
      ,{"User-Agent", kz_term:to_list(erlang:node())}
      ]).
