%%%-------------------------------------------------------------------
%%% @copyright (C) 2024, 2600Hz
%%% @doc
%%% Check the HTML string contains the Cross Site Scripting (XSS)
%%% 3 important elements will be checked
%%* * some attributes and their values like href, src,...
%%% * CSS properties and their values, formatted likes &lt;word-word&gt;: &lt;word-word&gt;
%%% * script tags
%%% @end
%%%-------------------------------------------------------------------
-module(kz_html_xss).

%% API
-export([has_any_xss_items/1
        ,get_xss_items/1
        ]).

-include("kazoo_html_sanitizer_whitelist.hrl").

%% @doc
%% Check if the HTML input can contain Cross-Site Scripting items
%% If it detects any XSS item, returns true. Otherwise, it continue traverse the next node
%% NOTES: has_any_css_items/1 and get_css_items/1 do not use the same handler function
%% Because has_any_css_items/1 stops and returns true when it meets the first XSS item
%% get_css_items/1 has to traverse all HTML nodes to collect all XSS items
%% @end
-spec has_any_xss_items(binary()) -> boolean().
has_any_xss_items(<<HTML/binary>>) ->
    ParsedHTML = kz_html_sanitizer:simple_parse(HTML),
    has_any_xss_items_in_nodes(ParsedHTML).

has_any_xss_items_in_nodes([]) -> 'false';
has_any_xss_items_in_nodes([Node|Rest]) ->
    case any_xss_items_handler(Node) of
        'true' -> 'true';
        'false' -> has_any_xss_items_in_nodes(Rest)
    end.

any_xss_items_handler({'comment', _}) -> 'false';
any_xss_items_handler({_, SubNode}) ->
    has_any_xss_items_in_nodes(SubNode);

any_xss_items_handler({<<"script">>, _Attrs, _SubNode}) -> 'true';
any_xss_items_handler({<<"style">>, _Attrs, Text}) ->
    lists:any(fun find_xss_in_css/1, Text);
any_xss_items_handler({_Tag, Attrs, SubNode}) ->
    find_xss_in_attributes(Attrs)
        orelse has_any_xss_items_in_nodes(SubNode);
any_xss_items_handler(<<_Node/binary>>) -> 'false'.

%% @doc
%% Collect all XSS items exist in HTML nodes and return a list
%% with tags and their content that have XSS
%% @end
-spec get_xss_items(binary()) -> list().
get_xss_items(<<HTML/binary>>) ->
    ParsedHTML = kz_html_sanitizer:simple_parse(HTML),
    get_xss_items(ParsedHTML, []).

get_xss_items([], Acc) -> lists:flatten(Acc);
get_xss_items([Node|Rest], Acc) ->
    XssNode = get_xss_items_handler(Node),
    get_xss_items(Rest, [XssNode|Acc]).

get_xss_items_handler({'comment', _}) -> [];
get_xss_items_handler({_, SubNode}) -> get_xss_items(SubNode, []);
get_xss_items_handler({<<"script">>, _Attrs, _SubNode} = Node) ->
    kz_html_sanitizer:to_html(Node);
get_xss_items_handler({<<"style">>, _Attrs, Text} = Node) ->
    case lists:any(fun find_xss_in_css/1, Text) of
        'false' -> [];
        'true' -> kz_html_sanitizer:to_html(Node)
    end;
get_xss_items_handler({_Tag, Attrs, SubNode}=Node) ->
    XssSubNode = get_xss_items(SubNode, []),
    XssAttrs =
        case find_xss_in_attributes(Attrs) of
            'false' -> [];
            'true' -> kz_html_sanitizer:to_html(Node)
        end,
    [XssSubNode, XssAttrs];
get_xss_items_handler(<<_Node/binary>>) -> [].

find_xss_in_attributes(Attrs) ->
    lists:any(fun find_xss_in_attribute/1, Attrs).

-spec find_xss_in_attribute(tuple()) -> term().
find_xss_in_attribute({<<"style">>, Val}) ->
    find_xss_in_css(Val);
find_xss_in_attribute({Attribute, Value}) ->
    case lists:member(Attribute, ?ATTRIBUTES_CAN_TRIGGER_XSS) of
        'true' -> find_xss_in_val(Attribute, Value);
        'false' -> 'false'
    end.

find_xss_in_val(_Attr, <<"&", _/binary>>=_Val) ->
    'true';
find_xss_in_val(_Attr, <<"data:", _/binary>> = Src) ->
    'nomatch' =:= re:run(Src, ?ALLOWED_MIMETYPES_SOURCE, ['global']);
find_xss_in_val(_Attr, Src) ->
    not kz_html_sanitizer:validate_scheme(Src).

find_xss_in_css(Text) ->
    Text1 = re:replace(Text
                      ,<<"(\\/\\*|\\*\\/|<!--|-->)">>
                      ,<<" ">>
                      ,[{'return', 'binary'}, 'global']
                      ),
    case re:run(Text1
               ,<<"([-\\w]+)\\s*:\\s*([^:;]*)">>
               ,['global', {'capture', 'all_but_first', 'binary'}]
               )
    of
        {'match', MatchList} -> lists:any(fun validate_css_property/1, MatchList);
        'nomatch' -> 'false'
    end.

find_xss_property_val(Val) ->
    case re:run(Val
               ,<<"(\\S+)">>
               ,['global',{'capture', 'all_but_first', 'binary'}]
               )
    of
        {'match', Matches} -> lists:any(fun validate_css_property_value/1, Matches);
        'nomatch' -> 'false'
    end.

validate_css_property([Property, Value]) ->
    case not kz_html_sanitizer:validate_css_keyword(Property) of
        'true' -> 'true';
        'false' -> find_xss_property_val(Value)
    end.

validate_css_property_value(Value) ->
    not (kz_html_sanitizer:validate_css_keyword(Value)
         orelse kz_html_sanitizer:validate_css_unit(Value)).
