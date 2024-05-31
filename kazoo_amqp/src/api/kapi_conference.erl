%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2024, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapi_conference).

-export([api_definitions/0, api_definition/1]).

-export([focus_queue_name/1]).

-export([event/1
        ,event_v/1
        ,publish_event/1
        ,publish_event/2
        ]).
-export([search_req/1
        ,search_req_v/1
        ,publish_search_req/1
        ,publish_search_req/2
        ]).
-export([search_resp/1
        ,search_resp_v/1
        ,publish_search_resp/2
        ,publish_search_resp/3
        ]).
-export([discovery_req/1
        ,discovery_req_v/1
        ,publish_discovery_req/1
        ,publish_discovery_req/2
        ]).
-export([discovery_resp/1
        ,discovery_resp_v/1
        ,publish_discovery_resp/2
        ,publish_discovery_resp/3
        ]).
-export([add_participant/1
        ,add_participant_v/1
        ,publish_add_participant/2
        ,publish_add_participant/3
        ]).
-export([deaf_participant/1
        ,deaf_participant_v/1
        ,publish_deaf_participant/2
        ,publish_deaf_participant/3
        ]).
-export([participant_energy/1
        ,participant_energy_v/1
        ,publish_participant_energy/2
        ,publish_participant_energy/3
        ]).
-export([kick/1
        ,kick_v/1
        ,publish_kick/2
        ,publish_kick/3
        ]).
-export([participants_req/1
        ,participants_req_v/1
        ,publish_participants_req/2
        ,publish_participants_req/3
        ]).
-export([participants_resp/1
        ,participants_resp_v/1
        ,publish_participants_resp/2
        ,publish_participants_resp/3
        ]).
-export([lock/1
        ,lock_v/1
        ,publish_lock/2
        ,publish_lock/3
        ]).
-export([mute_participant/1
        ,mute_participant_v/1
        ,publish_mute_participant/2
        ,publish_mute_participant/3
        ]).
-export([play/1
        ,play_v/1
        ,publish_play/2
        ,publish_play/3
        ]).
-export([tones/1
        ,tones_v/1
        ]).
-export([say/1
        ,say_v/1
        ]).
-export([tts/1
        ,tts_v/1
        ]).
-export([record/1
        ,record_v/1
        ,publish_record/2
        ,publish_record/3
        ]).
-export([recordstop/1
        ,recordstop_v/1
        ,publish_recordstop/2
        ,publish_recordstop/3
        ]).
-export([relate_participants/1
        ,relate_participants_v/1
        ,publish_relate_participants/2
        ,publish_relate_participants/3
        ]).
-export([set/1
        ,set_v/1
        ,publish_set/2
        ,publish_set/3
        ]).
-export([stop_play/1
        ,stop_play_v/1
        ,publish_stop_play/2
        ,publish_stop_play/3
        ]).
-export([undeaf_participant/1
        ,undeaf_participant_v/1
        ,publish_undeaf_participant/2
        ,publish_undeaf_participant/3
        ]).
-export([unlock/1
        ,unlock_v/1
        ,publish_unlock/2
        ,publish_unlock/3
        ]).
-export([unmute_participant/1
        ,unmute_participant_v/1
        ,publish_unmute_participant/2
        ,publish_unmute_participant/3
        ]).
-export([participant_volume_in/1
        ,participant_volume_in_v/1
        ,publish_participant_volume_in/2
        ,publish_participant_volume_in/3
        ]).
-export([participant_volume_out/1
        ,participant_volume_out_v/1
        ,publish_participant_volume_out/2
        ,publish_participant_volume_out/3
        ]).
-export([participant_event/1
        ,participant_event_v/1
        ,publish_participant_event/3
        ,publish_participant_event/4
        ]).
-export([conference_error/1
        ,conference_error_v/1
        ,publish_error/2
        ,publish_error/3
        ]).
-export([config_req/1
        ,config_req_v/1
        ,publish_config_req/1
        ,publish_config_req/2
        ]).
-export([config_resp/1
        ,config_resp_v/1
        ,publish_config_resp/2
        ,publish_config_resp/3
        ]).
-export([play_macro_req/1
        ,play_macro_req_v/1
        ]).
-export([dial/1
        ,dial_v/1
        ,publish_dial/2
        ,publish_dial/3
        ]).
-export([dial_resp/1
        ,dial_resp_v/1
        ,publish_dial_resp/2
        ,publish_dial_resp/3
        ]).
-export([vars/1
        ,vars_v/1
        ,publish_vars/2
        ,publish_vars/3
        ]).

-export([bind_q/2
        ,unbind_q/2
        ]).
-export([declare_exchanges/0]).

-export([publish_command/2
        ,publish_command/3
        ]).
-export([publish_targeted_command/2
        ,publish_targeted_command/3
        ]).
-export([events/0]).

-ifdef(TEST).
-export([conference_event_key/4]).
-endif.

-include_lib("kz_amqp_util.hrl").
-include("kapi_dialplan.hrl").

-elvis([{'elvis_style', 'god_modules', 'disable'}]).

-type doc() :: kz_json:object().
-type discovery_req() :: kz_json:object().
-type config_req() :: kz_json:object().
-export_type([doc/0
             ,discovery_req/0
             ,config_req/0
             ]).

-define(APPLICATION_MAP, [appmap_tuple(<<"deaf_participant">>, deaf_participant_definition())
                         ,appmap_tuple(<<"participant_energy">>, participant_energy_definition())
                         ,appmap_tuple(<<"kick">>, kick_definition())
                         ,appmap_tuple(<<"participants">>, participants_req_definition())
                         ,appmap_tuple(<<"lock">>, lock_definition())
                         ,appmap_tuple(<<"mute_participant">>, mute_participant_definition())
                         ,appmap_tuple(<<"play">>, play_definition())
                         ,appmap_tuple(<<"record">>, record_definition())
                         ,appmap_tuple(<<"recordstop">>, recordstop_definition())
                         ,appmap_tuple(<<"relate_participants">>, relate_participants_definition())
                         ,appmap_tuple(<<"stop_play">>, stop_play_definition())
                         ,appmap_tuple(<<"undeaf_participant">>, undeaf_participant_definition())
                         ,appmap_tuple(<<"unlock">>, unlock_definition())
                         ,appmap_tuple(<<"unmute_participant">>, unmute_participant_definition())
                         ,appmap_tuple(<<"participant_volume_in">>,
                                       participant_volume_in_definition())
                         ,appmap_tuple(<<"participant_volume_out">>,
                                       participant_volume_out_definition())
                         ,appmap_tuple(<<"dial">>, dial_definition())
                         ,appmap_tuple(<<"dial_resp">>, dial_resp_definition())
                         ,appmap_tuple(<<"tones">>, tones_definition())
                         ,appmap_tuple(<<"say">>, say_definition())
                         ,appmap_tuple(<<"tts">>, tts_definition())
                         ,appmap_tuple(<<"play_macro">>, play_macro_req_definition())
                         ]).

-define(MEMBER_UPDATE_EVENTS, [<<"stop-talking">>
                              ,<<"start-talking">>
                              ,<<"mute-member">>
                              ,<<"unmute-member">>
                              ,<<"deaf-member">>
                              ,<<"undeaf-member">>
                              ]).

