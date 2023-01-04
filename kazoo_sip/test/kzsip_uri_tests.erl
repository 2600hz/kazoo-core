%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzsip_uri_tests).

-include_lib("eunit/include/eunit.hrl").

parse_full_uri_test_() ->
    URIParams = <<";transport=tcp;nat=yes;from-offnet=true">>,
    ExtraParams = <<";tag=random;expires=3600;q=0.7;reg-id=1;+sip.instance=\"<urn:uuid:00000000-0000-1000-8000-000A95A0E128>\"">>,
    [parse_full_uri_without_params()
    ,parse_full_uri_with_uri_params_only(URIParams, ExtraParams)
    ,parse_full_uri_with_extra_params_only(ExtraParams)
    ,parse_full_uri_with_uri_and_extra_params(URIParams, ExtraParams)
    ].

parse_full_uri_without_params() ->
    URIs = [<<"name sip:username@host.com:2600">> %% Non-quoted name, not <> enclosure.
           ,<<"name <sip:username@host.com:2600>">> %% Non-quoted name.
           ,<<"\"name\" sip:username@host.com:2600">> %% Quoted name, not <> enclosure.
           ,<<"\"name\" <sip:username@host.com:2600>">> %% Quoted name, <> enclosure.
           ],

    [{kz_term:to_list(URI)
     ,[?_assertEqual(<<"name">>, kzsip_uri:display_name(SIP_URI))
      ,?_assertEqual('sip', kzsip_uri:scheme(SIP_URI))
      ,?_assertEqual(<<"username">>, kzsip_uri:user(SIP_URI))
      ,?_assertEqual(<<"host.com">>, kzsip_uri:host(SIP_URI))
      ,?_assertEqual(2600, kzsip_uri:port(SIP_URI))
      ,?_assertEqual([], kzsip_uri:uri_params(SIP_URI))
      ,?_assertEqual([], kzsip_uri:extra_params(SIP_URI))
      ]
     } || {URI, SIP_URI} <- [{URI, kzsip_uri:parse(URI)} || URI <- URIs]
    ].

parse_full_uri_with_uri_params_only(URIParams, ExtraParams) ->
    %% Everything within the angle brackets (<>) and after the optional port is considered uri_params.
    URIs = [<<"name sip:username@host.com:2600", URIParams/binary>> %% Non-quoted name, not <> enclosure.
           ,<<"name <sip:username@host.com:2600", URIParams/binary, ">">> %% Non-quoted name.
           ,<<"\"name\" sip:username@host.com:2600", URIParams/binary>> %% Quoted name, not <> enclosure.
           ,<<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">">> %% Quoted name, <> enclosure.
           ],
    %% Not <> enclosure, which means, not extra params, everything after the port becomes uri_params.
    URIParamsURI = <<"name sip:username@host.com:2600", URIParams/binary, ExtraParams/binary>>,
    ParsedURIParamsURI = kzsip_uri:parse(URIParamsURI),

    [{kz_term:to_list(URI)
     ,[?_assertEqual(<<"name">>, kzsip_uri:display_name(SIP_URI))
      ,?_assertEqual('sip', kzsip_uri:scheme(SIP_URI))
      ,?_assertEqual(<<"username">>, kzsip_uri:user(SIP_URI))
      ,?_assertEqual(<<"host.com">>, kzsip_uri:host(SIP_URI))
      ,?_assertEqual(2600, kzsip_uri:port(SIP_URI))
      ,?_assertEqual([], kzsip_uri:extra_params(SIP_URI))
      ] ++ match_parse_full_uri_uri_params(SIP_URI)
     } || {URI, SIP_URI} <- [{URI, kzsip_uri:parse(URI)} || URI <- URIs]
    ] ++ [{kz_term:to_list(URIParamsURI)
          ,[?_assertEqual(<<"name">>, kzsip_uri:display_name(ParsedURIParamsURI))
           ,?_assertEqual('sip', kzsip_uri:scheme(ParsedURIParamsURI))
           ,?_assertEqual(<<"username">>, kzsip_uri:user(ParsedURIParamsURI))
           ,?_assertEqual(<<"host.com">>, kzsip_uri:host(ParsedURIParamsURI))
           ,?_assertEqual(2600, kzsip_uri:port(ParsedURIParamsURI))
           ,?_assertEqual([], kzsip_uri:extra_params(ParsedURIParamsURI))
           ] ++ match_parse_full_uri_uri_params(ParsedURIParamsURI, default_expected_uri_params() ++ default_expected_extra_params())
          }
         ].

