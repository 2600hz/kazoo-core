%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Accessors for `metaflows_tts' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_metaflows_tts).

-export([new/0]).
-export([engine/1, engine/2, set_engine/2]).
-export([language/1, language/2, set_language/2]).
-export([leg/1, leg/2, set_leg/2]).
-export([terminators/1, terminators/2, set_terminators/2]).
-export([text/1, text/2, set_text/2]).
-export([voice/1, voice/2, set_voice/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"metaflows.tts">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec engine(doc()) -> binary().
engine(Doc) ->
    engine(Doc, <<"flite">>).

-spec engine(doc(), Default) -> binary() | Default.
engine(Doc, Default) ->
    kz_json:get_binary_value([<<"engine">>], Doc, Default).

-spec set_engine(doc(), binary()) -> doc().
set_engine(Doc, Engine) ->
    kz_json:set_value([<<"engine">>], Engine, Doc).

-spec language(doc()) -> kz_term:api_binary().
language(Doc) ->
    language(Doc, 'undefined').

-spec language(doc(), Default) -> binary() | Default.
language(Doc, Default) ->
    kz_json:get_binary_value([<<"language">>], Doc, Default).

-spec set_language(doc(), binary()) -> doc().
set_language(Doc, Language) ->
    kz_json:set_value([<<"language">>], Language, Doc).

-spec leg(doc()) -> binary().
leg(Doc) ->
    leg(Doc, <<"self">>).

-spec leg(doc(), Default) -> binary() | Default.
leg(Doc, Default) ->
    kz_json:get_binary_value([<<"leg">>], Doc, Default).

-spec set_leg(doc(), binary()) -> doc().
set_leg(Doc, Leg) ->
    kz_json:set_value([<<"leg">>], Leg, Doc).

-spec terminators(doc()) -> kz_term:ne_binaries().
terminators(Doc) ->
    terminators(Doc, ?ANY_DIGIT).

-spec terminators(doc(), Default) -> kz_term:ne_binaries() | Default.
terminators(Doc, Default) ->
    kz_json:get_list_value([<<"terminators">>], Doc, Default).

-spec set_terminators(doc(), kz_term:ne_binaries()) -> doc().
set_terminators(Doc, Terminators) ->
    kz_json:set_value([<<"terminators">>], Terminators, Doc).

-spec text(doc()) -> kz_term:api_binary().
text(Doc) ->
    text(Doc, 'undefined').

-spec text(doc(), Default) -> binary() | Default.
text(Doc, Default) ->
    kz_json:get_binary_value([<<"text">>], Doc, Default).

-spec set_text(doc(), binary()) -> doc().
set_text(Doc, Text) ->
    kz_json:set_value([<<"text">>], Text, Doc).

-spec voice(doc()) -> binary().
voice(Doc) ->
    voice(Doc, <<"female">>).

-spec voice(doc(), Default) -> binary() | Default.
voice(Doc, Default) ->
    kz_json:get_binary_value([<<"voice">>], Doc, Default).

-spec set_voice(doc(), binary()) -> doc().
set_voice(Doc, Voice) ->
    kz_json:set_value([<<"voice">>], Voice, Doc).
