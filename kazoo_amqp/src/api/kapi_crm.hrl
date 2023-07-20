%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023 2600Hz
%%% @doc CRM API definitions.
%%% @author Kusal Fernando
%%% @end
%%%-----------------------------------------------------------------------------
-define(CRM_EXCHANGE, <<"crm">>).

-define(CRM_ROUTE(A, E), <<"crm.", A/binary, ".", E/binary>>).

-define(AUTH_HEADERS, [
                       <<"Event-Category">>
                      ,<<"Connected-App">>
                      ]).

-define(CALLER_INFO_HEADERS, [<<"Caller-ID">>]).

