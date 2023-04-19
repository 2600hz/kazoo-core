%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `call_recording_source' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_call_recording_source).

-export([new/0]).
-export([any/1, any/2, set_any/2]).
-export([offnet/1, offnet/2, set_offnet/2]).
-export([onnet/1, onnet/2, set_onnet/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"call_recording.source">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec any(doc()) -> kz_term:api_object().
any(Doc) ->
    any(Doc, 'undefined').

-spec any(doc(), Default) -> kz_json:object() | Default.
any(Doc, Default) ->
    kz_json:get_json_value([<<"any">>], Doc, Default).

-spec set_any(doc(), kz_json:object()) -> doc().
set_any(Doc, Any) ->
    kz_json:set_value([<<"any">>], Any, Doc).

-spec offnet(doc()) -> kz_term:api_object().
offnet(Doc) ->
    offnet(Doc, 'undefined').

-spec offnet(doc(), Default) -> kz_json:object() | Default.
offnet(Doc, Default) ->
    kz_json:get_json_value([<<"offnet">>], Doc, Default).

-spec set_offnet(doc(), kz_json:object()) -> doc().
set_offnet(Doc, Offnet) ->
    kz_json:set_value([<<"offnet">>], Offnet, Doc).

-spec onnet(doc()) -> kz_term:api_object().
onnet(Doc) ->
    onnet(Doc, 'undefined').

-spec onnet(doc(), Default) -> kz_json:object() | Default.
onnet(Doc, Default) ->
    kz_json:get_json_value([<<"onnet">>], Doc, Default).

-spec set_onnet(doc(), kz_json:object()) -> doc().
set_onnet(Doc, Onnet) ->
    kz_json:set_value([<<"onnet">>], Onnet, Doc).
