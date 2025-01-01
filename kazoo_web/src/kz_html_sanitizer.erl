%%%-------------------------------------------------------------------
%%% @author dhuynh
%%% @copyright (C) 2023-2025, 2600Hz
%%% @doc
%%% Check the HTML string contains the Cross Site Scripting (XSS)
%%% 3 important elements will be checked
%%* * some attributes and their values like href, src,...
%%% * CSS properties and their values, formatted likes &lt;word-word&gt;: &lt;word-word&gt;
%%% * script tag
%%% If any of them are found, scrub them.
%%% @end
%%%-------------------------------------------------------------------
-module(kz_html_sanitizer).

%% API
-export([apply/1
        ,parse/1
        ,simple_parse/1
        ,traverse/1
        ,scrub_css/1
        ,to_html/1
        ,validate_css_keyword/1
        ,validate_css_unit/1
        ,validate_scheme/1
        ]).

-include("kazoo_html_sanitizer_whitelist.hrl").

-type html_node() :: {string() | binary(), [html_attr()], [html_node() | list()]}.
-type html_attr() :: list() | binary().

-spec apply(binary() | string()) -> binary().
apply(HTML) ->
    Parsed = parse(HTML),
    Traversed = traverse(Parsed),
    to_html(Traversed).

-spec simple_parse(binary()) -> [html_node()].
simple_parse(<<HTML/binary>>) ->
    HTML_1 = <<"<dummy_tag>", HTML/binary, "</dummy_tag>">>,
    {_, _, ParsedHTML} = kz_mochiweb_html:parse(HTML_1),
    ParsedHTML.

-spec parse(binary()) -> html_node().
parse(<<HTML/binary>>) ->
    HTML1 = remove_cdata_sections_before_scrub(HTML),
    HTML2 = before_parse(HTML1),
    HTML3 = <<"<html_sanitizer>", HTML2/binary, "</html_sanitizer>">>,
    {_, _, ParsedHTML} = kz_mochiweb_html:parse(HTML3),
    collapse_list(ParsedHTML).

-spec to_html(html_node() | [html_node()]) -> binary().
to_html(Tokens) when is_list(Tokens)->
    HTML = kz_mochiweb_html:to_html({"html_sanitizer", [], Tokens}),
    HTML1 = re:replace(HTML
                      ,"^<html_sanitizer>"
                      ,""
                      ,[{'return', 'binary'}, 'global']
                      ),
    HTML2 = re:replace(HTML1
                      ,"<\/html_sanitizer>$"
                      ,""
                      ,[{'return', 'binary'}, 'global']
                      ),
    HTML3 = re:replace(HTML2
                      ,"&lt;/html_sanitizer&gt;"
                      ,""
                      ,[{'return', 'binary'}, 'global']
                      ),
    after_to_html(HTML3);
to_html(Token) -> to_html([Token]).

remove_cdata_sections_before_scrub(HTML) ->
    re:replace(HTML
              ,"\\<\\!\\[CDATA\\["
              ,""
              ,['global', {'return', 'binary'}]
              ).

before_parse(HTML) ->
    HTML_1 = re:replace(HTML
                       ,"(>)(\r?\n)", "\\1 " ++ ?REPLACEMENT_LINEBREAK ++ " \\2"
                       ,[{'return', 'binary'}, 'global']
                       ),
    HTML_2 = re:replace(HTML_1
                       ,"(>)(\ +)(<)", "\\1 " ++ ?REPLACEMENT_SPACE ++ "\\2\\3"
                       ,[{'return', 'binary'}, 'global']
                       ),
    re:replace(HTML_2
              ,"(>)(\t+)(<)", "\\1 " ++ ?REPLACEMENT_TAB ++ "\\2\\3"
              ,[{'return', 'binary'}, 'global']
              ).

after_to_html(HTML) ->
    HTML1 = re:replace(HTML
                      ,"(\ ?" ++ ?REPLACEMENT_LINEBREAK ++ " )(\r?\n)","\\2"
                      ,[{'return', 'binary'}, 'global']
                      ),
    HTML2 = re:replace(HTML1
                      ,"(\&gt\;|>)(\ +)(" ++ ?REPLACEMENT_SPACE ++ ")(\ +)(\&lt\;|<)"
                      ,"\\1\\4\\5"
                      ,[{'return', 'binary'}, 'global']
                      ),
    re:replace(HTML2
              ,"(\&gt\;|>)(\ +)(" ++ ?REPLACEMENT_TAB ++ ")(\t+)(\&lt\;|<)"
              ,"\\1\\4\\5"
              ,[{'return', 'binary'}, 'global']
              ).

-spec traverse(list() | html_node() | tuple()) -> html_node() | html_attr().
traverse(Nodes) when is_list(Nodes)->
    [Res || Node <- Nodes,
            Res <- [handle_node(Node)],
            Res =/= 'undefined'
    ];
traverse(Nodes) -> traverse([Nodes]).

handle_node({Tag, Attr, Children}) ->
    Children_1 = traverse(Children),
    scrub({Tag, Attr, Children_1});
handle_node({Token, Children}) ->
    Children_1 = traverse(Children),
    Children_2 = collapse_list(Children_1),
    scrub({Token, Children_2});
