%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `match_lists_rule_temporal_route' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_match_lists_rule_temporal_route).

-export([new/0]).
-export([temporal_route/1, temporal_route/2, set_temporal_route/2]).
-export([temporal_route_cycle/1, temporal_route_cycle/2, set_temporal_route_cycle/2]).
-export([temporal_route_days/1, temporal_route_days/2, set_temporal_route_days/2]).
-export([temporal_route_enabled/1, temporal_route_enabled/2, set_temporal_route_enabled/2]).
-export([temporal_route_end_date/1, temporal_route_end_date/2, set_temporal_route_end_date/2]).
-export([temporal_route_exclude/1, temporal_route_exclude/2, set_temporal_route_exclude/2]).
-export([temporal_route_flags/1, temporal_route_flags/2, set_temporal_route_flags/2]).
-export([temporal_route_id/1, temporal_route_id/2, set_temporal_route_id/2]).
-export([temporal_route_interval/1, temporal_route_interval/2, set_temporal_route_interval/2]).
-export([temporal_route_month/1, temporal_route_month/2, set_temporal_route_month/2]).
-export([temporal_route_name/1, temporal_route_name/2, set_temporal_route_name/2]).
-export([temporal_route_ordinal/1, temporal_route_ordinal/2, set_temporal_route_ordinal/2]).
-export([temporal_route_owner_id/1, temporal_route_owner_id/2, set_temporal_route_owner_id/2]).
-export([temporal_route_start_date/1, temporal_route_start_date/2, set_temporal_route_start_date/2]).
-export([temporal_route_time_window_start/1, temporal_route_time_window_start/2, set_temporal_route_time_window_start/2]).
-export([temporal_route_time_window_stop/1, temporal_route_time_window_stop/2, set_temporal_route_time_window_stop/2]).
-export([temporal_route_wdays/1, temporal_route_wdays/2, set_temporal_route_wdays/2]).
-export([type/1, type/2, set_type/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"match_lists.rule.temporal_route">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec temporal_route(doc()) -> kz_term:api_object().
temporal_route(Doc) ->
    temporal_route(Doc, 'undefined').

-spec temporal_route(doc(), Default) -> kz_json:object() | Default.
temporal_route(Doc, Default) ->
    kz_json:get_json_value([<<"temporal_route">>], Doc, Default).

-spec set_temporal_route(doc(), kz_json:object()) -> doc().
set_temporal_route(Doc, TemporalRoute) ->
    kz_json:set_value([<<"temporal_route">>], TemporalRoute, Doc).

-spec temporal_route_cycle(doc()) -> kz_term:api_binary().
temporal_route_cycle(Doc) ->
    temporal_route_cycle(Doc, 'undefined').

-spec temporal_route_cycle(doc(), Default) -> binary() | Default.
temporal_route_cycle(Doc, Default) ->
    kz_json:get_binary_value([<<"temporal_route">>, <<"cycle">>], Doc, Default).

-spec set_temporal_route_cycle(doc(), binary()) -> doc().
set_temporal_route_cycle(Doc, TemporalRouteCycle) ->
    kz_json:set_value([<<"temporal_route">>, <<"cycle">>], TemporalRouteCycle, Doc).

-spec temporal_route_days(doc()) -> kz_term:api_integers().
temporal_route_days(Doc) ->
    temporal_route_days(Doc, 'undefined').

-spec temporal_route_days(doc(), Default) -> kz_term:integers() | Default.
temporal_route_days(Doc, Default) ->
    kz_json:get_list_value([<<"temporal_route">>, <<"days">>], Doc, Default).

-spec set_temporal_route_days(doc(), kz_term:integers()) -> doc().
set_temporal_route_days(Doc, TemporalRouteDays) ->
    kz_json:set_value([<<"temporal_route">>, <<"days">>], TemporalRouteDays, Doc).

-spec temporal_route_enabled(doc()) -> kz_term:api_boolean().
temporal_route_enabled(Doc) ->
    temporal_route_enabled(Doc, 'undefined').

-spec temporal_route_enabled(doc(), Default) -> boolean() | Default.
temporal_route_enabled(Doc, Default) ->
    kz_json:get_boolean_value([<<"temporal_route">>, <<"enabled">>], Doc, Default).

-spec set_temporal_route_enabled(doc(), boolean()) -> doc().
set_temporal_route_enabled(Doc, TemporalRouteEnabled) ->
    kz_json:set_value([<<"temporal_route">>, <<"enabled">>], TemporalRouteEnabled, Doc).

-spec temporal_route_end_date(doc()) -> kz_term:api_integer().
temporal_route_end_date(Doc) ->
    temporal_route_end_date(Doc, 'undefined').

-spec temporal_route_end_date(doc(), Default) -> integer() | Default.
temporal_route_end_date(Doc, Default) ->
    kz_json:get_integer_value([<<"temporal_route">>, <<"end_date">>], Doc, Default).

-spec set_temporal_route_end_date(doc(), integer()) -> doc().
set_temporal_route_end_date(Doc, TemporalRouteEndDate) ->
    kz_json:set_value([<<"temporal_route">>, <<"end_date">>], TemporalRouteEndDate, Doc).

-spec temporal_route_exclude(doc()) -> kz_term:api_ne_binaries().
temporal_route_exclude(Doc) ->
    temporal_route_exclude(Doc, 'undefined').

-spec temporal_route_exclude(doc(), Default) -> kz_term:ne_binaries() | Default.
temporal_route_exclude(Doc, Default) ->
    kz_json:get_list_value([<<"temporal_route">>, <<"exclude">>], Doc, Default).

-spec set_temporal_route_exclude(doc(), kz_term:ne_binaries()) -> doc().
set_temporal_route_exclude(Doc, TemporalRouteExclude) ->
    kz_json:set_value([<<"temporal_route">>, <<"exclude">>], TemporalRouteExclude, Doc).

-spec temporal_route_flags(doc()) -> kz_term:api_ne_binaries().
temporal_route_flags(Doc) ->
    temporal_route_flags(Doc, 'undefined').

-spec temporal_route_flags(doc(), Default) -> kz_term:ne_binaries() | Default.
temporal_route_flags(Doc, Default) ->
    kz_json:get_list_value([<<"temporal_route">>, <<"flags">>], Doc, Default).

-spec set_temporal_route_flags(doc(), kz_term:ne_binaries()) -> doc().
set_temporal_route_flags(Doc, TemporalRouteFlags) ->
    kz_json:set_value([<<"temporal_route">>, <<"flags">>], TemporalRouteFlags, Doc).

-spec temporal_route_id(doc()) -> kz_term:api_binary().
temporal_route_id(Doc) ->
    temporal_route_id(Doc, 'undefined').

-spec temporal_route_id(doc(), Default) -> binary() | Default.
temporal_route_id(Doc, Default) ->
    kz_json:get_binary_value([<<"temporal_route_id">>], Doc, Default).

-spec set_temporal_route_id(doc(), binary()) -> doc().
set_temporal_route_id(Doc, TemporalRouteId) ->
    kz_json:set_value([<<"temporal_route_id">>], TemporalRouteId, Doc).

-spec temporal_route_interval(doc()) -> integer().
temporal_route_interval(Doc) ->
    temporal_route_interval(Doc, 1).

-spec temporal_route_interval(doc(), Default) -> integer() | Default.
temporal_route_interval(Doc, Default) ->
    kz_json:get_integer_value([<<"temporal_route">>, <<"interval">>], Doc, Default).

-spec set_temporal_route_interval(doc(), integer()) -> doc().
set_temporal_route_interval(Doc, TemporalRouteInterval) ->
    kz_json:set_value([<<"temporal_route">>, <<"interval">>], TemporalRouteInterval, Doc).

-spec temporal_route_month(doc()) -> kz_term:api_integer().
temporal_route_month(Doc) ->
    temporal_route_month(Doc, 'undefined').

-spec temporal_route_month(doc(), Default) -> integer() | Default.
temporal_route_month(Doc, Default) ->
    kz_json:get_integer_value([<<"temporal_route">>, <<"month">>], Doc, Default).

-spec set_temporal_route_month(doc(), integer()) -> doc().
set_temporal_route_month(Doc, TemporalRouteMonth) ->
    kz_json:set_value([<<"temporal_route">>, <<"month">>], TemporalRouteMonth, Doc).

-spec temporal_route_name(doc()) -> kz_term:api_ne_binary().
temporal_route_name(Doc) ->
    temporal_route_name(Doc, 'undefined').

-spec temporal_route_name(doc(), Default) -> kz_term:ne_binary() | Default.
temporal_route_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"temporal_route">>, <<"name">>], Doc, Default).

-spec set_temporal_route_name(doc(), kz_term:ne_binary()) -> doc().
set_temporal_route_name(Doc, TemporalRouteName) ->
    kz_json:set_value([<<"temporal_route">>, <<"name">>], TemporalRouteName, Doc).

-spec temporal_route_ordinal(doc()) -> kz_term:api_binary().
temporal_route_ordinal(Doc) ->
    temporal_route_ordinal(Doc, 'undefined').

-spec temporal_route_ordinal(doc(), Default) -> binary() | Default.
temporal_route_ordinal(Doc, Default) ->
    kz_json:get_binary_value([<<"temporal_route">>, <<"ordinal">>], Doc, Default).

-spec set_temporal_route_ordinal(doc(), binary()) -> doc().
set_temporal_route_ordinal(Doc, TemporalRouteOrdinal) ->
    kz_json:set_value([<<"temporal_route">>, <<"ordinal">>], TemporalRouteOrdinal, Doc).

-spec temporal_route_owner_id(doc()) -> kz_term:api_binary().
temporal_route_owner_id(Doc) ->
    temporal_route_owner_id(Doc, 'undefined').

-spec temporal_route_owner_id(doc(), Default) -> binary() | Default.
temporal_route_owner_id(Doc, Default) ->
    kz_json:get_binary_value([<<"temporal_route">>, <<"owner_id">>], Doc, Default).

-spec set_temporal_route_owner_id(doc(), binary()) -> doc().
set_temporal_route_owner_id(Doc, TemporalRouteOwnerId) ->
    kz_json:set_value([<<"temporal_route">>, <<"owner_id">>], TemporalRouteOwnerId, Doc).

-spec temporal_route_start_date(doc()) -> integer().
temporal_route_start_date(Doc) ->
    temporal_route_start_date(Doc, 62586115200).

-spec temporal_route_start_date(doc(), Default) -> integer() | Default.
temporal_route_start_date(Doc, Default) ->
    kz_json:get_integer_value([<<"temporal_route">>, <<"start_date">>], Doc, Default).

-spec set_temporal_route_start_date(doc(), integer()) -> doc().
set_temporal_route_start_date(Doc, TemporalRouteStartDate) ->
    kz_json:set_value([<<"temporal_route">>, <<"start_date">>], TemporalRouteStartDate, Doc).

-spec temporal_route_time_window_start(doc()) -> kz_term:api_integer().
temporal_route_time_window_start(Doc) ->
    temporal_route_time_window_start(Doc, 'undefined').

-spec temporal_route_time_window_start(doc(), Default) -> integer() | Default.
temporal_route_time_window_start(Doc, Default) ->
    kz_json:get_integer_value([<<"temporal_route">>, <<"time_window_start">>], Doc, Default).

-spec set_temporal_route_time_window_start(doc(), integer()) -> doc().
set_temporal_route_time_window_start(Doc, TemporalRouteTimeWindowStart) ->
    kz_json:set_value([<<"temporal_route">>, <<"time_window_start">>], TemporalRouteTimeWindowStart, Doc).

-spec temporal_route_time_window_stop(doc()) -> kz_term:api_integer().
temporal_route_time_window_stop(Doc) ->
    temporal_route_time_window_stop(Doc, 'undefined').

-spec temporal_route_time_window_stop(doc(), Default) -> integer() | Default.
temporal_route_time_window_stop(Doc, Default) ->
    kz_json:get_integer_value([<<"temporal_route">>, <<"time_window_stop">>], Doc, Default).

-spec set_temporal_route_time_window_stop(doc(), integer()) -> doc().
set_temporal_route_time_window_stop(Doc, TemporalRouteTimeWindowStop) ->
    kz_json:set_value([<<"temporal_route">>, <<"time_window_stop">>], TemporalRouteTimeWindowStop, Doc).

-spec temporal_route_wdays(doc()) -> kz_term:api_ne_binaries().
temporal_route_wdays(Doc) ->
    temporal_route_wdays(Doc, 'undefined').

-spec temporal_route_wdays(doc(), Default) -> kz_term:ne_binaries() | Default.
temporal_route_wdays(Doc, Default) ->
    kz_json:get_list_value([<<"temporal_route">>, <<"wdays">>], Doc, Default).

-spec set_temporal_route_wdays(doc(), kz_term:ne_binaries()) -> doc().
set_temporal_route_wdays(Doc, TemporalRouteWdays) ->
    kz_json:set_value([<<"temporal_route">>, <<"wdays">>], TemporalRouteWdays, Doc).

-spec type(doc()) -> kz_term:api_binary().
type(Doc) ->
    type(Doc, 'undefined').

-spec type(doc(), Default) -> binary() | Default.
type(Doc, Default) ->
    kz_json:get_binary_value([<<"type">>], Doc, Default).

-spec set_type(doc(), binary()) -> doc().
set_type(Doc, Type) ->
    kz_json:set_value([<<"type">>], Type, Doc).
