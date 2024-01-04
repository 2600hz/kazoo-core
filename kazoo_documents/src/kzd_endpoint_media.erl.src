%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `endpoint_media' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_endpoint_media).

-export([new/0]).
-export([audio/1, audio/2, set_audio/2]).
-export([audio_codecs/1, audio_codecs/2, set_audio_codecs/2]).
-export([bypass_media/1, bypass_media/2, set_bypass_media/2]).
-export([encryption/1, encryption/2, set_encryption/2]).
-export([encryption_enforce_security/1, encryption_enforce_security/2, set_encryption_enforce_security/2]).
-export([encryption_methods/1, encryption_methods/2, set_encryption_methods/2]).
-export([fax_option/1, fax_option/2, set_fax_option/2]).
-export([ignore_early_media/1, ignore_early_media/2, set_ignore_early_media/2]).
-export([progress_timeout/1, progress_timeout/2, set_progress_timeout/2]).
-export([video/1, video/2, set_video/2]).
-export([video_codecs/1, video_codecs/2, set_video_codecs/2]).
-export([webrtc/1, webrtc/2, set_webrtc/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"endpoint.media">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec audio(doc()) -> kz_json:object().
audio(Doc) ->
    audio(Doc, kz_json:new()).

-spec audio(doc(), Default) -> kz_json:object() | Default.
audio(Doc, Default) ->
    kz_json:get_json_value([<<"audio">>], Doc, Default).

-spec set_audio(doc(), kz_json:object()) -> doc().
set_audio(Doc, Audio) ->
    kz_json:set_value([<<"audio">>], Audio, Doc).

-spec audio_codecs(doc()) -> kz_term:api_ne_binaries().
audio_codecs(Doc) ->
    audio_codecs(Doc, 'undefined').

-spec audio_codecs(doc(), Default) -> kz_term:ne_binaries() | Default.
audio_codecs(Doc, Default) ->
    kz_json:get_list_value([<<"audio">>, <<"codecs">>], Doc, Default).

-spec set_audio_codecs(doc(), kz_term:ne_binaries()) -> doc().
set_audio_codecs(Doc, AudioCodecs) ->
    kz_json:set_value([<<"audio">>, <<"codecs">>], AudioCodecs, Doc).

-spec bypass_media(doc()) -> any().
bypass_media(Doc) ->
    bypass_media(Doc, 'undefined').

-spec bypass_media(doc(), Default) -> any() | Default.
bypass_media(Doc, Default) ->
    kz_json:get_value([<<"bypass_media">>], Doc, Default).

-spec set_bypass_media(doc(), any()) -> doc().
set_bypass_media(Doc, BypassMedia) ->
    kz_json:set_value([<<"bypass_media">>], BypassMedia, Doc).

-spec encryption(doc()) -> kz_json:object().
encryption(Doc) ->
    encryption(Doc, kz_json:new()).

-spec encryption(doc(), Default) -> kz_json:object() | Default.
encryption(Doc, Default) ->
    kz_json:get_json_value([<<"encryption">>], Doc, Default).

-spec set_encryption(doc(), kz_json:object()) -> doc().
set_encryption(Doc, Encryption) ->
    kz_json:set_value([<<"encryption">>], Encryption, Doc).

-spec encryption_enforce_security(doc()) -> boolean().
encryption_enforce_security(Doc) ->
    encryption_enforce_security(Doc, 'false').

-spec encryption_enforce_security(doc(), Default) -> boolean() | Default.
encryption_enforce_security(Doc, Default) ->
    kz_json:get_boolean_value([<<"encryption">>, <<"enforce_security">>], Doc, Default).

-spec set_encryption_enforce_security(doc(), boolean()) -> doc().
set_encryption_enforce_security(Doc, EncryptionEnforceSecurity) ->
    kz_json:set_value([<<"encryption">>, <<"enforce_security">>], EncryptionEnforceSecurity, Doc).

-spec encryption_methods(doc()) -> kz_term:ne_binaries().
encryption_methods(Doc) ->
    encryption_methods(Doc, []).

-spec encryption_methods(doc(), Default) -> kz_term:ne_binaries() | Default.
encryption_methods(Doc, Default) ->
    kz_json:get_list_value([<<"encryption">>, <<"methods">>], Doc, Default).

-spec set_encryption_methods(doc(), kz_term:ne_binaries()) -> doc().
set_encryption_methods(Doc, EncryptionMethods) ->
    kz_json:set_value([<<"encryption">>, <<"methods">>], EncryptionMethods, Doc).

-spec fax_option(doc()) -> kz_term:api_boolean().
fax_option(Doc) ->
    fax_option(Doc, 'undefined').

-spec fax_option(doc(), Default) -> boolean() | Default.
fax_option(Doc, Default) ->
    kz_json:get_boolean_value([<<"fax_option">>], Doc, Default).

-spec set_fax_option(doc(), boolean()) -> doc().
set_fax_option(Doc, FaxOption) ->
    kz_json:set_value([<<"fax_option">>], FaxOption, Doc).

-spec ignore_early_media(doc()) -> kz_term:api_boolean().
ignore_early_media(Doc) ->
    ignore_early_media(Doc, 'undefined').

-spec ignore_early_media(doc(), Default) -> boolean() | Default.
ignore_early_media(Doc, Default) ->
    kz_json:get_boolean_value([<<"ignore_early_media">>], Doc, Default).

-spec set_ignore_early_media(doc(), boolean()) -> doc().
set_ignore_early_media(Doc, IgnoreEarlyMedia) ->
    kz_json:set_value([<<"ignore_early_media">>], IgnoreEarlyMedia, Doc).

-spec progress_timeout(doc()) -> kz_term:api_integer().
progress_timeout(Doc) ->
    progress_timeout(Doc, 'undefined').

-spec progress_timeout(doc(), Default) -> integer() | Default.
progress_timeout(Doc, Default) ->
    kz_json:get_integer_value([<<"progress_timeout">>], Doc, Default).

-spec set_progress_timeout(doc(), integer()) -> doc().
set_progress_timeout(Doc, ProgressTimeout) ->
    kz_json:set_value([<<"progress_timeout">>], ProgressTimeout, Doc).

-spec video(doc()) -> kz_json:object().
video(Doc) ->
    video(Doc, kz_json:new()).

-spec video(doc(), Default) -> kz_json:object() | Default.
video(Doc, Default) ->
    kz_json:get_json_value([<<"video">>], Doc, Default).

-spec set_video(doc(), kz_json:object()) -> doc().
set_video(Doc, Video) ->
    kz_json:set_value([<<"video">>], Video, Doc).

-spec video_codecs(doc()) -> kz_term:api_ne_binaries().
video_codecs(Doc) ->
    video_codecs(Doc, 'undefined').

-spec video_codecs(doc(), Default) -> kz_term:ne_binaries() | Default.
video_codecs(Doc, Default) ->
    kz_json:get_list_value([<<"video">>, <<"codecs">>], Doc, Default).

-spec set_video_codecs(doc(), kz_term:ne_binaries()) -> doc().
set_video_codecs(Doc, VideoCodecs) ->
    kz_json:set_value([<<"video">>, <<"codecs">>], VideoCodecs, Doc).

-spec webrtc(doc()) -> kz_term:api_boolean().
webrtc(Doc) ->
    webrtc(Doc, 'undefined').

-spec webrtc(doc(), Default) -> boolean() | Default.
webrtc(Doc, Default) ->
    kz_json:get_boolean_value([<<"webrtc">>], Doc, Default).

-spec set_webrtc(doc(), boolean()) -> doc().
set_webrtc(Doc, Webrtc) ->
    kz_json:set_value([<<"webrtc">>], Webrtc, Doc).
