%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `notify_callback' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_notify_callback).

-export([new/0]).
-export([attempts/1, attempts/2, set_attempts/2]).
-export([disabled/1, disabled/2, set_disabled/2]).
-export([interval_s/1, interval_s/2, set_interval_s/2]).
-export([number/1, number/2, set_number/2]).
-export([schedule/1, schedule/2, set_schedule/2]).
-export([timeout_s/1, timeout_s/2, set_timeout_s/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"notify.callback">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec attempts(doc()) -> kz_term:api_integer().
attempts(Doc) ->
    attempts(Doc, 'undefined').

-spec attempts(doc(), Default) -> integer() | Default.
attempts(Doc, Default) ->
    kz_json:get_integer_value([<<"attempts">>], Doc, Default).

-spec set_attempts(doc(), integer()) -> doc().
set_attempts(Doc, Attempts) ->
    kz_json:set_value([<<"attempts">>], Attempts, Doc).

-spec disabled(doc()) -> kz_term:api_boolean().
disabled(Doc) ->
    disabled(Doc, 'undefined').

-spec disabled(doc(), Default) -> boolean() | Default.
disabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"disabled">>], Doc, Default).

-spec set_disabled(doc(), boolean()) -> doc().
set_disabled(Doc, Disabled) ->
    kz_json:set_value([<<"disabled">>], Disabled, Doc).

-spec interval_s(doc()) -> kz_term:api_integer().
interval_s(Doc) ->
    interval_s(Doc, 'undefined').

-spec interval_s(doc(), Default) -> integer() | Default.
interval_s(Doc, Default) ->
    kz_json:get_integer_value([<<"interval_s">>], Doc, Default).

-spec set_interval_s(doc(), integer()) -> doc().
set_interval_s(Doc, IntervalS) ->
    kz_json:set_value([<<"interval_s">>], IntervalS, Doc).

-spec number(doc()) -> kz_term:api_binary().
number(Doc) ->
    number(Doc, 'undefined').

-spec number(doc(), Default) -> binary() | Default.
number(Doc, Default) ->
    kz_json:get_binary_value([<<"number">>], Doc, Default).

-spec set_number(doc(), binary()) -> doc().
set_number(Doc, Number) ->
    kz_json:set_value([<<"number">>], Number, Doc).

-spec schedule(doc()) -> kz_term:api_integers().
schedule(Doc) ->
    schedule(Doc, 'undefined').

-spec schedule(doc(), Default) -> kz_term:integers() | Default.
schedule(Doc, Default) ->
    kz_json:get_list_value([<<"schedule">>], Doc, Default).

-spec set_schedule(doc(), kz_term:integers()) -> doc().
set_schedule(Doc, Schedule) ->
    kz_json:set_value([<<"schedule">>], Schedule, Doc).

-spec timeout_s(doc()) -> kz_term:api_integer().
timeout_s(Doc) ->
    timeout_s(Doc, 'undefined').

-spec timeout_s(doc(), Default) -> integer() | Default.
timeout_s(Doc, Default) ->
    kz_json:get_integer_value([<<"timeout_s">>], Doc, Default).

-spec set_timeout_s(doc(), integer()) -> doc().
set_timeout_s(Doc, TimeoutS) ->
    kz_json:set_value([<<"timeout_s">>], TimeoutS, Doc).
