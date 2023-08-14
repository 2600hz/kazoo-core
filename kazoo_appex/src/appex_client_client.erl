%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
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
-export([load_app/2
        ,link_cluster/1
        ,unlink_cluster/0
        ,fetch_license/2
        ]).

-include("appex_client.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(HTTP_FETCH_TIMEOUT, appex_client_config:http_timeout_s() * ?MILLISECONDS_IN_SECOND).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec load_app(ParentApp::atom(), App::atom()) -> {'ok', appex_bluepak:loaded()} | {'error', any()}.
load_app(ParentApp, App) ->
    ClusterId = appex_client_config:cluster_id(),
    Headers = fetch_app_headers(),

    %% Link = kz_json:get_ne_binary_value(<<"link">>, AppMeta),
    AppLink = app_link(ClusterId, ParentApp, App),

    not kz_term:is_ne_binary(AppLink)
        andalso throw({'error', 'no_app_link'}),

    Url = appex_server_url([<<"api/">>, AppLink]),

    lager:debug("fetching app ~s (as dependency for ~s)", [App, ParentApp]),
    case kz_http:async_req(self(), 'get', Url, Headers, <<>>, fetch_app_options()) of
        {'http_req_id', ReqId} ->
            FetchParams = #{cluster_id => ClusterId
                           ,resp_body => <<>>
                           ,start => kz_time:now()
                           ,app_name => App
                           ,parent_app => ParentApp
                           },
            maybe_redirect(receive_app(ReqId, FetchParams), FetchParams);
        {'error', _Reason}=Error ->
            lager:error("failed to query for ~s: ~p", [AppLink, _Reason]),
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
    Headers = [{<<"authorization">>, <<"APPEX-LINK ", Secret/binary>>}
              ,{<<"content-type">>, <<"application/json">>}
              ],
    Payload = link_payload(ReqData),
    URL = appex_server_url([<<"api/appex/cluster">>]),
    case kz_http:post(URL, Headers, kz_json:encode(Payload)) of
        {'ok', Code, _RespHeaders, RespBody} ->
            Body = kz_json:decode(RespBody, decode_error(Code)),
            case kz_json:get_value(<<"error">>, Body) of
                'undefined' ->
                    lager:info("successfully linked cluster to marketplace"),
                    process_link_cluster(ReqData, Body);
                Error ->
                    lager:error("failed to connect to appex server: ~p", [Error]),
                    {'error', Error}
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
          {'ok', kz_json:object()} |
          {'ok' | 'error', kz_json:object()}.
unlink_cluster() ->
    lager:info("unlinking cluster from marketplace"),
    Headers = appex_server_authorization_header(),
    ClusterId = appex_client_config:cluster_id(),
    URL = appex_server_url(
            [kz_binary:join(
               [<<"api/appex/cluster">>, ClusterId], <<"/">>
              )
            ]
           ),
    case kz_http:delete(URL, Headers) of
        {'ok', 401, _RespHeaders, _RespBody} ->
            %% in case you unlinked the cluster directly from marketplace portal and want to re-link the cluster again
            %% using mui
            lager:debug("got 401 when unlinking cluster, considering the cluster is already unlinked from marketplace"),
            %% don't stop kazoo_appex to let it clean out apps when they stop
            _ = appex_client_config:set_cluster_secret('null'),
            {'ok', kz_json:new()};
        {'ok', Code, _RespHeaders, RespBody} ->
            Body = kz_json:decode(RespBody, decode_error(Code)),
            case kz_json:get_value(<<"error">>, Body) of
                'undefined' ->
                    lager:info("successfully unlinked cluster from marketplace"),
                    process_unlink_cluster(Body);
                Error ->
                    lager:error("failed to connect to appex server: ~p", [Error]),
                    {'error', Error}
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
-spec fetch_license(atom(), atom()) ->
          {'ok', kz_json:object()} |
          {'error', kz_term:ne_binary() | kz_json:object()}.
fetch_license(_, 'undefined') ->
    {'error', <<"no app name">>};
