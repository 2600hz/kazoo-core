%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc
%%% Accessor for 'P_basic'
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_amqp_basic).

%% -record('P_basic', {content_type
%%                    ,content_encoding
%%                    ,headers
%%                    ,delivery_mode
%%                    ,priority
%%                    ,correlation_id
%%                    ,reply_to
%%                    ,expiration
%%                    ,message_id
%%                    ,timestamp
%%                    ,type
%%                    ,user_id
%%                    ,app_id
%%                    ,cluster_id
%%                    }).

%% ====================================================================
%% API functions
%% ====================================================================
-export([message_id/1
         %% ,content_type/1
         %% ,content_encoding/1
         %% ,delivery_mode/1
         %% ,priority/1
         %% ,correlation_id/1
         %% ,reply_to/1
        ,expiration/1
        ,timestamp/1
         %% ,type/1
         %% ,user_id/1
         %% ,app_id/1
         %% ,cluster_id/1
        ]).

-export([set_message_id/2
         %% ,set_content_type/2
         %% ,set_content_encoding/2
         %% ,set_delivery_mode/2
         %% ,set_priority/2
         %% ,set_correlation_id/2
         %% ,set_reply_to/2
         %% ,set_expiration/2
         %% ,set_timestamp/2
         %% ,set_type/2
         %% ,set_user_id/2
         %% ,set_app_id/2
         %% ,set_cluster_id/2
        ]).

-export([headers/1
        ,header/2
        ,header_value/2
        ]).

%% -export([set_headers/2
%%         ,set_header/3
%%         ,set_header_value/2
%%         ]).

-include_lib("amqp_client/include/amqp_client.hrl").

-type basic() :: #'P_basic'{}.

%% Copied from rabbit_framing_amqp_0_9_1.erl
-type amqp_field_type() ::
        'longstr' | 'signedint' | 'decimal' | 'timestamp' |
        'unsignedbyte' | 'unsignedshort' | 'unsignedint' |
        'table' | 'byte' | 'double' | 'float' | 'long' |
        'short' | 'bool' | 'binary' | 'void' | 'array'.

-type amqp_table() :: [{binary(), amqp_field_type(), amqp_value()}].
-type amqp_array() :: [{amqp_field_type(), amqp_value()}].
-type amqp_value() :: binary() |    % longstr
                      integer() |   % signedint
                      {non_neg_integer(), non_neg_integer()} | % decimal
                      amqp_table() |
                      amqp_array() |
                      byte() |      % byte
                      float() |     % double
                      integer() |   % long
                      integer() |   % short
                      boolean() |   % bool
                      binary() |    % binary
                      'undefined' | % void
                      non_neg_integer(). % timestamp


-spec message_id(basic()) -> binary() | 'undefined'.
message_id(#'P_basic'{message_id = MessageId}) -> MessageId.

-spec set_message_id(basic(), binary()) -> basic().
set_message_id(#'P_basic'{} = Basic, MessageId) -> Basic#'P_basic'{message_id = MessageId}.


-spec expiration(basic()) -> integer() | 'undefined'.
expiration(#'P_basic'{expiration = Expiration}) -> Expiration.

-spec timestamp(basic()) -> non_neg_integer() | 'undefined'.
timestamp(#'P_basic'{timestamp = Timestamp}) -> Timestamp.

-spec headers(basic()) -> amqp_table() | 'undefined'.
headers(#'P_basic'{headers = 'undefined'}) -> 'undefined';
headers(#'P_basic'{headers = Table}) -> Table.

-spec header(basic(), binary()) -> {amqp_field_type(), amqp_value()} | 'undefined'.
header(#'P_basic'{headers = 'undefined'}, _Key) -> 'undefined';
header(#'P_basic'{headers = Table}, Key) ->
    case lists:keysearch(Key, 1, Table) of
        {'value', {_, Type, Value}} -> {Type, Value};
        'false'                      -> 'undefined'
    end.

-spec header_value(basic(), binary()) -> amqp_value().
header_value(#'P_basic'{headers = 'undefined'}, _Key) -> 'undefined';
header_value(#'P_basic'{headers = Table}, Key) ->
    case lists:keysearch(Key, 1, Table) of
        {'value', {_, _Type, Value}} -> Value;
        'false'                      -> 'undefined'
    end.

%% ====================================================================
%% Internal functions
%% ====================================================================
