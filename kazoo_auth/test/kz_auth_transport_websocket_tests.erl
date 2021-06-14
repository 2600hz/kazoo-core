%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_transport_websocket_tests).

-include_lib("eunit/include/eunit.hrl").
-include("../src/kz_auth_scope.hrl").

-define(ROUTE_1, <<"call.events.answered">>).
-define(ROUTE_2, <<"channel.created.*">>).

maybe_deny_access_test_() ->
    AuthDoc = kz_json:new(),

    Allow1 = fixture("rule-ws-allow-1.json"),
    Allow2 = fixture("rule-ws-allow-2.json"),
    Deny1 = fixture("rule-ws-deny-1.json"),
    Deny2 = fixture("rule-ws-deny-2.json"),
    PrecedenceAllow = fixture("rule-ws-precedence-allow.json"),
    PrecedenceDeny = fixture("rule-ws-precedence-deny.json"),
    NoPrecedence = fixture("rule-ws-no-precedence.json"),

    [{"verify undefined routing_key returns false"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, 'undefined', [Allow1]), 'false')
     }
    ,{"verify empty routing_key returns false"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, <<>>, [Allow1]), 'false')
     }
    ,{"verify empty rule list returns false"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, []), 'false')
     }
    ,{"verify allowed binding when using allowed only"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [Allow1]), 'false')
     }
    ,{"verify allowed binding when multiple rules"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [Allow1, Allow2]), 'false')
     }
    ,{"verify denied binding when multiple rules"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [Deny1, Deny2]), 'true')
     }
    ,{"verify allowing with rules order allow,deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [Allow1, Deny1]), 'false')
     }
    ,{"verify denying with rules order allow,deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [Deny1, Allow1]), 'true')
     }
    ,{"verify allowing with precedence allow"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [PrecedenceAllow]), 'false')
     }
    ,{"verify denying with precedence deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [PrecedenceDeny]), 'true')
     }
    ,{"verify allow when deny has no match with precedence deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [PrecedenceDeny]), 'false')
     }
    ,{"verify deny when allow has no match with precedence allow"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [PrecedenceAllow]), 'true')
     }
    ,{"verify not denying with rule doesn't have correct precedence value"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [NoPrecedence]), 'false')
     }
    ].


fixture(Filename) ->
    {'ok', JObj} = kz_json:fixture('kazoo_auth', "fixtures/scope_ws_rules/" ++ Filename),
    JObj.
