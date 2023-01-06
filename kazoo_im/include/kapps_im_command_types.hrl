-ifndef(KAPPS_IM_COMMAND_TYPES_HRL).

-type api_error() :: 'timeout' |
                     'not_found' |
                     'no_endpoints_available' |
                     'strategy_not_implemented' |
                     kz_json:object().
-type kapps_api_error() :: {'error', api_error()}.
-type kapps_api_std_return() :: kapps_api_error() |
                                {'ok', kz_json:object() | kz_term:ne_binary()} |
                                'ok'.

-define(KAPPS_IM_COMMAND_TYPES_HRL, 'true').
-endif.
