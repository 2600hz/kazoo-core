%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_tts_utils).

-export([create_response/1
        ,check_response/3
        ]).

-spec create_response(kz_http:ret()) ->
          kz_http:req_id() |
          {'ok', kz_term:ne_binary(), kz_term:ne_binary()} |
          {'error', 'tts_provider_failure', binary()}.
create_response({'error', _R}) ->
    lager:warning("creating speech file failed with error ~p", [_R]),
    {'error', 'tts_provider_failure', <<"unexpected error encountered accessing provider">>};
create_response({'http_req_id', ReqID}) ->
    lager:debug("speech file streaming as ~p", [ReqID]),
    {'async', ReqID, 'undefined'};
create_response({'ok', 200, Headers, Content}) ->
    check_response(kz_term:to_binary(props:get_value("content-type", Headers))
                  ,kz_term:to_integer(props:get_value("content-length", Headers))
                  ,Content
                  );
create_response({'ok', _Code, RespHeaders, Content}) ->
    lager:warning("creating speech file failed with code ~p: ~p", [_Code, Content]),
    _ = [lager:debug("hdr: ~p", [H]) || H <- RespHeaders],
    {'error', 'tts_provider_failure', kz_json:get_value(<<"message">>, kz_json:decode(Content))}.

-spec check_response(kz_term:ne_binary(), integer(), kz_term:ne_binary()) ->
          {'ok', kz_term:ne_binary(), kz_term:ne_binary()} |
          {'error', 'tts_provider_failure', binary()}.
check_response(_ContentType, 0, _Content) ->
    lager:info("zero-length TTS response, considering an error"),
    {'error', 'tts_provider_failure', <<"no content returned">>};
check_response(ContentType, ContentLength, Content) ->
    lager:debug("created speech file ~s of length ~s", [ContentType, ContentLength]),
    {'ok', ContentType, Content}.
