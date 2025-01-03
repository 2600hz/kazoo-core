%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc HTTP client for the app exchange
%%% 1. Fetches the listing of available apps for the cluster
%%% 2. Loads the app when requested via kapps_controller
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_client_client).

%% start the reader
-export([load_app/1
        ,link_cluster/1
        ,unlink_cluster/0
        ,fetch_license/1
        ,get_cluster/0, maybe_get_cluster/0
        ,update_cluster/1
        ,reset_cluster_secret/0
        ]).

-include("appex_client.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(HTTP_FETCH_TIMEOUT, appex_client_config:http_timeout_s() * ?MILLISECONDS_IN_SECOND).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec load_app(App::atom()) -> {'ok', appex_bluepak:loaded()} | {'error', any()}.
load_app(App) ->
    ClusterId = appex_client_config:cluster_id(),
    Headers = fetch_app_headers(),
    Payload = fetch_app_payload(),
    %% Link = kz_json:get_ne_binary_value(<<"link">>, AppMeta),
    URL = appex_server_url([<<"api/client/packages/">>, kz_term:to_binary(App)]),
    lager:debug("fetching app ~s: ~s", [App, URL]),
    case kz_http:async_req(self(), 'post', URL, Headers, kz_json:encode(Payload), fetch_app_options()) of
        {'http_req_id', ReqId} ->
            FetchParams = #{cluster_id => ClusterId
                           ,resp_body => <<>>
                           ,start => kz_time:now()
                           ,app_name => App
                           },
            case receive_app(ReqId, FetchParams) of
                {'redirect', _}=Redirect ->
                    maybe_redirect(Redirect, FetchParams);
                {'ok', _}=OK -> OK;
                {'error', _}=Error -> Error
            end;
        {'error', _Reason}=Error ->
            lager:error("failed to connect to appex server: ~p", [_Reason]),
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec link_cluster(kz_json:object()) ->
          {'ok' | 'error', kz_json:object()}.
link_cluster(ReqData) ->
    lager:info("linking cluster to marketplace"),
    Secret = kz_json:get_ne_binary_value(<<"access_code">>, ReqData, <<>>),
    Headers = [{<<"Authorization">>, <<"Bearer ", Secret/binary>>}
              ,{<<"content-type">>, <<"application/json">>}
              ],
    Payload = link_payload(ReqData),
    URL = appex_server_url([<<"api/client/cluster/link">>]),
    case kz_http:post(URL, Headers, kz_json:encode(Payload)) of
        {'ok', Code, _RespHeaders, RespBody} ->
            case decode_appex_response(RespBody, Code) of
                {'ok', Body} ->
                    lager:info("successfully linked cluster to marketplace"),
                    process_link_cluster(Body);
                {'error', ErrorJObj} ->
                    lager:error("failed to connect to appex server: ~p", [ErrorJObj]),
                    {'error', ErrorJObj}
            end;
        {'error', _Reason} ->
            lager:error("failed to connect to appex server: ~p", [_Reason]),
            {'error', kz_json:from_list(
                        [{<<"name">>, <<"NetworkError">>}
                        ,{<<"message">>, <<"Can not connect to server">>}
                        ]
                       )
            }
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec unlink_cluster() ->
          {'ok' | 'error', kz_json:object()}.
unlink_cluster() ->
    lager:info("unlinking cluster from marketplace"),
    Headers = appex_server_authorization_header(),
    URL = appex_server_url([<<"api/client/cluster">>]),
    case kz_http:delete(URL, Headers) of
        {'ok', 401, _RespHeaders, _RespBody} ->
            %% in case you unlinked the cluster directly from marketplace portal and want to re-link the cluster again
            %% using mui
            lager:debug("got 401 when unlinking cluster, considering the cluster is already unlinked from marketplace"),
            %% don't stop kazoo_appex to let it clean out apps when they stop
            _ = appex_client_config:set_cluster_secret('null'),
            {'ok', kz_json:new()};
        {'ok', Code, _RespHeaders, RespBody} ->
            case decode_appex_response(RespBody, Code) of
                {'ok', Body} ->
                    lager:info("successfully unlinked cluster from marketplace"),
                    process_unlink_cluster(Body);
                {'error', ErrorJObj} ->
                    lager:error("failed to connect to appex server: ~p", [ErrorJObj]),
                    {'error', ErrorJObj}
            end;
        {'error', _Reason} ->
            lager:error("failed to connect to appex server: ~p", [_Reason]),
            {'error', kz_json:from_list(
                        [{<<"name">>, <<"NetworkError">>}
                        ,{<<"message">>, <<"Can not connect to server">>}
                        ]
                       )
            }
    end.

