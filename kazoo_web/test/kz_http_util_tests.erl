%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2026, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_http_util_tests).

-include_lib("eunit/include/eunit.hrl").

urldecode_test_()->
    [urldecode_legacy()
    ,urldecode_rfc()
    ].

urldecode_legacy() ->
    [?_assertEqual(<<"abcd">>, kz_http_util:urldecode(<<"abcd">>, 'legacy'))
    ,?_assertEqual(<<"a b c d">>, kz_http_util:urldecode(<<"a+b+c+d">>, 'legacy'))
    ,?_assertEqual(<<"a b c d">>, kz_http_util:urldecode(<<"a%20b%20c%20d">>, 'legacy'))
    ,?_assertEqual(<<"a b c d">>, kz_http_util:urldecode(<<"a%20b+c%20d">>, 'legacy'))
    ,?_assertEqual(<<"a!b*c'd">>, kz_http_util:urldecode(<<"a%21b%2Ac%27d">>, 'legacy'))
    ,?_assertEqual(<<"!*'abcd">>, kz_http_util:urldecode(<<"%21%2A%27abcd">>, 'legacy'))
    ,?_assertEqual(<<"abcd!*'">>, kz_http_util:urldecode(<<"abcd%21%2A%27">>, 'legacy'))
    ,?_assertEqual(<<"()a;b:c@d&=">>, kz_http_util:urldecode(<<"%28%29a%3Bb%3Ac%40d%26%3D">>, 'legacy'))
    ,?_assertEqual(<<"+$,/?#[]">>, kz_http_util:urldecode(<<"%2B%24%2C%2F%3F%23%5B%5D">>, 'legacy'))
    ,?_assertEqual(<<"oetnh98(*&!@)#$*)!&*$TOHEDU)(FKQJTHDOE*UF**)(!@#&)~~()~*TOEADHuaoeua+?+OE{?LER?\"SN_<T>:QNJZVWM">>, kz_http_util:urldecode(<<"oetnh98(*%26!%40)%23%24*)!%26*%24TOHEDU)(FKQJTHDOE*UF**)(!%40%23%26)~~()~*TOEADHuaoeua%2B%3F%2BOE%7B%3FLER%3F%22SN_%3CT%3E%3AQNJZVWM">>, 'legacy'))
    ,?_assertEqual(<<"abcd">>, kz_http_util:urldecode(<<"%61%62%63%64">>, 'legacy'))
    ].

urldecode_rfc() ->
    [?_assertEqual(<<"abcd">>, kz_http_util:urldecode(<<"abcd">>, 'rfc'))
    ,?_assertEqual(<<"a+b+c+d">>, kz_http_util:urldecode(<<"a+b+c+d">>, 'rfc'))
    ,?_assertEqual(<<"a b c d">>, kz_http_util:urldecode(<<"a%20b%20c%20d">>, 'rfc'))
    ,?_assertEqual(<<"a b+c d">>, kz_http_util:urldecode(<<"a%20b+c%20d">>, 'rfc'))
    ,?_assertEqual(<<"a!b*c'd">>, kz_http_util:urldecode(<<"a%21b%2Ac%27d">>, 'rfc'))
    ,?_assertEqual(<<"!*'abcd">>, kz_http_util:urldecode(<<"%21%2A%27abcd">>, 'rfc'))
    ,?_assertEqual(<<"abcd!*'">>, kz_http_util:urldecode(<<"abcd%21%2A%27">>, 'rfc'))
    ,?_assertEqual(<<"()a;b:c@d&=">>, kz_http_util:urldecode(<<"%28%29a%3Bb%3Ac%40d%26%3D">>, 'rfc'))
    ,?_assertEqual(<<"+$,/?#[]">>, kz_http_util:urldecode(<<"%2B%24%2C%2F%3F%23%5B%5D">>, 'rfc'))
    ,?_assertEqual(<<"oetnh98(*&!@)#$*)!&*$TOHEDU)(FKQJTHDOE*UF**)(!@#&)~~()~*TOEADHuaoeua+?+OE{?LER?\"SN_<T>:QNJZVWM">>, kz_http_util:urldecode(<<"oetnh98(*%26!%40)%23%24*)!%26*%24TOHEDU)(FKQJTHDOE*UF**)(!%40%23%26)~~()~*TOEADHuaoeua%2B%3F%2BOE%7B%3FLER%3F%22SN_%3CT%3E%3AQNJZVWM">>, 'rfc'))
    ,?_assertEqual(<<"abcd">>, kz_http_util:urldecode(<<"%61%62%63%64">>, 'rfc'))
    ].

query_string_test_() ->
    Tests = [{[{<<"foo">>, <<"bar">>}
              ,{<<"baz">>, <<"wibble \r\n">>}
              ,{<<"z">>, <<"1">>}
              ]
             ,<<"foo=bar&baz=wibble+%0D%0A&z=1">>
             }
            ,{[{<<"">>, <<"bar">>}
              ,{<<"baz">>, <<"wibble \r\n">>}
              ,{<<"z">>, <<"">>}
              ]
             ,<<"=bar&baz=wibble+%0D%0A&z=">>
             }
            ,{[{<<"foo">>, <<"bar">>}
              ,{<<"baz">>, <<"wibble \r\n">>}
              ,{<<"z">>, <<"1">>}
              ]
             ,<<"foo=bar&baz=wibble+%0D%0A&z=1">>
             }
            ,{[], <<>>}
            ,{[{<<"via">>, <<"example.org">>}
              ,{<<"via">>, <<"other.example.org">>}
              ]
             ,<<"via=example.org&via=other.example.org">>
             }
            ],
    [?_assertEqual([{<<"foo">>, <<"">>}
                   ,{<<"bar">>, <<"">>}
                   ,{<<"baz">>, <<"">>}
                   ]
                  ,kz_http_util:parse_query_string(<<"foo;bar&baz">>)
                  )
    | [encode_decode(Decoded, Encoded)
       || {Decoded, Encoded} <- Tests
      ]
    ].

