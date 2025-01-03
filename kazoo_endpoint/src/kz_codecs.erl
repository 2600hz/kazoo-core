%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_codecs).

-export([audio_codecs/1, audio_codecs/2
        ,video_codecs/1, video_codecs/2
        ]).

-type doc() :: kz_json:object().
-export_type([doc/0]).

-spec audio_codecs(doc()) -> kz_term:api_ne_binaries().
audio_codecs(Doc) ->
    audio_codecs(Doc, 'undefined').

-spec audio_codecs(doc(), Default) -> kz_term:ne_binaries() | Default.
audio_codecs(Doc, Default) ->
    codecs(Doc, Default, <<"audio">>).

-spec video_codecs(doc()) -> kz_term:api_ne_binaries().
video_codecs(Doc) ->
    video_codecs(Doc, 'undefined').

-spec video_codecs(doc(), Default) -> kz_term:ne_binaries() | Default.
video_codecs(Doc, Default) ->
    codecs(Doc, Default, <<"video">>).

-spec codecs(doc(), Default, kz_term:ne_binary()) -> kz_term:ne_binaries() | Default.
codecs(Doc, Default, MediaType) ->
    case kz_json:get_list_value([<<"media">>, MediaType, <<"codecs">>], Doc, Default) of
        [_ | _] = Codecs -> transform(Doc, MediaType, Codecs);
        _Other -> Default
    end.

codec_formats(Payload, MediaType) ->
    kz_json:get_json_value([<<"media">>, MediaType, <<"codec_formats">>], Payload).

transform(JObj, MediaType, Codecs) ->
    case codec_formats(JObj, MediaType) of
        'undefined' -> Codecs;
        Formats -> lists:foldr(transform_fun(Formats), [], Codecs)
    end.

transform_fun(Formats) ->
    fun(Codec, Codecs) ->
            case kz_json:get_list_value(Codec, Formats) of
                'undefined' -> [Codec | Codecs];
                List -> transform_codec(Codec, List) ++ Codecs
            end
    end.

transform_codec(Codec, List) ->
    [list_to_binary([Codec, "~", Format]) || Format <- List].
