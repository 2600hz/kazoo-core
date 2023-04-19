%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `storage_plan_database_attachment' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_storage_plan_database_attachment).

-export([new/0]).
-export([handler/1, handler/2, set_handler/2]).
-export([params/1, params/2, set_params/2]).
-export([params_folder_path/1, params_folder_path/2, set_params_folder_path/2]).
-export([stub/1, stub/2, set_stub/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"storage.plan.database.attachment">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec handler(doc()) -> kz_term:api_binary().
handler(Doc) ->
    handler(Doc, 'undefined').

-spec handler(doc(), Default) -> binary() | Default.
handler(Doc, Default) ->
    kz_json:get_binary_value([<<"handler">>], Doc, Default).

-spec set_handler(doc(), binary()) -> doc().
set_handler(Doc, Handler) ->
    kz_json:set_value([<<"handler">>], Handler, Doc).

-spec params(doc()) -> kz_term:api_object().
params(Doc) ->
    params(Doc, 'undefined').

-spec params(doc(), Default) -> kz_json:object() | Default.
params(Doc, Default) ->
    kz_json:get_json_value([<<"params">>], Doc, Default).

-spec set_params(doc(), kz_json:object()) -> doc().
set_params(Doc, Params) ->
    kz_json:set_value([<<"params">>], Params, Doc).

-spec params_folder_path(doc()) -> kz_term:api_binary().
params_folder_path(Doc) ->
    params_folder_path(Doc, 'undefined').

-spec params_folder_path(doc(), Default) -> binary() | Default.
params_folder_path(Doc, Default) ->
    kz_json:get_binary_value([<<"params">>, <<"folder_path">>], Doc, Default).

-spec set_params_folder_path(doc(), binary()) -> doc().
set_params_folder_path(Doc, ParamsFolderPath) ->
    kz_json:set_value([<<"params">>, <<"folder_path">>], ParamsFolderPath, Doc).

-spec stub(doc()) -> kz_term:api_boolean().
stub(Doc) ->
    stub(Doc, 'undefined').

-spec stub(doc(), Default) -> boolean() | Default.
stub(Doc, Default) ->
    kz_json:get_boolean_value([<<"stub">>], Doc, Default).

-spec set_stub(doc(), boolean()) -> doc().
set_stub(Doc, Stub) ->
    kz_json:set_value([<<"stub">>], Stub, Doc).