encode_decode(Decoded, Encoded) ->
    [?_assertEqual(Decoded, kz_http_util:parse_query_string(Encoded))
    ,?_assertEqual(Encoded, iolist_to_binary(kz_http_util:props_to_querystring(Decoded)))
    ].

urlsplit_test_() ->
    [?_assertEqual({<<>>, <<>>, <<"/foo">>, <<>>, <<"bar?baz">>}
                  ,kz_http_util:urlsplit(<<"/foo#bar?baz">>)
                  )
    ,?_assertEqual({<<"http">>, {<<"host">>, 345}, <<"/foo">>, <<>>, <<"bar?baz">>}
                  ,kz_http_util:urlsplit(<<"http://host:345/foo#bar?baz">>)
                  )
    ,?_assertEqual({<<"http">>, <<"host">>, <<>>, <<>>, <<>>}
                  ,kz_http_util:urlsplit(<<"http://host">>)
                  )
    ,?_assertEqual({<<>>, <<>>, <<"/wiki/Category:Fruit">>, <<"">>, <<"">>}
                  ,kz_http_util:urlsplit(<<"/wiki/Category:Fruit">>)
                  )
    ,?_assertEqual({<<"https">>, {{<<"client.host">>, 1234}, <<"username">>, <<"password">>}, <<>>, <<>>, <<>>}
                  ,kz_http_util:urlsplit(<<"https://username:password@client.host:1234">>)
                  )
    ].

urlunsplit_test_() ->
    [?_assertEqual(<<"/foo#bar?baz">>, kz_http_util:urlunsplit({<<"">>, <<"">>, <<"/foo">>, <<"">>, <<"bar?baz">>}))
    ,?_assertEqual(<<"http://host:port/foo#bar?baz">>, kz_http_util:urlunsplit({<<"http">>, <<"host:port">>, <<"/foo">>, <<"">>, <<"bar?baz">>}))
    ].

url_split_unsplit_test_() ->
    Tests = [{<<"">>, <<"">>, <<"/foo">>, <<"">>, <<"bar?baz">>}
            ,{<<"http">>, {<<"host">>, 345}, <<"/foo">>, <<"">>, <<"bar?baz">>}
            ,{<<"http">>, <<"host">>, <<"">>, <<"">>, <<"">>}
            ,{<<"">>, <<"">>, <<"/wiki/Category:Fruit">>, <<"">>, <<"">>}
            ,{<<"https">>, {{<<"client.host">>, 1234}, <<"username">>, <<"password">>}, <<>>, <<>>, <<>>}
            ],
    [?_assertEqual(Test, kz_http_util:urlsplit(kz_http_util:urlunsplit(Test)))
     || Test <- Tests
    ].

urlencode_test_() ->
    QS = kz_http_util:json_to_querystring(
           kz_json:from_list([{<<"bar">>, <<"baz">>}])
          ),

    [?_assertEqual(<<"1">> , kz_http_util:urlencode(1))
     %% ,?_assertEqual(<<"1.1">> , kz_http_util:urlencode(1.1))
    ,?_assertEqual(<<"1">> , kz_http_util:urlencode(<<"1">>))
    ,?_assertEqual(<<"1.1">> , kz_http_util:urlencode(<<"1.1">>))
    ,?_assertEqual(<<"foo">> , kz_http_util:urlencode(<<"foo">>))
    ,?_assertEqual(<<"foo">> , kz_http_util:urlencode("foo", 'legacy'))
    ,?_assertEqual(<<"foo">> , kz_http_util:urlencode('foo', 'legacy'))
    ,?_assertEqual(<<"foo+bar">> , kz_http_util:urlencode(<<"foo bar">>, 'legacy'))
    ,?_assertEqual(<<"foo%0A">> , kz_http_util:urlencode(<<"foo\n">>, 'legacy'))
    ,?_assertEqual(<<"foo%3B%26%3D">> , kz_http_util:urlencode(<<"foo;&=">>))
    ,?_assertEqual(<<"http://host:port/foo?bar=baz">>
                  ,kz_http_util:urlunsplit({<<"http">>, <<"host:port">>, <<"/foo">>, QS, <<>>})
                  )
    ].

get_resp_header_test_() ->
    Tests = [{[{"content-type", "application/pdf"}], "application/pdf"}
            ,{[{"Content-Type", "application/pdf"}], "application/pdf"}
            ,{[{"CONTENT-TYPE", "application/pdf"}], "application/pdf"}
            ,{[{"CONTENT", "application/pdf"}], 'undefined'}
            ],
    [?_assertEqual(QS, kz_http_util:get_resp_header("Content-Type", Props)) || {Props, QS} <- Tests].

