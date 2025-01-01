%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2025, 2600Hz
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
-define(TWIML_MAX_PARTICIPANTS, 250).

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
                       ,content=NameTxts
                       ,attributes=ConfAttrs
                       }], DialAttrs) ->
    ConfProps = kz_xml:attributes_to_proplist(ConfAttrs),
    DialProps = kz_xml:attributes_to_proplist(DialAttrs),
    case kz_xml:texts_to_binary(NameTxts) of
        <<>> ->
            lager:info("conference name is empty, not processing Conference"),
            {'ok', Call};
        Name ->
            conference_dial(Call, Name, ConfProps, DialProps)
    end;

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

            {'ok', Call2} = kzt_receiver:wait_for_offnet(Call1, Props, 'bridge'),
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

    OffnetProps = [{<<"Force-Outbound">>, force_outbound(Props)}],

    Call2 = maybe_start_dial_record(Props, Call1),

    'ok' = kzt_util:offnet_req(Props, OffnetProps, Call2),

    {'ok', Call3} = kzt_receiver:wait_for_offnet(Call2, Props, 'offnet'),

    maybe_end_dial(Call3, Props).

-spec number_dial(kapps_call:call(), kz_term:proplist(), kz_term:proplist(), kz_term:ne_binary()) ->
          {'ok' | 'stop' | 'request', kapps_call:call()}.
number_dial(Call, DialProps, _NumberProps, DialMe) ->
    %% TODO: implement these
    %% SendDigits = props:get_value('sendDigits', NumberProps),
    %% _Url = props:get_value('url', NumberProps),
    %% _Method = props:get_value('method', NumberProps),

    lager:info("not implemented: maybe sending number ~s", [DialMe]),

    simple_dial(Call, DialProps, DialMe).

-spec conference_dial(kapps_call:call(), kz_term:ne_binary(), kz_term:proplist(), kz_term:proplist()) ->
          {'ok' | 'error' | 'stop', kapps_call:call()}.
conference_dial(Call, Name, ConfProps, DialProps) ->
    Id = props:get_ne_binary_value('id', ConfProps, kz_term:to_hex_binary(erlang:md5(Name))),

    lager:debug("dialing into conference ~s (~s)", [Name, Id]),

    publish_conference_request(Call, Id, Name, ConfProps),

    lager:debug("published conference request"),

    SetupCall = setup_call_for_dial(Call, DialProps),
    Call1 = kapps_call:kvs_store(<<"conference_props">>, ConfProps, SetupCall),

    {'ok', Call2} = kzt_receiver:wait_for_conference(Call1),
    maybe_end_dial(Call2, DialProps).

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

