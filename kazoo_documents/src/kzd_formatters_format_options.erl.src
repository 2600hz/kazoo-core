%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `formatters_format_options' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_formatters_format_options).

-export([new/0]).
-export([direction/1, direction/2, set_direction/2]).
-export([match_invite_format/1, match_invite_format/2, set_match_invite_format/2]).
-export([prefix/1, prefix/2, set_prefix/2]).
-export([regex/1, regex/2, set_regex/2]).
-export([strip/1, strip/2, set_strip/2]).
-export([suffix/1, suffix/2, set_suffix/2]).
-export([value/1, value/2, set_value/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"formatters.format_options">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec direction(doc()) -> kz_term:api_binary().
direction(Doc) ->
    direction(Doc, 'undefined').

-spec direction(doc(), Default) -> binary() | Default.
direction(Doc, Default) ->
    kz_json:get_binary_value([<<"direction">>], Doc, Default).

-spec set_direction(doc(), binary()) -> doc().
set_direction(Doc, Direction) ->
    kz_json:set_value([<<"direction">>], Direction, Doc).

-spec match_invite_format(doc()) -> kz_term:api_boolean().
match_invite_format(Doc) ->
    match_invite_format(Doc, 'undefined').

-spec match_invite_format(doc(), Default) -> boolean() | Default.
match_invite_format(Doc, Default) ->
    kz_json:get_boolean_value([<<"match_invite_format">>], Doc, Default).

-spec set_match_invite_format(doc(), boolean()) -> doc().
set_match_invite_format(Doc, MatchInviteFormat) ->
    kz_json:set_value([<<"match_invite_format">>], MatchInviteFormat, Doc).

-spec prefix(doc()) -> kz_term:api_binary().
prefix(Doc) ->
    prefix(Doc, 'undefined').

-spec prefix(doc(), Default) -> binary() | Default.
prefix(Doc, Default) ->
    kz_json:get_binary_value([<<"prefix">>], Doc, Default).

-spec set_prefix(doc(), binary()) -> doc().
set_prefix(Doc, Prefix) ->
    kz_json:set_value([<<"prefix">>], Prefix, Doc).

-spec regex(doc()) -> kz_term:api_binary().
regex(Doc) ->
    regex(Doc, 'undefined').

-spec regex(doc(), Default) -> binary() | Default.
regex(Doc, Default) ->
    kz_json:get_binary_value([<<"regex">>], Doc, Default).

-spec set_regex(doc(), binary()) -> doc().
set_regex(Doc, Regex) ->
    kz_json:set_value([<<"regex">>], Regex, Doc).

-spec strip(doc()) -> kz_term:api_boolean().
strip(Doc) ->
    strip(Doc, 'undefined').

-spec strip(doc(), Default) -> boolean() | Default.
strip(Doc, Default) ->
    kz_json:get_boolean_value([<<"strip">>], Doc, Default).

-spec set_strip(doc(), boolean()) -> doc().
set_strip(Doc, Strip) ->
    kz_json:set_value([<<"strip">>], Strip, Doc).

-spec suffix(doc()) -> kz_term:api_binary().
suffix(Doc) ->
    suffix(Doc, 'undefined').

-spec suffix(doc(), Default) -> binary() | Default.
suffix(Doc, Default) ->
    kz_json:get_binary_value([<<"suffix">>], Doc, Default).

-spec set_suffix(doc(), binary()) -> doc().
set_suffix(Doc, Suffix) ->
    kz_json:set_value([<<"suffix">>], Suffix, Doc).

-spec value(doc()) -> kz_term:api_binary().
value(Doc) ->
    value(Doc, 'undefined').

-spec value(doc(), Default) -> binary() | Default.
value(Doc, Default) ->
    kz_json:get_binary_value([<<"value">>], Doc, Default).

-spec set_value(doc(), binary()) -> doc().
set_value(Doc, Value) ->
    kz_json:set_value([<<"value">>], Value, Doc).
