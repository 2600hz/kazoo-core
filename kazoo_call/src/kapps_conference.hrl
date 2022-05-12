-ifndef(KAPPS_CONFERENCE_HRL).

-define(CONFERENCE_CONFIG_CAT, <<"conferences">>).

-define(DEFAULT_PROFILE_NAME, <<"default">>).
-define(PAGE_PROFILE_NAME, <<"page">>).
-define(VIDEO_PROFILE_NAME, <<"video">>).

-define(DEFAULT_CONTROLS_NAME, <<"default">>).
-define(VIDEO_CONTROLS_NAME, <<"video">>).
-define(PAGE_CONTROLS_NAME, <<"paging">>).

-define(DEFAULT_ENTRY_TONE, <<"tone_stream://v=-7;>=2;+=.1;%(300,0,523,659);v=-7;>=3;+=.1;%(800,0,659,783)">>).
-define(ENTRY_TONE(AccountId), kapps_account_config:get_global(AccountId, ?CONFERENCE_CONFIG_CAT, <<"entry_tone">>, ?DEFAULT_ENTRY_TONE)).
-define(MOD_ENTRY_TONE(AccountId), kapps_account_config:get_global(AccountId, ?CONFERENCE_CONFIG_CAT, <<"moderator_entry_tone">>, ?DEFAULT_ENTRY_TONE)).

-define(DEFAULT_EXIT_TONE, <<"tone_stream://v=-7;>=2;+=.1;%(300,0,523,440);v=-7;>=3;+=.1;%(800,0,349,440)">>).
-define(EXIT_TONE(AccountId), kapps_account_config:get_global(AccountId, ?CONFERENCE_CONFIG_CAT, <<"exit_tone">>, ?DEFAULT_EXIT_TONE)).
-define(MOD_EXIT_TONE(AccountId), kapps_account_config:get_global(AccountId, ?CONFERENCE_CONFIG_CAT, <<"moderator_exit_tone">>, ?DEFAULT_EXIT_TONE)).

-define(SUPPORT_NAME_ANNOUNCEMENT(AccountId), kz_term:is_true(kapps_account_config:get_global(AccountId, ?CONFERENCE_CONFIG_CAT, <<"support_name_announcement">>, 'true'))).

-define(DEFAULT_PROFILE_CONFIG, [{<<"alone-sound">>, <<"conf-alone">>}
                                ,{<<"caller-controls">>, <<"default">>}
                                ,{<<"channels">>, 2}
                                ,{<<"comfort-noise">>, 1000}
                                ,{<<"deaf-sound">>, <<"conf-deaf">>}
                                ,{<<"energy-level">>, 20}
                                ,{<<"enter-sound">>, ?DEFAULT_ENTRY_TONE}
                                ,{<<"exit-sound">>, ?DEFAULT_EXIT_TONE}
                                ,{<<"interval">>, 20}
                                ,{<<"locked-sound">>, <<"conf-max_participants">>}
                                ,{<<"max-members-sound">>, <<"conf-max_participants">>}
                                ,{<<"member-enter-sound">>, <<"conf-joining_conference">>}
                                ,{<<"moderator-controls">>, <<"default">>}
                                ,{<<"moh-sound">>, <<"$${hold_music}">>}
                                ,{<<"muted-sound">>, <<"conf-muted">>}
                                ,{<<"rate">>, 48000}
                                ,{<<"undeaf-sound">>, <<"conf-undeaf">>}
                                ,{<<"unmuted-sound">>, <<"conf-unmuted">>}
                                ,{<<"conference-flags">>, <<"rfc-4579|livearray-sync|livearray-json-status|json-events">>}
                                ]).

-define(PAGE_PROFILE_CONFIG, [{<<"caller-controls">>, <<"paging">>}
                             ,{<<"comfort-noise">>, 1000}
                             ,{<<"energy-level">>, 20}
                             ,{<<"enter-sound">>, <<"silence_stream://1">>}
                             ,{<<"exit-sound">>, <<"silence_stream://1">>}
                             ,{<<"interval">>, 20}
                             ,{<<"moh-sound">>, <<"silence_stream://1">>}
                             ,{<<"rate">>, 8000}
                             ]).

