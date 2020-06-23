%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-ifndef(KZ_AUTH_SCOPE_HRL).

% Token Definitions
-define(COMMA_SEP, <<",">>).
-define(ENTITY_SEP, <<":">>).
-define(RESOURCE_SEP, <<".">>).
-define(SEMI_SEP, <<";">>).
-define(SPACE_SEP, <<" ">>).
-define(SCOPE_SEPARATORS, [?SPACE_SEP
						  ,?COMMA_SEP
						  ,?SEMI_SEP
						  ]).

-define(READ_ONLY, <<"_read_only">>).

% Define OIDC Scopes
-define(OIDC_EMAIL, <<"email">>).
-define(OIDC_OPENID, <<"openid">>).
-define(OIDC_PROFILE, <<"profile">>).
-define(OIDC_SCOPES, [?OIDC_EMAIL
					 ,?OIDC_OPENID
					 ,?OIDC_PROFILE
					 ]).

% Default Kazoo Scopes
-define(SYS_ID, <<"identity">>).
-define(SYS_RBAC, <<"role">>).
-define(SYS_READ_ONLY, <<"read_only">>).
-define(SYS_SCOPES, [?SYS_ID
					,?SYS_RBAC
					,?SYS_READ_ONLY
					]).

% Minimum Viable Scopage
-define(DEFAULT_SCOPES, [?OIDC_OPENID						  
						,?SYS_ID
						,?SYS_RBAC						  						   
						]).

-define(READ, <<"read">>).
-define(WRITE, <<"write">>).
-define(FULL_CONTROL, <<"all">>).

-type scope_priv() :: kz_term:api_ne_binary().

-type scope_error() :: {'error', 'bad_scope'} |
					   {'error', kz_term:api_ne_binary()}.		      

-record(scope, {role = 'undefined' 			:: kz_term:api_ne_binary()
			   ,scope = 'undefined' 		:: kz_term:api_ne_binary()
               ,privileges = 'undefined' 	:: scope_priv() 
               ,source = 'undefined'		:: kz_term:api_ne_binary()
               }).

-type scope() :: #scope{}.
-type scopes() :: [#scope{}].

-define(KZ_AUTH_SCOPE_HRL, 'true').
-endif.