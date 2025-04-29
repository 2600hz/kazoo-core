%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2025, 2600Hz
%%% @doc Accessors for account base `trunkingio_settings' document.
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_trunkingio_settings).

-export([new/0, new/1]).
-export([pvt_type/0
        ,schema/0
        ,db_id/0
        ]).

-export([activate/1
        ,link/2
        ]).

-export([is_linked/1]).

-export([linking_error/1, linking_error/2, set_linking_error/2]).
-export([pvt_enabled/1, pvt_enabled/2, set_pvt_enabled/2]).
-export([pvt_status/1, pvt_status/2, set_pvt_status/2]).
-export([pvt_im_webhook_id/1, pvt_im_webhook_id/2, set_pvt_im_webhook_id/2]).
-export([pvt_im_webhook_secret/1, pvt_im_webhook_secret/2, set_pvt_im_webhook_secret/2]).
-export([pvt_tio_account_id/1, pvt_tio_account_id/2, set_pvt_tio_account_id/2]).
-export([pvt_tio_api_token/1, pvt_tio_api_token/2, set_pvt_tio_api_token/2]).
-export([pvt_linked_at/1, pvt_linked_at/2, insert_pvt_linked_at/2]).

-include_lib("kazoo_documents/src/kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(PVT_TYPE, <<"trunkingio_settings">>).
-define(SCHEMA, <<"trunkingio_settings">>).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_type() -> kz_term:ne_binary().
pvt_type() -> ?PVT_TYPE.

-spec db_id() -> kz_term:ne_binary().
db_id() -> ?PVT_TYPE.

-spec schema() -> kz_term:ne_binary().
schema() -> ?SCHEMA.

-spec new() -> doc().
new() ->
    new('undefined').

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec new(kz_term:api_ne_binary()) -> doc().
new(AccountId) ->
    Setters = [{fun kz_doc:set_id/2, db_id()}
              ,{fun kz_doc:set_type/2, pvt_type()}
              ,{fun kz_doc:set_account_id/2, AccountId}
              ,{fun kz_doc:set_account_db/2, kzs_util:format_account_db(AccountId)}
              ,{fun set_pvt_enabled/2, 'false'}
              ,{fun set_pvt_status/2, <<"unlinked">>}
              ],
    kz_doc:setters(Setters).

%%------------------------------------------------------------------------------
%% @doc Use to enable the tio for reseller and make it ready for linking
%% @end
%%------------------------------------------------------------------------------
-spec activate(doc()) -> doc().
activate(Doc) ->
    Routines = [{fun set_pvt_enabled/2, 'true'}
               ,{fun set_pvt_status/2, <<"linking">>}
               ],
    kz_doc:setters(Doc, Routines).

-spec link(doc(), kz_term:ne_binary()) -> doc().
link(Doc, TioAccountId) ->
    Routines = [{fun set_pvt_enabled/2, 'true'}
               ,{fun set_pvt_status/2, <<"linked">>}
               ,{fun set_pvt_tio_account_id/2, TioAccountId}
               ,{fun insert_pvt_linked_at/2, kz_time:now_s()}
               ],
    kz_json:delete_key(linking_error_path(), kz_doc:setters(Doc, Routines)).

-spec is_linked(doc()) -> boolean().
is_linked(Doc) ->
    kz_term:is_true(pvt_enabled(Doc))
        andalso kz_term:is_not_empty(pvt_tio_account_id(Doc))
        andalso pvt_status(Doc) =:= <<"linked">>.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec linking_error(doc()) -> kz_term:api_ne_binary().
linking_error(Doc) ->
    linking_error(Doc, 'undefined').

-spec linking_error(doc(), Default) -> kz_term:ne_binary() | Default.
linking_error(Doc, Default) ->
    kz_json:get_ne_binary_value(linking_error_path(), Doc, Default).

-spec set_linking_error(doc(), kz_term:ne_binary()) -> doc().
set_linking_error(Doc, Value) ->
    kz_json:set_value(linking_error_path(), Value, Doc).

linking_error_path() -> [<<"linking_error">>].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_enabled(doc()) -> boolean().
pvt_enabled(Doc) ->
    pvt_enabled(Doc, 'false').

-spec pvt_enabled(doc(), Default) -> boolean() | Default.
pvt_enabled(Doc, Default) ->
    kz_json:is_true([<<"pvt_enabled">>], Doc, Default).

-spec set_pvt_enabled(doc(), boolean()) -> doc().
set_pvt_enabled(Doc, Value) ->
    kz_json:set_value([<<"pvt_enabled">>], Value, Doc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_status(doc()) -> kz_term:ne_binary().
pvt_status(Doc) ->
    pvt_status(Doc, <<"unlinked">>).

-spec pvt_status(doc(), Default) -> kz_term:ne_binary() | Default.
pvt_status(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"pvt_status">>], Doc, Default).

-spec set_pvt_status(doc(), kz_term:ne_binary()) -> doc().
set_pvt_status(Doc, Value) ->
    kz_json:set_value([<<"pvt_status">>], Value, Doc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_tio_account_id(doc()) -> kz_term:api_ne_binary().
pvt_tio_account_id(Doc) ->
    pvt_tio_account_id(Doc, 'undefined').

-spec pvt_tio_account_id(doc(), Default) -> kz_term:ne_binary() | Default.
pvt_tio_account_id(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"pvt_tio_account_id">>], Doc, Default).

-spec set_pvt_tio_account_id(doc(), kz_term:ne_binary()) -> doc().
set_pvt_tio_account_id(Doc, Value) ->
    kz_json:set_value([<<"pvt_tio_account_id">>], Value, Doc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_tio_api_token(doc()) -> kz_term:api_ne_binary().
pvt_tio_api_token(Doc) ->
    pvt_tio_api_token(Doc, 'undefined').

-spec pvt_tio_api_token(doc(), Default) -> kz_term:ne_binary() | Default.
pvt_tio_api_token(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"pvt_tio_api_token">>], Doc, Default).

-spec set_pvt_tio_api_token(doc(), kz_term:ne_binary()) -> doc().
set_pvt_tio_api_token(Doc, Value) ->
    kz_json:set_value([<<"pvt_tio_api_token">>], Value, Doc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_im_webhook_id(doc()) -> kz_term:api_ne_binary().
pvt_im_webhook_id(Doc) ->
    pvt_im_webhook_id(Doc, 'undefined').

-spec pvt_im_webhook_id(doc(), Default) -> kz_term:ne_binary() | Default.
pvt_im_webhook_id(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"pvt_im_webhook_id">>], Doc, Default).

-spec set_pvt_im_webhook_id(doc(), kz_term:ne_binary()) -> doc().
set_pvt_im_webhook_id(Doc, Value) ->
    kz_json:set_value([<<"pvt_im_webhook_id">>], Value, Doc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_im_webhook_secret(doc()) -> kz_term:api_ne_binary().
pvt_im_webhook_secret(Doc) ->
    pvt_im_webhook_secret(Doc, 'undefined').

-spec pvt_im_webhook_secret(doc(), Default) -> kz_term:ne_binary() | Default.
pvt_im_webhook_secret(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"pvt_im_webhook_secret">>], Doc, Default).

-spec set_pvt_im_webhook_secret(doc(), kz_term:ne_binary()) -> doc().
set_pvt_im_webhook_secret(Doc, Value) ->
    kz_json:set_value([<<"pvt_im_webhook_secret">>], Value, Doc).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pvt_linked_at(doc()) -> kz_time:api_seconds().
pvt_linked_at(Doc) ->
    pvt_linked_at(Doc, 'undefined').

-spec pvt_linked_at(doc(), Default) -> kz_time:second() | Default.
pvt_linked_at(Doc, Default) ->
    kz_json:get_integer_value([<<"pvt_linked_at">>], Doc, Default).

-spec insert_pvt_linked_at(doc(), kz_term:ne_binary()) -> doc().
insert_pvt_linked_at(Doc, Value) ->
    kz_json:insert_value([<<"pvt_linked_at">>], Value, Doc).
