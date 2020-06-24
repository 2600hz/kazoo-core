%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2020, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope_tests).

-include_lib("eunit/include/eunit.hrl").
-include("kz_auth_scope.hrl").

-define(ROLE, <<"admin">>).
-define(DEF_ROLE, 'undefined').

-define(SCOPE_STR, kz_binary:join([?OIDC_OPENID, ?OIDC_PROFILE, ?OIDC_EMAIL], " ")).
-define(SCOPE_SIMPLE, #scope{scope=?OIDC_OPENID}).
-define(SCOPE_DEFAULT, #scope{role=?DEF_ROLE, scope=?OIDC_OPENID}).
-define(SCOPE_SINGLETON, #scope{role=?ROLE, scope=?OIDC_OPENID}).
-define(SCOPE_SINGLETON_LIST, [?SCOPE_SINGLETON]).
-define(SCOPE_DEFAULT_LIST
       ,lists:usort([#scope{role=?DEF_ROLE, scope=?OIDC_OPENID}
                    ,#scope{role=?DEF_ROLE, scope=?OIDC_PROFILE}
                    ,#scope{role=?DEF_ROLE, scope=?OIDC_EMAIL}
                    ])
       ).
-define(SCOPE_LIST
       ,lists:usort([#scope{role=?ROLE, scope=?OIDC_OPENID}
                    ,#scope{role=?ROLE, scope=?OIDC_PROFILE}
                    ,#scope{role=?ROLE, scope=?OIDC_EMAIL}
                    ])).

%% Test term casting to scope record
parse_test_() ->
    [{"Default instantiation test"
     ,?_assertEqual(?SCOPE_SIMPLE, kz_auth_scope:parse(?OIDC_OPENID))
     }
    ,{"Scope with privilege test"
     ,?_assertEqual(?SCOPE_SINGLETON
                   ,kz_auth_scope:parse(?OIDC_OPENID, ?ROLE)
                   )
     }
    ].

%% Test raw string to list of scopes
parse_raw_test_() ->
    [{"Raw string defaults parse test"
     ,?_assertEqual([?SCOPE_DEFAULT]
                   ,kz_auth_scope:parse_raw(?OIDC_OPENID)
                   )
     }
    ,{"Raw string singleton parse test"
     ,?_assertEqual(?SCOPE_SINGLETON_LIST
                   ,kz_auth_scope:parse_raw(?OIDC_OPENID, ?ROLE)
                   )
     }
    ,{"Raw string mutliple scopes parse test"
     ,?_assertEqual(?SCOPE_LIST
                   ,lists:reverse(kz_auth_scope:parse_raw(?SCOPE_STR, ?ROLE)))
     }
    ,{"Raw string mutliple scope binaries and dedupe"
     ,?_assertEqual(?SCOPE_DEFAULT_LIST
                   ,lists:reverse(kz_auth_scope:parse_raw([?SCOPE_STR, ?SCOPE_STR])))
     }
    ].
