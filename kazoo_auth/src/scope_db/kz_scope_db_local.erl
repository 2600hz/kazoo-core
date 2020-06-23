-module(kz_scope_db_local).
	
-behaviour('kz_scope_db').

-include("kazoo_stdlib/include/kz_databases.hrl").
-include("kz_auth_scope.hrl").

-export ([scopes/0
		 ,scope/1, has_scope/1		 			 
		 ,claims/1		 
		 ,mod/1
		 ,privileges/1
		 ]).

%%------------------------------------------------------------------------------
%% @doc Fetch all scopes
%% @end
%%------------------------------------------------------------------------------
-spec scopes() -> {'ok', kz_json:objects()} | scope_error().
scopes() ->
	Options = ['include_docs'], 
	case kz_datamgr:get_results(?KZ_IAM_DB, <<"scopes/list_by_id">>, Options) of
		{'ok', Scopes} -> {'ok', Scopes};
		{'error', _}=Error -> Error		
	end.

%%------------------------------------------------------------------------------
%% @doc Fetch a scope by name
%% @end
%%------------------------------------------------------------------------------
-spec scope(kz_term:ne_binary()) -> kz_doc:doc() | scope_error().
scope(Scope) -> 
	case kz_datamgr:open_cache_doc(?KZ_IAM_DB, Scope) of
		{'ok', Doc} ->
			Doc;
		{'error', _}=Error -> Error
	end.

-spec has_scope(kz_term:ne_binary()) -> boolean().
has_scope(Scope) ->
	case scope(Scope) of
		{'error', _} -> 'false';
		_ -> 'true'
	end.

%%------------------------------------------------------------------------------
%% @doc Fetch claims for a scope
%% @end
%%------------------------------------------------------------------------------
-spec claims(kz_term:binary()) -> kz_json:objects() | scope_error().
claims(Scope) ->	
	case scope(Scope) of
		{'error', _}=Error -> Error;
		Doc -> 
			kzd_scope:claims(Doc)					
	end.

% %%------------------------------------------------------------------------------
% %% @doc Fetch mapping module for a Scope
% %% @end
% %%------------------------------------------------------------------------------
-spec mod(kz_term:binary()) -> kz_json:objects() | scope_error().
mod(Scope) ->	
	case scope(Scope) of
		{'error', _}=Error -> Error;
		Doc -> 
			kzd_scope:mod(Doc)					
	end.

% %%------------------------------------------------------------------------------
% %% @doc Fetch scope privileges
% %% @end
% %%------------------------------------------------------------------------------
-spec privileges(kz_term:binary()) -> kz_json:objects() | scope_error().
privileges(Scope) ->	
	case scope(Scope) of
		{'error', _}=Error -> Error;
		Doc -> 
			kzd_scope:privileges(Doc)					
	end.
