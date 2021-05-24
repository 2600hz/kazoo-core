-ifndef(KZ_COUCH_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("couchbeam/include/couchbeam.hrl").
-include_lib("kazoo_couch/include/kazoo_couch.hrl").

-define(TIMEOUT, ?MILLISECONDS_IN_HOUR). %% check every hour

-define(COMPACT_THRESHOLD, 500).
-define(MIN_DISK_SIZE, 131072).
-define(DEFAULT_PORT, 5984).
-define(DEFAULT_ADMIN_PORT, 5986).

-define(RETRY_504(F), kz_couch_util:retry504s(fun() -> F end)).

-define(CONFIG_CAT, <<"kazoo_couch">>).

-type couchbeam_errors() :: 'not_found' | 'conflict' | 'failed' |
                            'precondition_failed' | 'db_not_reachable' |
                            'db_not_found' | 'worker_is_dead' | 'invalid_db_name' |
                            'unknown_req_id' | 'retry_later' |
                            'req_timedout' | 'sel_conn_closed' |
                            'invalid_view_name' | 'gateway_timeout' |
                            {integer(), _} | % {error_code, body}
                            integer() |
                            {'EXIT', _} |
                            {'url_parsing_failed', _} |
                            {'conn_failed', _} | 'tcp_closed' |
                            {'ok', string(), _, _}.
-type couchbeam_error() :: {'error', couchbeam_errors()}.

-record(kz_couch_connection, {host = "localhost" :: string()
                             ,port = ?DEFAULT_PORT :: inet:port_number()
                             ,username = "" :: string()
                             ,password = "" :: string()
                             ,options = [] :: kz_term:proplist()
                             }).
-type couch_connection() :: #kz_couch_connection{}.
-type couch_connections() :: [couch_connection()].

-type couchbeam_db() :: #db{}.

-record(kz_copy_doc, {source_dbname  :: kz_term:api_ne_binary()
                     ,source_doc_id  :: kz_term:api_ne_binary()
                     ,dest_dbname = 'undefined' :: kz_term:api_ne_binary()
                     ,dest_doc_id = 'undefined' :: kz_term:api_ne_binary()
                     }).
-type copy_doc() :: #kz_copy_doc{}.

-define(NO_OPTIONS, ['cookie', 'admin_port', 'compact_automatically']).
-define(ATOM_OPTIONS, ['pool', 'pool_name']).

-type couch_version() :: 'couchdb_1_6' | 'couchdb_2' | 'couchdb_3' | 'bigcouch'.

-define(KZ_COUCH_HRL, 'true').
-endif.
