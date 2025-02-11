%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `metaflows_pivot' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_pivot).

-export([new/0]).
-export([cdr_url/1, cdr_url/2, set_cdr_url/2]).
-export([debug/1, debug/2, set_debug/2]).
-export([method/1, method/2, set_method/2]).
-export([req_format/1, req_format/2, set_req_format/2]).
-export([voice_url/1, voice_url/2, set_voice_url/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.pivot">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec cdr_url(doc()) -> kz_term:api_ne_binary().
cdr_url(Doc) ->
    cdr_url(Doc, 'undefined').

-spec cdr_url(doc(), Default) -> kz_term:ne_binary() | Default.
cdr_url(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"cdr_url">>], Doc, Default).

-spec set_cdr_url(doc(), kz_term:ne_binary()) -> doc().
set_cdr_url(Doc, CdrUrl) ->
    kz_json:set_value([<<"cdr_url">>], CdrUrl, Doc).

-spec debug(doc()) -> boolean().
debug(Doc) ->
    debug(Doc, 'false').

-spec debug(doc(), Default) -> boolean() | Default.
debug(Doc, Default) ->
    kz_json:get_boolean_value([<<"debug">>], Doc, Default).

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

-spec req_format(doc()) -> binary().
req_format(Doc) ->
    req_format(Doc, <<"kazoo">>).

-spec req_format(doc(), Default) -> binary() | Default.
req_format(Doc, Default) ->
    kz_json:get_binary_value([<<"req_format">>], Doc, Default).

-spec set_req_format(doc(), binary()) -> doc().
set_req_format(Doc, ReqFormat) ->
    kz_json:set_value([<<"req_format">>], ReqFormat, Doc).

-spec voice_url(doc()) -> kz_term:api_ne_binary().
voice_url(Doc) ->
    voice_url(Doc, 'undefined').

-spec voice_url(doc(), Default) -> kz_term:ne_binary() | Default.
voice_url(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"voice_url">>], Doc, Default).

-spec set_voice_url(doc(), kz_term:ne_binary()) -> doc().
set_voice_url(Doc, VoiceUrl) ->
    kz_json:set_value([<<"voice_url">>], VoiceUrl, Doc).
