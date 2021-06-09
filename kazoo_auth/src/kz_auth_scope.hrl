-ifndef(KZ_AUTH_SCOPE_HRL).

-include("kazoo_auth.hrl").

-define(SCOPE_DOC_ID_PREFIX, "scope_definition-").
-define(SCOPE_RULE_DOC_ID_PREFIX, "scope_rule-").

-define(SCOPE_DELIM, <<":">>).
-define(SCOPE_SEP, <<" ">>).
-define(SCOPES_CAT, <<"system_auth">>).
-define(SCOPES_LIST, <<"scopes/crossbar_listing">>).


-define(CATCH_ALL, <<"*">>).

-define(KZ_AUTH_SCOPE_HRL, 'true').
-endif.