-define(CONFERENCE_EVENTS, [<<"conference-create">>
                           ,<<"conference-destroy">>
                           ,<<"lock">>
                           ,<<"unlock">>
                           ,<<"add-member">>
                           ,<<"del-member">>
                           | ?MEMBER_UPDATE_EVENTS
                           ]).

%%------------------------------------------------------------------------------
%% @doc Get all API definitions of this module.
%% @end
%%------------------------------------------------------------------------------
-spec api_definitions() -> kapi_definition:apis().
api_definitions() ->
    [event_definition()
    ,search_req_definition()
    ,search_resp_definition()
    ,discovery_req_definition()
    ,discovery_resp_definition()
    ,add_participant_definition()
    ,deaf_participant_definition()
    ,participant_energy_definition()
    ,kick_definition()
    ,participants_req_definition()
    ,participants_resp_definition()
    ,lock_definition()
    ,mute_participant_definition()
    ,play_definition()
    ,tones_definition()
    ,say_definition()
    ,tts_definition()
    ,record_definition()
    ,recordstop_definition()
    ,relate_participants_definition()
    ,set_definition()
    ,stop_play_definition()
    ,undeaf_participant_definition()
    ,unlock_definition()
    ,unmute_participant_definition()
    ,participant_volume_in_definition()
    ,participant_volume_out_definition()
    ,participant_event_definition()
    ,conference_error_definition()
    ,config_req_definition()
    ,config_resp_definition()
    ,play_macro_req_definition()
    ,dial_definition()
    ,dial_resp_definition()
    ,vars_definition()
    ].

