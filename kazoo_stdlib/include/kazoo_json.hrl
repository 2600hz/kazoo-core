-ifndef(KAZOO_JSON_HRL).

-include("kz_types.hrl").

%% How do we wrap proplists to denote they're json objects?
%% -define(JSON_WRAPPER(Proplist), {struct, Proplist}).
%% -define(IS_JSON_GUARD(Obj), is_tuple(Obj)
%%         andalso element(1, Obj) =:= 'struct'
%%         andalso is_list(element(2, Obj))
%%        ).

-define(JSON_WRAPPER(Proplist), {Proplist}).

-define(EMPTY_JSON_OBJECT, ?JSON_WRAPPER([])).

-type non_object_json_term() :: boolean()
                              | json_string() | <<>>
                              | json_number()
                              | json_array().

-type non_null_json_term() :: non_object_json_term()
                            | object().

%% Denotes term definitions for JSON.

-type flat_json_term() :: boolean()
                        | json_string() | <<>>
                        | json_number()
                        | flat_json_array().
%% Denotes all valid term definitions for JSON for a flatten JSON.

-type api_json_term() :: json_term() | 'undefined'.
%% Denotes all valid term definitions or `undefined' for JSON.

-ifdef(PROPER).
-type json_term() :: non_object_json_term() | object().

%% We want non-empty keys when generating objects
-type keys() :: [key(),...].
-type path() :: [key() | pos_integer(),...].

%% Denotes a full_path/value pair of a flattened JSON object.
-type flat_kv() :: {path(), flat_json_term()}.

%% Denotes array in JSON.
-type json_array() :: json_terms() | [].

-else.
-type json_term() :: non_null_json_term() | 'null'.

%% Denotes a list of JSON keys.
-type keys() :: [key()].
%% Denotes a path to (or n-th element of) a value in a JSON.
-type path() :: [key() | pos_integer()].

%% Denotes a full_path/value pair of a flattened JSON object.
-type flat_kv() :: {path(), flat_json_term() | 'null'}.

%% Denotes array in JSON.
-type json_array() :: json_terms().

-endif.

%% Denotes all valid term definitions for JSON.
-type json_terms() :: [json_term()].

-type flat_json_array() :: [flat_json_term()].

-type json_string() :: kz_term:ne_binary().

-type json_number() :: integer() | float().
%% Denotes number in JSON.

-type json_kv() :: {key(), json_term()}.
%% Denotes JSON KV Erlang representation.

-type json_proplist() :: [json_kv()].
%% Denotes proplist of JSON object Erlang representation.

-type json_ne_proplist() :: [json_kv(),...].
%% Denotes proplist of JSON object Erlang representation.

-type empty_object() :: ?EMPTY_JSON_OBJECT.

-ifdef(PROPER).
-type object() :: ?JSON_WRAPPER(json_proplist()) | empty_object().
-else.
-type object(Key, Value) :: ?JSON_WRAPPER([{Key, Value}]) | empty_object().
-type object() :: ?JSON_WRAPPER(json_proplist()) | empty_object() | map().
%% Denotes JSON object Erlang representation, {@link json_proplist} wrapped in `{}'.
-endif.

-type ne_map() :: #{any() := any()}.
-type ne_object() :: ?JSON_WRAPPER(json_ne_proplist()) | ne_map().

-type objects() :: [object()].
%% Denotes a list of {@link object()}.

-type ne_objects() :: [ne_object(),...].
%% Denotes a non empty list of {@link object()}.

%% Denotes a flatten version of JSON proplist, `[{full_path, value}]'.
-type flat_proplist() :: [flat_kv()].
-type ne_flat_proplist() :: [flat_kv(),...].

%% Denotes a JSON of flatten version of JSON proplist, same as {@link flat_proplist()} but wrapped in `{}'.
-type flat_object() :: ?JSON_WRAPPER(flat_proplist()).
-type ne_flat_object() :: ?JSON_WRAPPER(ne_flat_proplist()).

%% A list of flatten JSON objects.
-type flat_objects() :: [flat_object()].

%% Denotes a JSON key.
-type key() :: json_string().

-type ne_path() :: [key() | pos_integer(),...].
-type paths() :: [path()].
%% Denotes a list of paths (or n-th element of) a value in a JSON.

-type json_proplists() :: [json_proplist()].

-type encode_option() :: 'uescape'
                       | 'pretty'
                       | 'force_utf8'
                       | 'escape_forward_slashes'
                       | 'canonical' % RFC 8785
                       | {'bytes_per_iter', non_neg_integer()}
                       | {'bytes_per_red', non_neg_integer()}.
%% `jiffy' encode option.

-type encode_options() :: [encode_option()].
%% `jiffy' encode option.

-define(KAZOO_JSON_HRL, 'true').
-endif.
