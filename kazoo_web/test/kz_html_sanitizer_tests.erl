%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_html_sanitizer_tests).

-include_lib("eunit/include/eunit.hrl").

parse_html_test_()->
    List = [<<"<h1>hello <script>code!</script></h1>">>
           ,<<"<h1 class=\"heading\" style=\"font-weight: bold\">hello world!</h1>">>
           ,<<"<a href=\"http://github.com\" class=\"ext\">hello world!</a>">>
           ],

    Expected = [{<<"h1">>,[],[<<"hello ">>,{<<"script">>,[],[<<"code!">>]}]}
               ,{<<"h1">>
                ,[{<<"class">>,<<"heading">>}
                 ,{<<"style">>,<<"font-weight: bold">>}
                 ]
                ,[<<"hello world!">>]
                }
               ,{<<"a">>
                ,[{<<"href">>,<<"http://github.com">>}
                 ,{<<"class">>,<<"ext">>}
                 ]
                ,[<<"hello world!">>]
                }
               ],

    [?_assertEqual(Y, kz_html_sanitizer:parse(X)) || {X, Y} <- lists:zip(List, Expected)].

check_xss_in_html_with_good_content_test_()->
    List = [<<"This <b>is</b> <b>an</b> <i>example</i> of <u>space</u> eating.">>
           ,<<"<h1 class=\"heading\" style=\"font-weight: bold\">hello world!</h1>">>
           ,<<"<a href=\"http://github.com\" class=\"ext\">hello world!</a>">>
           ,<<"<img id=\"my-img\" src=\"cat.png\">">>
           ,<<"<section><header></header><p>hello </p><p><br></p><p><img src=\"https://avatars.githubusercontent.com/u/1481354?s=280&amp;v=4\" alt=\"The Elixir programming language · GitHub\"><br></p></section>">>
           ],
    [?_assertEqual('false', kz_html_xss:has_any_xss_items(HTML)) || HTML <- List].

check_xss_in_html_with_bad_content_test_()->
    Input = <<"<script>document.getElementById(\"demo\").innerHTML = \"Hello JavaScript!\";</script><a href=\"javascript:JavaScript_Function()\">Click</a><style>div.foo { width: 500px; behavior: url(http://foo.com); height: 200px; }</style>">>,
    Expected = [<<"<style>div.foo { width: 500px; behavior: url(http://foo.com); height: 200px; }</style>">>
               ,<<"<a href=\"javascript:JavaScript_Function()\">Click</a>">>
               ,<<"<script>document.getElementById(\"demo\").innerHTML = \"Hello JavaScript!\";</script>">>
               ],
    ?_assertEqual(Expected, kz_html_xss:get_xss_items(Input)).

good_css_test_() ->
    GoodCss =  [<<".test { color: red; border: 1px solid brown; }">>
               ,<<"div.foo { width: 500px; height: 200px; }">>
               ,<<"GI b gkljfl kj { { { ********">>
               ],
    [?_assertEqual(X, kz_html_sanitizer:scrub_css(X)) || X <- GoodCss].