fetch_license(ParentApp, App) ->
    AppName = kz_term:to_binary(App),
    Headers = appex_server_authorization_header(),
    ClusterId = appex_client_config:cluster_id(),
    URL = fetch_license_url(ClusterId, ParentApp, App),
    case kz_http:get(URL, Headers) of
        {'ok', Code, _RespHeaders, RespBody} when Code =< 400 ->
            JObj = kz_json:decode(RespBody, decode_error(Code)),
            case kz_json:get_value(<<"error">>, JObj) of
                'undefined' ->
                    case kz_json:get_value(<<"data">>, JObj) of
                        'null' -> {'error', <<"no license">>};
                        'undefined' -> {'error', <<"no license">>};
                        Data -> {'ok', kz_json:get_json_value(AppName, Data, Data)}
                    end;
                Error -> {'error', Error}
            end;
        {'ok', Code, _RespHeaders, RespBody} ->
            JObj = kz_json:decode(RespBody, decode_error(Code)),
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
    Secret = appex_client_config:cluster_secret(),
    [{<<"authorization">>, <<"APPEX ", Secret/binary>>}].

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

decode_error(Code) ->
    [{'default'
     ,kz_json:from_list_recursive(
        [{<<"error">>, [{<<"status">>, Code}
                       ,{<<"name">>, <<"InternalServerError">>}
                       ]
         }
        ]
       )
     }
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
    props:filter_undefined(
      [{<<"x-appex-kz-version">>, get_node_version(fun kapps_util:kazoo_version/0)}
      ,{<<"x-appex-mui-version">>, get_node_version(fun kapps_util:monsterui_version/0)}
      ,{<<"x-appex-commland-version">>, get_node_version(fun kapps_util:commland_version/0)}
      ,{<<"x-appex-meta-kazoo-version">>, get_node_version(fun kapps_util:meta_kazoo_version/0)}
      ,{<<"accept">>, kz_binary:join(
                        [<<"application/vnd.appex+", Suffix/binary>>
                             || Suffix <- [<<"kazoo">>, <<"monster">>, <<"commland">>]
                        ]
                       ,<<", ">>
                       )
       }
      | appex_server_authorization_header()
      ]
     ).

-spec get_node_version(function()) -> kz_term:api_ne_binary().
get_node_version(Fun) ->
    try Fun()
    catch
        _:_:_ ->
            'undefined'
    end.

-spec app_link(kz_term:ne_binary(), atom(), atom()) -> kz_http:url().
app_link(ClusterId, App, App) ->
    kz_binary:join([<<"appex/client">>, ClusterId, <<"packages">>, App], <<"/">>);
app_link(ClusterId, ParentApp, App) ->
    kz_binary:join([<<"appex/client">>, ClusterId, <<"packages">>, ParentApp, App], <<"/">>).

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

-spec receive_app(reference(), map()) ->
          {'ok', appex_bluepak:loaded()} |
          {'error', any()} |
          {'redirect', kz_term:api_string()}.
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
          {'error', any()}.
receive_app_response(ReqId, #{resp_body := Body}=FetchParams) ->
    Timeout = ?HTTP_FETCH_TIMEOUT,
    receive
        {'error', Error} ->
            handle_error(Error);
        {'http', {ReqId, {{_HTTP, 404, _RespMsg}
                         ,RespHeaders
                         ,_RespBody
                         }}} ->
            note_request_id(RespHeaders),
            lager:info("failed to find requested app/version"),
            {'error', 'not_found'};
        {'http', {ReqId, {{_HTTP, RespCode, _RespMsg}
                         ,RespHeaders
                         ,_RespBody
                         }}} when RespCode >= 400 ->
            note_request_id(RespHeaders),
            lager:error("failure fetching app: ~p: ~s", [RespCode, _RespBody]),
            {'error', RespCode};
        {'http', {ReqId, {{_HTTP, RespCode, _RespMsg}
                         ,RespHeaders
                         ,_RespBody
                         }}} when 300 =< RespCode
                                  andalso RespCode < 400 ->
            note_request_id(RespHeaders),
            lager:debug("got redirect url for app"),
            {'redirect', kz_http_util:get_resp_header("location", RespHeaders)};
        {'http', {ReqId, {'error', E}}} ->
            handle_error(E);
        {'http', {ReqId, _Msg}} ->
            {'continue', FetchParams};
        {'http', {ReqId, 'stream_start', RespHeaders}} ->
            note_request_id(RespHeaders),
            receive_app_response(ReqId, FetchParams#{resp_headers=>RespHeaders});
        {'http',{ReqId, 'stream', RespBody}} ->
            receive_app_response(ReqId, FetchParams#{resp_body=> <<Body/binary, RespBody/binary>>});
        {'http',{ReqId, 'stream_end', _RespHeaders}} ->
            {'finished', FetchParams};
        _Msg ->
            lager:info("ignoring ~p", [_Msg]),
            receive_app_response(ReqId, FetchParams)
    after
        Timeout ->
            lager:error("timed out waiting for http response"),
            {'error', 'timeout'}
    end.

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
                     ,parent_app := ParentApp
                     }) ->
    note_request_id(RespHeaders),
    CT = props:get_value("content-type", RespHeaders),
    try appex_bluepak:load_app(ParentApp, AppName, Archive, CT)
    catch
        'error':{'badmatch',{'error',{'running',_App}}} ->
            lager:info("~s is already running", [_App]),
            {'error',{'running',_App}};
        _E:_R:ST ->
            lager:error("failed to extract app archive: ~s: ~p", [_E, _R]),
            kz_log:log_stacktrace(ST),
            {'error', 'failed_to_load'}
    end.

-spec maybe_redirect({'ok', appex_bluepak:loaded()} | {'error', any()} | {'redirect', kz_term:api_string()}, map()) ->
          {'ok', appex_bluepak:loaded()} |
          {'error', any()}.
maybe_redirect({'error', _}=Error, _FetchParams) ->
    Error;
maybe_redirect({'ok', _}=OK, _FetchParams) ->
    OK;
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
%%% Fetch License Functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec fetch_license_url(kz_term:ne_binary(), atom(), atom()) -> kz_http:url().
fetch_license_url(ClusterId, AppName, AppName) ->
    appex_server_url([kz_binary:join([<<"api/appex/license">>, ClusterId, <<"packages">>, AppName], <<"/">>)]);
fetch_license_url(ClusterId, ParentApp, AppName) ->
    appex_server_url([kz_binary:join([<<"api/appex/license">>, ClusterId, <<"packages">>, ParentApp, AppName], <<"/">>)]).


%%%=============================================================================
%%% Link/Unlink Functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------

process_link_cluster(ReqData, Body) ->
    ShouldRestart = kz_json:is_true(<<"restart_appex_client">>, ReqData),
    case kz_json:get_ne_json_value([<<"data">>, <<"attributes">>], Body) of
        'undefined' ->
            lager:debug("git bad response data from appex server: undefined"),
            internal_server_error();
        Data ->
            Secret = kz_json:get_ne_binary_value(<<"cluster_secret">>, Data),
            _ = appex_client_config:set_cluster_secret(Secret),
            maybe_restart_appex_client(ShouldRestart),
            {'ok', kz_json:delete_key(<<"cluster_secret">>, Data)}
    end.

maybe_restart_appex_client('true') ->
    Restart = fun() ->
                      _ = application:stop(?APP),
                      application:start(?APP)
              end,
    _ = spawn(Restart),
    'ok';
maybe_restart_appex_client('false') ->
    'ok'.

link_payload(JObj) ->
    {'ok', MasterAccountId} = kapps_util:get_master_account_id(),
    {'ok', MasterDoc} = kzd_accounts:fetch(MasterAccountId),
    DefaultName = kz_binary:join([kzd_accounts:name(MasterDoc), <<"'s Cluster">>], <<" ">>),
    ClusterName = kz_json:get_ne_binary_value(<<"name">>, JObj, DefaultName),
    Data = kz_json:from_list(
             [{<<"cluster_id">>, kzd_cluster:id()}
             ,{<<"name">>, ClusterName}
             ,{<<"master_account_id">>, MasterAccountId}
             ,{<<"master_account_name">>, kzd_accounts:name(MasterDoc)}
             ,{<<"kazooVersion">>, kapps_util:meta_kazoo_version()}
             ]
            ),
    kz_json:from_list([{<<"data">>, Data}]).

process_unlink_cluster(Body) ->
    case kz_json:get_ne_json_value([<<"data">>, <<"attributes">>], Body) of
        'undefined' ->
            lager:debug("git bad response data from appex server: undefined"),
            internal_server_error();
        Data ->
            %% don't stop kazoo_appex to let it clean out apps when they stop
            _ = appex_client_config:set_cluster_secret('null'),
            {'ok', kz_json:delete_key(<<"cluster_secret">>, Data)}
    end.
