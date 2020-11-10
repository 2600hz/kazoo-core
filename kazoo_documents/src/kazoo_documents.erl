-module(kazoo_documents).

-type doc_validation_error() :: {kz_json:path(), kz_term:ne_binary(), kz_json:object()}.
-type doc_validation_errors() :: [doc_validation_error()].
-type doc_validation_acc() :: {kz_doc:doc(), doc_validation_errors()}.
-type doc_validation_fun() :: fun((kz_term:ne_binary(), doc_validation_acc()) -> doc_validation_acc()) |
                              fun((kz_term:ne_binary(), kz_term:api_ne_binary(), doc_validation_acc()) -> doc_validation_acc()).
-type doc_validation_after_fun() :: fun((doc_validation_acc()) -> doc_validation_acc()) | 'undefined'.
-type doc_validation_return() :: {'true', kz_doc:doc()} |
                                 {'validation_errors', doc_validation_errors()} |
                                 {'system_error', atom() | {atom(), kz_term:ne_binary()}}.
-export_type([doc_validation_error/0, doc_validation_errors/0
             ,doc_validation_acc/0, doc_validation_fun/0
             ,doc_validation_after_fun/0
             ,doc_validation_return/0
             ]).
