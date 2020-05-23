Terminals

open_paren
close_paren
open_bracket
close_bracket

schema_uri
path

value

equal
not_equal
contains
starts_with
ends_with
greater_than
greater_than_or_equal
less_than
less_than_or_equal
exists

'and'
'or'
'not'
.

Nonterminals
query
filter
valuePath
attrExp
logExp
attrPath
comp
.

Rootsymbol query.

query ->
    filter : {query, '$1'}.

filter ->
    attrExp : '$1'.
filter ->
    logExp : '$1'.
filter ->
    valuePath : '$1'.
filter ->
    open_paren filter close_paren : '$2'.
filter ->
    'not' open_paren filter close_paren : {'cond', 'not', '$3'}.

valuePath ->
    attrPath open_bracket filter close_bracket : {'cond', path, '$1', '$3'}.

attrExp ->
    attrPath exists : {'cond', exists, '$1'}.
attrExp ->
    attrPath comp value : {'cond', '$2', '$1', extract_value('$3')}.

logExp ->
    filter 'or' filter : {'cond', any, ['$1', '$3']}.
logExp ->
    filter 'and' filter : {'cond', all, ['$1', '$3']}.

attrPath ->
    schema_uri path : {'key', [extract_value('$1') | extract_value('$2')] }.
attrPath ->
    path : {'key', extract_value('$1')}.

comp -> equal       : extract_value('$1').
comp -> not_equal       : extract_value('$1').
comp -> contains       : extract_value('$1').
comp -> starts_with       : extract_value('$1').
comp -> ends_with       : extract_value('$1').
comp -> greater_than       : extract_value('$1').
comp -> greater_than_or_equal        : extract_value('$1').
comp -> less_than       : extract_value('$1').
comp -> less_than_or_equal       : extract_value('$1').


Erlang code.

extract_value({_, _, Value}) ->
    Value;
extract_value({Value, _}) ->
    Value.
