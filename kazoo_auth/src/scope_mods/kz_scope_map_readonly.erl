-module(kz_scope_map_readonly).

-export([map/2]).

-include("kz_auth_scope.hrl").

-define(RO_CLAIM, <<"_read_only">>).

%%------------------------------------------------------------------------------
%% @doc map auth properties to claims
%% @end
%%------------------------------------------------------------------------------
-spec map(kz_term:api_binaries(), kz_term:proplist()) -> kz_term:proplist().
map(_Map, _Props) ->
	[{?RO_CLAIM, 'true'}].

