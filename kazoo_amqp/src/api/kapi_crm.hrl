%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023 2600Hz
%%% @doc CRM API definitions.
%%% @author Kusal Fernando
%%% @end
%%%-----------------------------------------------------------------------------
-define(CRM_EXCHANGE, <<"crm">>).

-define(CRM_ROUTE(A, E), <<"crm.", A/binary, ".", E/binary>>).

-define(AUTH_HEADERS, [<<"Event-Category">>
                      ,<<"Connected-App">>
                      ]).

-define(AUTH_RESPONSE_HEADERS, [<<"access_token">>]).

-define(AUTH_RESPONSE_HEADERS_OPT, [<<"instance_url">>
                                   ,<<"signature">>
                                   ,<<"issued_at">>
                                   ,<<"id">>
                                   ,<<"token_type">>
                                   ]).

-define(CALLER_INFO_HEADERS, [<<"Caller-ID">>]).

-define(CALLER_INFO_RESPONSE_HEADERS, [<<"Id">>
                                      ,<<"Caller_Name__c">>
                                      ,<<"Phone_No__c">>
                                      ,<<"Call_Center__c">>
                                      ]).