%%------------------------------------------------------------------------------
%% @doc Get API definition of the given `Name'.
%% @see api_definitions/0
%% @end
%%------------------------------------------------------------------------------
-spec api_definition(kz_term:text()) -> kapi_definition:api().
api_definition(Name) when not is_binary(Name) ->
    api_definition(kz_term:to_binary(Name));
api_definition(<<"event">>) ->
    event_definition();
api_definition(<<"search_req">>) ->
    search_req_definition();
api_definition(<<"search_resp">>) ->
    search_resp_definition();
api_definition(<<"discovery_req">>) ->
    discovery_req_definition();
api_definition(<<"discovery_resp">>) ->
    discovery_resp_definition();
api_definition(<<"add_participant">>) ->
    add_participant_definition();
api_definition(<<"deaf_participant">>) ->
    deaf_participant_definition();
api_definition(<<"participant_energy">>) ->
    participant_energy_definition();
api_definition(<<"kick">>) ->
    kick_definition();
api_definition(<<"participants_req">>) ->
    participants_req_definition();
api_definition(<<"participants_resp">>) ->
    participants_resp_definition();
api_definition(<<"lock">>) ->
    lock_definition();
api_definition(<<"mute_participant">>) ->
    mute_participant_definition();
api_definition(<<"play">>) ->
    play_definition();
api_definition(<<"tones">>) ->
    tones_definition();
api_definition(<<"say">>) ->
    say_definition();
api_definition(<<"tts">>) ->
    tts_definition();
api_definition(<<"record">>) ->
    record_definition();
api_definition(<<"recordstop">>) ->
    recordstop_definition();
api_definition(<<"relate_participants">>) ->
    relate_participants_definition();
api_definition(<<"set">>) ->
    set_definition();
api_definition(<<"stop_play">>) ->
    stop_play_definition();
api_definition(<<"undeaf_participant">>) ->
    undeaf_participant_definition();
api_definition(<<"unlock">>) ->
    unlock_definition();
api_definition(<<"unmute_participant">>) ->
    unmute_participant_definition();
api_definition(<<"participant_volume_in">>) ->
    participant_volume_in_definition();
api_definition(<<"participant_volume_out">>) ->
    participant_volume_out_definition();
api_definition(<<"participant_event">>) ->
    participant_event_definition();
api_definition(<<"conference_error">>) ->
    conference_error_definition();
api_definition(<<"config_req">>) ->
    config_req_definition();
api_definition(<<"config_resp">>) ->
    config_resp_definition();
api_definition(<<"play_macro_req">>) ->
    play_macro_req_definition();
api_definition(<<"dial">>) ->
    dial_definition();
api_definition(<<"dial_resp">>) ->
    dial_resp_definition();
api_definition(<<"vars">>) ->
    vars_definition().

-spec event_definition() -> kapi_definition:api().
event_definition() ->
    EventName = <<"event">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Event">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Event">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun event/1}
              ,{fun kapi_definition:set_validate_fun/2, fun event_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_event/1}
              ,{fun kapi_definition:set_binding/2, fun event_key/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Conference-ID">>
                                                            ,<<"Event">>
                                                            ,<<"Instance-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Caller-ID-Name">>
                                                            ,<<"Caller-ID-Number">>
                                                            ,<<"Call-ID">>
                                                            ,<<"Channel-Presence-ID">>
                                                            ,<<"Conference-Channel-Vars">>
                                                            ,<<"Custom-Channel-Vars">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec search_req_definition() -> kapi_definition:api().
search_req_definition() ->
    EventName = <<"search_req">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Search Request">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Search Request">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun search_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun search_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_search_req/1}
              ,{fun kapi_definition:set_required_headers/2, [[<<"Conference-ID">>, <<"Account-ID">>]
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec search_resp_definition() -> kapi_definition:api().
search_resp_definition() ->
    EventName = <<"search_resp">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Search Response">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Search Response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun search_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun search_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_search_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [[<<"Conferences">>
                                                             ,<<"Conference-ID">>
                                                             ]
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Answered">>
                                                            ,<<"Custom-Conference-Vars">>
                                                            ,<<"Dynamic">>
                                                            ,<<"Locked">>
                                                            ,<<"Participant-Count">>
                                                            ,<<"Participants">>
                                                            ,<<"Run-Time">>
                                                            ,<<"Running">>
                                                            ,<<"Start-Time">>
                                                            ,<<"Switch-External-IP">>
                                                            ,<<"Switch-Hostname">>
                                                            ,<<"Switch-URL">>
                                                            ,<<"UUID">>
                                                            ,<<"Zone">>
                                                            ,<<?CALL_INTERACTION_ID>>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec discovery_req_definition() -> kapi_definition:api().
discovery_req_definition() ->
    EventName = <<"discovery_req">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Discovery Request">>}
              ,{fun kapi_definition:set_description/2, <<"">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun discovery_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun discovery_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_discovery_req/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Call">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Conference-Doc">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Conference-Name">>
                                                            ,<<"Moderator">>
                                                            ,<<"Play-Entry-Tone">>
                                                            ,<<"Play-Exit-Tone">>
                                                            ,<<"Play-Welcome">>
                                                            ,<<"Play-Welcome-Media">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Moderator">>, fun kz_term:is_boolean/1}
                ,{<<"Play-Welcome">>, fun kz_term:is_boolean/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec discovery_resp_definition() -> kapi_definition:api().
discovery_resp_definition() ->
    EventName = <<"discovery_resp">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Discovery Response">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Discovery Response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun discovery_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun discovery_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_discovery_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Conference-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec add_participant_definition() -> kapi_definition:api().
add_participant_definition() ->
    EventName = <<"add_participant">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Add Participant">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Add Participant">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun add_participant/1}
              ,{fun kapi_definition:set_validate_fun/2, fun add_participant_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_add_participant/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Call-ID">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Control-Queue">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Account-ID">>
                                                            ,<<"Answered">>
                                                            ,<<"Authorizing-ID">>
                                                            ,<<"Authorizing-Type">>
                                                            ,<<"Bridge-ID">>
                                                            ,<<"Call-Direction">>
                                                            ,<<"Callee-ID-Name">>
                                                            ,<<"Callee-ID-Number">>
                                                            ,<<"Caller-ID-Name">>
                                                            ,<<"Caller-ID-Number">>
                                                            ,<<"Call-ID">>
                                                            ,<<"Channel-Authorized">>
                                                            ,<<"Channel-Call-State">>
                                                            ,<<"Channel-Created-Time">>
                                                            ,<<"Channel-Is-Loopback">>
                                                            ,<<"Channel-Loopback-Bowout">>
                                                            ,<<"Channel-Loopback-Bowout-Execute">>
                                                            ,<<"Channel-Loopback-Leg">>
                                                            ,<<"Channel-Loopback-Other-Leg-ID">>
                                                            ,<<"Channel-Moving">>
                                                            ,<<"Channel-Name">>
                                                            ,<<"Channel-State">>
                                                            ,<<"Custom-Application-Vars">>
                                                            ,<<"Custom-Channel-Vars">>
                                                            ,<<"Custom-SIP-Headers">>
                                                            ,<<"Destination">>
                                                            ,<<"Disposition">>
                                                            ,<<"Ecallmgr-Node">>
                                                            ,<<"From">>
                                                            ,<<"From-Tag">>
                                                            ,<<"Hangup-Cause">>
                                                            ,<<"Hangup-Code">>
                                                            ,<<"Is-Loopback">>
                                                            ,<<"Is-On-Hold">>
                                                            ,<<"Media-Node">>
                                                            ,<<"Media-Server">>
                                                            ,<<"Msg-ID">>
                                                            ,<<"Node">>
                                                            ,<<"Origination-Call-ID">>
                                                            ,<<"Other-Leg-Caller-ID-Name">>
                                                            ,<<"Other-Leg-Caller-ID-Number">>
                                                            ,<<"Other-Leg-Call-ID">>
                                                            ,<<"Other-Leg-Destination-Number">>
                                                            ,<<"Other-Leg-Direction">>
                                                            ,<<"Participant-Flags">>
                                                            ,<<"Presence-ID">>
                                                            ,<<"Profile-Name">>
                                                            ,<<"Raw-Application-Data">>
                                                            ,<<"Raw-Application-Name">>
                                                            ,<<"Realm">>
                                                            ,<<"Replaced-By">>
                                                            ,<<"Request">>
                                                            ,<<"Switch-Hostname">>
                                                            ,<<"Switch-Nodename">>
                                                            ,<<"Switch-URI">>
                                                            ,<<"Switch-URL">>
                                                            ,<<"Timestamp">>
                                                            ,<<"To">>
                                                            ,<<"To-Tag">>
                                                            ,<<"Transfer-History">>
                                                            ,<<"Username">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec deaf_participant_definition() -> kapi_definition:api().
deaf_participant_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Deaf Participant">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Deaf Participant">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun deaf_participant/1}
              ,{fun kapi_definition:set_validate_fun/2, fun deaf_participant_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_deaf_participant/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"deaf_participant">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec participant_energy_definition() -> kapi_definition:api().
participant_energy_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Participant Energy">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Participant Energy">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun participant_energy/1}
              ,{fun kapi_definition:set_validate_fun/2, fun participant_energy_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_participant_energy/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Energy-Level">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"participant_energy">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec kick_definition() -> kapi_definition:api().
kick_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Kick">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Kick">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun kick/1}
              ,{fun kapi_definition:set_validate_fun/2, fun kick_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_kick/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"kick">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec participants_req_definition() -> kapi_definition:api().
participants_req_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Participants Request">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Participants Request">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun participants_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun participants_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_participants_req/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"participants">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec participants_resp_definition() -> kapi_definition:api().
participants_resp_definition() ->
    EventName = <<"participants_resp">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Participants Response">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Participants Response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun participants_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun participants_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_participants_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Participants">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec lock_definition() -> kapi_definition:api().
lock_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Lock">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Lock">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun lock/1}
              ,{fun kapi_definition:set_validate_fun/2, fun lock_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_lock/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"lock">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec mute_participant_definition() -> kapi_definition:api().
mute_participant_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Mute">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Mute">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun mute_participant/1}
              ,{fun kapi_definition:set_validate_fun/2, fun mute_participant_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_mute_participant/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"mute_participant">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec play_definition() -> kapi_definition:api().
play_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Play">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Play">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun play/1}
              ,{fun kapi_definition:set_validate_fun/2, fun play_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_play/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Media-Name">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Call-ID">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"play">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ,{<<"Media-Name">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec tones_definition() -> kapi_definition:api().
tones_definition() ->
    TonesDef = kapi_dialplan:api_definition(<<"tones">>),
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, kapi_definition:name(TonesDef)}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Tones">>}
              ,{fun kapi_definition:set_description/2, <<"Create a tone on the channel">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun tones/1}
              ,{fun kapi_definition:set_validate_fun/2, fun tones_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_command/2}
              ,{fun kapi_definition:set_required_headers/2
               ,kapi_definition:required_headers(TonesDef)
               }
              ,{fun kapi_definition:set_optional_headers/2
               ,kapi_definition:optional_headers(TonesDef)
               }
              ,{fun kapi_definition:set_values/2
               ,[{<<"Event-Category">>, Category}
                | props:delete(<<"Event-Category">>, kapi_definition:values(TonesDef))
                ]
               }
              ,{fun kapi_definition:set_types/2, kapi_definition:types(TonesDef)}
              ],
    kapi_definition:setters(Setters).

-spec say_definition() -> kapi_definition:api().
say_definition() ->
    TTSDef = kapi_dialplan:api_definition(<<"tts">>),
    Category = <<"Conference">>,
    Setters = [{fun kapi_definition:set_name/2, kapi_definition:name(TTSDef)}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference TTS">>}
              ,{fun kapi_definition:set_description/2, <<"TTS - Text-to-speech">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun say/1}
              ,{fun kapi_definition:set_validate_fun/2, fun say_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_command/2}
              ,{fun kapi_definition:set_required_headers/2
               ,kapi_definition:required_headers(TTSDef)
               }
              ,{fun kapi_definition:set_optional_headers/2
               ,kapi_definition:optional_headers(TTSDef)
               }
              ,{fun kapi_definition:set_values/2
               ,[{<<"Event-Category">>, Category}
                ,{<<"Application-Name">>, [<<"say">>, <<"tts">>]}
                | props:delete_keys([<<"Event-Category">>
                                    ,<<"Application-Name">>
                                    ]
                                   ,kapi_definition:values(tones_definition())
                                   )
                ]
               }
              ,{fun kapi_definition:set_types/2, kapi_definition:types(TTSDef)}
              ],
    kapi_definition:setters(Setters).

-spec tts_definition() -> kapi_definition:api().
tts_definition() ->
    Setters = [{fun kapi_definition:set_build_fun/2, fun tts/1}
              ,{fun kapi_definition:set_validate_fun/2, fun tts_v/1}
              ],
    kapi_definition:setters(Setters, say_definition()).

-spec record_definition() -> kapi_definition:api().
record_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Record">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Record">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun record/1}
              ,{fun kapi_definition:set_validate_fun/2, fun record_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_record/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Media-Name">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Call-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"record">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec recordstop_definition() -> kapi_definition:api().
recordstop_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference RecordStop">>}
              ,{fun kapi_definition:set_description/2, <<"Conference RecordStop">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun recordstop/1}
              ,{fun kapi_definition:set_validate_fun/2, fun recordstop_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_recordstop/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Media-Name">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Call-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"recordstop">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec relate_participants_definition() -> kapi_definition:api().
relate_participants_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Relate Participants">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Relate Participants">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun relate_participants/1}
              ,{fun kapi_definition:set_validate_fun/2, fun relate_participants_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_relate_participants/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Other-Participant">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Relationship">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"relate_participants">>}
                ,{<<"Relationship">>, [<<"deaf">>, <<"mute">>, <<"clear">>]}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ,{<<"Participant-ID">> ,fun(ID) -> is_integer(ID)
                                                       orelse is_binary(ID)
                                        end
                 }
                ,{<<"Other-Participant">>, fun(ID) -> is_integer(ID)
                                                          orelse is_binary(ID)
                                           end
                 }
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec set_definition() -> kapi_definition:api().
set_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Set">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Set">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun set/1}
              ,{fun kapi_definition:set_validate_fun/2, fun set_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_set/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Parameter">>
                                                            ,<<"Value">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"set">>}
                ,{<<"Parameter">>, [<<"Max-Members">>
                                   ,<<"Caller-ID-Name">>
                                   ,<<"Caller-ID-Number">>
                                   ]}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ,{<<"Value">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec stop_play_definition() -> kapi_definition:api().
stop_play_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Stop Play">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Stop Play">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun stop_play/1}
              ,{fun kapi_definition:set_validate_fun/2, fun stop_play_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_stop_play/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Affects">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"stop_play">>}
                ,{<<"Affects">>, [<<"current">>, <<"all">>]}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec undeaf_participant_definition() -> kapi_definition:api().
undeaf_participant_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Undeaf">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Undeaf">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun undeaf_participant/1}
              ,{fun kapi_definition:set_validate_fun/2, fun undeaf_participant_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_undeaf_participant/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"undeaf_participant">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec unlock_definition() -> kapi_definition:api().
unlock_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Unlock">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Unlock">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun unlock/1}
              ,{fun kapi_definition:set_validate_fun/2, fun unlock_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_unlock/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"unlock">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec unmute_participant_definition() -> kapi_definition:api().
unmute_participant_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Unmute">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Unmute">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun unmute_participant/1}
              ,{fun kapi_definition:set_validate_fun/2, fun unmute_participant_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_unmute_participant/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Participant-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"unmute_participant">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec participant_volume_in_definition() -> kapi_definition:api().
participant_volume_in_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Set Volume In">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Set Volume In">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun participant_volume_in/1}
              ,{fun kapi_definition:set_validate_fun/2, fun participant_volume_in_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_participant_volume_in/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Participant-ID">>
                                                            ,<<"Volume-In-Level">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"participant_volume_in">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec participant_volume_out_definition() -> kapi_definition:api().
participant_volume_out_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Set Volume Out">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Set Volume Out">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun participant_volume_out/1}
              ,{fun kapi_definition:set_validate_fun/2, fun participant_volume_out_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_participant_volume_out/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Participant-ID">>
                                                            ,<<"Volume-Out-Level">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"participant_volume_out">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec participant_event_definition() -> kapi_definition:api().
participant_event_definition() ->
    EventName = <<"participant_event">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Participants Event">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Participants Event">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun participant_event/1}
              ,{fun kapi_definition:set_validate_fun/2, fun participant_event_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_participant_event/3}
              ,{fun kapi_definition:set_required_headers/2, [<<"Caller-ID-Name">>
                                                            ,<<"Caller-ID-Number">>
                                                            ,<<"Call-ID">>
                                                            ,<<"Channel-Presence-ID">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Current-Energy">>
                                                            ,<<"Custom-Channel-Vars">>
                                                            ,<<"Energy-Level">>
                                                            ,<<"Event">>
                                                            ,<<"Floor">>
                                                            ,<<"Focus">>
                                                            ,<<"Hear">>
                                                            ,<<"Instance-ID">>
                                                            ,<<"Mute-Detect">>
                                                            ,<<"Participant-ID">>
                                                            ,<<"Speak">>
                                                            ,<<"Talking">>
                                                            ,<<"Video">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec conference_error_definition() -> kapi_definition:api().
conference_error_definition() ->
    EventName = <<"error">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Error">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Error">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun conference_error/1}
              ,{fun kapi_definition:set_validate_fun/2, fun conference_error_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_error/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Conference-ID">>
                                                            ,<<"Error-Message">>
                                                            ,<<"Request">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec config_req_definition() -> kapi_definition:api().
config_req_definition() ->
    EventName = <<"config_req">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Configuration Request">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Configuration Request">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun config_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun config_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_config_req/1}
              ,{fun kapi_definition:set_required_headers/2, [<<"Profile">>
                                                            ,<<"Request">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Call-ID">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Controls">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec config_resp_definition() -> kapi_definition:api().
config_resp_definition() ->
    EventName = <<"config_resp">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Configuration Response">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Configuration Response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun config_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun config_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_config_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [[<<"Profiles">>, <<"Caller-Controls">>]
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Advertise">>
                                                            ,<<"Chat-Permissions">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,kapi_definition:event_type_headers(Category, EventName)
               }
              ,{fun kapi_definition:set_types/2, []}
              ],
    kapi_definition:setters(Setters).

-spec play_macro_req_definition() -> kapi_definition:api().
play_macro_req_definition() ->
    Setters = [{fun kapi_definition:set_friendly_name/2, <<"Play Macro Request">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Play Macro Request">>}
              ,{fun kapi_definition:set_build_fun/2, fun play_macro_req/1}
              ,{fun kapi_definition:set_validate_fun/2, fun play_macro_req_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_command/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Media-Macro">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2, []}
              ,{fun kapi_definition:set_types/2
               ,[{<<"Conference-ID">>, fun is_binary/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec dial_definition() -> kapi_definition:api().
dial_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Dial Request">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Dial Request">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun dial/1}
              ,{fun kapi_definition:set_validate_fun/2, fun dial_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_dial/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ,<<"Endpoints">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Account-ID">>
                                                            ,<<"Caller-ID-Name">>
                                                            ,<<"Caller-ID-Number">>
                                                            ,<<"Custom-Application-Vars">>
                                                            ,<<"Custom-Channel-Vars">>
                                                            ,<<"Outbound-Call-ID">>
                                                            ,<<"Participant-Flags">>
                                                            ,<<"Profile-Name">>
                                                            ,<<"Target-Call-ID">>
                                                            ,<<"Timeout">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"dial">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Caller-ID-Name">>, fun is_binary/1}
                ,{<<"Caller-ID-Number">>, fun is_binary/1}
                ,{<<"Endpoints">>, fun(Es) ->
                                           kz_term:is_ne_list(Es)
                                               andalso kz_json:are_json_objects(Es)
                                   end
                 }
                ,{<<"Custom-Channel-Vars">>, fun kz_json:is_json_object/1}
                ,{<<"Custom-Application-Vars">>, fun kz_json:is_json_object/1}
                ,{<<"Timeout">>, fun is_integer/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec dial_resp_definition() -> kapi_definition:api().
dial_resp_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Dial Response">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Dial Response">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun dial_resp/1}
              ,{fun kapi_definition:set_validate_fun/2, fun dial_resp_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_dial_resp/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Endpoint-Responses">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, []}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"dial_resp">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Endpoint-Responses">>
                 ,fun(Es) ->
                          kz_term:is_ne_list(Es)
                              andalso kz_json:are_json_objects(Es)
                  end
                 }
                ]
               }
              ],
    kapi_definition:setters(Setters).

-spec vars_definition() -> kapi_definition:api().
vars_definition() ->
    EventName = <<"command">>,
    Category = <<"conference">>,
    Setters = [{fun kapi_definition:set_name/2, EventName}
              ,{fun kapi_definition:set_friendly_name/2, <<"Conference Vars">>}
              ,{fun kapi_definition:set_description/2, <<"Conference Vars">>}
              ,{fun kapi_definition:set_category/2, Category}
              ,{fun kapi_definition:set_build_fun/2, fun vars/1}
              ,{fun kapi_definition:set_validate_fun/2, fun vars_v/1}
              ,{fun kapi_definition:set_publish_fun/2, fun publish_vars/2}
              ,{fun kapi_definition:set_required_headers/2, [<<"Application-Name">>
                                                            ,<<"Conference-ID">>
                                                            ]}
              ,{fun kapi_definition:set_optional_headers/2, [<<"Custom-Conference-Vars">>
                                                            ]}
              ,{fun kapi_definition:set_values/2
               ,[{<<"Application-Name">>, <<"vars">>}
                | kapi_definition:event_type_headers(Category, EventName)
                ]
               }
              ,{fun kapi_definition:set_types/2
               ,[{<<"Custom-Conference-Vars">>, fun kz_json:is_json_object/1}
                ]
               }
              ],
    kapi_definition:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec events() -> kz_term:ne_binaries().
events() -> ?CONFERENCE_EVENTS.

-spec focus_queue_name(atom()) -> kz_term:ne_binary().
focus_queue_name(Focus) -> <<(kz_term:to_binary(Focus))/binary, "_conference">>.

%%------------------------------------------------------------------------------
%% @doc TTS - Text To Speech.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec say(kz_term:api_terms()) -> kz_api:api_formatter_return() .
say(Req) ->
    kapi_definition:build_message(Req, say_definition()).

-spec say_v(kz_term:api_terms()) -> boolean().
say_v(Req) ->
    kapi_definition:validate(Req, say_definition()).

-spec tts(kz_term:api_terms()) -> kz_api:api_formatter_return().
tts(API) ->
    say(API).

-spec tts_v(kz_term:api_terms()) -> boolean().
tts_v(API) ->
    say_v(API).

%%------------------------------------------------------------------------------
%% @doc Create a tone on the channel.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec tones(kz_term:api_terms()) -> kz_api:api_formatter_return().
tones(Prop) when is_list(Prop) ->
    Tones = [begin
                 {'ok', TonesProp} = kapi_dialplan:tones_req_tone_headers(Tone),
                 kz_json:from_list(TonesProp)
             end
             || Tone <- props:get_value(<<"Tones">>, Prop, []),
                kapi_dialplan:tones_req_tone_v(Tone)
            ],
    Prop1 = [ {<<"Tones">>, Tones} | props:delete(<<"Tones">>, Prop)],
    kapi_definition:build_message(Prop1, tones_definition());
tones(JObj) ->
    tones(kz_json:to_proplist(JObj)).

-spec tones_v(kz_term:api_terms()) -> boolean().
tones_v(Req) ->
    kapi_definition:validate(Req, tones_definition()).

%%------------------------------------------------------------------------------
%% @doc Conference Search Request.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec search_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
search_req(Req) ->
    kapi_definition:build_message(Req, search_req_definition()).

-spec search_req_v(kz_term:api_terms()) -> boolean().
search_req_v(Req) ->
    kapi_definition:validate(Req, search_req_definition()).

-spec publish_search_req(kz_term:api_terms()) -> 'ok'.
publish_search_req(JObj) ->
    publish_search_req(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_search_req(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_search_req(Req, ContentType) ->
    Definition = search_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'discovery', 'undefined', [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Search Response.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec search_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
search_resp(Req) ->
    kapi_definition:build_message(Req, search_resp_definition()).

-spec search_resp_v(kz_term:api_terms()) -> boolean().
search_resp_v(Req) ->
    kapi_definition:validate(Req, search_resp_definition()).

-spec publish_search_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_search_resp(Queue, Resp) ->
    publish_search_resp(Queue, Resp, ?DEFAULT_CONTENT_TYPE).

-spec publish_search_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_search_resp(Queue, Resp, ContentType) ->
    Definition = search_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Resp
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Discovery Request.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec discovery_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
discovery_req(Req) ->
    kapi_definition:build_message(Req, discovery_req_definition()).

-spec discovery_req_v(kz_term:api_terms()) -> boolean().
discovery_req_v(Req) ->
    kapi_definition:validate(Req, discovery_req_definition()).

-spec publish_discovery_req(kz_term:api_terms()) -> 'ok'.
publish_discovery_req(JObj) ->
    publish_discovery_req(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_discovery_req(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_discovery_req(Req, ContentType) ->
    Definition = discovery_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'discovery', 'undefined', [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Discovery Response.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec discovery_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
discovery_resp(Req) ->
    kapi_definition:build_message(Req, discovery_resp_definition()).

-spec discovery_resp_v(kz_term:api_terms()) -> boolean().
discovery_resp_v(Req) ->
    kapi_definition:validate(Req, discovery_resp_definition()).

-spec publish_discovery_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_discovery_resp(Q, JObj) ->
    publish_discovery_resp(Q, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_discovery_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_discovery_resp(Q, Req, ContentType) ->
    Definition = discovery_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Q, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Add Participant.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec add_participant(kz_term:api_terms()) -> kz_api:api_formatter_return().
add_participant(Req) ->
    kapi_definition:build_message(Req, add_participant_definition()).

-spec add_participant_v(kz_term:api_terms()) -> boolean().
add_participant_v(Req) ->
    kapi_definition:validate(Req, add_participant_definition()).

-spec publish_add_participant(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_add_participant(Zone, JObj) ->
    publish_add_participant(Zone, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_add_participant(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_add_participant(Zone, Req, ContentType) ->
    Definition = add_participant_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', Zone, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Deaf Participant.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec deaf_participant(kz_term:api_terms()) -> kz_api:api_formatter_return().
deaf_participant(Req) ->
    kapi_definition:build_message(Req, deaf_participant_definition()).

-spec deaf_participant_v(kz_term:api_terms()) -> boolean().
deaf_participant_v(Req) ->
    kapi_definition:validate(Req, deaf_participant_definition()).

-spec publish_deaf_participant(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_deaf_participant(ConferenceId, JObj) ->
    publish_deaf_participant(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_deaf_participant(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_deaf_participant(ConferenceId, Req, ContentType) ->
    Definition = deaf_participant_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Participant Energy.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec participant_energy(kz_term:api_terms()) -> kz_api:api_formatter_return().
participant_energy(Req) ->
    kapi_definition:build_message(Req, participant_energy_definition()).

-spec participant_energy_v(kz_term:api_terms()) -> boolean().
participant_energy_v(Req) ->
    kapi_definition:validate(Req, participant_energy_definition()).

-spec publish_participant_energy(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_participant_energy(ConferenceId, JObj) ->
    publish_participant_energy(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_participant_energy(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_participant_energy(ConferenceId, Req, ContentType) ->
    Definition = participant_energy_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Kick.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec kick(kz_term:api_terms()) -> kz_api:api_formatter_return().
kick(Req) ->
    kapi_definition:build_message(Req, kick_definition()).

-spec kick_v(kz_term:api_terms()) -> boolean().
kick_v(Req) ->
    kapi_definition:validate(Req, kick_definition()).

-spec publish_kick(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_kick(ConferenceId, JObj) ->
    publish_kick(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_kick(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_kick(ConferenceId, Req, ContentType) ->
    Definition = kick_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Participants Request.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec participants_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
participants_req(Req) ->
    kapi_definition:build_message(Req, participants_req_definition()).

-spec participants_req_v(kz_term:api_terms()) -> boolean().
participants_req_v(Req) ->
    kapi_definition:validate(Req, participants_req_definition()).

-spec publish_participants_req(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_participants_req(ConferenceId, JObj) ->
    publish_participants_req(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_participants_req(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_participants_req(ConferenceId, Req, ContentType) ->
    Definition = participants_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Participants Response.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec participants_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
participants_resp(Req) ->
    kapi_definition:build_message(Req, participants_resp_definition()).

-spec participants_resp_v(kz_term:api_terms()) -> boolean().
participants_resp_v(Req) ->
    kapi_definition:validate(Req, participants_resp_definition()).

-spec publish_participants_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_participants_resp(Queue, Resp) ->
    publish_participants_resp(Queue, Resp, ?DEFAULT_CONTENT_TYPE).

-spec publish_participants_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_participants_resp(Queue, Resp, ContentType) ->
    Definition = participants_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Resp
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Lock.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec lock(kz_term:api_terms()) -> kz_api:api_formatter_return().
lock(Req) ->
    kapi_definition:build_message(Req, lock_definition()).

-spec lock_v(kz_term:api_terms()) -> boolean().
lock_v(Req) ->
    kapi_definition:validate(Req, lock_definition()).

-spec publish_lock(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_lock(ConferenceId, JObj) ->
    publish_lock(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_lock(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_lock(ConferenceId, Req, ContentType) ->
    Definition = lock_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Mute.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec mute_participant(kz_term:api_terms()) -> kz_api:api_formatter_return().
mute_participant(Req) ->
    kapi_definition:build_message(Req, mute_participant_definition()).

-spec mute_participant_v(kz_term:api_terms()) -> boolean().
mute_participant_v(Req) ->
    kapi_definition:validate(Req, mute_participant_definition()).

-spec publish_mute_participant(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_mute_participant(ConferenceId, JObj) ->
    publish_mute_participant(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_mute_participant(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_mute_participant(ConferenceId, Req, ContentType) ->
    Definition = mute_participant_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Play.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec play(kz_term:api_terms()) -> kz_api:api_formatter_return().
play(Req) ->
    kapi_definition:build_message(Req, play_definition()).

-spec play_v(kz_term:api_terms()) -> boolean().
play_v(Req) ->
    kapi_definition:validate(Req, play_definition()).

-spec publish_play(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_play(ConferenceId, JObj) ->
    publish_play(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_play(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_play(ConferenceId, Req, ContentType) ->
    Definition = play_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Play Macro Request.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec play_macro_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
play_macro_req(Req) ->
    kapi_definition:build_message(Req, play_macro_req_definition()).

-spec play_macro_req_v(kz_term:api_terms()) -> boolean().
play_macro_req_v(Req) ->
    kapi_definition:validate(Req, play_macro_req_definition()).

%%------------------------------------------------------------------------------
%% @doc Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec record(kz_term:api_terms()) -> kz_api:api_formatter_return().
record(Req) ->
    kapi_definition:build_message(Req, record_definition()).

-spec record_v(kz_term:api_terms()) -> boolean().
record_v(Req) ->
    kapi_definition:validate(Req, record_definition()).

-spec publish_record(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_record(ConferenceId, JObj) ->
    publish_record(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_record(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_record(ConferenceId, Req, ContentType) ->
    Definition = record_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec recordstop(kz_term:api_terms()) -> kz_api:api_formatter_return().
recordstop(Req) ->
    kapi_definition:build_message(Req, recordstop_definition()).

-spec recordstop_v(kz_term:api_terms()) -> boolean().
recordstop_v(Req) ->
    kapi_definition:validate(Req, recordstop_definition()).

-spec publish_recordstop(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_recordstop(ConferenceId, JObj) ->
    publish_recordstop(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_recordstop(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_recordstop(ConferenceId, Req, ContentType) ->
    Definition = recordstop_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Relate Participants.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec relate_participants(kz_term:api_terms()) -> kz_api:api_formatter_return().
relate_participants(Req) ->
    kapi_definition:build_message(Req, relate_participants_definition()).

-spec relate_participants_v(kz_term:api_terms()) -> boolean().
relate_participants_v(Req) ->
    kapi_definition:validate(Req, relate_participants_definition()).

-spec publish_relate_participants(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_relate_participants(ConferenceId, JObj) ->
    publish_relate_participants(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_relate_participants(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_relate_participants(ConferenceId, Req, ContentType) ->
    Definition = relate_participants_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Set.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec set(kz_term:api_terms()) -> kz_api:api_formatter_return().
set(Req) ->
    kapi_definition:build_message(Req, set_definition()).

-spec set_v(kz_term:api_terms()) -> boolean().
set_v(Req) ->
    kapi_definition:validate(Req, set_definition()).

-spec publish_set(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_set(ConferenceId, JObj) ->
    publish_set(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_set(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_set(ConferenceId, Req, ContentType) ->
    Definition = set_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Stop Play.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec stop_play(kz_term:api_terms()) -> kz_api:api_formatter_return().
stop_play(Req) ->
    kapi_definition:build_message(Req, stop_play_definition()).

-spec stop_play_v(kz_term:api_terms()) -> boolean().
stop_play_v(Req) ->
    kapi_definition:validate(Req, stop_play_definition()).

-spec publish_stop_play(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_stop_play(ConferenceId, JObj) ->
    publish_stop_play(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_stop_play(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_stop_play(ConferenceId, Req, ContentType) ->
    Definition = stop_play_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Undeaf.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec undeaf_participant(kz_term:api_terms()) -> kz_api:api_formatter_return().
undeaf_participant(Req) ->
    kapi_definition:build_message(Req, undeaf_participant_definition()).

-spec undeaf_participant_v(kz_term:api_terms()) -> boolean().
undeaf_participant_v(Req) ->
    kapi_definition:validate(Req, undeaf_participant_definition()).

-spec publish_undeaf_participant(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_undeaf_participant(ConferenceId, JObj) ->
    publish_undeaf_participant(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_undeaf_participant(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_undeaf_participant(ConferenceId, Req, ContentType) ->
    Definition = undeaf_participant_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Unlock.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec unlock(kz_term:api_terms()) -> kz_api:api_formatter_return().
unlock(Req) ->
    kapi_definition:build_message(Req, unlock_definition()).

-spec unlock_v(kz_term:api_terms()) -> boolean().
unlock_v(Req) ->
    kapi_definition:validate(Req, unlock_definition()).

-spec publish_unlock(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_unlock(ConferenceId, JObj) ->
    publish_unlock(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_unlock(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_unlock(ConferenceId, Req, ContentType) ->
    Definition = unlock_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Unmute.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec unmute_participant(kz_term:api_terms()) -> kz_api:api_formatter_return().
unmute_participant(Req) ->
    kapi_definition:build_message(Req, unmute_participant_definition()).

-spec unmute_participant_v(kz_term:api_terms()) -> boolean().
unmute_participant_v(Req) ->
    kapi_definition:validate(Req, unmute_participant_definition()).

-spec publish_unmute_participant(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_unmute_participant(ConferenceId, JObj) ->
    publish_unmute_participant(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_unmute_participant(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_unmute_participant(ConferenceId, Req, ContentType) ->
    Definition = unmute_participant_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Set Volume In.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec participant_volume_in(kz_term:api_terms()) -> kz_api:api_formatter_return().
participant_volume_in(Req) ->
    kapi_definition:build_message(Req, participant_volume_in_definition()).

-spec participant_volume_in_v(kz_term:api_terms()) -> boolean().
participant_volume_in_v(Req) ->
    kapi_definition:validate(Req, participant_volume_in_definition()).

-spec publish_participant_volume_in(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_participant_volume_in(ConferenceId, JObj) ->
    publish_participant_volume_in(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_participant_volume_in(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_participant_volume_in(ConferenceId, Req, ContentType) ->
    Definition = participant_volume_in_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Set Volume Out.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec participant_volume_out(kz_term:api_terms()) -> kz_api:api_formatter_return().
participant_volume_out(Req) ->
    kapi_definition:build_message(Req, participant_volume_out_definition()).

-spec participant_volume_out_v(kz_term:api_terms()) -> boolean().
participant_volume_out_v(Req) ->
    kapi_definition:validate(Req, participant_volume_out_definition()).

-spec publish_participant_volume_out(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_participant_volume_out(ConferenceId, JObj) ->
    publish_participant_volume_out(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_participant_volume_out(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_participant_volume_out(ConferenceId, Req, ContentType) ->
    Definition = participant_volume_out_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Participants Event.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec participant_event(kz_term:api_terms()) -> kz_api:api_formatter_return().
participant_event(Req) ->
    kapi_definition:build_message(Req, participant_event_definition()).

-spec participant_event_v(kz_term:api_terms()) -> boolean().
participant_event_v(Req) ->
    kapi_definition:validate(Req, participant_event_definition()).

-spec publish_participant_event(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_participant_event(ConferenceId, CallId, JObj) ->
    publish_participant_event(ConferenceId, CallId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_participant_event(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_participant_event(ConferenceId, CallId, Event, ContentType) ->
    Definition = participant_event_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Event
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'event', ConferenceId, kz_amqp_util:encode(CallId), [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Event.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec event(kz_term:api_terms()) -> kz_api:api_formatter_return().
event(Req) ->
    kapi_definition:build_message(Req, event_definition()).

-spec event_v(kz_term:api_terms()) -> boolean().
event_v(Req) ->
    kapi_definition:validate(Req, event_definition()).

-spec publish_event(kz_term:api_terms()) -> 'ok'.
publish_event(API) ->
    publish_event(API, ?DEFAULT_CONTENT_TYPE).

-spec publish_event(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_event(API, ContentType) ->
    Definition = event_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(API
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload
                                   ,'event'
                                   ,(kapi_definition:binding(Definition))(API)
                                   ,[]
                                   ,ContentType
                                   ).

%%------------------------------------------------------------------------------
%% @doc Conference Error.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec conference_error(kz_term:api_terms()) -> kz_api:api_formatter_return().
conference_error(Req) ->
    kapi_definition:build_message(Req, conference_error_definition()).

-spec conference_error_v(kz_term:api_terms()) -> boolean().
conference_error_v(Req) ->
    kapi_definition:validate(Req, conference_error_definition()).

-spec publish_error(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_error(Queue, JObj) ->
    publish_error(Queue, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_error(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_error(Queue, Req, ContentType) ->
    Definition = conference_error_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Configuration Request.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec config_req(kz_term:api_terms()) -> kz_api:api_formatter_return().
config_req(Req) ->
    kapi_definition:build_message(Req, config_req_definition()).

-spec config_req_v(kz_term:api_terms()) -> boolean().
config_req_v(Req) ->
    kapi_definition:validate(Req, config_req_definition()).

-spec publish_config_req(kz_term:api_terms()) -> 'ok'.
publish_config_req(JObj) ->
    publish_config_req(JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_config_req(kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_config_req(Req, ContentType) ->
    Definition = config_req_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'config', profile(Req), [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Configuration Response.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec config_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
config_resp(Req) ->
    kapi_definition:build_message(Req, config_resp_definition()).

-spec config_resp_v(kz_term:api_terms()) -> boolean().
config_resp_v(Req) ->
    kapi_definition:validate(Req, config_resp_definition()).

-spec publish_config_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_config_resp(Queue, JObj) ->
    publish_config_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_config_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_config_resp(Queue, Req, ContentType) ->
    Definition = config_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Dial Request.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec dial(kz_term:api_terms()) -> kz_api:api_formatter_return().
dial(Req) ->
    kapi_definition:build_message(Req, dial_definition()).

-spec dial_v(kz_term:api_terms()) -> boolean().
dial_v(Req) ->
    kapi_definition:validate(Req, dial_definition()).

-spec publish_dial(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_dial(Zone, JObj) ->
    publish_dial(Zone, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_dial(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_dial(Zone, Req, ContentType) ->
    Definition = dial_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', Zone, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Dial Response.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec dial_resp(kz_term:api_terms()) -> kz_api:api_formatter_return().
dial_resp(Req) ->
    kapi_definition:build_message(Req, dial_resp_definition()).

-spec dial_resp_v(kz_term:api_terms()) -> boolean().
dial_resp_v(Req) ->
    kapi_definition:validate(Req, dial_resp_definition()).

-spec publish_dial_resp(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_dial_resp(Queue, JObj) ->
    publish_dial_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_dial_resp(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_dial_resp(Queue, Req, ContentType) ->
    Definition = dial_resp_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:targeted_publish(Queue, Payload, ContentType).

%%------------------------------------------------------------------------------
%% @doc Conference Vars.
%% Takes {@link kz_term:proplist()}, creates JSON string or error.
%% @end
%%------------------------------------------------------------------------------
-spec vars(kz_term:api_terms()) -> kz_api:api_formatter_return().
vars(Req) ->
    kapi_definition:build_message(Req, vars_definition()).

-spec vars_v(kz_term:api_terms()) -> boolean().
vars_v(Req) ->
    kapi_definition:validate(Req, vars_definition()).

-spec publish_vars(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_vars(ConferenceId, JObj) ->
    publish_vars(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_vars(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_vars(ConferenceId, Req, ContentType) ->
    Definition = vars_definition(),
    {'ok', Payload} = kz_api:prepare_api_payload(Req
                                                ,kapi_definition:values(Definition)
                                                ,kapi_definition:build_fun(Definition)
                                                ),
    kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType).

%%------------------------------------------------------------------------------
%% @doc Bind a queue to the conference exchange.
%% @end
%%------------------------------------------------------------------------------
-spec bind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
bind_q(Queue, Props) ->
    bind_to_q(Queue, props:get_value('restrict_to', Props), Props).

bind_to_q(Q, 'undefined', _) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'discovery'),
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'command'),
    kz_amqp_util:bind_q_to_conference(Q, 'event');
bind_to_q(Q, ['discovery'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'discovery'),
    bind_to_q(Q, T, Props);
bind_to_q(Q, ['command'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'command'),
    bind_to_q(Q, T, Props);
bind_to_q(Q, ['event'|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'event', <<"#">>),
    bind_to_q(Q, T, Props);
bind_to_q(Q, ['config'|T], Props) ->
    Profile = props:get_value('profile', Props, <<"*">>),
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'config', Profile),
    bind_to_q(Q, T, Props);
bind_to_q(Q, [{'config', Profile}|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'config', Profile),
    bind_to_q(Q, T, Props);
bind_to_q(Q, [{'event', {_ConfId, _CallId}=Key}|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'event', event_binding_key(Key)),
    bind_to_q(Q, T, Props);
bind_to_q(Q, [{'event', ConfIdOrProps}|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'event', event_binding_key(ConfIdOrProps)),
    bind_to_q(Q, T, Props);
bind_to_q(Q, [{'command', ConfId}|T], Props) ->
    'ok' = kz_amqp_util:bind_q_to_conference(Q, 'command', ConfId),
    bind_to_q(Q, T, Props);
bind_to_q(_Q, [], _) ->
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Unbind a queue from the conference exchange.
%% @end
%%------------------------------------------------------------------------------
-spec unbind_q(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
unbind_q(Queue, Props) ->
    unbind_from_q(Queue, props:get_value('restrict_to', Props), Props).

unbind_from_q(Q, 'undefined', _) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'discovery'),
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'command'),
    kz_amqp_util:unbind_q_from_conference(Q, 'event');
unbind_from_q(Q, ['discovery'|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'discovery'),
    unbind_from_q(Q, T, Props);
unbind_from_q(Q, ['command'|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'command'),
    unbind_from_q(Q, T, Props);
unbind_from_q(Q, ['event'|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'event', <<"#">>),
    unbind_from_q(Q, T, Props);
unbind_from_q(Q, ['config'|T], Props) ->
    Profile = props:get_value('profile', Props, <<"*">>),
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'config', Profile),
    unbind_from_q(Q, T, Props);
unbind_from_q(Q, [{'config', Profile}|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'config', Profile),
    unbind_from_q(Q, T, Props);
unbind_from_q(Q, [{'event', {_ConfId, _CallId}=Key}|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'event', event_binding_key(Key)),
    unbind_from_q(Q, T, Props);
unbind_from_q(Q, [{'event', ConfIdOrProps}|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'event', event_binding_key(ConfIdOrProps)),
    unbind_from_q(Q, T, Props);
unbind_from_q(Q, [{'command', ConfId}|T], Props) ->
    'ok' = kz_amqp_util:unbind_q_from_conference(Q, 'command', ConfId),
    unbind_from_q(Q, T, Props);
unbind_from_q(_Q, [], _) -> 'ok'.

%%------------------------------------------------------------------------------
%% @doc Declare the exchanges used by this API.
%% @end
%%------------------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    kz_amqp_util:conference_exchange().

event_binding_key(ConferenceId)
  when is_binary(ConferenceId) ->
    conference_event_key(<<"*">>, <<"*">>, ConferenceId, <<"*">>);
event_binding_key({ConferenceId, CallId}) ->
    conference_event_key(<<"*">>, <<"*">>, ConferenceId, CallId);
event_binding_key(Props) ->
    Event = props:get_value('event', Props, <<"*">>),
    AccountId = props:get_value('account_id', Props, <<"*">>),
    ConferenceId = props:get_value('conference_id', Props, <<"*">>),
    CallId = props:get_value('call_id', Props, <<"*">>),
    conference_event_key(Event, AccountId, ConferenceId, CallId).

event_key(API)
  when is_list(API) ->
    event_key(kz_json:from_list(API));
event_key(API) ->
    Event = kz_json:get_ne_binary_value(<<"Event">>, API),
    AccountId = kz_json:get_first_defined([<<"Account-ID">>
                                          ,[<<"Custom-Channel-Vars">>, <<"Account-ID">>]
                                          ]
                                         ,API
                                         ),
    ConferenceId = kz_json:get_value(<<"Conference-ID">>, API),
    CallId = kz_json:get_value(<<"Call-ID">>, API, ConferenceId),
    conference_event_key(Event, AccountId, ConferenceId, CallId).

-spec conference_event_key(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binary().
conference_event_key(Event, AccountId, ConferenceId, <<CallId/binary>>) ->
    list_to_binary([Event, "."
                   ,AccountId, "."
                   ,ConferenceId, "."
                   ,kz_amqp_util:encode(CallId)
                   ]).

%%------------------------------------------------------------------------------
%% @doc Publish to the conference exchange.
%% @end
%%------------------------------------------------------------------------------

-spec publish_command(kz_term:ne_binary(), kz_term:api_terms()) -> 'ok'.
publish_command(ConferenceId, JObj) ->
    publish_command(ConferenceId, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_command(kz_term:ne_binary(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_command(ConferenceId, Req, ContentType) ->
    App = props:get_value(<<"Application-Name">>, Req),
    case lists:keyfind(App, 1, ?APPLICATION_MAP) of
        'false' -> throw({'invalid_conference_command', Req});
        {_, Values, Fun} ->
            {'ok', Payload} = kz_api:prepare_api_payload(Req, Values, Fun),
            kz_amqp_util:conference_publish(Payload, 'command', ConferenceId, [], ContentType)
    end.

%%------------------------------------------------------------------------------
%% @doc Publish to the conference exchange.
%% @end
%%------------------------------------------------------------------------------

-spec publish_targeted_command(atom(), kz_term:api_terms()) -> 'ok'.
publish_targeted_command(Focus, JObj) ->
    publish_targeted_command(Focus, JObj, ?DEFAULT_CONTENT_TYPE).

-spec publish_targeted_command(atom(), kz_term:api_terms(), kz_term:ne_binary()) -> 'ok'.
publish_targeted_command(Focus, Req, ContentType) ->
    App = props:get_value(<<"Application-Name">>, Req),
    case lists:keyfind(App, 1, ?APPLICATION_MAP) of
        'false' -> throw({'invalid_conference_command', Req});
        {_, Values, Fun} ->
            {'ok', Payload} = kz_api:prepare_api_payload(Req, Values, Fun),
            Queue = focus_queue_name(Focus),
            kz_amqp_util:targeted_publish(Queue, Payload, ContentType)
    end.

profile(Props) when is_list(Props) -> props:get_value(<<"Profile">>, Props);
profile(JObj) -> kz_json:get_value(<<"Profile">>, JObj).

-spec appmap_tuple(kz_term:ne_binary(), kapi_definition:api()) ->
          {kz_term:ne_binary(), kz_api:api_valid_values(), kapi_definition:build_fun()}.
appmap_tuple(App, Definition) ->
    {App, kapi_definition:values(Definition), kapi_definition:build_fun(Definition)}.
