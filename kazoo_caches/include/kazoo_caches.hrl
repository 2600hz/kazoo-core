-ifndef(KAZOO_CACHES_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-type flush_callback_fun() :: fun((atom()) -> any()).
-type callback_msg() :: 'flush' | 'erase' | 'expire' | 'timeout' | 'store'.
-type callback_fun() :: fun((any(), any(), callback_msg()) -> any()).
-type callback_funs() :: [callback_fun()].
-type origin_tuple() :: {'db', kz_term:ne_binary(), kz_term:ne_binary()} | %% {db, Database, PvtType or Id}
                        {'type', kz_term:ne_binary(), kz_term:ne_binary()} | %% {type, PvtType, Id}
                        {'db', kz_term:ne_binary()} | %% {db, Database}
                        {'db', kz_term:ne_binary(), kz_term:ne_binary() | '_'} | %% {db, Database, Type}
                        {'database', kz_term:ne_binary()} | %% {database, Database} added for notify db create/delete
                        {'type', kz_term:ne_binary()}. %% {type, PvtType}
-type origin_tuples() :: [origin_tuple()].

-record(cache_obj, {key :: any()| '_' | '$1'
                   ,value :: any() | '_' | '$1' | '$2'
                   ,expires_s :: timeout() | '_' | '$3'
                   ,timestamp_ms = kz_time:now_ms() :: pos_integer() | '_' | '$4'
                   ,callback :: callback_fun() | '_' | '$2' | '$3' | '$5' | 'undefined'
                   ,origin :: origin_tuple() | origin_tuples() | '$1' | '_' | 'undefined'
                   ,monitor_pids = [] :: [pid()] | '_'
                   }).
-type cache_obj() :: #cache_obj{}.
-type cache_objs() :: [cache_obj()].

-define(KAZOO_CACHES_HRL, 'true').
-endif.