-define(ENC(I), uri_string:compose_query(uri_string:dissect_query(I))).

json_to_querystring_test_() ->
    Tests = [{<<"{}">>, <<>>}
            ,{<<"{\"foo\":\"bar\"}">>, <<"foo=bar">>}
            ,{<<"{\"foo\":\"bar\",\"fizz\":\"buzz\"}">>, <<"foo=bar&fizz=buzz">>}
            ,{<<"{\"foo\":\"bar\",\"fizz\":\"buzz\",\"arr\":[1,3,5]}">>, ?ENC(<<"foo=bar&fizz=buzz&arr[]=1&arr[]=3&arr[]=5">>)}
            ,{<<"{\"Msg-ID\":\"123-abc\"}">>, <<"Msg-ID=123-abc">>}
            ,{<<"{\"url\":\"http://user:pass@host:port/\"}">>, <<"url=http%3A%2F%2Fuser%3Apass%40host%3Aport%2F">>}
            ,{<<"{\"topkey\":{\"subkey1\":\"v1\",\"subkey2\":\"v2\",\"subkey3\":[\"v31\",\"v32\"]}}">>
             ,?ENC(<<"topkey[subkey1]=v1&topkey[subkey2]=v2&topkey[subkey3][]=v31&topkey[subkey3][]=v32">>)
             }
            ,{<<"{\"topkey\":{\"subkey1\":\"v1\",\"subkey2\":{\"k3\":\"v3\"}}}">>
             ,?ENC(<<"topkey[subkey1]=v1&topkey[subkey2][k3]=v3">>)
             }
             %% Empty objects should not be included
            ,{<<"{\"Poppy\": {}}">>, <<>>}
            ,{<<"{\"Poppy\": { \"Hyacinth\": {} }}">>, <<>>}
            ,{<<"{\"Poppy\": { \"Hyacinth\": {}, \"Tulip\": {} }}">>, <<>>}
            ,{<<"{\"Poppy\": { \"Hyacinth\": {}, \"Tulip\": true }}">>, ?ENC(<<"Poppy[Tulip]=true">>)}
             %% Empty lists should not be included
            ,{<<"{\"Poppy\": []}">>, <<>>}
            ,{<<"{\"Poppy\": { \"Hyacinth\": [] }}">>, <<>>}
            ,{<<"{\"Poppy\": { \"Hyacinth\": [], \"Tulip\": [] }}">>, <<>>}
            ,{<<"{\"Poppy\": { \"Hyacinth\": [], \"Tulip\": true }}">>, ?ENC(<<"Poppy[Tulip]=true">>)}
             %% Empty binary should be empty value
            ,{<<"{\"Poppy\": \"\"}">>, ?ENC(<<"Poppy=">>)}
            ,{<<"{\"Poppy\": \"\", \"Hyacinth\": true}">>, ?ENC(<<"Poppy=&Hyacinth=true">>)}
            ],
    [[?_assertEqual(QS, kz_term:to_binary(
                          kz_http_util:json_to_querystring(
                            kz_json:decode(JSON)
                           )
                         )
                   )
      || {JSON, QS} <- Tests
     ]
    | advanced_qs_encodes()
    ].

advanced_qs_encodes() ->
    %% Some of these tests are from https://github.com/ljharb/qs
    %% we tests both json_to_querystring and props_to_query_string as they may hit different
    %% path before recursive calling.
    [{"qs encode options", chech_encode_options()}
    ,{"qs encode nested falsy values", encode_nested_falsy_values()}
    ,{"qs encode nested objects", encode_nested_objects()}
    ,{"qs encode simple array", encode_simple_array()}
    ,{"qs encode complex arrays and objects", encode_complex_arrays_and_objects()}
    ].

