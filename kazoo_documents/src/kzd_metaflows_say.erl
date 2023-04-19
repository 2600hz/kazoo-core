%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `metaflows_say' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_say).

-export([new/0]).
-export([gender/1, gender/2, set_gender/2]).
-export([language/1, language/2, set_language/2]).
-export([method/1, method/2, set_method/2]).
-export([text/1, text/2, set_text/2]).
-export([type/1, type/2, set_type/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.say">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec gender(doc()) -> kz_term:api_binary().
gender(Doc) ->
    gender(Doc, 'undefined').

-spec gender(doc(), Default) -> binary() | Default.
gender(Doc, Default) ->
    kz_json:get_binary_value([<<"gender">>], Doc, Default).

-spec set_gender(doc(), binary()) -> doc().
set_gender(Doc, Gender) ->
    kz_json:set_value([<<"gender">>], Gender, Doc).

-spec language(doc()) -> kz_term:api_binary().
language(Doc) ->
    language(Doc, 'undefined').

-spec language(doc(), Default) -> binary() | Default.
language(Doc, Default) ->
    kz_json:get_binary_value([<<"language">>], Doc, Default).

-spec set_language(doc(), binary()) -> doc().
set_language(Doc, Language) ->
    kz_json:set_value([<<"language">>], Language, Doc).

-spec method(doc()) -> kz_term:api_binary().
method(Doc) ->
    method(Doc, 'undefined').

-spec method(doc(), Default) -> binary() | Default.
method(Doc, Default) ->
    kz_json:get_binary_value([<<"method">>], Doc, Default).

-spec set_method(doc(), binary()) -> doc().
set_method(Doc, Method) ->
    kz_json:set_value([<<"method">>], Method, Doc).

-spec text(doc()) -> kz_term:api_binary().
text(Doc) ->
    text(Doc, 'undefined').

-spec text(doc(), Default) -> binary() | Default.
text(Doc, Default) ->
    kz_json:get_binary_value([<<"text">>], Doc, Default).

-spec set_text(doc(), binary()) -> doc().
set_text(Doc, Text) ->
    kz_json:set_value([<<"text">>], Text, Doc).

-spec type(doc()) -> kz_term:api_binary().
type(Doc) ->
    type(Doc, 'undefined').

-spec type(doc(), Default) -> binary() | Default.
type(Doc, Default) ->
    kz_json:get_binary_value([<<"type">>], Doc, Default).

-spec set_type(doc(), binary()) -> doc().
set_type(Doc, Type) ->
    kz_json:set_value([<<"type">>], Type, Doc).
