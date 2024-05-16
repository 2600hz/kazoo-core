%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `metaflows_audio_level' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_audio_level).

-export([new/0]).
-export([action/1, action/2, set_action/2]).
-export([level/1, level/2, set_level/2]).
-export([mode/1, mode/2, set_mode/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.audio_level">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec action(doc()) -> kz_term:api_binary().
action(Doc) ->
    action(Doc, 'undefined').

-spec action(doc(), Default) -> binary() | Default.
action(Doc, Default) ->
    kz_json:get_binary_value([<<"action">>], Doc, Default).

-spec set_action(doc(), binary()) -> doc().
set_action(Doc, Action) ->
    kz_json:set_value([<<"action">>], Action, Doc).

-spec level(doc()) -> kz_term:api_integer().
level(Doc) ->
    level(Doc, 'undefined').

-spec level(doc(), Default) -> integer() | Default.
level(Doc, Default) ->
    kz_json:get_integer_value([<<"level">>], Doc, Default).

-spec set_level(doc(), integer()) -> doc().
set_level(Doc, Level) ->
    kz_json:set_value([<<"level">>], Level, Doc).

-spec mode(doc()) -> kz_term:api_binary().
mode(Doc) ->
    mode(Doc, 'undefined').

-spec mode(doc(), Default) -> binary() | Default.
mode(Doc, Default) ->
    kz_json:get_binary_value([<<"mode">>], Doc, Default).

-spec set_mode(doc(), binary()) -> doc().
set_mode(Doc, Mode) ->
    kz_json:set_value([<<"mode">>], Mode, Doc).
