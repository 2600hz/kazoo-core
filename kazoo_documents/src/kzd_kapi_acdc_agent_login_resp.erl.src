%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `kapi_acdc_agent_login_resp' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_kapi_acdc_agent_login_resp).

-export([new/0]).
-export([event_category/1, event_category/2, set_event_category/2]).
-export([event_name/1, event_name/2, set_event_name/2]).
-export([status/1, status/2, set_status/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"kapi.acdc_agent.login_resp">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec event_category(doc()) -> kz_term:api_binary().
event_category(Doc) ->
    event_category(Doc, 'undefined').

-spec event_category(doc(), Default) -> binary() | Default.
event_category(Doc, Default) ->
    kz_json:get_binary_value([<<"Event_Category">>], Doc, Default).

-spec set_event_category(doc(), binary()) -> doc().
set_event_category(Doc, EventCategory) ->
    kz_json:set_value([<<"Event_Category">>], EventCategory, Doc).

-spec event_name(doc()) -> kz_term:api_binary().
event_name(Doc) ->
    event_name(Doc, 'undefined').

-spec event_name(doc(), Default) -> binary() | Default.
event_name(Doc, Default) ->
    kz_json:get_binary_value([<<"Event_Name">>], Doc, Default).

-spec set_event_name(doc(), binary()) -> doc().
set_event_name(Doc, EventName) ->
    kz_json:set_value([<<"Event_Name">>], EventName, Doc).

-spec status(doc()) -> kz_term:api_binary().
status(Doc) ->
    status(Doc, 'undefined').

-spec status(doc(), Default) -> binary() | Default.
status(Doc, Default) ->
    kz_json:get_binary_value([<<"Status">>], Doc, Default).

-spec set_status(doc(), binary()) -> doc().
set_status(Doc, Status) ->
    kz_json:set_value([<<"Status">>], Status, Doc).
