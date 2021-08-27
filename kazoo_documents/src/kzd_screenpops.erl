%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc Accessors for `screenpops' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_screenpops).

-export([new/0]).
-export([custom_parameters/1, custom_parameters/2, set_custom_parameters/2]).
-export([custom_parameters_custom_url/1, custom_parameters_custom_url/2, set_custom_parameters_custom_url/2]).
-export([custom_parameters_link_text/1, custom_parameters_link_text/2, set_custom_parameters_link_text/2]).
-export([custom_parameters_name/1, custom_parameters_name/2, set_custom_parameters_name/2]).
-export([custom_parameters_render_name_as_label/1, custom_parameters_render_name_as_label/2, set_custom_parameters_render_name_as_label/2]).
-export([custom_parameters_request_method/1, custom_parameters_request_method/2, set_custom_parameters_request_method/2]).
-export([custom_parameters_token/1, custom_parameters_token/2, set_custom_parameters_token/2]).
-export([custom_parameters_type_custom_parameter/1, custom_parameters_type_custom_parameter/2, set_custom_parameters_type_custom_parameter/2]).
-export([custom_parameters_url/1, custom_parameters_url/2, set_custom_parameters_url/2]).
-export([custom_parameters_url_parameters/1, custom_parameters_url_parameters/2, set_custom_parameters_url_parameters/2]).
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

-spec custom_parameters(doc()) -> kz_term:api_object().
custom_parameters(Doc) ->
    custom_parameters(Doc, 'undefined').

-spec custom_parameters(doc(), Default) -> kz_json:object() | Default.
custom_parameters(Doc, Default) ->
    kz_json:get_json_value([<<"custom_parameters">>], Doc, Default).

-spec set_custom_parameters(doc(), kz_json:object()) -> doc().
set_custom_parameters(Doc, CustomParameters) ->
    kz_json:set_value([<<"custom_parameters">>], CustomParameters, Doc).

-spec custom_parameters_custom_url(doc()) -> kz_term:api_binary().
custom_parameters_custom_url(Doc) ->
    custom_parameters_custom_url(Doc, 'undefined').

-spec custom_parameters_custom_url(doc(), Default) -> binary() | Default.
custom_parameters_custom_url(Doc, Default) ->
    kz_json:get_binary_value([<<"custom_parameters">>, <<"custom_url">>], Doc, Default).

-spec set_custom_parameters_custom_url(doc(), binary()) -> doc().
set_custom_parameters_custom_url(Doc, CustomParametersCustomUrl) ->
    kz_json:set_value([<<"custom_parameters">>, <<"custom_url">>], CustomParametersCustomUrl, Doc).

-spec custom_parameters_link_text(doc()) -> kz_term:api_binary().
custom_parameters_link_text(Doc) ->
    custom_parameters_link_text(Doc, 'undefined').

-spec custom_parameters_link_text(doc(), Default) -> binary() | Default.
custom_parameters_link_text(Doc, Default) ->
    kz_json:get_binary_value([<<"custom_parameters">>, <<"link_text">>], Doc, Default).

-spec set_custom_parameters_link_text(doc(), binary()) -> doc().
set_custom_parameters_link_text(Doc, CustomParametersLinkText) ->
    kz_json:set_value([<<"custom_parameters">>, <<"link_text">>], CustomParametersLinkText, Doc).

-spec custom_parameters_name(doc()) -> kz_term:api_binary().
custom_parameters_name(Doc) ->
    custom_parameters_name(Doc, 'undefined').

-spec custom_parameters_name(doc(), Default) -> binary() | Default.
custom_parameters_name(Doc, Default) ->
    kz_json:get_binary_value([<<"custom_parameters">>, <<"name">>], Doc, Default).

-spec set_custom_parameters_name(doc(), binary()) -> doc().
set_custom_parameters_name(Doc, CustomParametersName) ->
    kz_json:set_value([<<"custom_parameters">>, <<"name">>], CustomParametersName, Doc).

-spec custom_parameters_render_name_as_label(doc()) -> kz_term:api_boolean().
custom_parameters_render_name_as_label(Doc) ->
    custom_parameters_render_name_as_label(Doc, 'undefined').

-spec custom_parameters_render_name_as_label(doc(), Default) -> boolean() | Default.
custom_parameters_render_name_as_label(Doc, Default) ->
    kz_json:get_boolean_value([<<"custom_parameters">>, <<"render_name_as_label">>], Doc, Default).

-spec set_custom_parameters_render_name_as_label(doc(), boolean()) -> doc().
set_custom_parameters_render_name_as_label(Doc, CustomParametersRenderNameAsLabel) ->
    kz_json:set_value([<<"custom_parameters">>, <<"render_name_as_label">>], CustomParametersRenderNameAsLabel, Doc).

-spec custom_parameters_request_method(doc()) -> kz_term:api_binary().
custom_parameters_request_method(Doc) ->
    custom_parameters_request_method(Doc, 'undefined').

-spec custom_parameters_request_method(doc(), Default) -> binary() | Default.
custom_parameters_request_method(Doc, Default) ->
    kz_json:get_binary_value([<<"custom_parameters">>, <<"request_method">>], Doc, Default).

-spec set_custom_parameters_request_method(doc(), binary()) -> doc().
set_custom_parameters_request_method(Doc, CustomParametersRequestMethod) ->
    kz_json:set_value([<<"custom_parameters">>, <<"request_method">>], CustomParametersRequestMethod, Doc).

-spec custom_parameters_token(doc()) -> kz_term:api_binary().
custom_parameters_token(Doc) ->
    custom_parameters_token(Doc, 'undefined').

-spec custom_parameters_token(doc(), Default) -> binary() | Default.
custom_parameters_token(Doc, Default) ->
    kz_json:get_binary_value([<<"custom_parameters">>, <<"token">>], Doc, Default).

-spec set_custom_parameters_token(doc(), binary()) -> doc().
set_custom_parameters_token(Doc, CustomParametersToken) ->
    kz_json:set_value([<<"custom_parameters">>, <<"token">>], CustomParametersToken, Doc).

-spec custom_parameters_type_custom_parameter(doc()) -> kz_term:api_binary().
custom_parameters_type_custom_parameter(Doc) ->
    custom_parameters_type_custom_parameter(Doc, 'undefined').

-spec custom_parameters_type_custom_parameter(doc(), Default) -> binary() | Default.
custom_parameters_type_custom_parameter(Doc, Default) ->
    kz_json:get_binary_value([<<"custom_parameters">>, <<"type_custom_parameter">>], Doc, Default).

-spec set_custom_parameters_type_custom_parameter(doc(), binary()) -> doc().
set_custom_parameters_type_custom_parameter(Doc, CustomParametersTypeCustomParameter) ->
    kz_json:set_value([<<"custom_parameters">>, <<"type_custom_parameter">>], CustomParametersTypeCustomParameter, Doc).

-spec custom_parameters_url(doc()) -> kz_term:api_binary().
custom_parameters_url(Doc) ->
    custom_parameters_url(Doc, 'undefined').

-spec custom_parameters_url(doc(), Default) -> binary() | Default.
custom_parameters_url(Doc, Default) ->
    kz_json:get_binary_value([<<"custom_parameters">>, <<"url">>], Doc, Default).

-spec set_custom_parameters_url(doc(), binary()) -> doc().
set_custom_parameters_url(Doc, CustomParametersUrl) ->
    kz_json:set_value([<<"custom_parameters">>, <<"url">>], CustomParametersUrl, Doc).

-spec custom_parameters_url_parameters(doc()) -> kz_term:api_object().
custom_parameters_url_parameters(Doc) ->
    custom_parameters_url_parameters(Doc, 'undefined').

-spec custom_parameters_url_parameters(doc(), Default) -> kz_json:object() | Default.
custom_parameters_url_parameters(Doc, Default) ->
    kz_json:get_json_value([<<"custom_parameters">>, <<"url_parameters">>], Doc, Default).

-spec set_custom_parameters_url_parameters(doc(), kz_json:object()) -> doc().
set_custom_parameters_url_parameters(Doc, CustomParametersUrlParameters) ->
    kz_json:set_value([<<"custom_parameters">>, <<"url_parameters">>], CustomParametersUrlParameters, Doc).

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
