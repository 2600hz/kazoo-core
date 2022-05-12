%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc Accessors for `tone' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_tone).

-export([new/0]).
-export([duration_off/1, duration_off/2, set_duration_off/2]).
-export([duration_on/1, duration_on/2, set_duration_on/2]).
-export([frequencies/1, frequencies/2, set_frequencies/2]).
-export([repeat/1, repeat/2, set_repeat/2]).
-export([volume/1, volume/2, set_volume/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"tone">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec duration_off(doc()) -> kz_term:api_integer().
duration_off(Doc) ->
    duration_off(Doc, 'undefined').

-spec duration_off(doc(), Default) -> integer() | Default.
duration_off(Doc, Default) ->
    kz_json:get_integer_value([<<"duration_off">>], Doc, Default).

-spec set_duration_off(doc(), integer()) -> doc().
set_duration_off(Doc, DurationOff) ->
    kz_json:set_value([<<"duration_off">>], DurationOff, Doc).

-spec duration_on(doc()) -> kz_term:api_integer().
duration_on(Doc) ->
    duration_on(Doc, 'undefined').

-spec duration_on(doc(), Default) -> integer() | Default.
duration_on(Doc, Default) ->
    kz_json:get_integer_value([<<"duration_on">>], Doc, Default).

-spec set_duration_on(doc(), integer()) -> doc().
set_duration_on(Doc, DurationOn) ->
    kz_json:set_value([<<"duration_on">>], DurationOn, Doc).

-spec frequencies(doc()) -> kz_term:api_integers().
frequencies(Doc) ->
    frequencies(Doc, 'undefined').

-spec frequencies(doc(), Default) -> kz_term:integers() | Default.
frequencies(Doc, Default) ->
    kz_json:get_list_value([<<"frequencies">>], Doc, Default).

-spec set_frequencies(doc(), kz_term:integers()) -> doc().
set_frequencies(Doc, Frequencies) ->
    kz_json:set_value([<<"frequencies">>], Frequencies, Doc).

-spec repeat(doc()) -> kz_term:api_integer().
repeat(Doc) ->
    repeat(Doc, 'undefined').

-spec repeat(doc(), Default) -> integer() | Default.
repeat(Doc, Default) ->
    kz_json:get_integer_value([<<"repeat">>], Doc, Default).

-spec set_repeat(doc(), integer()) -> doc().
set_repeat(Doc, Repeat) ->
    kz_json:set_value([<<"repeat">>], Repeat, Doc).

-spec volume(doc()) -> kz_term:api_integer().
volume(Doc) ->
    volume(Doc, 'undefined').

-spec volume(doc(), Default) -> integer() | Default.
volume(Doc, Default) ->
    kz_json:get_integer_value([<<"volume">>], Doc, Default).

-spec set_volume(doc(), integer()) -> doc().
set_volume(Doc, Volume) ->
    kz_json:set_value([<<"volume">>], Volume, Doc).