evil_css_test_() ->
    EvilCSS = [<<"div.foo { width: 500px; behavior: url(http://foo.com); height: 200px; }">>
              ,<<".test { color: red; background-image: url('javascript:alert');  border: 1px solid brown; }">>
              ,<<"div.foo { width: 500px; -moz-binding: foo; height: 200px; }">>
              ,<<"\@import url(javascript:alert('Your cookie:'+document.cookie));">>
              ,<<"behaviour:expression(function(element){alert(&#39;xss&#39;);}(this));'>">>
              ,<<"-Moz-binding: url(\"http://www.example.comtest.xml\");">>
              ,<<"background:url(&quot;javascri\\dpt:alert('injected js goes here')&quot;)">>
              ,<<"xss:expr/*XSS*/ession(alert('XSS'));">>
              ,<<"background:url(java<!-- -->script:alert('XSS'));">>
              ,<<"a.foo { ba/* hack */r: x }">>
              ,<<"color: e/* * / */xpression(\"r\" + \"e\" + \"d\");">>
              ,<<"color: e/*/**/xpression(\"r\" + \"e\" + \"d\");">>
              ,<<"
                    p {
                       dummy: '//'; background:url(javascript:alert('XSS'));
                      }
                 ">>
              ,<<"
                    test{ width: expression(alert(\"sux 2 be u\")); }
                    a:link { color: red }
                                                  ">>
              ],
                                            [?_assertNotEqual(X, kz_html_sanitizer:scrub_css(X)) || X <- EvilCSS].

css_background_test_() ->
    CSSBackground = [
                     %% \uxxrl unicode
                     <<"background:\\75rl('javascript:alert(\"\\75rl\")');">>
                    ,<<"background:&#x75;rl(javascript:alert('html &amp;#x75;'))">>
                    ,<<"b\\nackground: url(javascript:alert('line-broken background '))">>
                    ,<<"background:&#xff55;rl(javascript:alert('&amp;#xff55;rl(full-width u)'))">>
                    ,<<"background:&#117;rl(javascript:alert(&amp;#117;rl'))">>
                    ,<<"background:&#x75;rl(javascript:alert('&amp;#x75;rl'))">>
                    ,<<"background:\\75rl('javascript:alert(\"\\75rl\")')">>

                                                % \uxxrl unicode
                    ,<<"div { background:\\75rl('javascript:alert(\"\\75rl\")'); }">>
                    ,<<"div { background:&#x75;rl(javascript:alert('html &amp;#x75;')) }">>
                    ,<<"div { b\\nackground: url(javascript:alert('line-broken background ')) }">>
                    ,<<"div { background:&#xff55;rl(javascript:alert('&amp;#xff55;rl(full-width u)')) }">>
                    ,<<"div { background:&#117;rl(javascript:alert(&amp;#117;rl')) }">>
                    ,<<"div { background:&#x75;rl(javascript:alert('&amp;#x75;rl')) }">>
                    ,<<"div { background:\\75rl('javascript:alert(\"\\75rl\")') }">>
                    ],
    [?_assertNotEqual(X, kz_html_sanitizer:scrub_css(X)) || X <- CSSBackground].

sanitize_html_with_bad_content_test_()->
    List = [<<"<h1>hello <script>code!</script></h1>">>
           ,<<"<h1 style=\"color: red; background-image: url('javascript:alert');  border: 1px solid brown;\">hello code!</h1>">>
           ,<<"<section><header><script>code!</script></header><p>hello <script>code!</script></p></section><h1 style=\"color: red; background-image: url('javascript:alert');  border: 1px solid brown;\">hello code!</h1>">>
           ],
    [?_assertNotEqual(X, kz_html_sanitizer:apply(X)) || X <- List].

sanitize_simple_account_announcement_test_() ->
    Announcement = <<"<div style=\"text-align: center; \"><font size=\"5\" color=\"#5f497a\"><i style=\"\"><u style=\"\"><strike style=\"\">This is a test</strike></u></i></font></div><div style=\"text-align: center; \"><br></div><div><span style=\"background-color: transparent;\"><a href=\"https://unsplash.com/photos/qEOV3icU_Y4\"><img src=\"https://media2.giphy.com/media/EulSbube9JIha/200w.webp?cid=ecf05e47hudg36imxioemwbhv403xtstb4lggsa08le9gn22&amp;rid=200w.webp&amp;ct=g\"><br></a></span></div><div><span style=\"background-color: transparent;\"><br></span></div><div><span style=\"background-color: transparent;\"><a href=\"https://unsplash.com/photos/qEOV3icU_Y4\">Hyperlink Here</a></span><br><br>I have another <span style=\"background-color: transparent;\"><a href=\"https://tinhte.vn/\">hyperlink</a></span><br></div><div><br></div><div><font color=\"#8db3e2\">Hi there, I am testing the HTML&nbsp; generation note.<br><br></font></div><div><font color=\"#8db3e2\">Testing image link</font></div><div><br></div><div><br></div><ul><ul><ul><ul><ul><ul><ul><li><b>Testing photo</b></li><li><b>Testing audio</b></li><li><b>Testing video</b></li></ul></ul></ul></ul></ul></ul></ul><div><br></div><div><br></div><div><br></div><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"text-align: right; margin: 0px 0px 0px 40px; border: none; padding: 0px;\"><span style=\"color: rgb(0, 0, 0); font-size: x-large;\">Adding image</span><br></blockquote></blockquote></blockquote></blockquote></blockquote></blockquote></blockquote><div><br></div>    <img src=\"data:image/png;base64, iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\">">>,
    Expected = <<"<div style=\"text-align: center; \"><font size=\"5\" color=\"#5f497a\"><i style=\"\"><u style=\"\"><strike style=\"\">This is a test</strike></u></i></font></div><div style=\"text-align: center; \"><br /></div><div><span style=\"background-color: transparent;\"><a href=\"https://unsplash.com/photos/qEOV3icU_Y4\"><img src=\"https://media2.giphy.com/media/EulSbube9JIha/200w.webp?cid=ecf05e47hudg36imxioemwbhv403xtstb4lggsa08le9gn22&amp;rid=200w.webp&amp;ct=g\" /><br /></a></span></div><div><span style=\"background-color: transparent;\"><br /></span></div><div><span style=\"background-color: transparent;\"><a href=\"https://unsplash.com/photos/qEOV3icU_Y4\">Hyperlink Here</a></span><br /><br />I have another <span style=\"background-color: transparent;\"><a href=\"https://tinhte.vn/\">hyperlink</a></span><br /></div><div><br /></div><div><font color=\"#8db3e2\">Hi there, I am testing the HTMLÂ  generation note.<br /><br /></font></div><div><font color=\"#8db3e2\">Testing image link</font></div><div><br /></div><div><br /></div><ul><ul><ul><ul><ul><ul><ul><li><b>Testing photo</b></li><li><b>Testing audio</b></li><li><b>Testing video</b></li></ul></ul></ul></ul></ul></ul></ul><div><br /></div><div><br /></div><div><br /></div><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"margin: 0 0 0 40px; border: none; padding: 0px;\"><blockquote style=\"text-align: right; margin: 0px 0px 0px 40px; border: none; padding: 0px;\"><span style=\"color: rgb(0, 0, 0); font-size: x-large;\">Adding image</span><br /></blockquote></blockquote></blockquote></blockquote></blockquote></blockquote></blockquote><div><br /></div>    <img src=\"data:image/png;base64, iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\" />">>,
    ?_assertEqual(Expected, kz_html_sanitizer:apply(Announcement)).
