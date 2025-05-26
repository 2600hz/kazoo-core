%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
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

-export([set_headers/2
        ,set_header/2
        ]).

-export([set_header_longstr/3
        ,set_header_signedint/3
        ,set_header_decimal/3
        ,set_header_table/3
        ,set_header_array/3
        ,set_header_byte/3
        ,set_header_double/3
        ,set_header_float/3
        ,set_header_long/3
        ,set_header_short/3
        ,set_header_bool/3
        ,set_header_binary/3
        ,set_header_timestamp/3
        ]).

-include_lib("amqp_client/include/amqp_client.hrl").

-type basic() :: #'P_basic'{}.

%% Copied from rabbit_framing_amqp_0_9_1.erl
-type amqp_field_type() ::
        'longstr' | 'signedint' | 'decimal' | 'timestamp' |
        'unsignedbyte' | 'unsignedshort' | 'unsignedint' |
        'table' | 'byte' | 'double' | 'float' | 'long' |
        'short' | 'bool' | 'binary' | 'void' | 'array'.

-type amqp_table() :: [amqp_header()].
-type amqp_header() :: {binary(), amqp_field_type(), amqp_value()}.
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

-spec set_headers(basic(), amqp_table()) -> basic().
set_headers(#'P_basic'{}=Basic, Headers) ->
    Basic#'P_basic'{headers = Headers}.

-spec set_header(basic(), amqp_header()) -> basic().
set_header(#'P_basic'{headers = 'undefined'} = Basic, Value) ->
    set_header(Basic#'P_basic'{headers = []}, Value);
set_header(#'P_basic'{headers = Headers} = Basic, {Key, _, _} = Value) ->
    Basic#'P_basic'{headers = [Value | lists:keydelete(Key, 1, Headers)]}.

-spec set_header_longstr(basic(), binary(), integer()) -> basic().
set_header_longstr(Basic, Key, Value) ->
    set_header(Basic, {Key, 'longstr', Value}).

-spec set_header_signedint(basic(), binary(), integer()) -> basic().
set_header_signedint(Basic, Key, Value) ->
    set_header(Basic, {Key, 'signedint', Value}).

-spec set_header_decimal(basic(), binary(), {non_neg_integer(), non_neg_integer()}) -> basic().
set_header_decimal(Basic, Key, Value) ->
    set_header(Basic, {Key, 'decimal', Value}).

-spec set_header_table(basic(), binary(), amqp_table()) -> basic().
set_header_table(Basic, Key, Value) ->
    set_header(Basic, {Key, 'table', Value}).

-spec set_header_array(basic(), binary(), amqp_array()) -> basic().
set_header_array(Basic, Key, Value) ->
    set_header(Basic, {Key, 'array', Value}).

-spec set_header_byte(basic(), binary(), byte()) -> basic().
set_header_byte(Basic, Key, Value) ->
    set_header(Basic, {Key, 'byte', Value}).

-spec set_header_double(basic(), binary(), float()) -> basic().
set_header_double(Basic, Key, Value) ->
    set_header(Basic, {Key, 'double', Value}).

-spec set_header_float(basic(), binary(), float()) -> basic().
set_header_float(Basic, Key, Value) ->
    set_header(Basic, {Key, 'float', Value}).

-spec set_header_long(basic(), binary(), integer()) -> basic().
set_header_long(Basic, Key, Value) ->
    set_header(Basic, {Key, 'long', Value}).

-spec set_header_short(basic(), binary(), integer()) -> basic().
set_header_short(Basic, Key, Value) ->
    set_header(Basic, {Key, 'short', Value}).

-spec set_header_bool(basic(), binary(), boolean()) -> basic().
set_header_bool(Basic, Key, Value) ->
    set_header(Basic, {Key, 'bool', Value}).

-spec set_header_binary(basic(), binary(), binary()) -> basic().
set_header_binary(Basic, Key, Value) ->
    set_header(Basic, {Key, 'binary', Value}).

-spec set_header_timestamp(basic(), binary(), non_neg_integer()) -> basic().
set_header_timestamp(Basic, Key, Value) ->
    set_header(Basic, {Key, 'timestamp', Value}).


%% ====================================================================
%% Internal functions
%% ====================================================================
