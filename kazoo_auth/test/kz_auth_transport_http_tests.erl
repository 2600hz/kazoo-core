%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_transport_http_tests).

-include_lib("eunit/include/eunit.hrl").
-include("../src/kz_auth_scope.hrl").

maybe_deny_access_test_() ->
    AuthDoc = kz_json:new(),
    Method = <<"GET">>,

    Rule1 = fixture("rule-http-1.json"),
    Rule1_1 = kzd_scope_rules:set_precedence(Rule1, <<"deny">>),
    Rule2 = fixture("rule-http-2.json"),
    Rule2_1 = kzd_scope_rules:set_precedence(Rule2, <<"allow">>),

    [{"undefined http path returns false"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, 'undefined', Method, [Rule1]), 'false')
     }
    ,{"<<>> http path returns false"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<>>, Method, [Rule1]), 'false')
     }
    ,{"[] http path returns false"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, [], Method, [Rule1]), 'false')
     }
    ,{"undefined http method returns false"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"hello">>, 'undefined', [Rule1]), 'false')
     }
    ,{"[] rules returns false"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"hello">>, Method, []), 'false')
     }
    ,{"undefined http method returns false"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"hello">>, 'undefined', [Rule1]), 'false')
     }


    ,{"(allow) simple"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts">>, Method, [Rule1]), 'false')
     }
    ,{"(allow) simple *"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/qwerty">>, Method, [Rule1]), 'false')
     }
    ,{"(allow) another simple"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/callflow">>, Method, [Rule1]), 'false')
     }
    ,{"(allow) complex match with no segement"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/device">>, Method, [Rule1]), 'false')
     }
    ,{"(allow) complex match with more segements"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/device/123">>, Method, [Rule1]), 'false')
     }
    ,{"(allow) relative url no other segments"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"user">>, Method, [Rule1]), 'false')
     }
    ,{"(allow) relative url with one more segment"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"user/123">>, Method, [Rule1]), 'false')
     }


    ,{"(deny) simple"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/alerts">>, Method, [Rule1]), 'true')
     }
    ,{"(deny) simple *"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/cdrs">>, Method, [Rule1]), 'true')
     }
    ,{"(deny) another simple"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/cdrs">>, Method, [Rule1]), 'true')
     }
    ,{"(deny) complex match no segements"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/channels">>, Method, [Rule1]), 'true')
     }
    ,{"(deny) complex match with more segements"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/channels/123">>, Method, [Rule1]), 'true')
     }
    ,{"(deny) relative url with no segements"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"pivot">>, Method, [Rule1]), 'true')
     }
    ,{"(deny) relative url with more segments"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"pivot/123">>, Method, [Rule1]), 'true')
     }

    ,{"(precedence deny) simple deny"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/media/123">>, Method, [Rule1_1]), 'true')
     }
    ,{"(precedence deny) simple allow with * match"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/321">>, Method, [Rule1_1]), 'false')
     }
    ,{"(precedence deny) complex match deny"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/devices/123">>, Method, [Rule1_1]), 'true')
     }
    ,{"(precedence deny) complex match allow"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/devices/321">>, Method, [Rule1_1]), 'false')
     }
    ,{"(precedence deny) complex match allow with * in deny and # in allow"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/teletype">>, Method, [Rule1_1]), 'false')
     }
    ,{"(precedence deny) complex match deny with * in deny and # in allow"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/teletype/123">>, Method, [Rule1_1]), 'true')
     }
    ,{"(precedence deny) complex match allow with * in deny and # and moar segments"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/teletype/123/email">>, Method, [Rule1_1]), 'false')
     }
    ,{"(precedence deny) simple allow"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/system_configs">>, Method, [Rule1_1]), 'false')
     }
    ,{"(precedence deny) simpler allow"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/vmboxes">>, Method, [Rule1_1]), 'false')
     }


    ,{"relative url deny with more segments"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"pivot/123">>, Method, [Rule1]), 'true')
     }


    ,{"deny, no catch all if method rule is matched"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/teletype/123">>, Method, [Rule2]), 'true')
     }
    ,{"deny, catch all if no method rules matched"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/devices/123">>, Method, [Rule2]), 'true')
     }

    ,{"allow, catch all if no method rules matched"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, <<"/accounts/123/devices/123">>, Method, [Rule2_1]), 'false')
     }


    ,{"list path"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, [<<"accounts">>, <<"123">>, <<"devices">>], Method, [Rule1]), 'false')
     }
    ,{"list path with empty binary at the begining"
     ,?_assertEqual(kz_auth_transport_http:maybe_deny_access(AuthDoc, [<<>>, <<"accounts">>, <<"123">>, <<"devices">>], Method, [Rule1]), 'false')
     }
    ].


fixture(Filename) ->
    {'ok', JObj} = kz_json:fixture('kazoo_auth', "fixtures/scope_http_rules/" ++ Filename),
    JObj.
