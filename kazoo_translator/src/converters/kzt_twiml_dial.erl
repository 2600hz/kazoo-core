%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2024, 2600Hz
%%% @doc Handle the emulation of the Dial verb
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzt_twiml_dial).

-export([exec/3]).

-ifdef(TEST).
-export([cleanup_dial_me/1]).
-endif.

-include("kzt.hrl").

-define(DEFAULT_TIMEOUT_S, 30).
-define(MINIMUM_TIMEOUT_S, 0). %% note: min is 5s, but we add buffer so we get our 5s min back
-define(TIMEOUT_BUFFER_S, 5).
-define(MAXIMUM_TINEOUT_S, 600).

-define(DEFAULT_TIME_LIMIT_S, 4 * ?SECONDS_IN_HOUR).
-define(MAXIMUM_TIME_LIMIT_S, 4 * ?SECONDS_IN_HOUR).

-define(MAX_DIAL_NOUNS, 10).

-spec exec(kapps_call:call(), kz_types:xml_els() | kz_types:xml_texts(), kz_types:xml_attribs()) ->
          {'ok' | 'stop', kapps_call:call()}.
exec(Call, [#xmlComment{}|Rest], Attrs) ->
    exec(Call, Rest, Attrs);
exec(Call, [#xmlText{type='text'}|_]=DialMeTxts, Attrs) ->
    case cleanup_dial_me(kz_xml:texts_to_binary(DialMeTxts)) of
        <<>> ->
            lager:debug("no dial-able plain text, continuing to next verb..."),
            {'ok', Call};
        DialMe ->
            Props = kz_xml:attributes_to_proplist(Attrs),
            simple_dial(Call, Props, normalize_number(DialMe, Call))
    end;
exec(Call
    ,[#xmlElement{name='Number'
                 ,content=Number
                 ,attributes=NumberAttrs
                 }=_El
     ]
    ,DialAttrs) ->
    case cleanup_dial_me(kz_xml:texts_to_binary(Number)) of
        <<>> ->
            lager:debug("no dial-able Number in tag, continuing to next verb"),
            {'ok', Call};
        NumberText ->
            DialProps = kz_xml:attributes_to_proplist(DialAttrs),
            NumberProps = kz_xml:attributes_to_proplist(NumberAttrs),
            number_dial(Call, DialProps, NumberProps, normalize_number(NumberText, Call))
    end;
exec(Call, [#xmlElement{name='Conference'
                       ,content=ConfIdTxts
                       ,attributes=ConfAttrs
                       }], DialAttrs) ->
    kapps_call_command:answer(Call),

    ConfId = conference_id(ConfIdTxts),

    ConfProps = kz_xml:attributes_to_proplist(ConfAttrs),
    DialProps = kz_xml:attributes_to_proplist(DialAttrs),

    gen_listener:add_binding(kzt_util:get_amqp_listener(Call)
                            ,'conference'
                            ,[{'restrict_to'
                              ,[{'event', {ConfId, kapps_call:call_id_direct(Call)}}]
                              }
                             ]),

    ConfDoc = build_conference_doc(Call, ConfId, ConfProps),

    ConfReq = [{<<"Call">>, kapps_call:to_json(Call)}
              ,{<<"Conference-ID">>, ConfId}
              ,{<<"Conference-Doc">>, ConfDoc}
              ,{<<"Conference-Name">>, kzd_conferences:name(ConfDoc)}
              ,{<<"Moderator">>, props:get_is_true('startConferenceOnEnter', ConfProps, 'true')}
              | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
              ],
    kapi_conference:publish_discovery_req(ConfReq),

    lager:debug("published conference request"),

    %% Will need to support fetching media OR TwiML
    _WaitUrl = props:get_value('waitUrl', ConfProps),
    _WaitMethod = kzt_util:http_method(ConfProps),

    CallWithConf = add_conference_profile(Call, ConfProps),
    SetupCall = setup_call_for_dial(CallWithConf, DialProps),

    {'ok', Call1} = kzt_receiver:wait_for_conference(SetupCall),

    maybe_end_dial(Call1, DialProps);

exec(Call, [#xmlElement{name='Queue'
                       ,content=QueueIdTxts
                       ,attributes=QueueAttrs
                       }], DialAttrs) ->
    DialProps = kz_xml:attributes_to_proplist(DialAttrs),

    QueueId = kz_xml:texts_to_binary(QueueIdTxts),
    QueueProps = kz_xml:attributes_to_proplist(QueueAttrs),

    %% Fetch TwiML to play to caller before connecting agent
    _Url = props:get_value('url', QueueProps),
    _Method = kzt_util:http_method(QueueProps),

    Call1 = setup_call_for_dial(kzt_util:set_queue_sid(QueueId, Call)
                               ,DialProps
                               ),

    lager:info("dialing into queue ~s, unsupported", [QueueId]),
    {'stop', kzt_util:add_error(Call1, <<"not_implemented">>, <<"Queue is not implemented">>)};

exec(Call, [#xmlElement{}|_]=Endpoints, Attrs) ->
    lager:debug("collecting endpoints inside Dial"),

    Props = kz_xml:attributes_to_proplist(Attrs),
    Call1 = setup_call_for_dial(Call, Props),

    case collecting_endpoints(Call1, Endpoints) of
        [] ->
            lager:debug("no endpoints were found to dial, continuing"),
            {'ok', Call};
        EPs ->
            lager:debug("~b endpoint(s) created, sending bridge command", [length(EPs)]),
            Timeout = dial_timeout(Props),
            IgnoreEarlyMedia = kz_endpoints:ignore_early_media(EPs),
            Strategy = dial_strategy(Props),

            send_bridge_command(EPs, Timeout, Strategy, IgnoreEarlyMedia, Call1),

            {'ok', Call2} = kzt_receiver:wait_for_offnet(Call1, Props),
            maybe_end_dial(Call2, Props)
    end;
exec(Call, [Elm|Rest], Attrs) ->
    lager:debug("unhandled XML object: ~p", [Elm]),
    exec(Call, Rest, Attrs).

-spec simple_dial(kapps_call:call(), kz_term:proplist(), kz_term:ne_binary()) ->
          {'ok' | 'stop' | 'request', kapps_call:call()}.
simple_dial(Call, Props, DialMe) ->
    lager:debug("dial text DID '~s'", [DialMe]),

    Call1 = setup_call_for_dial(kapps_call:set_request(request_id(DialMe, Call), Call)
                               ,Props
                               ),

    OffnetProps = [{<<"Force-Outbound">>, force_outbound(Props)}
                  ],
    'ok' = kzt_util:offnet_req(Props, OffnetProps, Call1),

    {'ok', Call2} = kzt_receiver:wait_for_offnet(Call1, Props),
    maybe_end_dial(Call2, Props).

-spec number_dial(kapps_call:call(), kz_term:proplist(), kz_term:proplist(), kz_term:ne_binary()) ->
          {'ok' | 'stop' | 'request', kapps_call:call()}.
number_dial(Call, DialProps, _NumberProps, DialMe) ->
    %% TODO: impelement these
    %% SendDigits = props:get_value('sendDigits', NumberProps),
    %% _Url = props:get_value('url', NumberProps),
    %% _Method = props:get_value('method', NumberProps),

    lager:info("not implemented: maybe sending number ~s", [DialMe]),

    simple_dial(Call, DialProps, DialMe).

send_bridge_command(EPs, Timeout, Strategy, IgnoreEarlyMedia, Call) ->
    Command = [{<<"Application-Name">>, <<"bridge">>}
              ,{<<"Endpoints">>, EPs}
              ,{<<"Loopback-Bowout">>, <<"false">>}
              ,{<<"Timeout">>, Timeout}
              ,{<<"Ignore-Early-Media">>, IgnoreEarlyMedia}
              ,{<<"Dial-Endpoint-Method">>, Strategy}
              ,{<<"Fail-On-Single-Reject">>, <<"false">>}
              ,{<<"Dial-Endpoint-Method">>, <<"simultaneous">>}
              ,{<<"Ignore-Forward">>, <<"false">>}
              | kz_api:default_headers(kapps_call:controller_queue(Call), ?APP_NAME, ?APP_VERSION)
              ],
    kapps_call_command:send_command(Command, Call).

-spec setup_call_for_dial(kapps_call:call(), kz_term:proplist()) -> kapps_call:call().
setup_call_for_dial(Call, Props) ->
    Setters = [{fun kapps_call:set_caller_id_number/2, caller_id(Props, Call)}
              ,{fun kzt_util:set_hangup_dtmf/2, hangup_dtmf(Props)}
              ,{fun kzt_util:set_record_call/2, should_record_call(Props)}
              ,{fun kzt_util:set_recording_stereo/2, should_recording_stereo(Props)}
              ,{fun kzt_util:set_call_timeout/2, dial_timeout(Props)}
              ,{fun kzt_util:set_call_time_limit/2, timelimit_s(Props)}
              ],
    kapps_call:exec(Setters, Call).

-spec maybe_end_dial(kapps_call:call(), kz_term:proplist()) ->
          {'ok' | 'stop' | 'request', kapps_call:call()}.
maybe_end_dial(Call, Props) ->
    IsHungup = kzt_util:get_is_caller_hungup(Call),
    lager:debug("a-leg status after bridge: ~s is caller hungup: ~p", [kzt_util:get_call_status(Call), IsHungup]),
    maybe_end_dial(Call, Props, kzt_twiml_util:action_url(Props), IsHungup).

-spec maybe_end_dial(kapps_call:call(), kz_term:proplist(), kz_term:api_ne_binary(), boolean()) ->
          {'ok' | 'stop' | 'request', kapps_call:call()}.
maybe_end_dial(Call, _Props, _ActionUrl, 'true') ->
    lager:debug("caller leg is ended with ~s, not continuing twiml render"
               ,[kzt_util:get_call_status(Call)]
               ),
    {'stop', Call};
maybe_end_dial(Call, _Props, 'undefined', 'false') ->
    %% will progress to next TwiML element if any
    {'ok', Call};
maybe_end_dial(Call, Props, ActionUrl, 'false') ->
    CurrentUri = kzt_util:get_voice_uri(Call),
    NewUri = kzt_util:resolve_uri(CurrentUri, ActionUrl),
    lager:debug("sending req to ~s: ~s", [ActionUrl, NewUri]),
    Method = kzt_util:http_method(Props),

    Setters = [{fun kzt_util:set_voice_uri_method/2, Method}
              ,{fun kzt_util:set_voice_uri/2, NewUri}
              ],
    {'request', kapps_call:exec(Setters, Call)}.

-spec cleanup_dial_me(binary()) -> binary().
cleanup_dial_me(<<"+", Txt/binary>>) ->
    <<"+", (kz_binary:remove_non_numeric(Txt))/binary>>;
cleanup_dial_me(Txt) ->
    kz_binary:remove_non_numeric(Txt).

%% To maintain compatibility with Twilo, we force the call offnet (otherwise
%% the redirect onnet steals our callid, and callflow/trunkstore/other could
%% potentially hangup our A-leg. If the B-leg is forced offnet, we can still
%% capture the failed B-leg and continue processing the TwiML (if any).
force_outbound(Props) -> props:get_is_true('continueOnFail', Props, 'true').

-spec collecting_endpoints(kapps_call:call(), kz_types:xml_els()) ->
          kz_json:objects().
collecting_endpoints(Call, EPs) ->
    collecting_endpoints(Call, EPs, []).

-spec collecting_endpoints(kapps_call:call(), kz_types:xml_els(), kz_json:objects()) ->
          kz_json:objects().
collecting_endpoints(_, [], Acc) ->
    EPs = lists:reverse(Acc),
    try lists:split(?MAX_DIAL_NOUNS, EPs) of
        {LimitedEPs, _} -> LimitedEPs
    catch
        'error':'badarg' -> EPs
    end;
collecting_endpoints(Call, [#xmlElement{name='Device'} = EP | EPs], Acc) ->
    #xmlElement{content=DeviceIdTxt} = EP,

    DeviceId = kz_xml:texts_to_binary(DeviceIdTxt),
    lager:debug("adding device ~s to ring group", [DeviceId]),
    case kz_endpoint:build(DeviceId, Call) of
        {'ok', DeviceEPs} ->
            collecting_endpoints(Call, EPs, lists:reverse(DeviceEPs) ++ Acc);
        {'error', _E} ->
            lager:debug("failed to add device ~s: ~p", [DeviceId, _E]),
            collecting_endpoints(Call, EPs, Acc)
    end;
collecting_endpoints(Call, [#xmlElement{name='User'} = EP | EPs], Acc) ->
    #xmlElement{content=UserIdTxt} = EP,

    UserId = kz_xml:texts_to_binary(UserIdTxt),
    lager:debug("adding user ~s to ring group", [UserId]),

    case get_endpoints(UserId, kz_json:new(), Call) of
        [] ->
            lager:debug("no user endpoints built for ~s, skipping", [UserId]),
            collecting_endpoints(Call, EPs, Acc);
        UserEPs ->
            collecting_endpoints(Call, EPs, lists:reverse(UserEPs) ++ Acc)
    end;
collecting_endpoints(Call, [#xmlElement{name='Number'} = EP | EPs], Acc) ->
    #xmlElement{content=Number, attributes=_Attrs} = EP,

    %% Props = kz_xml:attributes_to_proplist(Attrs),

    %% TODO: impelement these
    %% SendDigits = props:get_value('sendDigits', Props),
    %% _Url = props:get_value('url', Props),
    %% _Method = props:get_value('method', Props),

    DialMe = normalize_number(kz_xml:texts_to_binary(Number), Call),
    case kz_term:is_empty(DialMe) of
        'true' ->
            collecting_endpoints(Call, EPs, Acc);
        'false' ->
            lager:debug("adding Number with DID ~s", [DialMe]),
            FwdEP = create_fwd_endpoint(DialMe, Call),
            collecting_endpoints(Call, EPs, [FwdEP|Acc])
    end;
collecting_endpoints(Call,[#xmlElement{name='Sip'} = EP | EPs], Acc) ->
    #xmlElement{content=Number, attributes=Attrs} = EP,

    lager:debug("adding Sip with uri ~s", [Number]),

    _Props = kz_xml:attributes_to_proplist(Attrs),

    try kzsip_uri:parse(kz_xml:texts_to_binary(Number)) of
        URI ->
            collecting_endpoints(Call, EPs, [sip_uri(Call, URI)|Acc])
    catch
        'throw':_E ->
            lager:debug("failed to parse SIP uri: ~p", [_E]),
            collecting_endpoints(Call, EPs, Acc)
    end;

collecting_endpoints(Call, [_Xml|EPs], Acc) ->
    lager:debug("unknown endpoint, skipping: ~p", [_Xml]),
    collecting_endpoints(Call, EPs, Acc).

-spec create_fwd_endpoint(kz_term:ne_binary(), kapps_call:call()) -> kz_json:object().
create_fwd_endpoint(Number, Call) ->
    CallFwd = kz_json:from_list([{<<"enabled">>, 'true'}
                                ,{<<"number">>, Number}
                                ,{<<"require_keypress">>, 'false'}
                                ,{<<"substitute">>, 'true'}
                                ]),
    Unconditional = kzd_call_forward:set_unconditional(CallFwd, CallFwd),
    Endpoint0 = get_caller_endpoint(Call),
    Endpoint = kzd_endpoint:set_call_forward(Endpoint0, Unconditional),
    kz_endpoint:create_call_fwd_endpoint(Endpoint, kz_json:new(), Call).

-spec sip_uri(kapps_call:call(), kzsip_uri:sip_uri()) -> kz_json:object().
sip_uri(Call, URI) ->
    lager:debug("maybe adding SIP endpoint: ~s", [kzsip_uri:encode(URI)]),
    SIPDevice = sip_device(URI),
    kz_endpoint:create_sip_endpoint(SIPDevice, kz_json:new(), Call).

-spec sip_device(kzsip_uri:sip_uri()) -> kzd_devices:doc().
sip_device(URI) ->
    lists:foldl(fun({F, V}, D) -> F(D, V) end
               ,kzd_devices:new()
               ,[{fun kzd_devices:set_sip_invite_format/2, <<"route">>}
                ,{fun kzd_devices:set_sip_route/2, kzsip_uri:encode(URI)}
                ]).

request_id(N, Call) -> iolist_to_binary([N, <<"@">>, kapps_call:from_realm(Call)]).

get_max_participants(Props) when is_list(Props) ->
    get_max_participants(props:get_integer_value('maxParticipants', Props, 40));
get_max_participants(N) when is_integer(N), N =< 40, N > 2 -> N.

dial_strategy(Props) ->
    case props:get_value('strategy', Props) of
        <<"single">> -> <<"single">>;
        _ -> <<"simultaneous">>
    end.

-spec caller_id(kz_term:proplist(), kapps_call:call()) -> kz_term:ne_binary().
caller_id(Props, Call) ->
    kz_term:to_binary(
      props:get_value('callerId', Props, kapps_call:caller_id_number(Call))
     ).

-spec hangup_dtmf(kz_term:proplist() | kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
hangup_dtmf('undefined') ->
    'undefined';
hangup_dtmf(Props) when is_list(Props) ->
    case props:is_true('hangupOnStar', Props) of
        'true' -> <<"*">>;
        _ -> hangup_dtmf(props:get_ne_binary_value('hangupOn', Props))
    end;
hangup_dtmf(<<DTMF/binary>>) ->
    case lists:member(DTMF, ?ANY_DIGIT) of
        'true' ->
            DTMF;
        'false' ->
            lager:debug("unsupported digit ~s for hangupOn", [DTMF]),
            'undefined'
    end.

-spec should_record_call(kz_term:proplist()) -> boolean().
should_record_call(Props) ->
    %% new possible values:
    %% - do-not-record
    %% - record-from-answer
    %% - record-from-ringing
    %% - record-from-answer-dual
    %% - record-from-ringing-dual
    %% Backward compatibility: true is an alias for record-from-answer
    %%                         false is an alias for do-not-record
    case props:get_ne_binary_value('record', Props) of
        <<"true">> -> 'true';
        <<"record-from", _/binary>> -> 'true';
        _ -> 'false'
    end.

-spec should_recording_stereo(kz_term:proplist()) -> boolean().
should_recording_stereo(Props) ->
    %% Backward compatibility: true is an alias for record-from-answer
    %%                         false is an alias for do-not-record
    %% In Kazoo, stereo (dual) is default, defaulting true to dual, so user must explicitly request mono.
    case props:get_ne_binary_value('record', Props) of
        'undefined' -> 'undefined';
        <<"false">> -> 'undefined';
        <<"true">> -> 'true';
        <<"record-from-answer-dual">> -> 'true';
        <<"record-from-ringing-dual">> -> 'true';
        _ -> 'false'
    end.

-spec dial_timeout(kz_term:proplist()) -> pos_integer().
dial_timeout(Props) ->
    %% Add 5s timeout buffer
    case props:get_integer_value('timeout', Props) of
        'undefined' -> ?DEFAULT_TIMEOUT_S + ?TIMEOUT_BUFFER_S;
        N when N >= ?MAXIMUM_TINEOUT_S -> ?MAXIMUM_TIME_LIMIT_S;
        N -> erlang:max(?MINIMUM_TIMEOUT_S, N) + ?TIMEOUT_BUFFER_S
    end.

-spec timelimit_s(kz_term:proplist()) -> non_neg_integer().
timelimit_s(Props) ->
    case props:get_integer_value('timeLimit', Props) of
        'undefined' -> ?DEFAULT_TIME_LIMIT_S;
        N when N >= ?MAXIMUM_TIME_LIMIT_S -> ?MAXIMUM_TIME_LIMIT_S;
        N -> erlang:max(?MINIMUM_TIMEOUT_S, N)
    end.

-spec build_conference_doc(kapps_call:call(), kz_term:ne_binary(), kz_term:proplist()) ->
          kz_json:object().
build_conference_doc(Call, ConfId, ConfProps) ->
    StartOnEnter = props:is_true('startConferenceOnEnter', ConfProps),
    AccountId = kapps_call:account_id(Call),

    kz_json:from_list([{<<"name">>, ConfId}
                      ,{<<"id">>, ConfId}
                      ,{<<"play_welcome">>, 'false'}
                      ,{<<"play_entry_tone">>, props:is_true('beep', ConfProps, 'true')}
                      ,{<<"member">>, member_flags(ConfProps, StartOnEnter)}
                      ,{<<"moderator">>, moderator_flags(ConfProps, StartOnEnter)}
                      ,{<<"require_moderator">>, require_moderator(StartOnEnter)}
                      ,{<<"wait_for_moderator">>, 'true'}
                      ,{<<"max_participants">>, get_max_participants(ConfProps)}
                      ,{<<"profile_name">>, <<ConfId/binary, "_", AccountId/binary>>}
                      ,{<<"profile">>, conference_profile(Call, ConfProps)}
                      ]).

require_moderator('undefined') -> 'false';
require_moderator('true') -> 'false';
require_moderator('false') -> 'true'.

member_flags(_, 'true') -> kz_json:new();
member_flags(ConfProps, _) ->
    kz_json:from_list([{<<"join_muted">>, props:is_true('muted', ConfProps, 'false')}
                      ,{<<"join_deaf">>, props:is_true('deaf', ConfProps, 'false')}
                      ,{<<"play_name">>, props:is_true('play_name', ConfProps, 'false')}
                      ,{<<"play_entry_prompt">>, props:is_true('play_entry_prompt', ConfProps, 'true')}
                      ]).

moderator_flags(ConfProps, 'true') ->
    kz_json:from_list([{<<"join_muted">>, props:is_true('muted', ConfProps, 'false')}
                      ,{<<"join_deaf">>, props:is_true('deaf', ConfProps, 'false')}
                      ,{<<"play_name">>, props:is_true('play_name', ConfProps, 'false')}
                      ,{<<"play_entry_prompt">>, props:is_true('play_entry_prompt', ConfProps, 'true')}
                      ]);
moderator_flags(_, _) -> kz_json:new().

conference_id(Txts) ->
    Id = kz_xml:texts_to_binary(Txts),
    MD5 = kz_term:to_hex_binary(erlang:md5(Id)),
    lager:debug("conf name: ~s (~s)", [Id, MD5]),
    MD5.

-spec add_conference_profile(kapps_call:call(), kz_term:proplist()) -> kapps_call:call().
add_conference_profile(Call, ConfProps) ->
    Profile = conference_profile(Call, ConfProps),
    kzt_util:set_conference_profile(Profile, Call).

-spec conference_profile(kapps_call:call(), kz_term:proplist()) -> kz_json:object().
conference_profile(Call, ConfProps) ->
    AccountId = kapps_call:account_id(Call),
    kz_json:from_list(
      [{<<"announce-count">>, props:get_integer_value('announceCount', ConfProps)}
      ,{<<"caller-controls">>, props:get_binary_value('callerControls', ConfProps, <<"default">>)}
      ,{<<"caller-id-name">>, props:get_binary_value('callerIdName', ConfProps, kapps_call:unknown_caller_id_name(AccountId))}
      ,{<<"caller-id-number">>, props:get_binary_value('callerIdNumber', ConfProps, kz_privacy:anonymous_caller_id_number(AccountId))}
      ,{<<"comfort-noise">>, props:get_integer_value('comfortNoise', ConfProps, 1000)}
      ,{<<"conference-flags">>, conference_flags(ConfProps)}
      ,{<<"energy-level">>, props:get_integer_value('energyLevel', ConfProps, 20)}
      ,{<<"interval">>, props:get_integer_value('interval', ConfProps, 20)}
      ,{<<"max-members">>, get_max_participants(ConfProps)}
      ,{<<"member-flags">>, conference_member_flags(ConfProps)}
      ,{<<"moderator-controls">>, props:get_binary_value('moderatorControls', ConfProps, <<"default">>)}
      ,{<<"moh-sound">>, get_moh(ConfProps)}
      ,{<<"rate">>, props:get_integer_value('rate', ConfProps, 16000)}
      ,{<<"tts-engine">>, kzt_twiml_util:get_engine(Call, ConfProps)}
      ,{<<"tts-voice">>, kzt_twiml_util:get_voice(ConfProps)}
      ]).

-spec get_moh(kz_term:proplist()) -> kz_term:ne_binary().
get_moh(ConfProps) ->
    Default = kapps_config:get_ne_binary(<<"pivot.twiml">>, <<"conference_moh">>, <<"$${hold_music}">>),
    props:get_binary_value('waitUrl', ConfProps, Default).

-spec conference_flags(kz_term:proplist()) -> kz_term:api_ne_binary().
conference_flags(ConfProps) ->
    case props:get_is_true('startConferenceOnEnter', ConfProps, 'true') of
        'true' -> 'undefined';
        'false' -> <<"wait-mod">>
    end.

-spec conference_member_flags(kz_term:proplist()) -> kz_term:api_ne_binary().
conference_member_flags(ConfProps) ->
    case props:get_is_true('endConferenceOnExit', ConfProps, 'false') of
        'true' -> <<"endconf">>;
        'false' -> 'undefined'
    end.

-spec get_caller_endpoint(kapps_call:call()) -> kz_json:object().
get_caller_endpoint(Call) ->
    case kz_endpoint:get(Call) of
        {'ok', Endpoint} ->
            Endpoint;
        {'error', _} ->
            {'ok', Endpoint} = kzd_accounts:fetch(kapps_call:account_id(Call)),
            kz_doc:set_type(Endpoint, <<"device">>)
    end.

-spec get_endpoints(binary(), kz_json:object(), kapps_call:call()) ->
          kz_json:objects().
get_endpoints(UserId, Data, Call) ->
    Params = kz_json:set_value(<<"source">>, kz_term:to_binary(?MODULE), Data),
    kz_endpoints:by_owner_id(UserId, Params, Call).

-spec normalize_number(kz_term:ne_binary(), kapps_call:call()) -> kz_term:ne_binary().
normalize_number(Number, Call) ->
    knm_converters:normalize(Number, kapps_call:account_id(Call)).
