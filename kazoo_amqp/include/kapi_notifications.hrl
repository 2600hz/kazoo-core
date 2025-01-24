-ifndef(KAPI_NOTIFICATIONS_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").

-define(DEFAULT_OPTIONAL_HEADERS, [<<"Account-DB">>
                                  ,<<"Attachment-URL">>
                                  ,<<"Bcc">>
                                  ,<<"Cc">>
                                  ,<<"From">>
                                  ,<<"HTML">>
                                  ,<<"Preview">>
                                  ,<<"Reply-To">>
                                  ,<<"Subject">>
                                  ,<<"Text">>
                                  ,<<"To">>
                                  ]).

-define(BINDING_STRING(Category, Name), <<"notifications.", (Category)/binary, ".", (Name)/binary>>).

-define(NOTIFY_VALUES(Name), kapi_definition:event_type_headers(<<"notification">>, Name)).

-define(KAPI_NOTIFICATIONS_HRL, 'true').
-endif.
