%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023-2025 2600Hz
%%% @doc CRM API definitions.
%%% @author Kusal Fernando
%%% @end
%%%-----------------------------------------------------------------------------
-define(CRM_EXCHANGE, <<"crm">>).

-define(CRM_EXCHANGE_TYPE, <<"topic">>).

-define(CRM_ROUTE(A, E), <<"crm.", A/binary, ".", E/binary>>).