parse_full_uri_with_extra_params_only(ExtraParams) ->
    %% Everything after closing angle bracket (>) is considered extra_params.
    URIs = [<<"name <sip:line1@192.0.2.2:2600>", ExtraParams/binary>> %% Non-quoted name.
           ,<<"\"name\" <sip:line1@192.0.2.2:2600>", ExtraParams/binary>> %% Quoted name.
           ],

    [{kz_term:to_list(URI)
     ,[?_assertEqual(<<"name">>, kzsip_uri:display_name(SIP_URI))
      ,?_assertEqual('sip', kzsip_uri:scheme(SIP_URI))
      ,?_assertEqual(<<"line1">>, kzsip_uri:user(SIP_URI))
      ,?_assertEqual(<<"192.0.2.2">>, kzsip_uri:host(SIP_URI))
      ,?_assertEqual(2600, kzsip_uri:port(SIP_URI))
      ,?_assertEqual([], kzsip_uri:uri_params(SIP_URI))
      ] ++ match_parse_full_uri_extra_params(SIP_URI)
     } || {URI, SIP_URI} <- [{URI, kzsip_uri:parse(URI)} || URI <- URIs]
    ].

parse_full_uri_with_uri_and_extra_params(URIParams, ExtraParams) ->
    URIs = [<<"name <sip:line1@192.0.2.2:2600", URIParams/binary, ">", ExtraParams/binary>> %% Non-quoted name.
           ,<<"\"name\" <sip:line1@192.0.2.2:2600", URIParams/binary, ">", ExtraParams/binary>> %% Quoted name.
           ],
    %% extra_params already have a complex parameter: +sip.instance="<urn:uuid:00000000-0000-1000-8000-000A95A0E128>"
    ComplexURIParams = <<URIParams/binary, ";+complex.key=\"<com:plex:va-lue>\"">>,
    ComplexParamsURIs = [<<"name <sip:line1@192.0.2.2:2600", ComplexURIParams/binary, ">", ExtraParams/binary>> %% Non-quoted name.
                        ,<<"\"name\" <sip:line1@192.0.2.2:2600", ComplexURIParams/binary, ">", ExtraParams/binary>> %% Quoted name.
                        ],

    DefaultAsserts = fun(SIP_URI) ->
                             [?_assertEqual(<<"name">>, kzsip_uri:display_name(SIP_URI))
                             ,?_assertEqual('sip', kzsip_uri:scheme(SIP_URI))
                             ,?_assertEqual(<<"line1">>, kzsip_uri:user(SIP_URI))
                             ,?_assertEqual(<<"192.0.2.2">>, kzsip_uri:host(SIP_URI))
                             ,?_assertEqual(2600, kzsip_uri:port(SIP_URI))
                             ]
                     end,

    [{kz_term:to_list(URI)
     ,DefaultAsserts(SIP_URI)
      ++ match_parse_full_uri_uri_params(SIP_URI)
      ++ match_parse_full_uri_extra_params(SIP_URI)
     } || {URI, SIP_URI} <- [{URI, kzsip_uri:parse(URI)} || URI <- URIs]
    ] ++ [{kz_term:to_list(URI)
          ,DefaultAsserts(SIP_URI)
           ++ match_parse_full_uri_uri_params(SIP_URI, default_expected_uri_params() ++ [{<<"+complex.key">>, <<"\"<com:plex:va-lue>\"">>}])
           ++ match_parse_full_uri_extra_params(SIP_URI)
          } || {URI, SIP_URI} <- [{URI, kzsip_uri:parse(URI)} || URI <- ComplexParamsURIs]
         ].

