%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_trunkserver).

-export([server/1, server/2, set_server/2]).
-export([server_id/1, server_id/2]).
-export([server_name/1, server_name/2]).
-export([delete/1, delete/2]).
-export([save/1, save/2]).

-export([auth_method/1, auth_method/2, is_ip_auth_method/1]).
-export([auth_password/1, auth_password/2]).
-export([auth_user/1, auth_user/2]).
-export([auth_ip/1, auth_ip/2]).
-export([auth_port/1, auth_port/2]).

-export([trunkstore_id/1, set_trunkstore_id/2]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-spec server(doc()) -> kz_json:object().
server(Doc) ->
    server(Doc, kz_json:new()).

-spec server(doc(), Default) -> kz_json:object() | Default.
server(Doc, Default) ->
    kz_json:get_json_value([<<"server">>], Doc, Default).

-spec set_server(doc(), kz_json:object()) -> doc().
set_server(Doc, Server) ->
    kz_json:set_value([<<"server">>], Server, Doc).

-spec server_id(doc()) -> kz_term:api_binary().
server_id(Doc) ->
    server_id(Doc, 'undefined').

-spec server_id(doc(), Default) -> binary() | Default.
server_id(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"server_id">>], server(Doc), Default).

-spec server_name(doc()) -> kz_term:api_binary().
server_name(Doc) ->
    server_name(Doc, 'undefined').

-spec server_name(doc(), Default) -> binary() | Default.
server_name(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"server_name">>], server(Doc), Default).

-spec auth_method(doc()) -> kz_term:api_binary().
auth_method(Doc) ->
    auth_method(Doc, 'undefined').

-spec auth_method(doc(), Default) -> binary() | Default.
auth_method(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"server">>, <<"auth">>, <<"auth_method">>], Doc, Default).

-spec auth_password(doc()) -> kz_term:api_binary().
auth_password(Doc) ->
    auth_password(Doc, 'undefined').

-spec auth_password(doc(), Default) -> binary() | Default.
auth_password(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"server">>, <<"auth">>, <<"auth_password">>], Doc, Default).

-spec auth_user(doc()) -> kz_term:api_binary().
auth_user(Doc) ->
    auth_user(Doc, 'undefined').

-spec auth_user(doc(), Default) -> binary() | Default.
auth_user(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"server">>, <<"auth">>, <<"auth_user">>], Doc, Default).

-spec auth_ip(doc()) -> kz_term:api_binary().
auth_ip(Doc) ->
    auth_ip(Doc, 'undefined').

-spec auth_ip(doc(), Default) -> binary() | Default.
auth_ip(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"server">>, <<"auth">>, <<"ip">>], Doc, Default).

-spec auth_port(doc()) -> kz_term:api_integer().
auth_port(Doc) ->
    auth_port(Doc, 'undefined').

-spec auth_port(doc(), Default) -> integer() | Default.
auth_port(Doc, Default) ->
    kz_json:get_integer_value([<<"server">>, <<"auth">>, <<"port">>], Doc, Default).

-spec is_ip_auth_method(doc()) -> boolean().
is_ip_auth_method(Doc) ->
    auth_method(Doc) =:= <<"IP">>.

-spec trunkstore_id(doc()) -> kz_term:api_binary().
trunkstore_id(Doc) ->
    kz_json:get_ne_binary_value(<<"trunkstore_id">>, Doc).

-spec set_trunkstore_id(kz_json:object(), kz_term:ne_binary()) -> kz_json:object().
set_trunkstore_id(Doc, TrunkstoreId) ->
    kz_json:set_value(<<"trunkstore_id">>, TrunkstoreId, Doc).

build_trunk_server(Server, Doc) ->
    AccountId = kz_doc:account_id(Doc),
    TrunkstoreId = kz_doc:id(Doc),
    Setters = [{fun kz_doc:set_type/2, <<"trunk_server">>}
              ,{fun kz_doc:set_account_id/2, AccountId}
              ,{fun kz_doc:set_account_db/2, kzs_util:format_account_db(AccountId)}
              ,{fun set_server/2, Server}
              ,{fun kzd_trunkstore:set_servers/2, 'null'}
              ,{fun set_trunkstore_id/2, TrunkstoreId}
              ],
    Built = kz_doc:setters(kz_doc:public_fields(Doc), Setters),
    kz_doc:set_id(Built, server_id(Built)).

-spec save(doc()) ->
          {'ok', doc()} |
          kz_datamgr:data_error().
save(Doc) ->
    AccountId = kz_doc:account_id(Doc),
    IPAuth = is_ip_auth_method(Doc),
    case kz_datamgr:save_doc(AccountId, Doc) of
        {'error', _} = Error -> Error;
        {'ok', Saved} when IPAuth ->
            case kz_datamgr:save_doc(?KZ_SIP_DB, Doc) of
                {'ok', _} -> {'ok', Saved};
                Error -> Error
            end;
        {'ok', _} = OK -> OK
    end.

-spec save(doc(), kzd_trunkstore:doc()) ->
          {'ok', doc()} |
          kz_datamgr:data_error().
save(Server, Doc) ->
    save(build_trunk_server(Server, Doc)).

-spec delete(kzd_trunkstore:doc()) -> 'ok'.
delete(Doc) ->
    AccountId = kz_doc:account_id(Doc),
    TrunkstoreId = trunkstore_id(Doc),
    delete(AccountId, TrunkstoreId).

-spec delete(kz_term:api_binary(), kz_term:api_binary()) -> 'ok'.
delete('undefined', _TrunkstoreId) -> 'ok';
delete(_AccountId, 'undefined') -> 'ok';
delete(AccountId, TrunkstoreId) ->
    _ = case fetch_trunkserver_docs(AccountId, TrunkstoreId) of
            [] -> 'ok';
            Docs ->
                _ = kz_datamgr:del_docs(AccountId, Docs),
                kz_datamgr:del_docs(?KZ_SIP_DB, Docs)
        end,
    'ok'.

-spec fetch_trunkserver_docs(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_json:objects().
fetch_trunkserver_docs(AccountId, TrunkstoreId) ->
    DesignDoc = <<"crossbar_listings/by_type_id">>,
    Result = kz_view:find(AccountId, DesignDoc, fetch_selector(), fetch_options()),
    handle_fetch_trunkserver_docs(TrunkstoreId, Result).

-spec fetch_options() -> kz_view:options().
fetch_options() ->
    [{'doc_type', <<"trunk_server">>}
    ,'include_docs'
    ].

-spec fetch_selector() -> kz_view:selector().
fetch_selector() ->
    [{'start', [{<<"doc_type">>, <<"trunk_server">>}]}
    ,{'end', [{<<"doc_type">>, <<"trunk_server">>}]}
    ].

-spec handle_fetch_trunkserver_docs(kz_term:ne_binary(), kz_view:result()) -> kz_json:objects().
handle_fetch_trunkserver_docs(_TrunkstoreId, {'error', _}) -> [];
handle_fetch_trunkserver_docs(_TrunkstoreId, {'ok', []}) -> [];
handle_fetch_trunkserver_docs(TrunkstoreId, {'ok', Result}) ->
    [kz_json:get_json_value(<<"doc">>, Row)
     || Row <- Result,
        trunkstore_id(kz_json:get_json_value(<<"doc">>, Row)) =:= TrunkstoreId
    ].
