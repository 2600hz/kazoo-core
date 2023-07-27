%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023 2600Hz
%%% @doc CRM API definitions.
%%% @author Kusal Fernando
%%% @end
%%%-----------------------------------------------------------------------------
-define(CRM_EXCHANGE, <<"crm">>).

-define(CRM_EXCHANGE_TYPE, <<"topic">>).

-define(CRM_APP_NAME, <<"crm">>).

-define(CRM_APP_VER, <<"5.2">>).

-define(CRM_ROUTE(A, E), <<"crm.", A/binary, ".", E/binary>>).

-define(AUTH_HEADERS, [<<"Client-Id">>
                      ,<<"Client-Secret">>
                      ,<<"Instance-Url">>
                      ]).

-define(AUTH_RESPONSE_HEADERS, [<<"access_token">>]).

-define(AUTH_RESPONSE_HEADERS_OPT, [<<"instance_url">>
                                   ,<<"signature">>
                                   ,<<"issued_at">>
                                   ,<<"id">>
                                   ,<<"token_type">>
                                   ]).

-define(CALLER_INFO_HEADERS, [<<"Caller-ID">>
                             ,<<"Client-Id">>
                             ,<<"Client-Secret">>
                             ,<<"Instance-Url">>
                             ,<<"Access-Token">>
                             ]).

-define(CALLER_INFO_RESPONSE_HEADERS, [<<"Id">>
                                      ,<<"Caller_Name__c">>
                                      ,<<"Phone_No__c">>
                                      ,<<"Call_Center__c">>
                                      ]).

