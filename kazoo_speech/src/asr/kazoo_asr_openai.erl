%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2018-2025, 2600Hz
%%% @doc This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_asr_openai).
-behaviour(gen_asr_provider).

-export([available/0]).
-export([preferred_content_type/0]).
-export([accepted_content_types/0]).
-export([freeform/4]).
-export([commands/5]).
-export([set_api_key/1]).

-include("kazoo_speech.hrl").

-define(OPENAI_CONFIG_CAT, <<(?MOD_CONFIG_CAT)/binary, ".openai">>).
-define(OPENAI_ASR_URL, kapps_config:get_binary(?OPENAI_CONFIG_CAT, <<"asr_url">>, <<"https://api.openai.com/v1/audio/transcriptions">>)).
-define(OPENAI_ASR_KEY, kapps_config:get_string(?OPENAI_CONFIG_CAT, <<"asr_api_key">>, <<>>)).
-define(OPENAI_ASR_MODEL, kapps_config:get_binary(?OPENAI_CONFIG_CAT, <<"asr_model">>, <<"gpt-4o-transcribe">>)).
-define(OPENAI_ASR_PREFERRED_CONTENT_TYPE, <<"audio/mpeg">>).
-define(OPENAI_ASR_ACCEPTED_CONTENT_TYPES, [<<"audio/mpeg">>, <<"audio/wav">>]).
-define(OPENAI_EXTENSION_MAPPINGS, [{<<"audio/wav">>, <<"wav">>}, {<<"audio/mpeg">>, <<"mp3">>}]).

%%%------------------------------------------------------------------------------
%%% @doc Return true if IBM ASR is configured / available otherwise false.
%%% @end
%%%------------------------------------------------------------------------------
-spec available() -> boolean().
available() ->
    kz_term:is_not_empty(?OPENAI_ASR_KEY)
        andalso kz_term:is_not_empty(?OPENAI_ASR_URL).

%%%-----------------------------------------------------------------------------
%%% @doc Return or set the preferred asr content type for the ASR provider
%%% @end
%%%-----------------------------------------------------------------------------
-spec preferred_content_type() -> kz_term:ne_binary().
preferred_content_type() ->
    ?OPENAI_ASR_PREFERRED_CONTENT_TYPE.

%%%-----------------------------------------------------------------------------
%%% @doc Return list of supported Content Types by ASR provider
%%% @end
%%%-----------------------------------------------------------------------------
-spec accepted_content_types() -> kz_term:ne_binaries().
accepted_content_types() ->
    ?OPENAI_ASR_ACCEPTED_CONTENT_TYPES.

%%%-----------------------------------------------------------------------------
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-spec commands(kz_term:ne_binary(), kz_term:ne_binaries(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> provider_return().
commands(_Bin, _Commands, _ContentType, _Locale, _Opts) ->
    {'error', 'asr_provider_failure', <<"not implemented">>}.

%%%-----------------------------------------------------------------------------
%%% @doc Callback for API request to ASR Provider and handle transcription response.
%%% @end
%%%-----------------------------------------------------------------------------
-spec freeform(binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> asr_resp().
freeform(Content, ContentType, Locale, Options) ->
    case kazoo_asr_util:maybe_convert_content(Content, ContentType, accepted_content_types(), preferred_content_type()) of
        {'error', _}=E -> E;
        {Content1, ContentType1} -> exec_freeform(Content1, ContentType1, Locale, Options)
    end.

-spec exec_freeform(binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) ->
          asr_resp().
exec_freeform(Content, ContentType, _Locale, Options) ->
    URL = ?OPENAI_ASR_URL,
    Boundary = kz_http_util:create_boundary(),
    Body = create_multipart_body(Content, ContentType, Boundary),
    Headers =  [{"Content-Type", "multipart/form-data; boundary=" ++ kz_term:to_list(Boundary)}
               ,{"Authorization", "Bearer " ++ ?OPENAI_ASR_KEY}
               ],
    lager:debug("sending request to ~s", [URL]),
    handle_response(make_request(URL, Headers, Body, Options)).

%kz_term:to_binary([ContentType, ";base64"]
create_multipart_body(Content, ContentType, Boundary) ->
    Extension = props:get_value(ContentType, ?OPENAI_EXTENSION_MAPPINGS),
    Parts = [{Content
             ,[{<<"content-disposition">>, <<"form-data; name=file; filename=asr.", Extension/binary>>}
              ,{<<"content-type">>, <<"text/plain">>}
              ]
             }
            ,{?OPENAI_ASR_MODEL
             ,[{<<"content-disposition">>, <<"form-data; name=model">>}
              ,{<<"content-type">>, <<"text/plain">>}
              ]
             }
            ],
    kz_http_util:encode_multipart(Parts, Boundary).

%%%-----------------------------------------------------------------------------
%%% @doc Execute API request to ASR Provider and handle transcription response.
%%% @end
%%%-----------------------------------------------------------------------------
-spec make_request(kz_term:ne_binary(), kz_term:proplist(), iodata(), kz_term:proplist()) ->
          kz_http:ret().
make_request(BaseUrl, Headers, Body, Opts) ->
    case props:get_value('receiver', Opts) of
        Pid when is_pid(Pid) ->
            HTTPOptions = props:delete('receiver', Opts),
            lager:debug("streaming response to ~p", [Pid]),
            kz_http:async_req(Pid, 'post', kz_term:to_list(BaseUrl), Headers, Body, HTTPOptions);
        _ ->
            HTTPOptions = props:delete('receiver', Opts),
            kz_http:post(kz_term:to_list(BaseUrl), Headers, Body, HTTPOptions)
    end.

-spec handle_response(kz_http:ret()) -> asr_resp().
handle_response({'error', _R}=E) ->
    lager:debug("asr failed with error ~p", [_R]),
    E;
handle_response({'http_req_id', ReqID}) ->
    lager:debug("streaming response ~p to provided receiver", [ReqID]),
    {'ok', ReqID};
handle_response({'ok', 200, _Headers, Content2}) ->
    lager:debug("ASR of media succeeded"),
    Text = kz_json:get_value(<<"text">>, kz_json:decode(Content2)),
    Props = [{<<"result">>, <<"success">>}
            ,{<<"text">>, Text}
            ],
    {'ok', kz_json:from_list(Props)};
handle_response({'ok', _Code, _Hdrs, Content2}) ->
    lager:debug("asr of media failed with code ~p", [_Code]),
    lager:debug("resp: ~s", [Content2]),
    {'error', 'asr_provider_failure', Content2}.

%%%-----------------------------------------------------------------------------
%%% @doc Set the asr key
%%% @end
%%%-----------------------------------------------------------------------------
-spec set_api_key(kz_term:ne_binary()) -> 'ok'.
set_api_key(Key) ->
    {'ok', _} = kapps_config:set_default(?OPENAI_CONFIG_CAT, <<"asr_api_key">>, Key),
    'ok'.