-spec maybe_get_cluster() -> {'ok', kz_json:object()} | {'error', kz_json:object() | 'not_linked'}.
maybe_get_cluster() ->
    case appex_client_config:is_configured() of
        'true' ->
            get_cluster();
        'false' ->
            lager:debug("can't getting cluster info, cluster is not linked"),
            {'error', 'not_linked'}
    end.

-spec get_cluster() ->
          {'ok' | 'error', kz_json:object()}.
get_cluster() ->
    lager:info("getting cluster info from marketplace"),
    Headers = appex_server_authorization_header(),
    URL = appex_server_url([<<"api/client/cluster">>]),
    case kz_http:get(URL, Headers) of
        {'ok', Code, _RespHeaders, RespBody} ->
            case decode_appex_response(RespBody, Code) of
                {'ok', Body} ->
                    lager:info("successfully get cluster info from marketplace"),
                    process_get_cluster(Body);
                {'error', ErrorJObj} ->
                    lager:error("failed to connect to appex server: ~p", [ErrorJObj]),
                    {'error', ErrorJObj}
            end;
        {'error', _Reason} ->
            lager:error("failed to connect to appex server: ~p", [_Reason]),
            {'error', kz_json:from_list(
                        [{<<"name">>, <<"NetworkError">>}
                        ,{<<"message">>, <<"Can not connect to server">>}
                        ]
                       )
            }
    end.

-spec update_cluster(kz_json:object()) ->
          {'ok' | 'error', kz_json:object()}.
update_cluster(ReqData) ->
    case appex_client_config:is_configured() of
        'true' ->
            do_update_cluster(ReqData);
        'false' ->
            appex_client_config:get_public_configs()
    end.

-spec do_update_cluster(kz_json:object()) ->
          {'ok' | 'error', kz_json:object()}.
do_update_cluster(ReqData) ->
    lager:info("updating cluster info in marketplace"),
    Headers = [{<<"content-type">>, <<"application/json">>}
              | appex_server_authorization_header()
              ],
    URL = appex_server_url([<<"api/client/cluster">>]),
    Payload = kz_json:from_list([{<<"cluster">>, ReqData}]),
    case kz_http:put(URL, Headers, kz_json:encode(Payload)) of
        {'ok', Code, _RespHeaders, RespBody} ->
            case decode_appex_response(RespBody, Code) of
                {'ok', Body} ->
                    lager:info("successfully updated cluster to marketplace"),
                    process_get_cluster(Body);
                {'error', ErrorJObj} ->
                    lager:error("failed to connect to appex server: ~p", [ErrorJObj]),
                    {'error', ErrorJObj}
            end;
        {'error', _Reason} ->
            lager:error("failed to connect to appex server: ~p", [_Reason]),
            {'error', kz_json:from_list(
                        [{<<"name">>, <<"NetworkError">>}
                        ,{<<"message">>, <<"Can not connect to server">>}
                        ]
                       )
            }
    end.

-spec reset_cluster_secret() ->
          {'ok' | 'error', kz_json:object()}.
reset_cluster_secret() ->
    lager:info("reset cluster secret in marketplace"),
    Headers = appex_server_authorization_header(),
    URL = appex_server_url([<<"api/client/cluster/reset-secret">>]),
    case kz_http:patch(URL, Headers) of
        {'ok', Code, _RespHeaders, RespBody} ->
            case decode_appex_response(RespBody, Code) of
                {'ok', Body} ->
                    lager:info("successfully reset the cluster secret in marketplace"),
                    process_link_cluster(Body);
                {'error', ErrorJObj} ->
                    lager:error("failed to connect to appex server: ~p", [ErrorJObj]),
                    {'error', ErrorJObj}
            end;
        {'error', _Reason} ->
            lager:error("failed to connect to appex server: ~p", [_Reason]),
            {'error', kz_json:from_list(
                        [{<<"name">>, <<"NetworkError">>}
                        ,{<<"message">>, <<"Can not connect to server">>}
                        ]
                       )
            }
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec fetch_license(atom()) ->
          {'ok', kz_json:object()} |
          {'error', kz_term:ne_binary() | kz_json:object()}.
fetch_license('undefined') ->
    {'error', <<"no app name">>};
