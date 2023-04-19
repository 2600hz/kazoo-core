%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `metaflows_play' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_play).

-export([new/0]).
-export([id/1, id/2, set_id/2]).
-export([leg/1, leg/2, set_leg/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.play">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec id(doc()) -> kz_term:api_binary().
id(Doc) ->
    id(Doc, 'undefined').

-spec id(doc(), Default) -> binary() | Default.
id(Doc, Default) ->
    kz_json:get_binary_value([<<"id">>], Doc, Default).

-spec set_id(doc(), binary()) -> doc().
set_id(Doc, Id) ->
    kz_json:set_value([<<"id">>], Id, Doc).

-spec leg(doc()) -> binary().
leg(Doc) ->
    leg(Doc, <<"both">>).

-spec leg(doc(), Default) -> binary() | Default.
leg(Doc, Default) ->
    kz_json:get_binary_value([<<"leg">>], Doc, Default).

-spec set_leg(doc(), binary()) -> doc().
set_leg(Doc, Leg) ->
    kz_json:set_value([<<"leg">>], Leg, Doc).
