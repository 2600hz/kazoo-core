%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc Accessors for `screenpops' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_screenpops).

-export([new/0]).
-export([custom_parameters/1, custom_parameters/2, set_custom_parameters/2]).
-export([post_call_extension_time/1, post_call_extension_time/2, set_post_call_extension_time/2]).
-export([show_location_call_time/1, show_location_call_time/2, set_show_location_call_time/2]).
-export([type_screenpops/1, type_screenpops/2, set_type_screenpops/2]).

-export([type/0
        ,schema_name/0
        ]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"screenpops">>).
-define(TYPE, <<"screenpop">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec type() -> kz_term:ne_binary().
type() -> ?TYPE.

-spec schema_name() -> kz_term:ne_binary().
schema_name() -> ?SCHEMA.


-spec custom_parameters(doc()) -> kz_term:api_objects().
custom_parameters(Doc) ->
    custom_parameters(Doc, 'undefined').

-spec custom_parameters(doc(), Default) -> kz_json:objects() | Default.
custom_parameters(Doc, Default) ->
    kz_json:get_list_value([<<"custom_parameters">>], Doc, Default).

-spec set_custom_parameters(doc(), kz_json:objects()) -> doc().
set_custom_parameters(Doc, CustomParameters) ->
    kz_json:set_value([<<"custom_parameters">>], CustomParameters, Doc).

-spec post_call_extension_time(doc()) -> kz_term:api_number().
post_call_extension_time(Doc) ->
    post_call_extension_time(Doc, 'undefined').

-spec post_call_extension_time(doc(), Default) -> number() | Default.
post_call_extension_time(Doc, Default) ->
    kz_json:get_float_value([<<"post_call_extension_time">>], Doc, Default).

-spec set_post_call_extension_time(doc(), number()) -> doc().
set_post_call_extension_time(Doc, PostCallExtensionTime) ->
    kz_json:set_value([<<"post_call_extension_time">>], PostCallExtensionTime, Doc).

-spec show_location_call_time(doc()) -> boolean().
show_location_call_time(Doc) ->
    show_location_call_time(Doc, false).

-spec show_location_call_time(doc(), Default) -> boolean() | Default.
show_location_call_time(Doc, Default) ->
    kz_json:get_boolean_value([<<"show_location_call_time">>], Doc, Default).

-spec set_show_location_call_time(doc(), boolean()) -> doc().
set_show_location_call_time(Doc, ShowLocationCallTime) ->
    kz_json:set_value([<<"show_location_call_time">>], ShowLocationCallTime, Doc).

-spec type_screenpops(doc()) -> binary().
type_screenpops(Doc) ->
    type_screenpops(Doc, <<"notification">>).

-spec type_screenpops(doc(), Default) -> binary() | Default.
type_screenpops(Doc, Default) ->
    kz_json:get_binary_value([<<"type_screenpops">>], Doc, Default).

-spec set_type_screenpops(doc(), binary()) -> doc().
set_type_screenpops(Doc, TypeScreenpops) ->
    kz_json:set_value([<<"type_screenpops">>], TypeScreenpops, Doc).
