%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `call_recording_parameters' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_call_recording_parameters).

-export([new/0]).
-export([enabled/1, enabled/2, set_enabled/2]).
-export([format/1, format/2, set_format/2]).
-export([record_min_sec/1, record_min_sec/2, set_record_min_sec/2]).
-export([record_on_answer/1, record_on_answer/2, set_record_on_answer/2]).
-export([record_on_bridge/1, record_on_bridge/2, set_record_on_bridge/2]).
-export([record_sample_rate/1, record_sample_rate/2, set_record_sample_rate/2]).
-export([should_announce_when_recording/1, should_announce_when_recording/2, set_should_announce_when_recording/2]).
-export([should_record_feature_calls/1, should_record_feature_calls/2, set_should_record_feature_calls/2]).
-export([time_limit/1, time_limit/2, set_time_limit/2]).
-export([url/1, url/2, set_url/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"call_recording.parameters">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec enabled(doc()) -> kz_term:api_boolean().
enabled(Doc) ->
    enabled(Doc, 'undefined').

-spec enabled(doc(), Default) -> boolean() | Default.
enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"enabled">>], Doc, Default).

-spec set_enabled(doc(), boolean()) -> doc().
set_enabled(Doc, Enabled) ->
    kz_json:set_value([<<"enabled">>], Enabled, Doc).

-spec format(doc()) -> kz_term:api_binary().
format(Doc) ->
    format(Doc, 'undefined').

-spec format(doc(), Default) -> binary() | Default.
format(Doc, Default) ->
    kz_json:get_binary_value([<<"format">>], Doc, Default).

-spec set_format(doc(), binary()) -> doc().
set_format(Doc, Format) ->
    kz_json:set_value([<<"format">>], Format, Doc).

-spec record_min_sec(doc()) -> kz_term:api_integer().
record_min_sec(Doc) ->
    record_min_sec(Doc, 'undefined').

-spec record_min_sec(doc(), Default) -> integer() | Default.
record_min_sec(Doc, Default) ->
    kz_json:get_integer_value([<<"record_min_sec">>], Doc, Default).

-spec set_record_min_sec(doc(), integer()) -> doc().
set_record_min_sec(Doc, RecordMinSec) ->
    kz_json:set_value([<<"record_min_sec">>], RecordMinSec, Doc).

-spec record_on_answer(doc()) -> kz_term:api_boolean().
record_on_answer(Doc) ->
    record_on_answer(Doc, 'undefined').

-spec record_on_answer(doc(), Default) -> boolean() | Default.
record_on_answer(Doc, Default) ->
    kz_json:get_boolean_value([<<"record_on_answer">>], Doc, Default).

-spec set_record_on_answer(doc(), boolean()) -> doc().
set_record_on_answer(Doc, RecordOnAnswer) ->
    kz_json:set_value([<<"record_on_answer">>], RecordOnAnswer, Doc).

-spec record_on_bridge(doc()) -> kz_term:api_boolean().
record_on_bridge(Doc) ->
    record_on_bridge(Doc, 'undefined').

-spec record_on_bridge(doc(), Default) -> boolean() | Default.
record_on_bridge(Doc, Default) ->
    kz_json:get_boolean_value([<<"record_on_bridge">>], Doc, Default).

-spec set_record_on_bridge(doc(), boolean()) -> doc().
set_record_on_bridge(Doc, RecordOnBridge) ->
    kz_json:set_value([<<"record_on_bridge">>], RecordOnBridge, Doc).

-spec record_sample_rate(doc()) -> kz_term:api_integer().
record_sample_rate(Doc) ->
    record_sample_rate(Doc, 'undefined').

-spec record_sample_rate(doc(), Default) -> integer() | Default.
record_sample_rate(Doc, Default) ->
    kz_json:get_integer_value([<<"record_sample_rate">>], Doc, Default).

-spec set_record_sample_rate(doc(), integer()) -> doc().
set_record_sample_rate(Doc, RecordSampleRate) ->
    kz_json:set_value([<<"record_sample_rate">>], RecordSampleRate, Doc).

-spec should_announce_when_recording(doc()) -> kz_term:api_boolean().
should_announce_when_recording(Doc) ->
    should_announce_when_recording(Doc, 'undefined').

-spec should_announce_when_recording(doc(), Default) -> boolean() | Default.
should_announce_when_recording(Doc, Default) ->
    kz_json:get_boolean_value([<<"should_announce_when_recording">>], Doc, Default).

-spec set_should_announce_when_recording(doc(), boolean()) -> doc().
set_should_announce_when_recording(Doc, ShouldAnnounceWhenRecording) ->
    kz_json:set_value([<<"should_announce_when_recording">>], ShouldAnnounceWhenRecording, Doc).

-spec should_record_feature_calls(doc()) -> boolean().
should_record_feature_calls(Doc) ->
    should_record_feature_calls(Doc, 'true').

-spec should_record_feature_calls(doc(), Default) -> boolean() | Default.
should_record_feature_calls(Doc, Default) ->
    kz_json:get_boolean_value([<<"should_record_feature_calls">>], Doc, Default).

-spec set_should_record_feature_calls(doc(), boolean()) -> doc().
set_should_record_feature_calls(Doc, ShouldRecordFeatureCalls) ->
    kz_json:set_value([<<"should_record_feature_calls">>], ShouldRecordFeatureCalls, Doc).

-spec time_limit(doc()) -> kz_term:api_integer().
time_limit(Doc) ->
    time_limit(Doc, 'undefined').

-spec time_limit(doc(), Default) -> integer() | Default.
time_limit(Doc, Default) ->
    kz_json:get_integer_value([<<"time_limit">>], Doc, Default).

-spec set_time_limit(doc(), integer()) -> doc().
set_time_limit(Doc, TimeLimit) ->
    kz_json:set_value([<<"time_limit">>], TimeLimit, Doc).

-spec url(doc()) -> kz_term:api_ne_binary().
url(Doc) ->
    url(Doc, 'undefined').

-spec url(doc(), Default) -> kz_term:ne_binary() | Default.
url(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"url">>], Doc, Default).

-spec set_url(doc(), kz_term:ne_binary()) -> doc().
set_url(Doc, Url) ->
    kz_json:set_value([<<"url">>], Url, Doc).
