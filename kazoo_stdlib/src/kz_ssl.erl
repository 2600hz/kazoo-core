%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2025, 2600Hz
%%% @doc SSL helpers
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_ssl).

-export([ssl_opts/0, ssl_opts/1
        ,sni_opts/1
        ,https_opts/0
        ]).

-spec ssl_opts() -> [ssl:tls_option()].
ssl_opts() ->
    ssl_opts([]).

-spec ssl_opts([ssl:tls_option()]) -> [ssl:tls_option()].
ssl_opts(Options) ->
    props:insert_values(
      [{'versions', ['tlsv1.2']}
      ,{'verify', 'verify_peer'}
      ,{'cacerts', public_key:cacerts_get()} % recommended since OTP-25
      ]
     ,Options
     ).

%%------------------------------------------------------------------------------
%% Server Name Indication extension https://www.erlang.org/docs/26/man/ssl.html#connect-3
%% If the option verify is set to verify_peer the option server_name_indication
%% shall also be specified, if it is not no Server Name Indication extension
%% will be sent, and public_key:pkix_verify_hostname/2 will be called with
%% the IP-address of the connection as ReferenceID
%% not including sni host leads to {bad_cert,hostname_check_failed}
%%------------------------------------------------------------------------------
-spec sni_opts(string()) -> [ssl:tls_option()].
sni_opts(Host) ->
    ssl_opts([{server_name_indication, Host}]).

%% see https://www.erlang.org/docs/26/man/ssl.html#type-customize_hostname_check
%% and https://www.erlang.org/docs/26/man/public_key#pkix_verify_hostname_match_fun-1
%% specifically: "Currently supported https fun will allow wildcard
%% certificate matching as specified by the HTTP standard."
-spec https_opts() -> [ssl:tls_option()].
https_opts() ->
    https_opts([]).

-spec https_opts([ssl:tls_option()]) -> [ssl:tls_option()].
https_opts(Options) ->
    props:insert_value('customize_hostname_check'
                      ,[{'match_fun', public_key:pkix_verify_hostname_match_fun('https')}]
                      ,ssl_opts(Options)
                      ).
