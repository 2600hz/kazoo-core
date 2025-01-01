%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2024-2025, 2600Hz
%%% @doc Simple URL Storage for attachments.
%%% @author Taran Romana
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_att_sftp).
-behaviour(gen_attachment).

-include("kz_att.hrl").

%% `gen_attachment' behaviour callbacks (API)
-export([put_attachment/6]).
-export([fetch_attachment/4]).

%%from ssh_sftp.erl
-type sftp_error() :: atom() | string() | tuple() .

-define(SSH_CONNECTION_TIMEOUT, ?MILLISECONDS_IN_SECOND * 10).

%%%=============================================================================
%%% gen_attachment behaviour callbacks (API)
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec put_attachment(gen_attachment:settings()
                    ,gen_attachment:db_name()
                    ,gen_attachment:doc_id()
                    ,gen_attachment:att_name()
                    ,gen_attachment:contents()
                    ,gen_attachment:options()
                    ) -> gen_attachment:put_response().
put_attachment(Params, DbName, DocId, AName, Contents, Options) ->
    #{url := BaseUrlParam} = Params,
    Timeout = maps:get('timeout', Params, ?SSH_CONNECTION_TIMEOUT),
    DocUrlField = maps:get('document_url_field', Params, 'undefined'),
    BaseUrl = kz_binary:strip_right(BaseUrlParam, $/),
    Url = list_to_binary([BaseUrl, "/", kz_att_util:format_url(Params, {DbName, DocId, AName})]),

    case send_request(Url, Contents, Timeout) of
        'ok' ->
            lager:debug("attachment ~s of document ~s/~s uploaded to ~s"
                       ,[AName, DocId, DbName, Url]
                       ),
            {'ok', url_fields(DocUrlField, Url, Timeout)};
        Resp ->
            Routines = [{fun kz_att_error:set_req_url/2, Url}
                       | kz_att_error:put_routines(Params, DbName, DocId, AName,
                                                   Contents, Options)
                       ],
            handle_sftp_error_response(Resp, Routines)
    end.

-spec fetch_attachment(gen_attachment:handler_props()
                      ,gen_attachment:db_name()
                      ,gen_attachment:doc_id()
                      ,gen_attachment:att_name()
                      ) -> gen_attachment:fetch_response().
fetch_attachment(HandlerProps, DbName, DocId, AName) ->
    case kz_json:get_value(<<"url">>, HandlerProps) of
        'undefined' ->
            Routines = kz_att_error:fetch_routines(HandlerProps, DbName, DocId, AName),
            kz_att_error:new('invalid_data', Routines);
        Url ->
            Timeout = kz_json:get_integer_value(<<"timeout">>, HandlerProps, ?SSH_CONNECTION_TIMEOUT),
            case fetch_attachment(Url, Timeout) of
                {'ok', _Bin} = Resp ->
                    Resp;
                Resp ->
                    Routines = [{fun kz_att_error:set_req_url/2, Url}
                               | kz_att_error:fetch_routines(HandlerProps, DbName, DocId, AName)
                               ],
                    handle_sftp_error_response(Resp, Routines)
            end
    end.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec send_request(kz_term:ne_binary(), kz_term:ne_binary(), timeout()) ->
          'ok' |
          {'error', sftp_error() | binary()}.
send_request(Url, Contents, Timeout) ->
    case uri_string:parse(kz_term:to_list(Url)) of
        #{path := FullPath} = URI ->
            send_sftp_request(sftp_connect(URI, Timeout), FullPath, Contents);
        _ -> {'error', <<"error parsing url: ", Url/binary>>}
    end.

-spec send_sftp_request(sftp_connect_info(), string(), binary()) ->
          'ok' | {'error', sftp_error()}.
send_sftp_request({Host, Port, Options}, FullPath, Contents) ->
    try
        case ssh_sftp:start_channel(Host, Port, Options) of
            {'ok', Pid, _} ->
                Resp = ssh_sftp:write_file(Pid, FullPath, Contents),
                catch(ssh_sftp:stop_channel(Pid)),
                Resp;
            Resp -> Resp
        end
    catch
        _Exc:Err ->
            lager:debug("error ~p / ~p sending file ~s to ~s", [_Exc, Err, FullPath, Host]),
            {'error', Err}
    end.

-type sftp_connect_info() :: {string(), pos_integer(),
                              [{'timeout', timeout()} | {user, string()} | {password, string()} | {'silently_accept_hosts', boolean()}]}.

-spec sftp_connect(map(), timeout()) -> sftp_connect_info().
sftp_connect(#{host := Host, port := Port, userinfo := UserPass}, Timeout) ->
    [User, Pass] = string:tokens(UserPass, ":"),
    {Host, Port
    ,[{'timeout', Timeout}
     ,{'user', User}
     ,{'password', Pass}
     ,{'silently_accept_hosts', 'true'}
     ]
    };
sftp_connect(#{host := Host, userinfo := UserPass}, Timeout) ->
    [User, Pass] = string:tokens(UserPass, ":"),
    {Host, 22
    ,[{'timeout', Timeout}
     ,{'user', User}
     ,{'password', Pass}
     ,{'silently_accept_hosts', 'true'}
     ]
    }.

url_fields('undefined', Url, Timeout) ->
    [{'attachment', [{<<"url">>, Url}
                    ,{<<"timeout">>, Timeout}
                    ]
     }];
url_fields(DocUrlField, Url, Timeout) ->
    [{'attachment', [{<<"url">>, Url}
                    ,{<<"timeout">>, Timeout}
                    ]}
    ,{'document', [{DocUrlField, Url}]}
    ].

-spec fetch_attachment(kz_term:ne_binary(), timeout()) -> {'ok', binary()} |
          {'error', binary() | atom() | term()}.
fetch_attachment(Url, Timeout) ->
    case uri_string:parse(kz_term:to_list(Url)) of
        #{path := FullPath} = URI ->
            get_sftp_request(sftp_connect(URI, Timeout), FullPath, Timeout);
        _ -> {'error', <<"error parsing url: ", Url/binary>>}
    end.

get_sftp_request({Host, Port, Options}, FullPath, Timeout) ->
    try ssh_sftp:start_channel(Host, Port, Options) of
        {'ok', Pid, _} ->
            FetchResult = ssh_sftp:read_file(Pid, kz_term:to_list(FullPath), Timeout),
            handle_fetch(Pid, FetchResult);
        {'error', _Reason}=Err ->
            lager:debug("error '~p' opening sftp connection to ~s for retreiving ~s"
                       ,[_Reason, Host, FullPath]
                       ),
            Err
    catch
        _E:Reason ->
            lager:debug("exception '~p/~p' opening sftp connection to ~s for retreiving ~s"
                       ,[_E, Reason, Host, FullPath]
                       ),
            {'error', Reason}
    end.

-spec handle_fetch(pid(), {'ok', binary()} | {'error', any()}) ->
          {'ok', binary()} |
          {'error', any()}.
handle_fetch(Pid, {'ok', _Bin}=OK) ->
    ssh_sftp:stop_channel(Pid),
    OK;
handle_fetch(Pid, {'error', _Reason}=Err) ->
    lager:debug("error transferring file from sftp server : ~p", [_Reason]),
    ssh_sftp:stop_channel(Pid),
    Err.

-spec handle_sftp_error_response({'error', binary() | atom() | term()},
                                 kz_att_error:update_routines()) -> kz_att_error:error().
handle_sftp_error_response({'error', Reason}, Routines)
  when is_atom(Reason); is_binary(Reason) ->
    lager:error("sftp error ~p", [Reason]),
    kz_att_error:new(Reason, Routines);
handle_sftp_error_response(_E, Routines) ->
    lager:error("sftp request error ~p", [_E]),
    kz_att_error:new('request_error', Routines).