default_expected_uri_params() ->
    [{<<"transport">>, <<"tcp">>}
    ,{<<"nat">>, <<"yes">>}
    ,{<<"from-offnet">>, <<"true">>}
    ].

default_expected_extra_params() ->
    [{<<"tag">>, <<"random">>}
    ,{<<"expires">>, <<"3600">>}
    ,{<<"q">>, <<"0.7">>}
    ,{<<"reg-id">>, <<"1">>}
    ,{<<"+sip.instance">>, <<"\"<urn:uuid:00000000-0000-1000-8000-000A95A0E128>\"">>}
    ].

match_parse_full_uri_uri_params(SIP_URI) ->
    match_parse_full_uri_uri_params(SIP_URI, default_expected_uri_params()).

match_parse_full_uri_uri_params(SIP_URI, Expected) ->
    [?_assertEqual(Value, kzsip_uri:get_uri_param(Param, SIP_URI))
     || {Param, Value} <- Expected
    ].

match_parse_full_uri_extra_params(SIP_URI) ->
    match_parse_full_uri_extra_params(SIP_URI, default_expected_extra_params()).

match_parse_full_uri_extra_params(SIP_URI, Expected) ->
    [?_assertEqual(Value, kzsip_uri:get_extra_param(Param, SIP_URI))
     || {Param, Value} <- Expected
    ].

parse_user_host_test_() ->
    Uri = kzsip_uri:parse(<<"sip:username@host.com">>),
    [?_assertEqual(<<>>, kzsip_uri:display_name(Uri))
    ,?_assertEqual('sip', kzsip_uri:scheme(Uri))
    ,?_assertEqual(<<"username">>, kzsip_uri:user(Uri))
    ,?_assertEqual(<<"host.com">>, kzsip_uri:host(Uri))
    ,?_assertEqual(5060, kzsip_uri:port(Uri))
    ,?_assertEqual([], kzsip_uri:uri_params(Uri))
    ,?_assertEqual([], kzsip_uri:extra_params(Uri))
    ].

parse_scheme_user_host_test_() ->
    Uri = kzsip_uri:parse(<<"sips:username@host.com">>),
    [?_assertEqual(<<>>, kzsip_uri:display_name(Uri))
    ,?_assertEqual('sips', kzsip_uri:scheme(Uri))
    ,?_assertEqual(<<"username">>, kzsip_uri:user(Uri))
    ,?_assertEqual(<<"host.com">>, kzsip_uri:host(Uri))
    ,?_assertEqual(5060, kzsip_uri:port(Uri))
    ,?_assertEqual([], kzsip_uri:uri_params(Uri))
    ,?_assertEqual([], kzsip_uri:extra_params(Uri))
    ].

parse_noscheme_test_() ->
    Uri = kzsip_uri:parse(<<"username@host.com">>),
    [?_assertEqual(<<>>, kzsip_uri:display_name(Uri))
    ,?_assertEqual('sip', kzsip_uri:scheme(Uri))
    ,?_assertEqual(<<"username">>, kzsip_uri:user(Uri))
    ,?_assertEqual(<<"host.com">>, kzsip_uri:host(Uri))
    ,?_assertEqual(5060, kzsip_uri:port(Uri))
    ,?_assertEqual([], kzsip_uri:uri_params(Uri))
    ,?_assertEqual([], kzsip_uri:extra_params(Uri))
    ].

parse_noscheme_port_test_() ->
    Uri = kzsip_uri:parse(<<"username@host.com:2600">>),
    [?_assertEqual(<<>>, kzsip_uri:display_name(Uri))
    ,?_assertEqual('sip', kzsip_uri:scheme(Uri))
    ,?_assertEqual(<<"username">>, kzsip_uri:user(Uri))
    ,?_assertEqual(<<"host.com">>, kzsip_uri:host(Uri))
    ,?_assertEqual(2600, kzsip_uri:port(Uri))
    ,?_assertEqual([], kzsip_uri:uri_params(Uri))
    ,?_assertEqual([], kzsip_uri:extra_params(Uri))
    ].

