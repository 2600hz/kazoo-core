%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `pivot' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_pivot).

-export([new/0]).
-export([id/1]).
-export([cdr_url/1, cdr_url/2, set_cdr_url/2]).
-export([custom_request_headers/1, custom_request_headers/2, set_custom_request_headers/2]).
-export([debug/1, debug/2, set_debug/2]).
-export([method/1, method/2, set_method/2]).
-export([req_body_format/1, req_body_format/2, set_req_body_format/2]).
-export([req_format/1, req_format/2, set_req_format/2]).
-export([req_timeout_ms/1, req_timeout_ms/2, set_req_timeout_ms/2]).
-export([serverless/1, serverless/2, set_serverless/2]).
-export([serverless_flow_doc/1, serverless_flow_doc/2, set_serverless_flow_doc/2]).
-export([serverless_flow_type/1, serverless_flow_type/2, set_serverless_flow_type/2]).
-export([skip_module/1, skip_module/2, set_skip_module/2]).
-export([voice_url/1, voice_url/2, set_voice_url/2]).

-export([type/0]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-type docs() :: [doc()].
-export_type([doc/0
             ,docs/0
             ]).

-define(SCHEMA, <<"pivot">>).
-define(PVT_TYPE, <<"pivot">>).

-spec type() -> kz_term:ne_binary().
type() -> ?PVT_TYPE.

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec id(doc()) -> kz_term:api_ne_binary().
id(Doc) ->
    kz_json:get_ne_binary_value(<<"id">>, Doc).

-spec cdr_url(doc()) -> kz_term:api_ne_binary().
cdr_url(Doc) ->
    cdr_url(Doc, 'undefined').

-spec cdr_url(doc(), Default) -> kz_term:ne_binary() | Default.
cdr_url(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"cdr_url">>], Doc, Default).

-spec set_cdr_url(doc(), kz_term:ne_binary()) -> doc().
set_cdr_url(Doc, CdrUrl) ->
    kz_json:set_value([<<"cdr_url">>], CdrUrl, Doc).

-spec custom_request_headers(doc()) -> kz_term:api_object().
custom_request_headers(Doc) ->
    custom_request_headers(Doc, 'undefined').

-spec custom_request_headers(doc(), Default) -> kz_json:object() | Default.
custom_request_headers(Doc, Default) ->
    kz_json:get_json_value([<<"custom_request_headers">>], Doc, Default).

-spec set_custom_request_headers(doc(), kz_json:object()) -> doc().
set_custom_request_headers(Doc, CustomRequestHeaders) ->
    kz_json:set_value([<<"custom_request_headers">>], CustomRequestHeaders, Doc).

-spec debug(doc()) -> boolean().
debug(Doc) ->
    debug(Doc, 'false').

-spec debug(doc(), Default) -> boolean() | Default.
debug(Doc, Default) ->
    kz_json:is_true([<<"debug">>], Doc, Default).

-spec set_debug(doc(), boolean()) -> doc().
set_debug(Doc, Debug) ->
    kz_json:set_value([<<"debug">>], Debug, Doc).

-spec method(doc()) -> binary().
method(Doc) ->
    method(Doc, <<"get">>).

-spec method(doc(), Default) -> binary() | Default.
method(Doc, Default) ->
    kz_json:get_binary_value([<<"method">>], Doc, Default).

-spec set_method(doc(), binary()) -> doc().
set_method(Doc, Method) ->
    kz_json:set_value([<<"method">>], Method, Doc).

-spec req_body_format(doc()) -> binary().
req_body_format(Doc) ->
    req_body_format(Doc, <<"form">>).

-spec req_body_format(doc(), Default) -> binary() | Default.
req_body_format(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"req_body_format">>], Doc, Default).

-spec set_req_body_format(doc(), binary()) -> doc().
set_req_body_format(Doc, ReqBodyFormat) ->
    kz_json:set_value([<<"req_body_format">>], ReqBodyFormat, Doc).

-spec req_format(doc()) -> binary().
req_format(Doc) ->
    req_format(Doc, <<"kazoo">>).

-spec req_format(doc(), Default) -> binary() | Default.
req_format(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"req_format">>], Doc, Default).

-spec set_req_format(doc(), binary()) -> doc().
set_req_format(Doc, ReqFormat) ->
    kz_json:set_value([<<"req_format">>], ReqFormat, Doc).

-spec req_timeout_ms(doc()) -> kz_term:api_integer().
req_timeout_ms(Doc) ->
    req_timeout_ms(Doc, 'undefined').

-spec req_timeout_ms(doc(), Default) -> integer() | Default.
req_timeout_ms(Doc, Default) ->
    kz_json:get_integer_value([<<"req_timeout_ms">>], Doc, Default).

-spec set_req_timeout_ms(doc(), integer()) -> doc().
set_req_timeout_ms(Doc, ReqTimeoutMs) ->
    kz_json:set_value([<<"req_timeout_ms">>], ReqTimeoutMs, Doc).

-spec serverless(doc()) -> kz_term:api_object().
serverless(Doc) ->
    serverless(Doc, 'undefined').

-spec serverless(doc(), Default) -> kz_json:object() | Default.
serverless(Doc, Default) ->
    kz_json:get_json_value([<<"serverless">>], Doc, Default).

-spec set_serverless(doc(), kz_json:object()) -> doc().
set_serverless(Doc, Serverless) ->
    kz_json:set_value([<<"serverless">>], Serverless, Doc).

-spec serverless_flow_doc(doc()) -> any().
serverless_flow_doc(Doc) ->
    serverless_flow_doc(Doc, 'undefined').

-spec serverless_flow_doc(doc(), Default) -> any() | Default.
serverless_flow_doc(Doc, Default) ->
    kz_json:get_value([<<"serverless">>, <<"flow_doc">>], Doc, Default).

-spec set_serverless_flow_doc(doc(), any()) -> doc().
set_serverless_flow_doc(Doc, ServerlessFlowDoc) ->
    kz_json:set_value([<<"serverless">>, <<"flow_doc">>], ServerlessFlowDoc, Doc).

-spec serverless_flow_type(doc()) -> kz_term:api_binary().
serverless_flow_type(Doc) ->
    serverless_flow_type(Doc, 'undefined').

-spec serverless_flow_type(doc(), Default) -> binary() | Default.
serverless_flow_type(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"serverless">>, <<"flow_type">>], Doc, Default).

-spec set_serverless_flow_type(doc(), binary()) -> doc().
set_serverless_flow_type(Doc, ServerlessFlowType) ->
    kz_json:set_value([<<"serverless">>, <<"flow_type">>], ServerlessFlowType, Doc).

-spec skip_module(doc()) -> kz_term:api_boolean().
skip_module(Doc) ->
    skip_module(Doc, 'undefined').

-spec skip_module(doc(), Default) -> boolean() | Default.
skip_module(Doc, Default) ->
    kz_json:get_boolean_value([<<"skip_module">>], Doc, Default).

-spec set_skip_module(doc(), boolean()) -> doc().
set_skip_module(Doc, SkipModule) ->
    kz_json:set_value([<<"skip_module">>], SkipModule, Doc).

-spec voice_url(doc()) -> kz_term:api_ne_binary().
voice_url(Doc) ->
    voice_url(Doc, 'undefined').

-spec voice_url(doc(), Default) -> kz_term:ne_binary() | Default.
voice_url(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"voice_url">>], Doc, Default).

-spec set_voice_url(doc(), kz_term:ne_binary()) -> doc().
set_voice_url(Doc, VoiceUrl) ->
    kz_json:set_value([<<"voice_url">>], VoiceUrl, Doc).
