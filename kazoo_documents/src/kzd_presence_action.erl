%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `presence_action' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_presence_action).

-export([new/0]).
-export([action/1, action/2, set_action/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"presence.action">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec action(doc()) -> binary().
action(Doc) ->
    action(Doc, <<"reset">>).

-spec action(doc(), Default) -> binary() | Default.
action(Doc, Default) ->
    kz_json:get_binary_value([<<"action">>], Doc, Default).

-spec set_action(doc(), binary()) -> doc().
set_action(Doc, Action) ->
    kz_json:set_value([<<"action">>], Action, Doc).
