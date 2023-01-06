Definitions.

%% Grouping Operators
LPAREN = \(
RPAREN = \)
LBRACKET = \[
RBRACKET = \]

FALSE = 'false'
TRUE = 'true'
NULL = null
NUMBER = [0-9]+
STRING = "[^\"]+"

%% Attribute Operators
EQ = [e|E][q|Q]
NE = [n|N][e|E]
CO = [c|C][o|O]
SW = [s|S][w|W]
EW = [e|E][w|W]
GT = [g|G][t|T]
GE = [g|G][e|E]
LT = [l|L][t|T]
LE = [l|L][e|E]
PR = [p|P][r|R]

%% Logical Operators
AND = [a|A][n|N][d|D]
OR = [o|O][r|R]
NOT = [n|N][o|O][t|T]

SCHEMA_URI = [a-zA-Z]+:[a-zA-Z0-9:\._-]+:

SUBFIELD = \.[a-zA-Z][a-zA-Z0-9_-]*
FIELD = [a-zA-Z][a-zA-Z0-9_-]*
PATH = {FIELD}({SUBFIELD})*


%OPERATORS = {EQ} | {NE} | {CO} | {SW} | {EW} | {GT} | {GE} | {LT} | {LE} | {PR}
%LOGICAL = {AND} | {OR} | {NOT}

WHITESPACE = [\s\t\r\n]+

Rules.

{LPAREN} : {token, {open_paren, TokenLine}}.
{RPAREN}  : {token, {close_paren, TokenLine}}.
{LBRACKET}  : {token, {open_bracket, TokenLine}}.
{RBRACKET}  : {token, {close_bracket, TokenLine}}.

%% OPERATORS
{EQ} : {token, {equal, TokenLine}}.
{NE} : {token, {not_equal, TokenLine}}.
{CO} : {token, {contains, TokenLine}}.
{SW} : {token, {starts_with, TokenLine}}.
{EW} : {token, {ends_with, TokenLine}}.
{GT} : {token, {greater_than, TokenLine}}.
{GE} : {token, {greater_than_or_equal, TokenLine}}.
{LT} : {token, {less_than, TokenLine}}.
{LE} : {token, {less_than_or_equal, TokenLine}}.
{PR} : {token, {exists, TokenLine}}.

%% LOGICAL
{AND} : {token, {list_to_atom(string:lowercase(TokenChars)), TokenLine}}.
{OR} : {token, {list_to_atom(string:lowercase(TokenChars)), TokenLine}}.
{NOT} : {token, {list_to_atom(string:lowercase(TokenChars)), TokenLine}}.

{STRING}     : {token, {value, TokenLine, {binary, extract_string(TokenChars)}}}.
{NUMBER}\.{NUMBER} : {token, {value, TokenLine, {float, list_to_float(TokenChars)}}}.
{NUMBER}        : {token, {value, TokenLine, {integer, list_to_integer(TokenChars)}}}.
{FALSE} : {token, {value, TokenLine, {boolean, 'false'}}}.
{TRUE} : {token, {value, TokenLine, {boolean, 'true'}}}.
{NULL} : {token, {value, TokenLine, {is_null, null}}}.

{SCHEMA_URI}     : {token, {schema_uri, TokenLine, list_to_binary(string:trim(TokenChars, trailing, ":"))}}.
{PATH}     : {token, {path, TokenLine, binary:split(list_to_binary(TokenChars), <<".">>, [global])}}.
{FIELD}     : {token, {field, TokenLine, list_to_binary(TokenChars)}}.
{SUBFIELD}     : {token, {subfield, TokenLine, list_to_binary(string:sub_string(TokenChars, 2))}}.

{WHITESPACE} : skip_token.

Erlang code.

extract_string(Chars) ->
    list_to_binary(lists:sublist(Chars, 2, length(Chars) - 2)).

-type error_descriptor() :: term().
-type error_line() :: integer().
-type error_info() :: {error_line(), module(), error_descriptor()}.
-type token() :: tuple().
-type tokens() :: [token()].

-type string_ret() :: {ok, tokens(), integer()} | error_info().

-spec string(string()) -> string_ret().
-spec string(string(), integer()) -> string_ret().

-type chars() :: string() | eof.
-type cont() :: [] | tuple().
-type token_ret() :: {ok, token(), integer()} | {eof, integer()} | error_info().
-type tokens_ret() :: {ok, tokens(), integer()} | {eof, integer()} | error_info().

-spec token(cont(), chars()) -> {more, tuple()} | {done, token_ret(), chars()}.
-spec token(cont(), chars(), integer()) -> {more, tuple()} | {done, token_ret(), chars()}.

-spec tokens(cont(), chars()) -> {more, tuple()} | {done, tokens_ret(), chars()}.
-spec tokens(cont(), chars(), integer()) -> {more, tuple()} | {done, tokens_ret(), chars()}.

-spec format_error(error_info()) -> string().
