%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc Accessors for `scope_rules' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_scope_rules).

-export([new/0]).
-export([application/1, application/2, set_application/2]).
-export([description/1, description/2, set_description/2]).
-export([precedence/1, precedence/2, set_precedence/2]).
-export([rules/1, rules/2, set_rules/2]).
-export([scope_name/1, scope_name/2, set_scope_name/2]).
-export([transport/1, transport/2, set_transport/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"scope_rules">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec application(doc()) -> kz_term:api_binary().
application(Doc) ->
    application(Doc, 'undefined').

-spec application(doc(), Default) -> binary() | Default.
application(Doc, Default) ->
    kz_json:get_binary_value([<<"application">>], Doc, Default).

-spec set_application(doc(), binary()) -> doc().
set_application(Doc, Application) ->
    kz_json:set_value([<<"application">>], Application, Doc).

-spec description(doc()) -> kz_term:api_binary().
description(Doc) ->
    description(Doc, 'undefined').

-spec description(doc(), Default) -> binary() | Default.
description(Doc, Default) ->
    kz_json:get_binary_value([<<"description">>], Doc, Default).

-spec set_description(doc(), binary()) -> doc().
set_description(Doc, Description) ->
    kz_json:set_value([<<"description">>], Description, Doc).

-spec precedence(doc()) -> binary().
precedence(Doc) ->
    precedence(Doc, <<"allow">>).

-spec precedence(doc(), Default) -> binary() | Default.
precedence(Doc, Default) ->
    kz_json:get_binary_value([<<"precedence">>], Doc, Default).

-spec set_precedence(doc(), binary()) -> doc().
set_precedence(Doc, Precedence) ->
    kz_json:set_value([<<"precedence">>], Precedence, Doc).

-spec rules(doc()) -> any().
rules(Doc) ->
    rules(Doc, 'undefined').

-spec rules(doc(), Default) -> any() | Default.
rules(Doc, Default) ->
    kz_json:get_value([<<"rules">>], Doc, Default).

-spec set_rules(doc(), any()) -> doc().
set_rules(Doc, Rules) ->
    kz_json:set_value([<<"rules">>], Rules, Doc).

-spec scope_name(doc()) -> kz_term:api_binary().
scope_name(Doc) ->
    scope_name(Doc, 'undefined').

-spec scope_name(doc(), Default) -> binary() | Default.
scope_name(Doc, Default) ->
    kz_json:get_binary_value([<<"scope_name">>], Doc, Default).

-spec set_scope_name(doc(), binary()) -> doc().
set_scope_name(Doc, ScopeName) ->
    kz_json:set_value([<<"scope_name">>], ScopeName, Doc).

-spec transport(doc()) -> kz_term:api_binary().
transport(Doc) ->
    transport(Doc, 'undefined').

-spec transport(doc(), Default) -> binary() | Default.
transport(Doc, Default) ->
    kz_json:get_binary_value([<<"transport">>], Doc, Default).

-spec set_transport(doc(), binary()) -> doc().
set_transport(Doc, Transport) ->
    kz_json:set_value([<<"transport">>], Transport, Doc).
