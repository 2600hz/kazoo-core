-ifndef(KZ_AUTH_SCOPE_HRL).

-include("kazoo_auth.hrl").

-define(SCOPE_DOC_ID_PREFIX, "scope_definition-").
-define(SCOPE_RULE_DOC_ID_PREFIX, "scope_rule-").

-define(SCOPE_DELIM, <<":">>).
-define(SCOPE_SEP, <<" ">>).
-define(SCOPES_CAT, <<"system_auth">>).
-define(SCOPES_LIST, <<"scopes/crossbar_listing">>).


-define(MATCH_ALL_PERMISIONS, <<"*">>).

-define(KZ_AUTH_SCOPE_HRL, 'true').
-endif.
