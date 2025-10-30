%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2026, 2600Hz
%%% @doc Accessors for `entitlements' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_entitlements).

-export([new/0]).
-export([capabilities/1, capabilities/2, set_capabilities/2]).
-export([capabilities_system/1, capabilities_system/2, set_capabilities_system/2]).
-export([capability/2, capability/3, set_capability/3]).
-export([enrollments/1, enrollments/2, set_enrollments/2]).
-export([enrollment/2, enrollment/3, set_enrollment/3]).

-export([path_capabilities/0
        ,path_enrollments/0
        ,create/2
        ,filter_disabled/1
        ]).

-export([set_capability_enabled/2, set_capability_disabled/2
        ,set_enrollment_enabled/2, set_enrollment_disabled/2

        ,is_capable/2, is_enrolled/2, is_enrolled/3
        ]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().

-type capabilities() :: kz_json:object(kz_json:key(), kzd_capability:doc()).
-type enrollments() :: kz_json:object(kz_json:key(), kzd_enrollment:doc()).

-export_type([doc/0
             ,capabilities/0
             ,enrollments/0
             ]).

-define(SCHEMA, <<"entitlements">>).
-define(PATH_CAPABILITIES, [<<"capabilities">>]).
-define(PATH_ENROLLMENTS, [<<"enrollments">>]).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec capabilities(doc()) -> kz_json:object().
capabilities(Doc) ->
    capabilities(Doc, kz_json:new()).

-spec capabilities(doc(), Default) -> kz_json:object() | Default.
capabilities(Doc, Default) ->
    kz_json:get_json_value(?PATH_CAPABILITIES, Doc, Default).

-spec set_capabilities(doc(), kz_json:object()) -> doc().
set_capabilities(Doc, Capabilities) ->
    kz_json:set_value(?PATH_CAPABILITIES, Capabilities, Doc).

-spec path_capabilities() -> kz_json:path().
path_capabilities() ->
    ?PATH_CAPABILITIES.

-spec capabilities_system(doc()) -> kz_term:api_objects().
capabilities_system(Doc) ->
    capabilities_system(Doc, 'undefined').

-spec capabilities_system(doc(), Default) -> kz_json:objects() | Default.
capabilities_system(Doc, Default) ->
    kz_json:get_list_value([<<"capabilities">>, <<"system">>], Doc, Default).

-spec set_capabilities_system(doc(), kz_json:objects()) -> doc().
set_capabilities_system(Doc, CapabilitiesSystem) ->
    kz_json:set_value([<<"capabilities">>, <<"system">>], CapabilitiesSystem, Doc).

-spec capability(doc(), kz_json:key()) -> kz_json:object().
capability(Doc, Capability) ->
    capability(Doc, Capability, kz_json:new()).

-spec capability(doc(), kz_json:key(), Default) -> kz_json:object() | Default.
capability(Doc, Capability, Default) ->
    kz_json:get_json_value([<<"capabilities">>, Capability], Doc, Default).

-spec set_capability(doc(), kz_json:key(), kz_json:object()) -> doc().
set_capability(Doc, Capability, Value) ->
    kz_json:set_value([<<"capabilities">>, Capability], Value, Doc).

-spec enrollments(doc()) -> kz_json:object().
enrollments(Doc) ->
    enrollments(Doc, kz_json:new()).

-spec enrollments(doc(), Default) -> kz_json:object() | Default.
enrollments(Doc, Default) ->
    kz_json:get_json_value([<<"enrollments">>], Doc, Default).

-spec set_enrollments(doc(), kz_json:object()) -> doc().
set_enrollments(Doc, Enrollments) ->
    kz_json:set_value([<<"enrollments">>], Enrollments, Doc).

-spec path_enrollments() -> kz_json:path().
path_enrollments() ->
    ?PATH_ENROLLMENTS.

-spec enrollment(doc(), kz_term:ne_binary()) -> kzd_enrollment:doc().
enrollment(Doc, CapabilityId) ->
    enrollment(Doc, CapabilityId, kz_json:new()).

-spec enrollment(doc(), kz_term:ne_binary(), Default) -> kzd_enrollment:doc() | Default.
enrollment(Doc, CapabilityId, Default) ->
    kz_json:get_json_value([<<"enrollments">>, CapabilityId], Doc, Default).

-spec set_enrollment(doc(), kz_json:key(), kzd_enrollment:doc()) -> doc().
set_enrollment(Doc, Capability, Value) ->
    kz_json:set_value([<<"enrollments">>, Capability], Value, Doc).

-spec create(capabilities(), enrollments()) -> doc().
create(Capabilities, Enrollments) ->
    set_enrollments(set_capabilities(new(), Capabilities)
                   ,Enrollments
                   ).

-spec filter_disabled(doc()) -> doc().
filter_disabled(Entitlements) ->
    create(filter_disabled_ities(capabilities(Entitlements, kz_json:new()))
          ,filter_disabled_ities(enrollments(Entitlements, kz_json:new()))
          ).

%% could be capabilities or enrollments
%% filter out capability IDs with enabled:false
filter_disabled_ities(Ities) ->
    kz_json:filter(fun filter_disabled_f/1, Ities).

filter_disabled_f({_CapabilityId, Properties}) ->
    kz_json:is_true(<<"enabled">>, Properties, 'false').

-spec set_capability_enabled(doc(), kz_term:ne_binary()) -> doc().
set_capability_enabled(Entitlements, CapabilityId) ->
    Cap = capability(Entitlements, CapabilityId),
    set_capability(Entitlements, CapabilityId
                  ,kzd_capability:set_enabled(Cap, 'true')
                  ).

-spec set_capability_disabled(doc(), kz_term:ne_binary()) -> doc().
set_capability_disabled(Entitlements, CapabilityId) ->
    Cap = capability(Entitlements, CapabilityId),
    set_capability(Entitlements, CapabilityId
                  ,kzd_capability:set_enabled(Cap, 'false')
                  ).

-spec set_enrollment_enabled(doc(), kz_term:ne_binary()) -> doc().
set_enrollment_enabled(Entitlements, CapabilityId) ->
    Enroll = enrollment(Entitlements, CapabilityId),
    set_enrollment(Entitlements, CapabilityId
                  ,kzd_enrollment:set_enabled(Enroll, 'true')
                  ).

-spec set_enrollment_disabled(doc(), kz_term:ne_binary()) -> doc().
set_enrollment_disabled(Entitlements, CapabilityId) ->
    Enroll = enrollment(Entitlements, CapabilityId),
    set_enrollment(Entitlements, CapabilityId
                  ,kzd_enrollment:set_enabled(Enroll, 'false')
                  ).

-spec is_capable(doc(), kz_term:ne_binary()) -> boolean().
is_capable(Entitlements, CapabilityId) ->
    kz_json:is_true([<<"capabilities">>, CapabilityId, <<"enabled">>], Entitlements, 'false').

-spec is_enrolled(doc(), kz_term:ne_binary()) -> boolean().
is_enrolled(Entitlements, CapabilityId) ->
    is_enrolled(Entitlements, CapabilityId, 'false').

-spec is_enrolled(doc(), kz_term:ne_binary(), Default) -> boolean() | Default.
is_enrolled(Entitlements, CapabilityId, Default) ->
    kz_json:is_true([<<"enrollments">>, CapabilityId, <<"enabled">>], Entitlements, Default).
