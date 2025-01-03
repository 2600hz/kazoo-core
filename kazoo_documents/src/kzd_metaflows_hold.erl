%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `metaflows_hold' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_hold).

-export([new/0]).
-export([moh_aleg/1, moh_aleg/2, set_moh_aleg/2]).
-export([moh_bleg/1, moh_bleg/2, set_moh_bleg/2]).
-export([unhold_key/1, unhold_key/2, set_unhold_key/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.hold">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec moh_aleg(doc()) -> kz_term:api_binary().
moh_aleg(Doc) ->
    moh_aleg(Doc, 'undefined').

-spec moh_aleg(doc(), Default) -> binary() | Default.
moh_aleg(Doc, Default) ->
    kz_json:get_binary_value([<<"moh_aleg">>], Doc, Default).

-spec set_moh_aleg(doc(), binary()) -> doc().
set_moh_aleg(Doc, MohAleg) ->
    kz_json:set_value([<<"moh_aleg">>], MohAleg, Doc).

-spec moh_bleg(doc()) -> kz_term:api_binary().
moh_bleg(Doc) ->
    moh_bleg(Doc, 'undefined').

-spec moh_bleg(doc(), Default) -> binary() | Default.
moh_bleg(Doc, Default) ->
    kz_json:get_binary_value([<<"moh_bleg">>], Doc, Default).

-spec set_moh_bleg(doc(), binary()) -> doc().
set_moh_bleg(Doc, MohBleg) ->
    kz_json:set_value([<<"moh_bleg">>], MohBleg, Doc).

-spec unhold_key(doc()) -> binary().
unhold_key(Doc) ->
    unhold_key(Doc, <<"1">>).

-spec unhold_key(doc(), Default) -> binary() | Default.
unhold_key(Doc, Default) ->
    kz_json:get_binary_value([<<"unhold_key">>], Doc, Default).

-spec set_unhold_key(doc(), binary()) -> doc().
set_unhold_key(Doc, UnholdKey) ->
    kz_json:set_value([<<"unhold_key">>], UnholdKey, Doc).