-spec publish_conference_request(kapps_call:call(), kz_term:ne_binary(), kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
publish_conference_request(Call, Id, Name, ConfProps) ->
    IsModerator = props:is_true('startConferenceOnEnter', ConfProps, 'true'),
    ProfileName = props:get_ne_binary_value('profileName', ConfProps),

    gen_listener:add_binding(kzt_util:get_amqp_listener(Call)
                            ,'conference'
                            ,[{'restrict_to'
                              ,[{'event', {Id, kapps_call:call_id_direct(Call)}}]
                              }
                             ]),

    ConfReq =
        props:filter_undefined(
          [{<<"Call">>, kapps_call:to_json(Call)}
          ,{<<"Conference-ID">>, Id}
          ,{<<"Conference-Name">>, Name}
          ,{<<"Profile-Name">>, ProfileName}
           %% FIXME: we must not set these if profile name is default, video, or page
          ,{<<"Max-Participants">>, get_max_participants(ConfProps)}
          ,{<<"Play-Entry-Tone">>, conference_play_entry_tone(ConfProps)}
          ,{<<"Play-Exit-Tone">>, conference_play_exit_tone(ConfProps)}
          ,{<<"Wait-For-Moderator">>, not IsModerator}
           %% member join-options, safe to set per member
          ,{<<"End-On-Last-Member-Leave">>, props:is_true('endConferenceOnLastMemberExit', ConfProps, 'undefined')}
          ,{<<"End-On-Leave">>, props:is_true('endConferenceOnExit', ConfProps, 'undefined')}
          ,{<<"Moderator">>, IsModerator}
          | deaf_muted_headers(ConfProps, IsModerator) ++ kz_api:default_headers(?APP_NAME, ?APP_VERSION)
          ]
         ),
    kapi_conference:publish_discovery_req(ConfReq).

-spec deaf_muted_headers(kz_term:proplist(), boolean()) -> kz_term:proplist().
deaf_muted_headers(ConfProps, 'true') ->
    [{<<"Moderator-Join-Deaf">>, props:is_true('deaf', ConfProps, 'false')}
    ,{<<"Moderator-Join-Muted">>, props:is_true('muted', ConfProps, 'false')}
    ];
deaf_muted_headers(ConfProps, 'false') ->
    [{<<"Member-Join-Deaf">>, props:is_true('deaf', ConfProps, 'false')}
    ,{<<"Member-Join-Muted">>, props:is_true('muted', ConfProps, 'false')}
    ].

-spec get_max_participants(kz_term:proplist()) -> 1..250.
get_max_participants(Props) ->
    case props:get_integer_value('maxParticipants', Props) of
        N when is_integer(N), N =< ?TWIML_MAX_PARTICIPANTS, N > 2 ->
            N;
        _ ->
            ?TWIML_MAX_PARTICIPANTS
    end.

-spec conference_play_entry_tone(kz_term:proplist()) -> boolean().
conference_play_entry_tone(ConfProps) ->
    case props:get_ne_binary_value('beep', ConfProps, <<"true">>) of
        <<"true">> -> 'true';
        <<"onEnter">> -> 'true';
        _ -> 'false'
    end.

-spec conference_play_exit_tone(kz_term:proplist()) -> boolean().
conference_play_exit_tone(ConfProps) ->
    case props:get_ne_binary_value('beep', ConfProps, <<"true">>) of
        <<"true">> -> 'true';
        <<"onExit">> -> 'true';
        _ -> 'false'
    end.

-spec get_caller_endpoint(kapps_call:call()) -> kz_json:object().
get_caller_endpoint(Call) ->
    case kz_endpoint:get(Call) of
        {'ok', Endpoint} ->
            Endpoint;
        {'error', _} ->
            {'ok', Endpoint} = kzd_accounts:fetch(kapps_call:account_id(Call)),
            Endpoint
    end.

-spec get_endpoints(binary(), kz_json:object(), kapps_call:call()) ->
          kz_json:objects().
get_endpoints(UserId, Data, Call) ->
    Params = kz_json:set_value(<<"source">>, kz_term:to_binary(?MODULE), Data),
    kz_endpoints:by_owner_id(UserId, Params, Call).

-spec normalize_number(kz_term:ne_binary(), kapps_call:call()) -> kz_term:ne_binary().
normalize_number(Number, Call) ->
    knm_converters:normalize(Number, kapps_call:account_id(Call)).

-spec maybe_start_dial_record(kz_term:proplist(), kapps_call:call()) -> kapps_call:call().
maybe_start_dial_record(Props, Call) ->
    Setters = [{fun kzt_util:set_record_call/2, should_record_call(Props)}
              ,{fun kzt_util:set_recording_stereo/2, props:get_ne_binary_value('record', Props)}
              ,{fun kapps_call:start_recording/2, get_recording_data(Props)}],
    kapps_call:exec(Setters, Call).

-spec get_recording_data(kz_term:proplist()) -> kz_term:api_object().
get_recording_data(Props) ->
    case should_record_call(Props) of
        'false' -> 'undefined';
        'true' ->
            kz_json:from_list([{<<"record_on_bridge">>, record_from_bridge(Props)}
                              ,{<<"record_on_answer">>, record_from_answer(Props)}
                              ,{<<"url">>, props:get_ne_binary_value('recordingUrl', Props)}
                              ,{<<"method">>, kzt_util:record_store_method(Props)}
                              ]
                             )
    end.

-spec record_from_answer(kz_term:proplist()) -> 'true' | 'undefined'.
record_from_answer(Props) ->
    case props:get_ne_binary_value('record', Props) of
        <<"record-from-answer">> -> 'true';
        <<"record-from-answer-dual">> -> 'true';
        <<"true">> -> 'true';
        _ -> 'undefined'
    end.

-spec record_from_bridge(kz_term:proplist()) -> 'true' | 'undefined'.
record_from_bridge(Props) ->
    case props:get_ne_binary_value('record', Props) of
        <<"record-from-ringing">> -> 'true';
        <<"record-from-ringing-dual">> -> 'true';
        _ -> 'undefined'
    end.
