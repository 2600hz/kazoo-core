-ifndef(KAPPS_CALL_HEADERS).

%% Since kapps_call.erl module also includes kapi_call_command.hrl headers file, and that file
%% already defined APP_NAME and APP_VERSION macros, these 2 new macros are prefixed with
%% KAPPS_CALL_.
-define(KAPPS_CALL_APP_NAME, <<"kapps_call">>).
-define(KAPPS_CALL_APP_VERSION, <<"1.0.0">>).

-define(KAPPS_CALL_HEADERS, 'true').
-endif.
