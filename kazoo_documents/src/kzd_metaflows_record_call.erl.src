%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `metaflows_record_call' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_record_call).

-export([new/0]).
-export([action/1, action/2, set_action/2]).
-export([format/1, format/2, set_format/2]).
-export([label/1, label/2, set_label/2]).
-export([media_name/1, media_name/2, set_media_name/2]).
-export([method/1, method/2, set_method/2]).
-export([origin/1, origin/2, set_origin/2]).
-export([record_min_sec/1, record_min_sec/2, set_record_min_sec/2]).
-export([record_on_answer/1, record_on_answer/2, set_record_on_answer/2]).
-export([record_on_bridge/1, record_on_bridge/2, set_record_on_bridge/2]).
-export([record_sample_rate/1, record_sample_rate/2, set_record_sample_rate/2]).
-export([time_limit/1, time_limit/2, set_time_limit/2]).
-export([url/1, url/2, set_url/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.record_call">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec action(doc()) -> binary().
action(Doc) ->
    action(Doc, <<"toggle">>).

-spec action(doc(), Default) -> binary() | Default.
action(Doc, Default) ->
    kz_json:get_binary_value([<<"action">>], Doc, Default).

-spec set_action(doc(), binary()) -> doc().
set_action(Doc, Action) ->
    kz_json:set_value([<<"action">>], Action, Doc).

-spec format(doc()) -> kz_term:api_binary().
format(Doc) ->
    format(Doc, 'undefined').

-spec format(doc(), Default) -> binary() | Default.
format(Doc, Default) ->
    kz_json:get_binary_value([<<"format">>], Doc, Default).

-spec set_format(doc(), binary()) -> doc().
set_format(Doc, Format) ->
    kz_json:set_value([<<"format">>], Format, Doc).

-spec label(doc()) -> kz_term:api_binary().
label(Doc) ->
    label(Doc, 'undefined').

-spec label(doc(), Default) -> binary() | Default.
label(Doc, Default) ->
    kz_json:get_binary_value([<<"label">>], Doc, Default).

-spec set_label(doc(), binary()) -> doc().
set_label(Doc, Label) ->
    kz_json:set_value([<<"label">>], Label, Doc).

-spec media_name(doc()) -> kz_term:api_binary().
media_name(Doc) ->
    media_name(Doc, 'undefined').

-spec media_name(doc(), Default) -> binary() | Default.
media_name(Doc, Default) ->
    kz_json:get_binary_value([<<"media_name">>], Doc, Default).

-spec set_media_name(doc(), binary()) -> doc().
set_media_name(Doc, MediaName) ->
    kz_json:set_value([<<"media_name">>], MediaName, Doc).

-spec method(doc()) -> kz_term:api_binary().
method(Doc) ->
    method(Doc, 'undefined').

-spec method(doc(), Default) -> binary() | Default.
method(Doc, Default) ->
    kz_json:get_binary_value([<<"method">>], Doc, Default).

-spec set_method(doc(), binary()) -> doc().
set_method(Doc, Method) ->
    kz_json:set_value([<<"method">>], Method, Doc).

-spec origin(doc()) -> kz_term:api_binary().
origin(Doc) ->
    origin(Doc, 'undefined').

-spec origin(doc(), Default) -> binary() | Default.
origin(Doc, Default) ->
    kz_json:get_binary_value([<<"origin">>], Doc, Default).

-spec set_origin(doc(), binary()) -> doc().
set_origin(Doc, Origin) ->
    kz_json:set_value([<<"origin">>], Origin, Doc).

-spec record_min_sec(doc()) -> kz_term:api_integer().
record_min_sec(Doc) ->
    record_min_sec(Doc, 'undefined').

-spec record_min_sec(doc(), Default) -> integer() | Default.
record_min_sec(Doc, Default) ->
    kz_json:get_integer_value([<<"record_min_sec">>], Doc, Default).

-spec set_record_min_sec(doc(), integer()) -> doc().
set_record_min_sec(Doc, RecordMinSec) ->
    kz_json:set_value([<<"record_min_sec">>], RecordMinSec, Doc).

-spec record_on_answer(doc()) -> boolean().
record_on_answer(Doc) ->
    record_on_answer(Doc, 'false').

-spec record_on_answer(doc(), Default) -> boolean() | Default.
record_on_answer(Doc, Default) ->
    kz_json:get_boolean_value([<<"record_on_answer">>], Doc, Default).

-spec set_record_on_answer(doc(), boolean()) -> doc().
set_record_on_answer(Doc, RecordOnAnswer) ->
    kz_json:set_value([<<"record_on_answer">>], RecordOnAnswer, Doc).

-spec record_on_bridge(doc()) -> boolean().
record_on_bridge(Doc) ->
    record_on_bridge(Doc, 'false').

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