encode_request_uri_test() ->
    Uri = kzsip_uri:parse(<<"username@host.com:2600">>),
    ?assertEqual(<<"sip:username@host.com:2600">>, kzsip_uri:encode(Uri)).

encode_from_uri_test_() ->
    URIParams = <<";transport=tcp;nat=yes;from-offnet=true">>,
    ExtraParams = <<";tag=random;expires=3600;q=0.7;reg-id=1;+sip.instance=\"<urn:uuid:00000000-0000-1000-8000-000A95A0E128>\"">>,
    [encode_from_uri_without_uri_and_extra_params()
    ,encode_from_uri_with_uri_params_only(URIParams)
    ,encode_from_uri_with_extra_params_only(ExtraParams)
    ,encode_from_uri_with_uri_and_extra_params(URIParams, ExtraParams)
    ].

encode_from_uri_without_uri_and_extra_params() ->
    URIs = [{<<"sip:username@host.com:2600">>, <<"username@host.com:2600">>} %% user@host:port.
           ,{<<"sip:username@host.com:2600">>, <<"<username@host.com:2600>">>} %% user@host:port (enclosed <>).
           ,{<<"sip:username@host.com:5060">>, <<"username@host.com">>} %% user@host.
           ,{<<"sip:username@host.com:5060">>, <<"<username@host.com>">>} %% user@host (enclosed <>).
           ,{<<"sips:username@host.com:2600">>, <<"sips:username@host.com:2600">>} %% scheme:user@host:port.
           ,{<<"sips:username@host.com:2600">>, <<"<sips:username@host.com:2600>">>} %% scheme:user@host:port (enclosed <>).
           ],

    [{kz_term:to_list(URI)
     ,?_assertEqual(Expect, kzsip_uri:encode(kzsip_uri:parse(URI), 'from'))
     } || {Expect, URI} <- URIs
    ].

encode_from_uri_with_uri_params_only(URIParams) ->
    Expected = <<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">">>,
    URIs = [{Expected, <<"name sip:username@host.com:2600", URIParams/binary>>} %% Non-quoted display_name.
           ,{Expected, <<"name  sip:username@host.com:2600", URIParams/binary>>} %% Spaces after non-quoted display_name.
           ,{Expected, <<"name <sip:username@host.com:2600", URIParams/binary, ">">>} %% Non-quoted display_name.
           ,{Expected, <<"name   <sip:username@host.com:2600", URIParams/binary, ">">>} %% Spaces after non-quoted display_name.
           ,{Expected, <<"\"name\" sip:username@host.com:2600", URIParams/binary>>} %% Quoted display_name, not <> enclosure.
           ,{Expected, <<"\"name\"    sip:username@host.com:2600", URIParams/binary>>} %% Spaces after quoted display_name, and not <> enclosure.
           ,{Expected, <<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">">>} %% Quotes around display_name, <> enclosure.
           ,{Expected, <<"\"name\"  <sip:username@host.com:2600", URIParams/binary, ">">>} %% Spaces after quoted display_name.
           ,{<<"\"name\" <sip:username@host.com:5060", URIParams/binary, ">">>
            ,<<"\"name\"  <sip:username@host.com", URIParams/binary, ">">> %% Not port.
            }
            %% If not extra_params provided, use <> enclosure only when display_name was provided.
           ,{<<"sip:username@host.com:2600", URIParams/binary>>
            ,<<"username@host.com:2600", URIParams/binary>> %% user@host:port;uri_params.
            }
           ,{<<"sip:username@host.com:5060", URIParams/binary>>
            ,<<"username@host.com", URIParams/binary>> %% user@host;uri_params.
            }
           ,{<<"sips:username@host.com:2600", URIParams/binary>>
            ,<<"sips:username@host.com:2600", URIParams/binary>> %% scheme:user@host:port;uri_params.
            }
           ],
    [{kz_term:to_list(URI)
     ,?_assertEqual(Expect, kzsip_uri:encode(kzsip_uri:parse(URI), 'from'))
     } || {Expect, URI} <- URIs
    ].

