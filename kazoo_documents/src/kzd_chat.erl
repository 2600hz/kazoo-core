%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_chat).

-export([chat/1, chat/2, set_chat/2]).
-export([chat_getstream/1, chat_getstream/2, set_chat_getstream/2]).
-export([chat_getstream_enabled/1, chat_getstream_enabled/2, set_chat_getstream_enabled/2]).

-type doc() :: kz_json:object().
-type docs() :: [doc()].
-export_type([doc/0, docs/0]).

-spec chat(doc()) -> kz_term:api_object().
chat(Doc) ->
    chat(Doc, 'undefined').

-spec chat(doc(), Default) -> kz_json:object() | Default.
chat(Doc, Default) ->
    kz_json:get_json_value([<<"pvt_chat">>], Doc, Default).

-spec set_chat(doc(), kz_json:object()) -> doc().
set_chat(Doc, Chat) ->
    kz_json:set_value([<<"pvt_chat">>], Chat, Doc).

-spec chat_getstream(doc()) -> kz_term:api_object().
chat_getstream(Doc) ->
    chat_getstream(Doc, 'undefined').

-spec chat_getstream(doc(), Default) -> kz_json:object() | Default.
chat_getstream(Doc, Default) ->
    kz_json:get_json_value([<<"pvt_chat">>, <<"getstream">>], Doc, Default).

-spec set_chat_getstream(doc(), kz_json:object()) -> doc().
set_chat_getstream(Doc, ChatGetstream) ->
    kz_json:set_value([<<"pvt_chat">>, <<"getstream">>], ChatGetstream, Doc).

-spec chat_getstream_enabled(doc()) -> boolean().
chat_getstream_enabled(Doc) ->
    chat_getstream_enabled(Doc, 'false').

-spec chat_getstream_enabled(doc(), Default) -> boolean() | Default.
chat_getstream_enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"pvt_chat">>, <<"getstream">>, <<"enabled">>], Doc, Default).

-spec set_chat_getstream_enabled(doc(), boolean()) -> doc().
set_chat_getstream_enabled(Doc, ChatGetstreamEnabled) ->
    kz_json:set_value([<<"pvt_chat">>, <<"getstream">>, <<"enabled">>], ChatGetstreamEnabled, Doc).