chech_encode_options() ->
    [{"add_query_prefix: even_on_empty on empty object prints ?"
     ,?_assertEqual(<<"?">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": {}}">>), #{return => 'binary', add_query_prefix => 'even_on_empty'}))
     }
    ,{"add_query_prefix adds ?"
     ,?_assertEqual(<<"?a=1">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": 1}">>), #{return => 'binary', add_query_prefix => 'even_on_empty'}))
     }
    ,{"add_query_prefix adds ?"
     ,?_assertEqual(<<"?a=1">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": 1}">>), #{return => 'binary', add_query_prefix => 'true'}))
     }

    ,?_assertEqual(<<"">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":\"\"}">>), #{return => 'binary', allow_empty_strings => 'false'}))
    ,?_assertEqual(<<"">>, kz_http_util:props_to_querystring([{<<"a">>, <<>>}], #{return => 'binary', allow_empty_strings => 'false'}))
    ,?_assertEqual(<<"a=">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":\"\"}">>), #{return => 'binary', allow_empty_strings => 'true'}))
    ,?_assertEqual(<<"a=">>, kz_http_util:props_to_querystring([{<<"a">>, <<>>}], #{return => 'binary', allow_empty_strings => 'true'}))

     %% the weirdness begins
    ,{"encode keys and values"
     ,[?_assertEqual(<<"my%20weird%20field=~q1%212%22%27w%245%267%2Fz8%29%3F">>
                    ,kz_http_util:json_to_querystring(kz_json:decode(<<"{\"my weird field\": \"~q1!2\\\"'w$5&7/z8)?\" }">>), #{return => 'binary'})
                    )
      ,?_assertEqual(<<"my%20weird%20field=~q1%212%22%27w%245%267%2Fz8%29%3F">>
                    ,kz_http_util:props_to_querystring([{<<"my weird field">>, <<"~q1!2\"'w$5&7/z8)?">>}], #{return => 'binary'})
                    )
      ,?_assertEqual(<<"my weird field=~q1!2\"'w$5&7/z8)?">>
                    ,kz_http_util:json_to_querystring(kz_json:decode(<<"{\"my weird field\": \"~q1!2\\\"'w$5&7/z8)?\" }">>), #{return => 'binary', encode_keys => 'false', encode_values => 'false'})
                    )
      ,?_assertEqual(<<"my weird field=~q1!2\"'w$5&7/z8)?">>
                    ,kz_http_util:props_to_querystring([{<<"my weird field">>, <<"~q1!2\"'w$5&7/z8)?">>}], #{return => 'binary', encode_keys => 'false', encode_values => 'false'})
                    )
      ]
     }
    ].

encode_nested_falsy_values() ->
    [?_assertEqual(<<"a[b][c]=null">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":{\"b\":{\"c\":null}}}">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"a[b][c]=null">>, kz_http_util:props_to_querystring([{<<"a">>, [{<<"b">>, [{<<"c">>, 'null'}]}]}], #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<>>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":{\"b\":{\"c\":null}}}">>), #{return => 'binary', keep_null => 'false'}))
    ,?_assertEqual(<<>>, kz_http_util:props_to_querystring([{<<"a">>, [{<<"b">>, [{<<"c">>, 'null'}]}]}], #{return => 'binary', keep_null => 'false'}))

    ,{"drop keys with a value of undefined"
     ,?_assertEqual(<<>>, kz_http_util:props_to_querystring([{<<"a">>, [{<<"b">>, [{<<"c">>, 'undefined'}]}]}], #{return => 'binary'}))
     }

    ,?_assertEqual(<<"a[b][c]=false">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":{\"b\":{\"c\":false}}}">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"a[b][c]=false">>, kz_http_util:props_to_querystring([{<<"a">>, [{<<"b">>, [{<<"c">>, 'false'}]}]}], #{return => 'binary', encode_keys => 'false'}))
    ].

encode_nested_objects() ->
    [?_assertEqual(<<"a[b][c]=d">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":{\"b\":{\"c\":\"d\"}}}">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"a[b][c][]=d&a[b][c][]=e">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":{\"b\":{\"c\":[\"d\", \"e\"]}}}">>), #{return => 'binary', encode_keys => 'false'}))
    ].

encode_simple_array() ->
    [?_assertEqual(<<"a[0]=b">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\"]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
    ,?_assertEqual(<<"a[0]=b">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>]}], #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))

    ,?_assertEqual(<<"a=b">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\"]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'repeat'}))
    ,?_assertEqual(<<"a=b">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>]}], #{return => 'binary', encode_keys => 'false', array_format => 'repeat'}))

    ,?_assertEqual(<<"a[]=b">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\"]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'brackets'}))
    ,?_assertEqual(<<"a[]=b">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>]}], #{return => 'binary', encode_keys => 'false', array_format => 'brackets'}))
    ,?_assertEqual(<<"a[]=b">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\"]}">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"a[]=b">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>]}], #{return => 'binary', encode_keys => 'false'}))

    ,?_assertEqual(<<"a[0]=b&a[1]=c">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\",\"c\"]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
    ,?_assertEqual(<<"a[0]=b&a[1]=c">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>, <<"c">>]}], #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))

    ,?_assertEqual(<<"a=b&a=c">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\",\"c\"]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'repeat'}))
    ,?_assertEqual(<<"a=b&a=c">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>, <<"c">>]}], #{return => 'binary', encode_keys => 'false', array_format => 'repeat'}))

    ,?_assertEqual(<<"a[]=b&a[]=c">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\",\"c\"]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'brackets'}))
    ,?_assertEqual(<<"a[]=b&a[]=c">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>, <<"c">>]}], #{return => 'binary', encode_keys => 'false', array_format => 'brackets'}))
    ,?_assertEqual(<<"a[]=b&a[]=c">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\"b\",\"c\"]}">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"a[]=b&a[]=c">>, kz_http_util:props_to_querystring([{<<"a">>, [<<"b">>, <<"c">>]}], #{return => 'binary', encode_keys => 'false'}))

    ,?_assertEqual(<<>>, kz_http_util:props_to_querystring([{<<"a">>, []}], #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<>>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[]}">>), #{return => 'binary', encode_keys => 'false'}))

    ,?_assertEqual(<<"b=c">>, kz_http_util:props_to_querystring([{<<"a">>, []}, {<<"b">>, <<"c">>}], #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"b=c">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[],\"b\":\"c\"}">>), #{return => 'binary', encode_keys => 'false'}))

    ].

encode_complex_arrays_and_objects() ->
    [?_assertEqual(<<"a[][][][]=b">>, kz_http_util:props_to_querystring([{<<"a">>, [[[[<<"b">>]]]]}], #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"a[][][][]=b">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": [[[[\"b\"]]]]}">>), #{return => 'binary', encode_keys => 'false'}))

    ,?_assertEqual(<<"">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": [[[[]]]]}">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"">>, kz_http_util:props_to_querystring([{<<"a">>, [[[[]]]]}], #{return => 'binary', encode_keys => 'false'}))

    ,?_assertEqual(<<"a[b][0]=c&a[b][1]=d">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{ \"a\": {\"b\": [\"c\", \"d\"] } }">>), #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
    ,?_assertEqual(<<"a[b][0]=c&a[b][1]=d">>, kz_http_util:props_to_querystring([{<<"a">>, [{<<"b">>, [<<"c">>, <<"d">>]}]}], #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
    ,?_assertEqual(<<"a[b][]=c&a[b][]=d">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{ \"a\": {\"b\": [\"c\", \"d\"] } }">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"a[b][]=c&a[b][]=d">>, kz_http_util:props_to_querystring([{<<"a">>, [{<<"b">>, [<<"c">>, <<"d">>]}]}], #{return => 'binary', encode_keys => 'false'}))

    ,{"comma in values"
     ,[?_assertEqual(<<"a[0]=%2C&a[1]=&a[2]=c%2Cd%25">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[\",\",\"\",\"c,d%\"]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
      ,?_assertEqual(<<"a[0]=%2C&a[1]=&a[2]=c%2Cd%25">>, kz_http_util:props_to_querystring([{<<"a">>, [<<",">>, <<>>, <<"c,d%">>] }], #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
      ]
     }

    ,{"mixed array with object"
     ,[?_assertEqual(<<"a[0][b]=1&a[1]=2&a[2]=3">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\":[{\"b\":1},2,3]}">>), #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
      ,?_assertEqual(<<"a[0][b]=1&a[1]=2&a[2]=3">>, kz_http_util:props_to_querystring([{ 'a', [[{ 'b', 1 }], 2, 3] }], #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))

      ,?_assertEqual(<<"a[0][b][c][0]=1">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{ \"a\": [{ \"b\": { \"c\": [1] } }] }">>), #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
      ,?_assertEqual(<<"a[0][b][c][0]=1">>, kz_http_util:props_to_querystring([{'a', [ [{'b', [{ 'c', [1]}] }] ]}], #{return => 'binary', encode_keys => 'false', array_format => 'indices'}))
      ]
     }

    ,?_assertEqual(<<"ips[][port]=5060&ips[][proto]=udp">>, kz_http_util:json_to_querystring(kz_json:decode(<<"{\"ips\":[{\"port\":5060,\"proto\":\"udp\"}]}">>), #{return => 'binary', encode_keys => 'false'}))
    ,?_assertEqual(<<"ips[][port]=5060&ips[][proto]=udp">>, kz_http_util:props_to_querystring([{<<"ips">>, [[{<<"port">>, 5060}, {<<"proto">>, <<"udp">>}]]}], #{return => 'binary', encode_keys => 'false'}))

    ,{"encode key a legacy"
     ,?_assertEqual(<<"my+weird+field=~q1%212%22%27w%245%267%2Fz8%29%3F">>
                   ,kz_http_util:props_to_querystring([{<<"my weird field">>, <<"~q1!2\"'w$5&7/z8)?">>}], #{return => 'binary', encode_keys_type => 'legacy'})
                   )
     }

    ,{"encode key in object with an array value"
     ,[?_assertEqual(<<"my%20weird%20field%5B%5D=b">>
                    ,kz_http_util:json_to_querystring(kz_json:decode(<<"{\"my weird field\": [\"b\"] }">>), #{return => 'binary'})
                    )
      ,?_assertEqual(<<"my%20weird%20field%5B%5D=b">>
                    ,kz_http_util:props_to_querystring([{<<"my weird field">>, [<<"b">>]}], #{return => 'binary'})
                    )
      ]
     }
    ,{"encode key in nested object with array value"
     ,[?_assertEqual(<<"a%5Bmy%20weird%20field%5D%5B%5D=b">>
                    ,kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": {\"my weird field\": [\"b\"]}}">>), #{return => 'binary'})
                    )
      ,?_assertEqual(<<"a%5Bmy%20weird%20field%5D%5B%5D=b">>
                    ,kz_http_util:props_to_querystring([{<<"a">>, [{<<"my weird field">>, [<<"b">>]}]}], #{return => 'binary'})
                    )
      ]
     }
    ,{"encode key in deeper nested object with array value"
     ,[?_assertEqual(<<"a%5Bb%5D%5Bmy%20weird%20field%5D%5B%5D=c">>
                    ,kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": {\"b\": {\"my weird field\": [\"c\"]}}}">>), #{return => 'binary'})
                    )
      ,?_assertEqual(<<"a%5Bb%5D%5Bmy%20weird%20field%5D%5B%5D=c">>
                    ,kz_http_util:props_to_querystring([{<<"a">>, [{<<"b">>, [{<<"my weird field">>, [<<"c">>]}]}]}], #{return => 'binary'})
                    )

      ]
     }
    ,{"encode key in dobject in array"
     ,[?_assertEqual(<<"a%5B%5D%5Bmy%20weird%20field%5D=b">>
                    ,kz_http_util:json_to_querystring(kz_json:decode(<<"{\"a\": [{\"my weird field\": \"b\"}]}">>), #{return => 'binary'})
                    )
      ,?_assertEqual(<<"a%5B%5D%5Bmy%20weird%20field%5D=b">>
                    ,kz_http_util:props_to_querystring([{<<"a">>, [[{<<"my weird field">>, <<"b">>}]]}], #{return => 'binary'})
                    )
      ]
     }
    ].

props_to_querystring_test_() ->
    Tests = [{[], <<>>}
            ,{[{<<"foo">>, <<"bar">>}], <<"foo=bar">>}
            ,{[{<<"foo">>, <<"bar">>}, {<<"fizz">>, <<"buzz">>}], <<"foo=bar&fizz=buzz">>}
            ,{[{'foo', <<"bar">>}
              ,{<<"fizz">>, <<"buzz">>}
              ,{<<"arr">>, [1,3,5]}
              ], ?ENC(<<"foo=bar&fizz=buzz&arr[]=1&arr[]=3&arr[]=5">>)}
            ,{[{<<"Msg-ID">>, <<"123-abc">>}], <<"Msg-ID=123-abc">>}
            ,{[{<<"url">>, <<"http://user:pass@host:port/">>}], <<"url=http%3A%2F%2Fuser%3Apass%40host%3Aport%2F">>}
            ],
    [?_assertEqual(QS, kz_term:to_binary(kz_http_util:props_to_querystring(Props)))
     || {Props, QS} <- Tests
    ].

uri_test_() ->
    [?_assertEqual(<<"http://test.com/path1/path2">>, kz_http_util:uri(<<"http://test.com">>, [<<"path1">>, <<"path2">>]))
    ,?_assertEqual(<<"http://192.168.0.1:8888/path1/path2">>, kz_http_util:uri(<<"http://192.168.0.1:8888/">>, [<<"path1">>, <<"path2">>]))
    ,?_assertEqual(<<"http://test.com/path1/path2">>, kz_http_util:uri(<<"http://test.com/">>, [<<"path1/">>, <<"path2/">>]))
    ].

resolve_uri_test_() ->
    RawPath = <<"http://pivot/script.php">>,
    Relative = <<"script2.php">>,
    [?_assertEqual(<<"http://pivot/script2.php">>, kz_http_util:resolve_uri(RawPath, Relative))
    ,?_assertEqual(<<"http://pivot/script2.php">>, kz_http_util:resolve_uri(RawPath, <<"/", Relative/binary>>))
    ,?_assertEqual(Relative, kz_http_util:resolve_uri(Relative, 'undefined'))
    ,?_assertEqual(RawPath, kz_http_util:resolve_uri(Relative, RawPath))
    ,?_assertEqual(Relative, kz_http_util:resolve_uri(kz_term:to_list(Relative), 'undefined'))
    ,?_assertEqual(RawPath, kz_http_util:resolve_uri(kz_term:to_list(Relative), RawPath))
    ,?_assertEqual(RawPath, kz_http_util:resolve_uri(Relative, kz_term:to_list(RawPath)))
    ,?_assertEqual(<<"http://host/d1/d2/a">>, kz_http_util:resolve_uri(<<"http://host/d1/d2/d3/file.ext">>, <<"../.././a">>))
    ].

resolve_uri_path_test_() ->
    RawPath = <<"http://pivot/script.php">>,
    Relative = <<"script2.php">>,
    RawPathList = [<<"http:">>, <<>>, <<"pivot">>, <<"script2.php">>],
    [?_assertEqual(RawPathList, kz_http_util:resolve_uri_path(RawPath, Relative))
    ,?_assertEqual(RawPathList, kz_http_util:resolve_uri_path(RawPath, <<"/", Relative/binary>>))
    ].


parse_query_arrays_test_() ->
    [{"parse arrays in query string"
     ,[{"simple strings", simple_strings()}
      ,{"simple array", simple_array()}
      ,{"simple nested objects", simple_nested_objects()}
      ,{"mix_and_match", mix_and_match()}
      ]
     }
    ].

simple_strings() ->
    [?_assertEqual(p_from_l([{<<"0">>, <<"a">>}]), parse_arrays(<<"0=a">>))
    ,?_assertEqual(p_from_l([{<<"a">>, 'true'}]), parse_arrays(<<"a">>))
    ,?_assertEqual(p_from_l([{<<"a">>, <<>>}]), parse_arrays(<<"a=">>))
    ,?_assertEqual(p_from_l([{<<"a">>, <<"b">>}]), parse_arrays(<<"a=b">>))
    ,?_assertEqual(p_from_l([{<<"a">>, <<"b=c">>}]), parse_arrays(<<"a=b=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>, <<"b">>}, {<<"b">>, <<"c">>}]), parse_arrays(<<"a=b&b=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>, <<"b">>}, {<<"c">>, <<>>}]), parse_arrays(<<"a=b&c=">>))
    ,?_assertEqual(p_from_l([{<<"a">>, <<"b">>}, {<<"c">>, 'true'}]), parse_arrays(<<"a=b&c">>))
    ].


simple_array() ->
    Expected = p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]),
    [?_assertEqual(Expected, parse_arrays(<<"a[]=b&a[]=c">>))
    ,?_assertEqual(Expected, parse_arrays(<<"a[0]=b&a[1]=c">>))
    ,?_assertEqual(Expected, parse_arrays(<<"a=b&a=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>, <<"b,c">>}]), parse_arrays(<<"a=b,c">>, #{comma_array => 'false'}))
    ,?_assertEqual(p_from_l([{<<"a">>,[<<>>,<<"b">>,<<"c">>]}]), parse_arrays(<<"a[]=&a[]=b&a[]=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>,[<<"b">>,<<>>,<<"c">>]}]), parse_arrays(<<"a[]=b&a[]=&a[]=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>,[<<"b">>,'true',<<"c">>,<<>>]}]), parse_arrays(<<"a[]=b&a[]&a[]=c&a[]=">>))
    ,?_assertEqual([{<<"a">>,<<"[\"b\"]">>}], parse_arrays(<<"a=[\"b\"]">>))
    ,?_assertEqual([{<<"a">>,kz_json:from_list([{<<"b c">>,<<"d">>}])}], parse_arrays(<<"a[b%20c]=d">>))
    ,?_assertEqual([{<<"a">>,kz_json:from_list([{<<"30">>,<<"b">>}])}], parse_arrays(<<"a[30]=b">>))
    ,?_assertEqual([{<<"a">>,kz_json:from_list([{<<"12b">>,<<"c">>}])}], parse_arrays(<<"a[12b]=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>, [{<<"0">>, <<"b">>}, {<<"b">>, <<"c">>}]}]), parse_arrays(<<"a[0]=b&a[b]=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>,kz_json:from_list([{<<"b">>,[<<"c">>,<<"d">>]}])}]), parse_arrays(<<"a[b][]=c&a[b][]=d">>))
    ].

simple_nested_objects() ->
    [?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a=b&a=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>, [{<<"b">>, <<"c">>}]}]), parse_arrays(<<"a[b]=c">>))
    ,?_assertEqual(p_from_l([{<<"a">>, [{<<"b">>, [{<<"c">>, <<"d">>}]}]}]), parse_arrays(<<"a[b][c]=d">>))
    ,?_assertEqual(p_from_l([{<<"a">>, [{<<"b">>, [{<<"c">>, [{<<"d">>, [{<<"e">>, [{<<"f">>, [{<<"[g][h]">>, <<"i">>}]}]}]}]}]}]}]), parse_arrays(<<"a[b][c][d][e][f][g][h]=i">>))
    ,?_assertEqual(p_from_l([{<<"a">>, [{<<"b">>, [{<<"[c]">>, <<"d">>}]}]}]), parse_arrays(<<"a[b][c]=d">>, #{depth => 1}))
    ,?_assertEqual(p_from_l([{<<"a[0][0]">>, <<"b">>}, {<<"a[0][1]">>, <<"c">>}, {<<"a[1]">>, <<"d">>}, {<<"e">>, <<"2">>}]), parse_arrays(<<"a[0][0]=b&a[0][1]=c&a[1]=d&e=2">>, #{depth => 0}))
    ].


mix_and_match() ->
    [{"correctly detect object and add key to object"
     ,[?_assertEqual(p_from_l([{<<"a">>, [{<<"b">>, <<"c">>}, {<<"d">>, 'true'}]}]), parse_arrays(<<"a[b]=c&a=d">>))]
     }
    ,{"compacts sparse arrays"
     ,[?_assertEqual(p_from_l([{<<"a">>, [<<"2">>, <<"1">>]}]), parse_arrays(<<"a[10]=1&a[2]=2">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [[{<<"b">>, [[{<<"c">>, <<"1">>}]]}]]}]), parse_arrays(<<"a[1][b][2][c]=1">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [[[[{<<"c">>, <<"1">>}]]]]}]), parse_arrays(<<"a[1][2][3][c]=1">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [[[[{<<"c">>, [<<"1">>]}]]]]}]), parse_arrays(<<"a[1][2][3][c][1]=1">>))
      ]
     }
    ,{"parse jquery arrays"
     ,?_assertEqual(p_from_l([{<<"filter">>, [[<<"int1">>, <<"=">>, <<"77">>], <<"and">>, [<<"int2">>, <<"=">>, <<"8">>]]}])
                   ,parse_arrays(<<"filter%5B0%5D%5B%5D=int1&filter%5B0%5D%5B%5D=%3D&filter%5B0%5D%5B%5D=77&filter%5B%5D=and&filter%5B2%5D%5B%5D=int2&filter%5B2%5D%5B%5D=%3D&filter%5B2%5D%5B%5D=8">>)
                   )
     }
    ,{"some test for when there is no parent key name"
     ,[?_assertEqual(p_from_l([{<<"0">>, <<>>}, {<<"a">>, <<"b">>}]), parse_arrays(<<"[]=&a=b">>))
      ,?_assertEqual(p_from_l([{<<"foo">>, <<"bar">>}]), parse_arrays(<<"[foo]=bar">>))
      ]
     }
    ,{"simple comma separated array"
     ,[?_assertEqual(p_from_l([{<<"a">>, <<"b,c">>}]), parse_arrays(<<"a=b,c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a=b,c">>, #{comma_array => 'true'}))
      ,?_assertEqual(p_from_l([{<<"a">>, [{<<"z">>, [<<"b">>, <<"c">>]}]}]), parse_arrays(<<"a[z]=b,c">>, #{comma_array => 'true'}))
      ]
     }
    ,{"explicit array and comma separated array"
     ,[?_assertEqual(p_from_l([{<<"a">>, [[<<"1">>, <<"2">>, <<"3">>], [<<"4">>, <<"5">>, <<"6">>]]}])
                    ,parse_arrays(<<"a[]=1,2,3&a[]=4,5,6">>, #{comma_array => 'true'})
                    )
      ,?_assertEqual(p_from_l([{<<"a">>, [[<<"1">>, <<"2">>, <<"3">>], <<>>]}])
                    ,parse_arrays(<<"a[]=1,2,3&a[]=">>, #{comma_array => 'true'})
                    )
      ,?_assertEqual(p_from_l([{<<"a">>, [[<<"1">>, <<"2">>, <<"3">>], [<<>>, <<>>]]}])
                    ,parse_arrays(<<"a[]=1,2,3&a[]=,">>, #{comma_array => 'true'})
                    )
      ,?_assertEqual(p_from_l([{<<"a">>, [[<<"1">>, <<"2">>, <<"3">>], <<"a">>]}])
                    ,parse_arrays(<<"a[]=1,2,3&a[]=a">>, #{comma_array => 'true'})
                    )
      ]
     }
    ,{"can handle un-closed opening brackets"
     ,[?_assertEqual(p_from_l([{<<"[">>, <<"b">>}]), parse_arrays(<<"[=b">>))
      ,?_assertEqual(p_from_l([{<<"[[">>, <<"b">>}]), parse_arrays(<<"[[=b">>))
      ,?_assertEqual(p_from_l([{<<"[a[">>, <<"b">>}]), parse_arrays(<<"[a[=b">>))
      ]
     }
    ,{"can handle un-closed closing brackets"
     ,[?_assertEqual(p_from_l([{<<"]">>, <<"b">>}]), parse_arrays(<<"]=b">>))
      ,?_assertEqual(p_from_l([{<<"]]">>, <<"b">>}]), parse_arrays(<<"]]=b">>))
      ,?_assertEqual(p_from_l([{<<"]a]">>, <<"b">>}]), parse_arrays(<<"]a]=b">>))
      ]
     }
    ,{"convert array to object"
     ,[?_assertEqual(p_from_l([{<<"aab">>, [{<<"0">>, <<"bar">>}, {<<"baar">>, <<"baz">>}]}]), parse_arrays(<<"aab[0]=bar&aab[baar]=baz">>))
      ,?_assertEqual(p_from_l([{<<"aab">>, [{<<"baar">>, <<"baz">>}, {<<"0">>, <<"bar">>}]}]), parse_arrays(<<"aab[baar]=baz&aab[0]=bar">>))
      ,?_assertEqual(p_from_l([{<<"aab">>, [{<<"baar">>, <<"baz">>}, {<<"0">>, <<"bar">>}]}]), parse_arrays(<<"aab[baar]=baz&aab[]=bar">>))
      ,?_assertEqual(p_from_l([{<<"aab">>, [{<<"0">>, <<"bar">>}, {<<"baar">>, <<"baz">>}]}]), parse_arrays(<<"aab[]=bar&aab[baar]=baz">>))
      ,?_assertEqual(p_from_l([{<<"aab">>, [{<<"baar">>, <<"baz">>}, {<<"0">>, <<"bar">>}, {<<"1">>, <<"aab">>}]}]), parse_arrays(<<"aab[baar]=baz&aab[]=bar&aab[]=aab">>))
      ,?_assertEqual(p_from_l([{<<"aab">>, [[{<<"a">>, <<"a">>}, {<<"b">>, <<"b">>}], [{<<"a">>, <<"aa">>}, {<<"b">>, <<"bb">>}]]}])
                    ,parse_arrays(<<"aab[0][a]=a&aab[0][b]=b&aab[1][a]=aa&aab[1][b]=bb">>)
                    )
      ]
     }
    ,{"correctly compact array when converting array to object and array limit is hit"
     ,[?_assertEqual(p_from_l([{<<"a">>,kz_json:from_list([{<<"2">>,<<"b">>},{<<"50">>,<<"c">>}])}])
                    ,parse_arrays(<<"a[2]=b&a[50]=c">>)
                    )
      ]
     }
    ,{"order array correctly when array indices are specified"
     ,[?_assertEqual(p_from_l([{<<"a">>,[<<"b">>,<<"c">>,<<"d">>]}])
                    ,parse_arrays(<<"a[1]=c&a[0]=b&a[2]=d">>)
                    )
      ]
     }
    ,{"explicit array"
     ,[?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a=b&a[]=c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a[]=b&a=c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a[0]=b&a=c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a=b&a[0]=c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a[1]=b&a=c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a=b&a[1]=c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>]}]), parse_arrays(<<"a[]=b">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>]}]), parse_arrays(<<"a[]=b&a[]=c">>))
      ,?_assertEqual(p_from_l([{<<"a">>, [<<"b">>, <<"c">>, <<"d">>]}]), parse_arrays(<<"a[]=b&a[]=c&a[]=d">>))
      ]
     }
    ].

parse_arrays(QS) -> kz_http_util:parse_query_arrays(cow_qs:parse_qs(QS)).
parse_arrays(QS, Options) -> kz_http_util:parse_query_arrays(cow_qs:parse_qs(QS), Options).
p_from_l(L) -> kz_json:to_proplist(kz_json:from_list_recursive(L)).
