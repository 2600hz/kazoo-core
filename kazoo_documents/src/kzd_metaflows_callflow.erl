%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `metaflows_callflow' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_callflow).

-export([new/0]).
-export([captures/1, captures/2, set_captures/2]).
-export([collected/1, collected/2, set_collected/2]).
-export([flow/1, flow/2, set_flow/2]).
-export([flow_child/2, flow_child/3, set_flow_child/3]).
-export([flow_children/1, flow_children/2, set_flow_children/2]).
-export([flow_data/1, flow_data/2, set_flow_data/2]).
-export([flow_module/1, flow_module/2, set_flow_module/2]).
-export([id/1, id/2, set_id/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.callflow">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec captures(doc()) -> kz_term:api_binary().
captures(Doc) ->
    captures(Doc, 'undefined').

-spec captures(doc(), Default) -> binary() | Default.
captures(Doc, Default) ->
    kz_json:get_binary_value([<<"captures">>], Doc, Default).

-spec set_captures(doc(), binary()) -> doc().
set_captures(Doc, Captures) ->
    kz_json:set_value([<<"captures">>], Captures, Doc).

-spec collected(doc()) -> kz_term:api_binary().
collected(Doc) ->
    collected(Doc, 'undefined').

-spec collected(doc(), Default) -> binary() | Default.
collected(Doc, Default) ->
    kz_json:get_binary_value([<<"collected">>], Doc, Default).

-spec set_collected(doc(), binary()) -> doc().
set_collected(Doc, Collected) ->
    kz_json:set_value([<<"collected">>], Collected, Doc).

-spec flow(doc()) -> kz_term:api_object().
flow(Doc) ->
    flow(Doc, 'undefined').

-spec flow(doc(), Default) -> kz_json:object() | Default.
flow(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>], Doc, Default).

-spec set_flow(doc(), kz_json:object()) -> doc().
set_flow(Doc, Flow) ->
    kz_json:set_value([<<"flow">>], Flow, Doc).

-spec flow_child(doc(), kz_json:key()) -> kz_term:api_object().
flow_child(Doc, Child) ->
    flow_child(Doc, Child, 'undefined').

-spec flow_child(doc(), kz_json:key(), Default) -> kz_json:object() | Default.
flow_child(Doc, Child, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"children">>, Child], Doc, Default).

-spec set_flow_child(doc(), kz_json:key(), kz_json:object()) -> doc().
set_flow_child(Doc, Child, Value) ->
    kz_json:set_value([<<"flow">>, <<"children">>, Child], Value, Doc).

-spec flow_children(doc()) -> kz_term:api_object().
flow_children(Doc) ->
    flow_children(Doc, 'undefined').

-spec flow_children(doc(), Default) -> kz_json:object() | Default.
flow_children(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"children">>], Doc, Default).

-spec set_flow_children(doc(), kz_json:object()) -> doc().
set_flow_children(Doc, FlowChildren) ->
    kz_json:set_value([<<"flow">>, <<"children">>], FlowChildren, Doc).

-spec flow_data(doc()) -> kz_json:object().
flow_data(Doc) ->
    flow_data(Doc, kz_json:new()).

-spec flow_data(doc(), Default) -> kz_json:object() | Default.
flow_data(Doc, Default) ->
    kz_json:get_json_value([<<"flow">>, <<"data">>], Doc, Default).

-spec set_flow_data(doc(), kz_json:object()) -> doc().
set_flow_data(Doc, FlowData) ->
    kz_json:set_value([<<"flow">>, <<"data">>], FlowData, Doc).

-spec flow_module(doc()) -> kz_term:api_ne_binary().
flow_module(Doc) ->
    flow_module(Doc, 'undefined').

-spec flow_module(doc(), Default) -> kz_term:ne_binary() | Default.
flow_module(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"flow">>, <<"module">>], Doc, Default).

-spec set_flow_module(doc(), kz_term:ne_binary()) -> doc().
set_flow_module(Doc, FlowModule) ->
    kz_json:set_value([<<"flow">>, <<"module">>], FlowModule, Doc).

-spec id(doc()) -> kz_term:api_binary().
id(Doc) ->
    id(Doc, 'undefined').

-spec id(doc(), Default) -> binary() | Default.
id(Doc, Default) ->
    kz_json:get_binary_value([<<"id">>], Doc, Default).

-spec set_id(doc(), binary()) -> doc().
set_id(Doc, Id) ->
    kz_json:set_value([<<"id">>], Id, Doc).
