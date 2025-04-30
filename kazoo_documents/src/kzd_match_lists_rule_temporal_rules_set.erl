%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `match_lists_rule_temporal_rules_set' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_match_lists_rule_temporal_rules_set).

-export([new/0]).
-export([temporal_rules_set_id/1, temporal_rules_set_id/2, set_temporal_rules_set_id/2]).
-export([type/1, type/2, set_type/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"match_lists.rule.temporal_rules_set">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec temporal_rules_set_id(doc()) -> kz_term:api_binary().
temporal_rules_set_id(Doc) ->
    temporal_rules_set_id(Doc, 'undefined').

-spec temporal_rules_set_id(doc(), Default) -> binary() | Default.
temporal_rules_set_id(Doc, Default) ->
    kz_json:get_binary_value([<<"temporal_rules_set_id">>], Doc, Default).

-spec set_temporal_rules_set_id(doc(), binary()) -> doc().
set_temporal_rules_set_id(Doc, TemporalRulesSetId) ->
    kz_json:set_value([<<"temporal_rules_set_id">>], TemporalRulesSetId, Doc).

-spec type(doc()) -> kz_term:api_binary().
type(Doc) ->
    type(Doc, 'undefined').

-spec type(doc(), Default) -> binary() | Default.
type(Doc, Default) ->
    kz_json:get_binary_value([<<"type">>], Doc, Default).

-spec set_type(doc(), binary()) -> doc().
set_type(Doc, Type) ->
    kz_json:set_value([<<"type">>], Type, Doc).
