%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `conferences_dial' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_conferences_dial).

-export([new/0]).
-export([caller_id_name/1, caller_id_name/2, set_caller_id_name/2]).
-export([caller_id_number/1, caller_id_number/2, set_caller_id_number/2]).
-export([endpoints/1, endpoints/2, set_endpoints/2]).
-export([participant_flags/1, participant_flags/2, set_participant_flags/2]).
-export([profile_name/1, profile_name/2, set_profile_name/2]).
-export([target_call_id/1, target_call_id/2, set_target_call_id/2]).
-export([timeout/1, timeout/2, set_timeout/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"conferences.dial">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec caller_id_name(doc()) -> kz_term:api_binary().
caller_id_name(Doc) ->
    caller_id_name(Doc, 'undefined').

-spec caller_id_name(doc(), Default) -> binary() | Default.
caller_id_name(Doc, Default) ->
    kz_json:get_binary_value([<<"caller_id_name">>], Doc, Default).

-spec set_caller_id_name(doc(), binary()) -> doc().
set_caller_id_name(Doc, CallerIdName) ->
    kz_json:set_value([<<"caller_id_name">>], CallerIdName, Doc).

-spec caller_id_number(doc()) -> kz_term:api_binary().
caller_id_number(Doc) ->
    caller_id_number(Doc, 'undefined').

-spec caller_id_number(doc(), Default) -> binary() | Default.
caller_id_number(Doc, Default) ->
    kz_json:get_binary_value([<<"caller_id_number">>], Doc, Default).

-spec set_caller_id_number(doc(), binary()) -> doc().
set_caller_id_number(Doc, CallerIdNumber) ->
    kz_json:set_value([<<"caller_id_number">>], CallerIdNumber, Doc).

-spec endpoints(doc()) -> kz_term:api_list().
endpoints(Doc) ->
    endpoints(Doc, 'undefined').

-spec endpoints(doc(), Default) -> list() | Default.
endpoints(Doc, Default) ->
    kz_json:get_list_value([<<"endpoints">>], Doc, Default).

-spec set_endpoints(doc(), list()) -> doc().
set_endpoints(Doc, Endpoints) ->
    kz_json:set_value([<<"endpoints">>], Endpoints, Doc).

-spec participant_flags(doc()) -> kz_term:api_ne_binaries().
participant_flags(Doc) ->
    participant_flags(Doc, 'undefined').

-spec participant_flags(doc(), Default) -> kz_term:ne_binaries() | Default.
participant_flags(Doc, Default) ->
    kz_json:get_list_value([<<"participant_flags">>], Doc, Default).

-spec set_participant_flags(doc(), kz_term:ne_binaries()) -> doc().
set_participant_flags(Doc, ParticipantFlags) ->
    kz_json:set_value([<<"participant_flags">>], ParticipantFlags, Doc).

-spec profile_name(doc()) -> kz_term:api_binary().
profile_name(Doc) ->
    profile_name(Doc, 'undefined').

-spec profile_name(doc(), Default) -> binary() | Default.
profile_name(Doc, Default) ->
    kz_json:get_binary_value([<<"profile_name">>], Doc, Default).

-spec set_profile_name(doc(), binary()) -> doc().
set_profile_name(Doc, ProfileName) ->
    kz_json:set_value([<<"profile_name">>], ProfileName, Doc).

-spec target_call_id(doc()) -> kz_term:api_binary().
target_call_id(Doc) ->
    target_call_id(Doc, 'undefined').

-spec target_call_id(doc(), Default) -> binary() | Default.
target_call_id(Doc, Default) ->
    kz_json:get_binary_value([<<"target_call_id">>], Doc, Default).

-spec set_target_call_id(doc(), binary()) -> doc().
set_target_call_id(Doc, TargetCallId) ->
    kz_json:set_value([<<"target_call_id">>], TargetCallId, Doc).

-spec timeout(doc()) -> kz_term:api_integer().
timeout(Doc) ->
    timeout(Doc, 'undefined').

-spec timeout(doc(), Default) -> integer() | Default.
timeout(Doc, Default) ->
    kz_json:get_integer_value([<<"timeout">>], Doc, Default).

-spec set_timeout(doc(), integer()) -> doc().
set_timeout(Doc, Timeout) ->
    kz_json:set_value([<<"timeout">>], Timeout, Doc).
