%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `caller_id_options' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_caller_id_options).

-export([new/0]).
-export([format/1, format/2, set_format/2]).
-export([format_all/1, format_all/2, set_format_all/2]).
-export([format_all_prefix/1, format_all_prefix/2, set_format_all_prefix/2]).
-export([format_all_regex/1, format_all_regex/2, set_format_all_regex/2]).
-export([format_all_suffix/1, format_all_suffix/2, set_format_all_suffix/2]).
-export([format_index/2, format_index/3, set_format_index/3]).
-export([ignore_completed_elsewhere/1, ignore_completed_elsewhere/2, set_ignore_completed_elsewhere/2]).
-export([outbound_privacy/1, outbound_privacy/2, set_outbound_privacy/2]).
-export([privacy_method/1, privacy_method/2, set_privacy_method/2]).
-export([show_rate/1, show_rate/2, set_show_rate/2]).
-export([type/1, type/2, set_type/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"caller_id_options">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec format(doc()) -> kz_term:api_object().
format(Doc) ->
    format(Doc, 'undefined').

-spec format(doc(), Default) -> kz_json:object() | Default.
format(Doc, Default) ->
    kz_json:get_json_value([<<"format">>], Doc, Default).

-spec set_format(doc(), kz_json:object()) -> doc().
set_format(Doc, Format) ->
    kz_json:set_value([<<"format">>], Format, Doc).

-spec format_all(doc()) -> kz_term:api_object().
format_all(Doc) ->
    format_all(Doc, 'undefined').

-spec format_all(doc(), Default) -> kz_json:object() | Default.
format_all(Doc, Default) ->
    kz_json:get_json_value([<<"format">>, <<"all">>], Doc, Default).

-spec set_format_all(doc(), kz_json:object()) -> doc().
set_format_all(Doc, FormatAll) ->
    kz_json:set_value([<<"format">>, <<"all">>], FormatAll, Doc).

-spec format_all_prefix(doc()) -> kz_term:api_binary().
format_all_prefix(Doc) ->
    format_all_prefix(Doc, 'undefined').

-spec format_all_prefix(doc(), Default) -> binary() | Default.
format_all_prefix(Doc, Default) ->
    kz_json:get_binary_value([<<"format">>, <<"all">>, <<"prefix">>], Doc, Default).

-spec set_format_all_prefix(doc(), binary()) -> doc().
set_format_all_prefix(Doc, FormatAllPrefix) ->
    kz_json:set_value([<<"format">>, <<"all">>, <<"prefix">>], FormatAllPrefix, Doc).

-spec format_all_regex(doc()) -> kz_term:api_binary().
format_all_regex(Doc) ->
    format_all_regex(Doc, 'undefined').

-spec format_all_regex(doc(), Default) -> binary() | Default.
format_all_regex(Doc, Default) ->
    kz_json:get_binary_value([<<"format">>, <<"all">>, <<"regex">>], Doc, Default).

-spec set_format_all_regex(doc(), binary()) -> doc().
set_format_all_regex(Doc, FormatAllRegex) ->
    kz_json:set_value([<<"format">>, <<"all">>, <<"regex">>], FormatAllRegex, Doc).

-spec format_all_suffix(doc()) -> kz_term:api_binary().
format_all_suffix(Doc) ->
    format_all_suffix(Doc, 'undefined').

-spec format_all_suffix(doc(), Default) -> binary() | Default.
format_all_suffix(Doc, Default) ->
    kz_json:get_binary_value([<<"format">>, <<"all">>, <<"suffix">>], Doc, Default).

-spec set_format_all_suffix(doc(), binary()) -> doc().
set_format_all_suffix(Doc, FormatAllSuffix) ->
    kz_json:set_value([<<"format">>, <<"all">>, <<"suffix">>], FormatAllSuffix, Doc).

-spec format_index(doc(), kz_json:key()) -> kz_term:api_object().
format_index(Doc, FormatIndex) ->
    format_index(Doc, FormatIndex, 'undefined').

-spec format_index(doc(), kz_json:key(), Default) -> kz_json:object() | Default.
format_index(Doc, FormatIndex, Default) ->
    kz_json:get_json_value([<<"format">>, FormatIndex], Doc, Default).

-spec set_format_index(doc(), kz_json:key(), kz_json:object()) -> doc().
set_format_index(Doc, FormatIndex, Value) ->
    kz_json:set_value([<<"format">>, FormatIndex], Value, Doc).

-spec ignore_completed_elsewhere(doc()) -> kz_term:api_boolean().
ignore_completed_elsewhere(Doc) ->
    ignore_completed_elsewhere(Doc, 'undefined').

-spec ignore_completed_elsewhere(doc(), Default) -> boolean() | Default.
ignore_completed_elsewhere(Doc, Default) ->
    kz_json:get_boolean_value([<<"ignore_completed_elsewhere">>], Doc, Default).

-spec set_ignore_completed_elsewhere(doc(), boolean()) -> doc().
set_ignore_completed_elsewhere(Doc, IgnoreCompletedElsewhere) ->
    kz_json:set_value([<<"ignore_completed_elsewhere">>], IgnoreCompletedElsewhere, Doc).

-spec outbound_privacy(doc()) -> kz_term:api_binary().
outbound_privacy(Doc) ->
    outbound_privacy(Doc, 'undefined').

-spec outbound_privacy(doc(), Default) -> binary() | Default.
outbound_privacy(Doc, Default) ->
    kz_json:get_binary_value([<<"outbound_privacy">>], Doc, Default).

-spec set_outbound_privacy(doc(), binary()) -> doc().
set_outbound_privacy(Doc, OutboundPrivacy) ->
    kz_json:set_value([<<"outbound_privacy">>], OutboundPrivacy, Doc).

-spec privacy_method(doc()) -> kz_term:api_binary().
privacy_method(Doc) ->
    privacy_method(Doc, 'undefined').

-spec privacy_method(doc(), Default) -> binary() | Default.
privacy_method(Doc, Default) ->
    kz_json:get_binary_value([<<"privacy_method">>], Doc, Default).

-spec set_privacy_method(doc(), binary()) -> doc().
set_privacy_method(Doc, PrivacyMethod) ->
    kz_json:set_value([<<"privacy_method">>], PrivacyMethod, Doc).

-spec show_rate(doc()) -> kz_term:api_boolean().
show_rate(Doc) ->
    show_rate(Doc, 'undefined').

-spec show_rate(doc(), Default) -> boolean() | Default.
show_rate(Doc, Default) ->
    kz_json:get_boolean_value([<<"show_rate">>], Doc, Default).

-spec set_show_rate(doc(), boolean()) -> doc().
set_show_rate(Doc, ShowRate) ->
    kz_json:set_value([<<"show_rate">>], ShowRate, Doc).

-spec type(doc()) -> kz_term:api_binary().
type(Doc) ->
    type(Doc, 'undefined').

-spec type(doc(), Default) -> binary() | Default.
type(Doc, Default) ->
    kz_json:get_binary_value([<<"type">>], Doc, Default).

-spec set_type(doc(), binary()) -> doc().
set_type(Doc, Type) ->
    kz_json:set_value([<<"type">>], Type, Doc).
