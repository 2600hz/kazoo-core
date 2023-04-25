-define(REPLACEMENT_LINEBREAK, [239,188,191]).
-define(REPLACEMENT_SPACE, [239,189,191]).
-define(REPLACEMENT_TAB, [239,190,191]).

-define(VALID_SCHEMES, [<<"http">>, <<"https">>, <<"mailto">>]).

-define(PROTOCOL_SEPARATOR, ":|(&#0*58)|(&#x70)|(&#x0*3a)|(%|&#37;)3A").
-define(HTTP_LIKE_SCHEME, "(?<scheme>.+?)", "(", ?PROTOCOL_SEPARATOR, ")//").
-define(OTHER_SCHEMES, "(?<other_schemes>mailto)","(", ?PROTOCOL_SEPARATOR,")").
-define(SCHEME_CAPTURE, <<"(",?HTTP_LIKE_SCHEME , ")", "|", "(", ?OTHER_SCHEMES, ")">>).

-define(ALLOWED_MIMETYPES_SOURCE, <<"data:(((image)|(audio)|(video))\/\\w+)(;\\w+),.+">>).
-define(CSS_UNIT_REGEX, <<"\\A(#[0-9a-fA-F]+|rgb\\(\\d+%?,\\d*%?,?\\d*%?\\)?|-?\\d{0,2}\\.?\\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\\))?)\\z">>).

-define(ATTRIBUTES_CAN_TRIGGER_XSS, [<<"href">>
                                    ,<<"action">>
                                    ,<<"src">>
                                    ,<<"lowsrc">>
                                    ,<<"srcset">>
                                    ]).
