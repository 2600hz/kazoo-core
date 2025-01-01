%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% @doc Dialplan API definitions.
%%% @author James Aimonetti
%%% @author Karl Anderson
%%% @author Sponsored by Velvetech LLC, Implemented by SIPLABS LLC
%%% @end
%%%-----------------------------------------------------------------------------
-ifndef(KAPI_DIALPLAN_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").

%% For dialplan messages, what does the Invite-Format param accept as values?
-define(INVITE_FORMAT_TUPLE, {<<"Invite-Format">>
                             ,[<<"username">>, <<"e164">>
                              ,<<"npan">>, <<"1npan">>
                              ,<<"route">>, <<"loopback">>
                              ,<<"contact">>
                              ,<<"endpoint">>, <<"forward">>
                              ,<<"strip_plus">>
                              ]
                             }).

%% For dialplan messages, an optional insert-at tuple is common across all requests
-define(INSERT_AT_TUPLE, {<<"Insert-At">>, [<<"head">>, <<"tail">>, <<"flush">>, <<"now">>]}).
-define(IS_TERMINATOR, fun kapi_dialplan:terminators_v/1).

-define(DIAL_METHOD_SINGLE, <<"single">>).
-define(DIAL_METHOD_SIMUL, <<"simultaneous">>).

-define(KAPI_DIALPLAN_HRL, 'true').
-endif.
