%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc Accessors for `scope_restrictions' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_scope_restrictions).

-export([new/0]).
-export([description/1, description/2, set_description/2]).
-export([http/1, http/2, set_http/2]).
-export([http_allow/1, http_allow/2, set_http_allow/2]).
-export([http_allow_index/2, http_allow_index/3, set_http_allow_index/3]).
-export([http_deny/1, http_deny/2, set_http_deny/2]).
-export([http_deny_index/2, http_deny_index/3, set_http_deny_index/3]).
-export([precedence/1, precedence/2, set_precedence/2]).
-export([scope_name/1, scope_name/2, set_scope_name/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"scope_restrictions">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec description(doc()) -> kz_term:api_binary().
description(Doc) ->
    description(Doc, 'undefined').

-spec description(doc(), Default) -> binary() | Default.
description(Doc, Default) ->
    kz_json:get_binary_value([<<"description">>], Doc, Default).

-spec set_description(doc(), binary()) -> doc().
set_description(Doc, Description) ->
    kz_json:set_value([<<"description">>], Description, Doc).

-spec http(doc()) -> kz_term:api_object().
http(Doc) ->
    http(Doc, 'undefined').

-spec http(doc(), Default) -> kz_json:object() | Default.
http(Doc, Default) ->
    kz_json:get_json_value([<<"http">>], Doc, Default).

-spec set_http(doc(), kz_json:object()) -> doc().
set_http(Doc, Http) ->
    kz_json:set_value([<<"http">>], Http, Doc).

-spec http_allow(doc()) -> kz_term:api_object().
http_allow(Doc) ->
    http_allow(Doc, 'undefined').

-spec http_allow(doc(), Default) -> kz_json:object() | Default.
http_allow(Doc, Default) ->
    kz_json:get_json_value([<<"http">>, <<"allow">>], Doc, Default).

-spec set_http_allow(doc(), kz_json:object()) -> doc().
set_http_allow(Doc, HttpAllow) ->
    kz_json:set_value([<<"http">>, <<"allow">>], HttpAllow, Doc).

-spec http_allow_index(doc(), kz_json:key()) -> kz_term:api_ne_binaries().
http_allow_index(Doc, AllowIndex) ->
    http_allow_index(Doc, AllowIndex, 'undefined').

-spec http_allow_index(doc(), kz_json:key(), Default) -> kz_term:ne_binaries() | Default.
http_allow_index(Doc, AllowIndex, Default) ->
    kz_json:get_list_value([<<"http">>, <<"allow">>, AllowIndex], Doc, Default).

-spec set_http_allow_index(doc(), kz_json:key(), kz_term:ne_binaries()) -> doc().
set_http_allow_index(Doc, AllowIndex, Value) ->
    kz_json:set_value([<<"http">>, <<"allow">>, AllowIndex], Value, Doc).

-spec http_deny(doc()) -> kz_term:api_object().
http_deny(Doc) ->
    http_deny(Doc, 'undefined').

-spec http_deny(doc(), Default) -> kz_json:object() | Default.
http_deny(Doc, Default) ->
    kz_json:get_json_value([<<"http">>, <<"deny">>], Doc, Default).

-spec set_http_deny(doc(), kz_json:object()) -> doc().
set_http_deny(Doc, HttpDeny) ->
    kz_json:set_value([<<"http">>, <<"deny">>], HttpDeny, Doc).

-spec http_deny_index(doc(), kz_json:key()) -> kz_term:api_ne_binaries().
http_deny_index(Doc, DenyIndex) ->
    http_deny_index(Doc, DenyIndex, 'undefined').

-spec http_deny_index(doc(), kz_json:key(), Default) -> kz_term:ne_binaries() | Default.
http_deny_index(Doc, DenyIndex, Default) ->
    kz_json:get_list_value([<<"http">>, <<"deny">>, DenyIndex], Doc, Default).

-spec set_http_deny_index(doc(), kz_json:key(), kz_term:ne_binaries()) -> doc().
set_http_deny_index(Doc, DenyIndex, Value) ->
    kz_json:set_value([<<"http">>, <<"deny">>, DenyIndex], Value, Doc).

-spec precedence(doc()) -> binary().
precedence(Doc) ->
    precedence(Doc, <<"allow">>).

-spec precedence(doc(), Default) -> binary() | Default.
precedence(Doc, Default) ->
    kz_json:get_binary_value([<<"precedence">>], Doc, Default).

-spec set_precedence(doc(), binary()) -> doc().
set_precedence(Doc, Precedence) ->
    kz_json:set_value([<<"precedence">>], Precedence, Doc).

-spec scope_name(doc()) -> kz_term:api_binary().
scope_name(Doc) ->
    scope_name(Doc, 'undefined').

-spec scope_name(doc(), Default) -> binary() | Default.
scope_name(Doc, Default) ->
    kz_json:get_binary_value([<<"scope_name">>], Doc, Default).

-spec set_scope_name(doc(), binary()) -> doc().
set_scope_name(Doc, ScopeName) ->
    kz_json:set_value([<<"scope_name">>], ScopeName, Doc).
