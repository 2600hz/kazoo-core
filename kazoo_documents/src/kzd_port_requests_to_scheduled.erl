%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `port_requests_to_scheduled' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_port_requests_to_scheduled).

-export([new/0]).
-export([schedule_on/1, schedule_on/2, set_schedule_on/2]).
-export([schedule_on_date_time/1, schedule_on_date_time/2, set_schedule_on_date_time/2]).
-export([schedule_on_timezone/1, schedule_on_timezone/2, set_schedule_on_timezone/2]).
-export([scheduled_date/1, scheduled_date/2, set_scheduled_date/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"port_requests.to_scheduled">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec schedule_on(doc()) -> kz_term:api_object().
schedule_on(Doc) ->
    schedule_on(Doc, 'undefined').

-spec schedule_on(doc(), Default) -> kz_json:object() | Default.
schedule_on(Doc, Default) ->
    kz_json:get_json_value([<<"schedule_on">>], Doc, Default).

-spec set_schedule_on(doc(), kz_json:object()) -> doc().
set_schedule_on(Doc, ScheduleOn) ->
    kz_json:set_value([<<"schedule_on">>], ScheduleOn, Doc).

-spec schedule_on_date_time(doc()) -> kz_term:api_binary().
schedule_on_date_time(Doc) ->
    schedule_on_date_time(Doc, 'undefined').

-spec schedule_on_date_time(doc(), Default) -> binary() | Default.
schedule_on_date_time(Doc, Default) ->
    kz_json:get_binary_value([<<"schedule_on">>, <<"date_time">>], Doc, Default).

-spec set_schedule_on_date_time(doc(), binary()) -> doc().
set_schedule_on_date_time(Doc, ScheduleOnDateTime) ->
    kz_json:set_value([<<"schedule_on">>, <<"date_time">>], ScheduleOnDateTime, Doc).

-spec schedule_on_timezone(doc()) -> kz_term:api_binary().
schedule_on_timezone(Doc) ->
    schedule_on_timezone(Doc, 'undefined').

-spec schedule_on_timezone(doc(), Default) -> binary() | Default.
schedule_on_timezone(Doc, Default) ->
    kz_json:get_binary_value([<<"schedule_on">>, <<"timezone">>], Doc, Default).

-spec set_schedule_on_timezone(doc(), binary()) -> doc().
set_schedule_on_timezone(Doc, ScheduleOnTimezone) ->
    kz_json:set_value([<<"schedule_on">>, <<"timezone">>], ScheduleOnTimezone, Doc).

-spec scheduled_date(doc()) -> kz_term:api_integer().
scheduled_date(Doc) ->
    scheduled_date(Doc, 'undefined').

-spec scheduled_date(doc(), Default) -> integer() | Default.
scheduled_date(Doc, Default) ->
    kz_json:get_integer_value([<<"scheduled_date">>], Doc, Default).

-spec set_scheduled_date(doc(), integer()) -> doc().
set_scheduled_date(Doc, ScheduledDate) ->
    kz_json:set_value([<<"scheduled_date">>], ScheduledDate, Doc).
