%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `presence_state' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_presence_state).

-export([new/0]).
-export([state/1, state/2, set_state/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"presence.state">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec state(doc()) -> kz_term:api_binary().
state(Doc) ->
    state(Doc, 'undefined').

-spec state(doc(), Default) -> binary() | Default.
state(Doc, Default) ->
    kz_json:get_binary_value([<<"state">>], Doc, Default).

-spec set_state(doc(), binary()) -> doc().
set_state(Doc, State) ->
    kz_json:set_value([<<"state">>], State, Doc).