handle_node(Any) -> scrub(Any).

scrub({<<"script">>, _, _}) -> 'undefined';
scrub({<<"style">>, Attrs, Text}) ->
    Attrs_1 = [X || X <- Attrs,
                    is_style_attribute_valid(X) =/= 'undefined'],
    {<<"style">>, Attrs_1, scrub_css(Text)};
scrub({Tag, Attrs, Data}) ->
    Attrs_1 = [Res || X <- Attrs,
                      Res <- [handle_attribute_and_value(X)],
                      Res =/= 'undefined'
              ],
    {Tag, Attrs_1, Data};
scrub({'comment', _}) -> 'undefined';
scrub({_, Children}) -> Children;
scrub(<<32,239,188,191,32, Rest/binary>>) -> Rest;
scrub(<<32,239,189,191,32, Rest/binary>>) -> <<" ",Rest/binary>>;
scrub(<<32,239,190,191,32, Rest/binary>>) -> Rest;
scrub(Any) -> Any.

handle_attribute_and_value({<<"style">>, Value}) ->
    {<<"style">>, scrub_css(Value)};
handle_attribute_and_value({Attribute, Value}) ->
    case lists:member(Attribute, ?ATTRIBUTES_CAN_TRIGGER_XSS) of
        'true' -> scrub_attribute_with_reference_src(Attribute, Value);
        'false' -> {Attribute, Value}
    end.

scrub_attribute_with_reference_src(_Attr,<<"&", _/binary>>) -> [];
scrub_attribute_with_reference_src(Attr, <<"data:", _/binary>> = Src) ->
    case re:run(Src, ?ALLOWED_MIMETYPES_SOURCE, ['global']) of
        {'match', _} -> {Attr, Src};
        'nomatch' -> 'undefined'
    end;
scrub_attribute_with_reference_src(Attr, Src) ->
    case validate_scheme(Src) of
        'true' -> {Attr, Src};
        'false' -> 'undefined'
    end.

-spec scrub_css(term()) -> term().
scrub_css([]) -> [];
scrub_css([Text]) ->
    Text1 = re:replace(Text
                      ,"(\\/\\*|\\*\\/|<!--|-->)"
                      ," "
                      ,[{'return', 'list'}, 'global']
                      ),
    Text2 = case re:run(Text1
                       ,"([-\\w]+)\\s*:\\s*([^:;]*)"
                       ,['global', {'capture', 'all', 'binary'}]
                       ) of
                {'match', List} -> lists:foldl(fun scrub_css_property/2, Text1, List);
                'nomatch' -> Text1
            end,
    [list_to_binary(Text2)];
scrub_css(Text) ->
    [Res] = scrub_css([Text]),
    Res.

scrub_css_val(Val) ->
    Val1 =
        case re:run(Val, <<"(\\\\|\&)">>, ['global']) of
            {'match', _} -> <<>>;
            'nomatch' -> Val
        end,
    case re:run(Val1, <<"(\\S+)">>,['global', {'capture', 'all_but_first', 'binary'}]) of
        {'match', MatchList} -> lists:foldl(fun scrub_css_property_value/2, Val1, MatchList);
        'nomatch' -> Val1
    end.

-spec validate_css_keyword(binary() | string()) -> boolean().
validate_css_keyword(Val) ->
    'nomatch' =/= re:run(Val, "^[a-zA-Z]+\-?[a-zA-Z]+$").

-spec validate_css_unit(binary() | string()) -> boolean().
validate_css_unit(Val) ->
    'nomatch' =/= re:run(Val, ?CSS_UNIT_REGEX).

-spec validate_scheme(binary() | string()) -> boolean().
validate_scheme(Src) ->
    case re:run(Src, ?PROTOCOL_SEPARATOR, ['multiline', 'caseless']) of
        {'match', _Matches} ->
            case re:run(Src
                       ,?SCHEME_CAPTURE
                       ,[{'capture', ['scheme', 'other_schemes'], 'binary'}, 'multiline', 'caseless']
                       )
            of
                {'match', [<<>>, X]} -> lists:member(X, ?VALID_SCHEMES);
                {'match', [X, <<>>]} -> lists:member(X, ?VALID_SCHEMES);
                _ -> 'false'
            end;
        'nomatch' -> 'true'
    end.

is_style_attribute_valid({Attr, Value}) ->
    case lists:member(Attr, [<<"media">>, <<"type">>, <<"scoped">>]) of
        'true' -> {Attr, Value};
        'false' -> 'undefined'
    end.

scrub_css_property([Prop_Val, Property, Value], Acc) ->
    Replace =
        case validate_css_keyword(Property) of
            'true' ->
                [Property, ": ", scrub_css_val(Value)];
            'false' -> ""
        end,
    string:replace(Acc, Prop_Val, Replace).

scrub_css_property_value([Value], Acc) ->
    %% Val2 may contain '(' or ')'  , that would cause error for re:replace
    %% so this one should use string:replace
    case validate_css_keyword(Value)
        orelse validate_css_unit(Value) of
        'true' -> Acc;
        'false' -> binary:replace(Acc, Value, <<>>)
    end.

collapse_list([X]) -> X;
collapse_list(L) -> L.