encode_from_uri_with_extra_params_only(ExtraParams) ->
    URIs = [{<<"\"name\" <sip:username@host.com:2600>", ExtraParams/binary>>
            ,<<"name <sip:username@host.com:2600>", ExtraParams/binary>> %% Non-quoted display_name.
            }
           ,{<<"\"name\" <sip:username@host.com:2600>", ExtraParams/binary>>
            ,<<"name   <sip:username@host.com:2600>", ExtraParams/binary>> %% Spaces after non-quoted display_name.
            }
           ,{<<"\"name\" <sip:username@host.com:2600>", ExtraParams/binary>>
            ,<<"\"name\" <sip:username@host.com:2600>", ExtraParams/binary>> %% Quotes around display_name, <> enclosure.
            }
           ,{<<"\"name\" <sip:username@host.com:2600>", ExtraParams/binary>>
            ,<<"\"name\"  <sip:username@host.com:2600>", ExtraParams/binary>> %% Spaces after quoted display_name.
            }
           ,{<<"\"name\" <sip:username@host.com:5060>", ExtraParams/binary>>
            ,<<"\"name\"  <sip:username@host.com>", ExtraParams/binary>> %% Not port.
            }
            %% If not display_name provided, only use <> enclosure if extra_params were provided.
           ,{<<"<sip:username@host.com:2600>", ExtraParams/binary>>
            ,<<"<username@host.com:2600>", ExtraParams/binary>> %% <user@host:port>;extra_params.
            }
           ,{<<"<sip:username@host.com:5060>", ExtraParams/binary>>
            ,<<"<username@host.com>", ExtraParams/binary>> %% <user@host>;extra_params.
            }
           ,{<<"<sips:username@host.com:2600>", ExtraParams/binary>>
            ,<<"<sips:username@host.com:2600>", ExtraParams/binary>> %% <scheme:user@host:port>;extra_params.
            }
           ],
    [{kz_term:to_list(URI)
     ,?_assertEqual(Expect, kzsip_uri:encode(kzsip_uri:parse(URI), 'from'))
     } || {Expect, URI} <- URIs
    ].

encode_from_uri_with_uri_and_extra_params(URIParams, ExtraParams) ->
    URIs = [{<<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"name <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>> %% Non-quoted display_name.
            }
           ,{<<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"name   <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>> %% Spaces after non-quoted display_name.
            }
           ,{<<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>> %% Quotes around display_name, <> enclosure.
            }
           ,{<<"\"name\" <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"\"name\"  <sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>> %% Spaces after quoted display_name.
            }
           ,{<<"\"name\" <sip:username@host.com:5060", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"\"name\"  <sip:username@host.com", URIParams/binary, ">", ExtraParams/binary>> %% Not port.
            }
            %% If not display_name provided, only use <> enclosure if extra_params were provided.
           ,{<<"<sip:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"<username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>> %% <user@host:port>;extra_params.
            }
           ,{<<"<sip:username@host.com:5060", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"<username@host.com", URIParams/binary, ">", ExtraParams/binary>> %% <user@host>;extra_params.
            }
           ,{<<"<sips:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>>
            ,<<"<sips:username@host.com:2600", URIParams/binary, ">", ExtraParams/binary>> %% <scheme:user@host:port>;extra_params.
            }
           ],
    [{kz_term:to_list(URI)
     ,?_assertEqual(Expect, kzsip_uri:encode(kzsip_uri:parse(URI), 'from'))
     } || {Expect, URI} <- URIs
    ].

encode_full_test() ->
    U = <<"sip:username@host.com:2600">>,
    Uri = kzsip_uri:parse(U),
    ?assertEqual(U, kzsip_uri:encode(Uri)).

encode_5060_test() ->
    U = <<"sips:username@host.com">>,
    Uri = kzsip_uri:parse(U),
    ?assertEqual(U, kzsip_uri:encode(Uri)).

