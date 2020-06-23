-module(kz_auth_scope_tests).

-include_lib("eunit/include/eunit.hrl").
-include("kz_auth_scope.hrl").

-define(OPENID, <<"openid">>).
-define(PROFILE, <<"profile">>).
-define(EMAIL, <<"email">>).
-define(ROLE, <<"admin">>).
-define(DEF_ROLE, 'undefined').

-define(SCOPE_STR, kz_binary:join([?OPENID, ?PROFILE, ?EMAIL], " ")).
-define(SCOPE_SIMPLE, #scope{scope=?OPENID}).
-define(SCOPE_DEFAULT, #scope{role=?DEF_ROLE, scope=?OPENID}).
-define(SCOPE_SINGLETON, #scope{role=?ROLE, scope=?OPENID}).
-define(SCOPE_SINGLETON_LIST, [?SCOPE_SINGLETON]).
-define(SCOPE_DEFAULT_LIST
	   ,lists:usort([#scope{role=?DEF_ROLE, scope=?OPENID}
	   				,#scope{role=?DEF_ROLE, scope=?PROFILE}
	   				,#scope{role=?DEF_ROLE, scope=?EMAIL}
	   				])
	   ).
-define(SCOPE_LIST
	   ,lists:usort([#scope{role=?ROLE, scope=?OPENID}
	   				,#scope{role=?ROLE, scope=?PROFILE}
	   				,#scope{role=?ROLE, scope=?EMAIL}
	   				])
	   ).

%% Test term casting to scope record
parse_test_() ->
	[{"Default instantiation test"
	 ,?_assertEqual(?SCOPE_SIMPLE, kz_auth_scope:parse(?OPENID))
	 }
	,{"Scope with privilege test"
	 ,?_assertEqual(?SCOPE_SINGLETON
				 ,kz_auth_scope:parse(?OPENID, ?ROLE)
				 )
	 }	
	].

%% Test raw string to list of scopes
parse_raw_test_() ->
	[{"Raw string defaults parse test"	
	 ,?_assertEqual([?SCOPE_DEFAULT]
	 			   ,kz_auth_scope:parse_raw(?OPENID)
	 			   )
	 }
	,{"Raw string singleton parse test"	
	 ,?_assertEqual(?SCOPE_SINGLETON_LIST
	 			   ,kz_auth_scope:parse_raw(?OPENID, ?ROLE)
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