%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `metaflows_move' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_move).

-export([new/0]).
-export([auto_answer/1, auto_answer/2, set_auto_answer/2]).
-export([can_call_self/1, can_call_self/2, set_can_call_self/2]).
-export([device_id/1, device_id/2, set_device_id/2]).
-export([dial_strategy/1, dial_strategy/2, set_dial_strategy/2]).
-export([owner_id/1, owner_id/2, set_owner_id/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.move">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec auto_answer(doc()) -> boolean().
auto_answer(Doc) ->
    auto_answer(Doc, 'false').

-spec auto_answer(doc(), Default) -> boolean() | Default.
auto_answer(Doc, Default) ->
    kz_json:get_boolean_value([<<"auto_answer">>], Doc, Default).

-spec set_auto_answer(doc(), boolean()) -> doc().
set_auto_answer(Doc, AutoAnswer) ->
    kz_json:set_value([<<"auto_answer">>], AutoAnswer, Doc).

-spec can_call_self(doc()) -> boolean().
can_call_self(Doc) ->
    can_call_self(Doc, 'true').

-spec can_call_self(doc(), Default) -> boolean() | Default.
can_call_self(Doc, Default) ->
    kz_json:get_boolean_value([<<"can_call_self">>], Doc, Default).

-spec set_can_call_self(doc(), boolean()) -> doc().
set_can_call_self(Doc, CanCallSelf) ->
    kz_json:set_value([<<"can_call_self">>], CanCallSelf, Doc).

-spec device_id(doc()) -> kz_term:api_binary().
device_id(Doc) ->
    device_id(Doc, 'undefined').

-spec device_id(doc(), Default) -> binary() | Default.
device_id(Doc, Default) ->
    kz_json:get_binary_value([<<"device_id">>], Doc, Default).

-spec set_device_id(doc(), binary()) -> doc().
set_device_id(Doc, DeviceId) ->
    kz_json:set_value([<<"device_id">>], DeviceId, Doc).

-spec dial_strategy(doc()) -> binary().
dial_strategy(Doc) ->
    dial_strategy(Doc, <<"simultaneous">>).

-spec dial_strategy(doc(), Default) -> binary() | Default.
dial_strategy(Doc, Default) ->
    kz_json:get_binary_value([<<"dial_strategy">>], Doc, Default).

-spec set_dial_strategy(doc(), binary()) -> doc().
set_dial_strategy(Doc, DialStrategy) ->
    kz_json:set_value([<<"dial_strategy">>], DialStrategy, Doc).

-spec owner_id(doc()) -> kz_term:api_binary().
owner_id(Doc) ->
    owner_id(Doc, 'undefined').

-spec owner_id(doc(), Default) -> binary() | Default.
owner_id(Doc, Default) ->
    kz_json:get_binary_value([<<"owner_id">>], Doc, Default).

-spec set_owner_id(doc(), binary()) -> doc().
set_owner_id(Doc, OwnerId) ->
    kz_json:set_value([<<"owner_id">>], OwnerId, Doc).