fetch_license(App) ->
    AppName = kz_term:to_binary(App),
    Headers = appex_server_authorization_header(),
    URL = appex_server_url([<<"api/client/license/">>, kz_term:to_binary(App)]),
    case kz_http:get(URL, Headers) of
        {'ok', Code, _RespHeaders, RespBody} when Code =< 400 ->
            case decode_appex_response(RespBody, Code) of
                {'ok', Body} ->
                    case kz_json:get_value(<<"data">>, Body) of
                        'null' -> {'error', <<"no license">>};
                        'undefined' -> {'error', <<"no license">>};
                        Data -> {'ok', kz_json:get_json_value(AppName, Data, Data)}
                    end;
                {'error', _}=Error -> Error
            end;
        {'ok', Code, _RespHeaders, RespBody} ->
            JObj = kz_json:decode(RespBody, decode_options(Code)),
            Err = kz_json:get_value(<<"error">>, JObj, "InternalServerError"),
            {'error', kz_binary:format("unexpected code ~b when getting license for app ~s: ~p", [Code, AppName, Err])};
        {'error', _Reason} ->
            {'error', kz_binary:format("failed to connect to appex server: ~p", [_Reason])}
    end.

%%%=============================================================================
%%% Common Functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec appex_server_authorization_header() -> kz_http:headers().
appex_server_authorization_header() ->
    appex_server_authorization_header(appex_client_config:cluster_secret()).

-spec appex_server_authorization_header(kz_term:api_ne_binary()) -> kz_http:headers().
appex_server_authorization_header('undefined') -> [];

appex_server_authorization_header(Secret) ->
    ClusterId = appex_client_config:cluster_id(),
    Encoded = base64:encode(<<ClusterId/binary, ":", Secret/binary>>),
    [{<<"Authorization">>, <<"Bearer ", Encoded/binary>>}].

-spec appex_server_url(iolist()) -> kz_http:url().
appex_server_url(Path) ->
    uri_string:resolve(kz_term:to_binary(Path), appex_client_config:app_exchange_url()).

-spec note_request_id(kz_term:proplist()) -> 'ok'.
note_request_id(RespHeaders) ->
    RequestId = kz_http_util:get_resp_header("x-request-id", RespHeaders),
    kz_log:put_callid(kz_term:to_binary(RequestId)).

internal_server_error() ->
    {'error', kz_json:from_list(
                [{<<"status">>, 500}
                ,{<<"name">>, <<"InternalServerError">>}
                ]
               )}.

decode_appex_response(RespBody, Code) ->
    Body = kz_json:decode(RespBody, decode_options(Code)),
    case kz_json:get_json_value(<<"error">>, Body) of
        'undefined' ->
            {'ok', Body};
        ErrorJObj ->
            {'error', ErrorJObj}
    end.

decode_options(Code) ->
    [{'default'
     ,kz_json:from_list_recursive(
        [{<<"error">>, [{<<"status">>, Code}
                       ,{<<"name">>, <<"InternalServerError">>}
                       ]
         }
        ]
       )
     }
    ,{'null_term', 'undefined'}
    ].

%%%=============================================================================
%%% Fetch App Functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec fetch_app_headers() -> kz_http:headers().
fetch_app_headers() ->
    [{<<"Accept">>, kz_binary:join(
                      [<<"application/vnd.bluepak+", Suffix/binary>>
                           || Suffix <- [<<"kazoo">>, <<"monster">>, <<"commland">>]
                      ]
                     ,<<", ">>
                     )
     }
    | appex_server_authorization_header()
    ].

-spec get_node_version(function()) -> kz_term:api_ne_binary().
get_node_version(Fun) ->
    try Fun()
    catch
        _:_:_ ->
            'undefined'
    end.

-spec fetch_app_payload() -> kz_json:object().
fetch_app_payload() ->
    Data = props:filter_undefined(
             [{<<"kz_core_version">>, get_node_version(fun kapps_util:kazoo_version/0)}
             ,{<<"mui_version">>, get_node_version(fun kapps_util:monsterui_version/0)}
             ,{<<"commland_version">>, get_node_version(fun kapps_util:commland_version/0)}
             ,{<<"meta_kazoo_version">>, get_node_version(fun kapps_util:meta_kazoo_version/0)}
             ,{<<"os_type">>, get_node_version(fun kapps_util:os_type/0)}
             ,{<<"os_release">>, get_node_version(fun kapps_util:os_release/0)}
             ,{<<"arch_type">>, get_node_version(fun kapps_util:arch_type/0)}
             ,{<<"c_compiler">>, get_node_version(fun kapps_util:c_compiler/0)}
             ,{<<"otp_version">>, get_node_version(fun kapps_util:otp_version/0)}
             ]),
    kz_json:from_list(Data).