encode_full_5060_test() ->
    U = <<"sips:username@host.com:5060">>,
    Uri = kzsip_uri:parse(U),
    ?assertEqual(<<"sips:username@host.com">>, kzsip_uri:encode(Uri)).

parse_angles_test_() ->
    U = <<"<sips:username@host.com:5060>">>,
    Uri = kzsip_uri:parse(U),
    [?_assertEqual(<<"username">>, kzsip_uri:user(Uri))
    ,?_assertEqual(<<"sips:username@host.com">>, kzsip_uri:encode(Uri))
    ].

parse_angles_2_test_() ->
    U = <<"<sip:username@host.com>">>,
    Uri = kzsip_uri:parse(U),
    [?_assertEqual(<<"username">>, kzsip_uri:user(Uri))
    ,?_assertEqual(<<"sip:username@host.com">>, kzsip_uri:encode(Uri))
    ].

sip_uri_setters_test_() ->
    URI = <<"sip:+12125551212@phone2net.com;tag=887s">>,
    SIP_URI = kzsip_uri:parse(URI),
    Mods = [{fun kzsip_uri:set_display_name/2, [<<"modified">>]}
           ,{fun kzsip_uri:set_scheme/2, ['sips']}
           ,{fun kzsip_uri:set_user/2, [<<"+13135551313">>]}
           ,{fun kzsip_uri:set_host/2, [<<"net2phone.com">>]}
           ,{fun kzsip_uri:set_port/2, [2600]}
           ,{fun(Acc, Key, Value) -> kzsip_uri:set_uri_param(Key, Value, Acc) end
            ,[<<"tag">>, <<"998s">>]
            }
           ,{fun(Acc, Key, Value) -> kzsip_uri:set_extra_param(Key, Value, Acc) end
            ,[<<"reg-id">>, <<"1">>]
            }
           ],
    ModSIP_URI = lists:foldl(fun({Setter, Params}, Acc) -> erlang:apply(Setter, [Acc | Params]) end
                            ,SIP_URI
                            ,Mods
                            ),

    [?_assertEqual(<<"">>, kzsip_uri:display_name(SIP_URI))
    ,?_assertEqual(<<"modified">>, kzsip_uri:display_name(ModSIP_URI))
    ,?_assertEqual('sip', kzsip_uri:scheme(SIP_URI))
    ,?_assertEqual('sips', kzsip_uri:scheme(ModSIP_URI))
    ,?_assertEqual(<<"+12125551212">>, kzsip_uri:user(SIP_URI))
    ,?_assertEqual(<<"+13135551313">>, kzsip_uri:user(ModSIP_URI))
    ,?_assertEqual(<<"phone2net.com">>, kzsip_uri:host(SIP_URI))
    ,?_assertEqual(<<"net2phone.com">>, kzsip_uri:host(ModSIP_URI))
    ,?_assertEqual(5060, kzsip_uri:port(SIP_URI))
    ,?_assertEqual(2600, kzsip_uri:port(ModSIP_URI))
    ,?_assertEqual([{<<"tag">>, <<"887s">>}], kzsip_uri:uri_params(SIP_URI))
    ,?_assertEqual([{<<"tag">>, <<"998s">>}], kzsip_uri:uri_params(ModSIP_URI))
    ,?_assertEqual([], kzsip_uri:extra_params(SIP_URI))
    ,?_assertEqual([{<<"reg-id">>, <<"1">>}], kzsip_uri:extra_params(ModSIP_URI))
    ,?_assertEqual(<<"sip:+12125551212@phone2net.com:5060;tag=887s">>
                  ,kzsip_uri:encode(SIP_URI, 'from')
                  )
    ,?_assertEqual(<<"\"modified\" <sips:+13135551313@net2phone.com:2600;tag=998s>;reg-id=1">>
                  ,kzsip_uri:encode(ModSIP_URI, 'from')
                  )
    ].

