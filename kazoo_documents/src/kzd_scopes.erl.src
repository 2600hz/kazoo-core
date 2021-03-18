%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc Accessors for `scopes' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_scopes).

-export([new/0]).
-export([allow_api_request/1, allow_api_request/2, set_allow_api_request/2]).
-export([description/1, description/2, set_description/2]).
-export([scopes/1, scopes/2, set_scopes/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"scopes">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec allow_api_request(doc()) -> kz_term:api_boolean().
allow_api_request(Doc) ->
    allow_api_request(Doc, 'undefined').

-spec allow_api_request(doc(), Default) -> boolean() | Default.
allow_api_request(Doc, Default) ->
    kz_json:get_boolean_value([<<"allow_api_request">>], Doc, Default).

-spec set_allow_api_request(doc(), boolean()) -> doc().
set_allow_api_request(Doc, AllowAPIRequest) ->
    kz_json:set_value([<<"allow_api_request">>], AllowAPIRequest, Doc).

-spec description(doc()) -> kz_term:api_binary().
description(Doc) ->
    description(Doc, 'undefined').

-spec description(doc(), Default) -> binary() | Default.
description(Doc, Default) ->
    kz_json:get_binary_value([<<"description">>], Doc, Default).

-spec set_description(doc(), binary()) -> doc().
set_description(Doc, Description) ->
    kz_json:set_value([<<"description">>], Description, Doc).

-spec scopes(doc()) -> kz_term:ne_binaries().
scopes(Doc) ->
    scopes(Doc, []).

-spec scopes(doc(), Default) -> kz_term:ne_binaries() | Default.
scopes(Doc, Default) ->
    kz_json:get_list_value([<<"scopes">>], Doc, Default).

-spec set_scopes(doc(), kz_term:ne_binaries()) -> doc().
set_scopes(Doc, Scopes) ->
    kz_json:set_value([<<"scopes">>], Scopes, Doc).