-spec fetch_app_options() -> kz_term:proplist().
fetch_app_options() ->
    %% SSLOptions = lists:foldl(fun(F, Acc) -> F(Acc) end
    %%                         ,[]
    %%                         ,[fun cacert/1]
    %%                         ),
    %% [{'ssl', SSLOptions}
    [{'timeout', ?HTTP_FETCH_TIMEOUT}
    ,{'connect_timeout', 30 * ?MILLISECONDS_IN_SECOND}
    ,{'autoredirect', 'false'}
    ].

-type recv_app_resp() :: {'ok', appex_bluepak:loaded()} |
                         {'error', any()} |
                         {'redirect', kz_term:api_string()}.
-spec receive_app(reference(), map()) ->
          recv_app_resp().
receive_app(ReqId, Fetch) ->
    case receive_app_response(ReqId, Fetch) of
        {'continue', Fetch1} -> receive_app(ReqId, Fetch1);
        {'finished', Fetch1} -> handle_received_app(Fetch1);
        {'redirect', _}=Redirect -> Redirect;
        {'error', _E}=Error -> Error
    end.

-spec receive_app_response(reference(), map()) ->
          {'continue', map()} |
          {'finished', map()} |
          {'redirect', kz_term:api_string()} |
          {'error', atom() | integer()}.
receive_app_response(ReqId, FetchParams) ->
    Timeout = ?HTTP_FETCH_TIMEOUT,
    receive
        Msg -> handle_app_response_message(ReqId, FetchParams, Msg)
    after
        Timeout ->
            lager:error("timed out waiting for http response"),
            {'error', 'timeout'}
    end.

handle_app_response_message(_ReqId, _FetchParams, {'error', Error}) ->
    handle_error(Error);
handle_app_response_message(ReqId, _FetchParams, {'http', {ReqId, {{_HTTP, 404, _RespMsg}
                                                                  ,RespHeaders
                                                                  ,_RespBody
                                                                  }}}) ->
    note_request_id(RespHeaders),
    lager:info("failed to find requested app/version"),
    {'error', 'not_found'};
handle_app_response_message(ReqId, _FetchParams, {'http', {ReqId, {{_HTTP, RespCode, _RespMsg}
                                                                  ,RespHeaders
                                                                  ,_RespBody
                                                                  }}})
  when RespCode >= 400 ->
    note_request_id(RespHeaders),
    lager:error("failed fetching app: ~p: ~s", [RespCode, _RespBody]),
    {'error', RespCode};
handle_app_response_message(ReqId, _FetchParams, {'http', {ReqId, {{_HTTP, RespCode, _RespMsg}
                                                                  ,RespHeaders
                                                                  ,_RespBody
                                                                  }}})
  when 300 =< RespCode
       andalso RespCode < 400 ->
    note_request_id(RespHeaders),
    lager:debug("got redirect url for app"),
    {'redirect', kz_http_util:get_resp_header("location", RespHeaders)};
handle_app_response_message(ReqId, _FetchParams, {'http', {ReqId, {'error', E}}}) ->
    handle_error(E);
handle_app_response_message(ReqId, FetchParams, {'http', {ReqId, _Msg}}) ->
    {'continue', FetchParams};
handle_app_response_message(ReqId, FetchParams, {'http', {ReqId, 'stream_start', RespHeaders}}) ->
    note_request_id(RespHeaders),
    receive_app_response(ReqId, FetchParams#{resp_headers=>RespHeaders});
handle_app_response_message(ReqId, #{resp_body := Body}=FetchParams, {'http',{ReqId, 'stream', RespBody}}) ->
    receive_app_response(ReqId, FetchParams#{resp_body=> <<Body/binary, RespBody/binary>>});
handle_app_response_message(ReqId, FetchParams, {'http',{ReqId, 'stream_end', _RespHeaders}}) ->
    {'finished', FetchParams};
handle_app_response_message(ReqId, FetchParams, _Msg) ->
    lager:info("ignoring ~p", [_Msg]),
    receive_app_response(ReqId, FetchParams).

-spec handle_error(any()) -> {'error', 'failed_to_connect' | 'failure'}.
handle_error({'failed_connect',[{'to_address',{_Host,_Port}}
                               ,{'inet',['inet'],_Error}
                               ]
             }) ->
    lager:error("failed to connect to ~s:~b: ~p", [_Host, _Port, _Error]),
    {'error', 'failed_to_connect'};
handle_error(_E) ->
    lager:error("error: ~p", [_E]),
    {'error', 'failure'}.

-spec handle_received_app(map()) -> {'ok', appex_bluepak:loaded()} | {'error', any()}.
handle_received_app(#{resp_body := Archive
                     ,resp_headers := RespHeaders
                     ,app_name := AppName
                     }) ->
    note_request_id(RespHeaders),
    CT = props:get_value("content-type", RespHeaders),
    try appex_bluepak:load_app(AppName, Archive, CT)
    catch
        'error':{'badmatch',{'error',{'running',_App}}} ->
            lager:info("~s is already running", [_App]),
            {'error', {'running',_App}};
        _E:_R:ST ->
            lager:error("failed to extract app archive: ~s: ~p", [_E, _R]),
            kz_log:log_stacktrace(ST),
            {'error', 'failed_to_load'}
    end.

-spec maybe_redirect({'redirect', kz_term:api_string()}, map()) ->
          recv_app_resp().
maybe_redirect({'redirect', 'undefined'}, _FetchParams) ->
    lager:error("redirect has no location url"),
    {'error', "bad_redirect"};
maybe_redirect({'redirect', LocationUrl}, #{app_name := AppName}=FetchParams) ->
    case kz_http:async_req(self(), 'get', LocationUrl) of
        {'http_req_id', ReqId} ->
            receive_app(ReqId, FetchParams);
        {'error', _Reason}=Error ->
            lager:error("failed to query for ~s: ~p", [AppName, _Reason]),
            Error
    end.

%%%=============================================================================
%%% Link/Unlink Functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec process_link_cluster(kz_json:object()) ->
          {'ok', kz_json:object()} |
          {'error', kz_json:object()}.
process_link_cluster(Body) ->
    case kz_json:get_ne_json_value([<<"data">>], Body) of
        'undefined' ->
            lager:debug("get bad response data from appex server: undefined"),
            internal_server_error();
        Data ->
            Secret = kz_json:get_ne_binary_value(<<"cluster_secret">>, Data),
            _ = appex_client_config:set_cluster_secret(Secret),
            _ = appex_client_config:set_is_enabled('true'),
            appex_client_config:get_public_configs(
              {'ok', kz_json:delete_key(<<"cluster_secret">>, Data)}
             )
    end.

-spec link_payload(kz_json:object()) ->  kz_json:object().
link_payload(JObj) ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),
    {'ok', MasterDoc} = kzd_accounts:fetch(MasterAccountId),
    DefaultName = kz_binary:join([kzd_accounts:name(MasterDoc), <<"'s Cluster">>], <<" ">>),
    ClusterName = kz_json:get_ne_binary_value(<<"name">>, JObj, DefaultName),
    IsAio = kz_term:to_binary(appex_client_config:is_aio_cluster()),
    Data = kz_json:from_list(
             [{<<"cluster_id">>, kzd_cluster:id()}
             ,{<<"name">>, ClusterName}
             ,{<<"master_account_id">>, MasterAccountId}
             ,{<<"master_account_name">>, kzd_accounts:name(MasterDoc)}
             ,{<<"kazoo_version">>, kapps_util:meta_kazoo_version()}
             ,{<<"is_aio">>, IsAio}
             ]
            ),
    kz_json:from_list([{<<"cluster">>, Data}]).

-spec process_unlink_cluster(kz_json:object()) ->
          {'ok', kz_json:object()} |
          {'error', kz_json:object()}.
process_unlink_cluster(Body) ->
    case kz_json:get_ne_json_value([<<"data">>], Body) of
        'undefined' ->
            lager:debug("get bad response data from appex server: undefined"),
            internal_server_error();
        Data ->
            %% don't stop kazoo_appex to let it clean out apps when they stop
            _ = appex_client_config:set_cluster_secret('null'),
            {'ok', Data}
    end.

-spec process_get_cluster(kz_json:object()) ->
          {'ok', kz_json:object()} |
          {'error', kz_json:object()}.
process_get_cluster(Body) ->
    case kz_json:get_ne_json_value([<<"data">>], Body) of
        'undefined' ->
            lager:debug("get bad response data from appex server: undefined"),
            internal_server_error();
        Data ->
            appex_client_config:get_public_configs(
              {'ok', kz_json:delete_key(<<"cluster_secret">>, Data)}
             )
    end.
