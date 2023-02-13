%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `match_lists' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_match_lists).

-export([new/0]).
-export([name/1, name/2, set_name/2]).
-export([rules/1, rules/2, set_rules/2]).

-export([schema/0, type/0]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"match_lists">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec schema() -> kz_term:ne_binary().
schema() ->
    ?SCHEMA.

-spec type() -> kz_term:ne_binary().
type() ->
    <<"match_list">>.

-spec name(doc()) -> kz_term:api_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> binary() | Default.
name(Doc, Default) ->
    kz_json:get_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

-spec rules(doc()) -> [kzd_match_list_rule:doc()].
rules(Doc) ->
    rules(Doc, []).

-spec rules(doc(), Default) -> [kzd_match_list_rule:doc()] | Default.
rules(Doc, Default) ->
    kz_json:get_list_value([<<"rules">>], Doc, Default).

-spec set_rules(doc(), [kzd_match_list_rule:doc()]) -> doc().
set_rules(Doc, Rules) ->
    kz_json:set_value([<<"rules">>], Rules, Doc).
