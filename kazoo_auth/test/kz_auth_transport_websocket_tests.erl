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
-define(ROUTE_2, <<"channel.created.thats-a-lie">>).
-define(ROUTE_3, <<"call.me.sometimes">>).

maybe_deny_access_test_() ->
    AuthDoc = kz_json:new(),

    Allow1 = fixture("rule-ws-allow-1.json"),
    Allow2 = fixture("rule-ws-allow-2.json"),
    Deny1 = fixture("rule-ws-deny-1.json"),
    Deny2 = fixture("rule-ws-deny-2.json"),
    PrecedenceAllow = fixture("rule-ws-precedence-allow.json"),
    PrecedenceDeny = fixture("rule-ws-precedence-deny.json"),
    NoPrecedence = fixture("rule-ws-no-precedence.json"),
    AllowMatchAll = fixture("rule-ws-precedence-allow-matchall.json"),
    DenyMatchAll = fixture("rule-ws-precedence-deny-matchall.json"),

    [{"undefined routing_key returns false"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, 'undefined', [Allow1]), 'false')
     }
    ,{"empty routing_key returns false"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, <<>>, [Allow1]), 'false')
     }
    ,{"empty rule list returns false"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, []), 'false')
     }
    ,{"allowed binding when using allowed only"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [Allow1]), 'false')
     }
    ,{"allowed binding when multiple rules"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [Allow1, Allow2]), 'false')
     }
    ,{"denied binding when multiple rules"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [Deny1, Deny2]), 'true')
     }
    ,{"allowing with rules order allow,deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [Allow1, Deny1]), 'false')
     }
    ,{"denying with rules order allow,deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [Deny1, Allow1]), 'true')
     }
    ,{"allowing with precedence allow"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [PrecedenceAllow]), 'false')
     }
    ,{"denying with precedence deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_2, [PrecedenceDeny]), 'true')
     }
    ,{"allow when deny has no match with precedence deny"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [PrecedenceDeny]), 'false')
     }
    ,{"deny when allow has no match with precedence allow"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [PrecedenceAllow]), 'true')
     }
    ,{"not denying with rule doesn't have correct precedence value"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_1, [NoPrecedence]), 'false')
     }
    ,{"allowing catch all with allow precedence"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_3, [AllowMatchAll]), 'false')
     }
    ,{"denying catch all with deny precedence"
     ,?_assertEqual(kz_auth_transport_websocket:maybe_deny_access(AuthDoc, ?ROUTE_3, [DenyMatchAll]), 'true')
     }
    ].


fixture(Filename) ->
    {'ok', JObj} = kz_json:fixture('kazoo_auth', "fixtures/scope_ws_rules/" ++ Filename),
    JObj.