%% https://www.rfc-editor.org/rfc/rfc3261.html#section-20.20
rfc_3261_from_header_examples_test_() ->
    URI0 = <<"\"Bob\" <sips:bob@biloxi.com> ;tag=a48s">>,
    SIP_URI0 = kzsip_uri:parse(URI0),
    URI1 = <<"sip:+12125551212@phone2net.com;tag=887s">>, %% Not display_name provided.
    SIP_URI1 = kzsip_uri:parse(URI1),
    URI2 = <<"Anonymous <sip:c8oqz84zk7z@privacy.org>;tag=hyh8">>,
    SIP_URI2 = kzsip_uri:parse(URI2),

    [{kz_term:to_list(URI0)
     ,[?_assertEqual(<<"Bob">>, kzsip_uri:display_name(SIP_URI0))
      ,?_assertEqual('sips', kzsip_uri:scheme(SIP_URI0))
      ,?_assertEqual(<<"bob">>, kzsip_uri:user(SIP_URI0))
      ,?_assertEqual(<<"biloxi.com">>, kzsip_uri:host(SIP_URI0))
      ,?_assertEqual(5060, kzsip_uri:port(SIP_URI0))
      ,?_assertEqual([], kzsip_uri:uri_params(SIP_URI0))
      ,?_assertEqual([{<<"tag">>, <<"a48s">>}], kzsip_uri:extra_params(SIP_URI0))
      ,?_assertEqual(<<"\"Bob\" <sips:bob@biloxi.com:5060>;tag=a48s">>, kzsip_uri:encode(SIP_URI0, 'from'))
      ]
     }
    ,{kz_term:to_list(URI1)
     ,[?_assertEqual(<<>>, kzsip_uri:display_name(SIP_URI1))
      ,?_assertEqual('sip', kzsip_uri:scheme(SIP_URI1))
      ,?_assertEqual(<<"+12125551212">>, kzsip_uri:user(SIP_URI1))
      ,?_assertEqual(<<"phone2net.com">>, kzsip_uri:host(SIP_URI1))
      ,?_assertEqual(5060, kzsip_uri:port(SIP_URI1))
      ,?_assertEqual([{<<"tag">>, <<"887s">>}], kzsip_uri:uri_params(SIP_URI1))
      ,?_assertEqual([], kzsip_uri:extra_params(SIP_URI1))
      ,?_assertEqual(<<"sip:+12125551212@phone2net.com:5060;tag=887s">>, kzsip_uri:encode(SIP_URI1, 'from'))
      ]
     }
    ,{kz_term:to_list(URI2)
     ,[?_assertEqual(<<"Anonymous">>, kzsip_uri:display_name(SIP_URI2))
      ,?_assertEqual('sip', kzsip_uri:scheme(SIP_URI2))
      ,?_assertEqual(<<"c8oqz84zk7z">>, kzsip_uri:user(SIP_URI2))
      ,?_assertEqual(<<"privacy.org">>, kzsip_uri:host(SIP_URI2))
      ,?_assertEqual(5060, kzsip_uri:port(SIP_URI2))
      ,?_assertEqual([], kzsip_uri:uri_params(SIP_URI2))
      ,?_assertEqual([{<<"tag">>, <<"hyh8">>}], kzsip_uri:extra_params(SIP_URI2))
      ,?_assertEqual(<<"\"Anonymous\" <sip:c8oqz84zk7z@privacy.org:5060>;tag=hyh8">>
                    ,kzsip_uri:encode(SIP_URI2, 'from')
                    )
      ]
     }
    ].

params_to_binary_test_() ->
    Params = [{<<"param1">>, <<"value1">>}
             ,{<<"empty-param">>, <<>>}
             ,{<<"+especial.param3">>, <<"\"<espe:cial:va-lue-3>\"">>}
             ,{<<"param2">>, <<"value2">>}
             ],

    [{"Non-empty parameters list"
     ,?_assertEqual(<<";param1=value1;empty-param=;+especial.param3=\"<espe:cial:va-lue-3>\";param2=value2">>
                   ,kzsip_uri:params_to_binary(Params)
                   )
     }
    ,{"Empty parameters list", ?_assertEqual(<<>>, kzsip_uri:params_to_binary([]))}
    ].