-define(VIDEO_PROFILE_CONFIG, [{<<"alone-sound">>, <<"conf-alone">>}
                              ,{<<"channels">>, 2}
                              ,{<<"comfort-noise">>, 1000}
                              ,{<<"deaf-sound">>, <<"conf-deaf">>}
                              ,{<<"energy-level">>, 200}
                              ,{<<"enter-sound">>, ?DEFAULT_ENTRY_TONE}
                              ,{<<"exit-sound">>, ?DEFAULT_EXIT_TONE}
                              ,{<<"interval">>, 10}
                              ,{<<"locked-sound">>, <<"conf-max_participants">>}
                              ,{<<"max-members-sound">>, <<"conf-max_participants">>}
                              ,{<<"member-enter-sound">>, <<"conf-joining_conference">>}
                              ,{<<"moh-sound">>, <<"$${hold_music}">>}
                              ,{<<"muted-sound">>, <<"conf-muted">>}
                              ,{<<"rate">>, 16000}
                              ,{<<"undeaf-sound">>, <<"conf-undeaf">>}
                              ,{<<"unmuted-sound">>, <<"conf-unmuted">>}

                              ,{<<"caller-controls">>, <<"video">>}
                              ,{<<"moderator-controls">>, <<"video">>}

                              ,{<<"video-super-canvas-bgcolor">>, <<"#333">>}
                              ,{<<"video-mode">>, <<"mux">>}

                              ,{<<"video-fps">>, 15}
                              ,{<<"video-codec-bandwidth">>, <<"1mb">>}
                              ,{<<"video-canvas-size">>, <<"1280x720">>}

                              ,{<<"video-layout-bgcolor">>, <<"#333">>}
                              ,{<<"video-canvas-bgcolor">>, <<"#333">>}
                              ,{<<"video-border-color">>, <<"#333">>}
                              ,{<<"video-auto-floor-msec">>, 1500}
                              ,{<<"conference-flags">>, <<"livearray-json-status|json-events|video-floor-only|rfc-4579|livearray-sync|minimize-video-encoding|video-required-for-canvas|video-mute-exit-canvas|mute-detect">>}
                              ]).

-define(DEFAULT_CONTROLS, [kz_json:from_list([{<<"action">>, <<"mute">>},     {<<"digits">>, <<"*1">>}])
                          ,kz_json:from_list([{<<"action">>, <<"mute on">>},  {<<"digits">>, <<"*2">>}])
                          ,kz_json:from_list([{<<"action">>, <<"mute off">>}, {<<"digits">>, <<"*3">>}])
                          ,kz_json:from_list([{<<"action">>, <<"deaf">>},     {<<"digits">>, <<"*4">>}])
                          ,kz_json:from_list([{<<"action">>, <<"deaf on">>},  {<<"digits">>, <<"*5">>}])
                          ,kz_json:from_list([{<<"action">>, <<"deaf off">>}, {<<"digits">>, <<"*6">>}])
                          ,kz_json:from_list([{<<"action">>, <<"hangup">>},   {<<"digits">>, <<"#">>}])
                          ]).

-define(VIDEO_CONTROLS, [kz_json:from_list([{<<"action">>, <<"mute">>},     {<<"digits">>, <<"0">>}])
                        ,kz_json:from_list([{<<"action">>, <<"vmute">>},    {<<"digits">>, <<"*0">>}])
                        ,kz_json:from_list([{<<"action">>, <<"mute">>},     {<<"digits">>, <<"*1">>}])
                        ,kz_json:from_list([{<<"action">>, <<"mute on">>},  {<<"digits">>, <<"*2">>}])
                        ,kz_json:from_list([{<<"action">>, <<"mute off">>}, {<<"digits">>, <<"*3">>}])
                        ,kz_json:from_list([{<<"action">>, <<"deaf">>},     {<<"digits">>, <<"*4">>}])
                        ,kz_json:from_list([{<<"action">>, <<"deaf on">>},  {<<"digits">>, <<"*5">>}])
                        ,kz_json:from_list([{<<"action">>, <<"deaf off">>}, {<<"digits">>, <<"*6">>}])
                        ,kz_json:from_list([{<<"action">>, <<"hangup">>},   {<<"digits">>, <<"#">>}])
                        ]).

-define(DEFAULT_ADVERTISE_CONFIG, 'undefined').
-define(PAGE_ADVERTISE_CONFIG, 'undefined').
-define(ADVERTISE(ConfigName, Default)
       ,kapps_config:get_json(?CONFIG_CAT, [<<"advertise">>, ConfigName], Default)
       ).
-define(ADVERTISE(ConfigName), ?ADVERTISE(ConfigName, 'undefined')).

-define(DEFAULT_CHAT_CONFIG, 'undefined').
-define(PAGE_CHAT_CONFIG, 'undefined').
-define(CHAT_PERMISSIONS(ConfigName, Default)
       ,kapps_config:get_json(?CONFIG_CAT, [<<"chat-permissions">>, ConfigName], Default)
       ).
-define(CHAT_PERMISSIONS(ConfigName), ?CHAT_PERMISSIONS(ConfigName, 'undefined')).

-define(KAPPS_CONFERENCE_HRL, 'true').
-endif.
