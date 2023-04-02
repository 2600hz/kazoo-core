%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `addresses' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_addresses).

-export([new/0]).
-export([emergency/1, emergency/2, set_emergency/2]).
-export([emergency_additional_information/1, emergency_additional_information/2, set_emergency_additional_information/2]).
-export([emergency_country/1, emergency_country/2, set_emergency_country/2]).
-export([emergency_county/1, emergency_county/2, set_emergency_county/2]).
-export([emergency_floor/1, emergency_floor/2, set_emergency_floor/2]).
-export([emergency_house_number/1, emergency_house_number/2, set_emergency_house_number/2]).
-export([emergency_house_number_suffix/1, emergency_house_number_suffix/2, set_emergency_house_number_suffix/2]).
-export([emergency_locality/1, emergency_locality/2, set_emergency_locality/2]).
-export([emergency_location_identifier/1, emergency_location_identifier/2, set_emergency_location_identifier/2]).
-export([emergency_name/1, emergency_name/2, set_emergency_name/2]).
-export([emergency_postal_code/1, emergency_postal_code/2, set_emergency_postal_code/2]).
-export([emergency_region/1, emergency_region/2, set_emergency_region/2]).
-export([emergency_street/1, emergency_street/2, set_emergency_street/2]).
-export([emergency_street_direction/1, emergency_street_direction/2, set_emergency_street_direction/2]).
-export([emergency_street_suffix/1, emergency_street_suffix/2, set_emergency_street_suffix/2]).
-export([emergency_street_type/1, emergency_street_type/2, set_emergency_street_type/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"addresses">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec emergency(doc()) -> kz_term:api_object().
emergency(Doc) ->
    emergency(Doc, 'undefined').

-spec emergency(doc(), Default) -> kz_json:object() | Default.
emergency(Doc, Default) ->
    kz_json:get_json_value([<<"emergency">>], Doc, Default).

-spec set_emergency(doc(), kz_json:object()) -> doc().
set_emergency(Doc, Emergency) ->
    kz_json:set_value([<<"emergency">>], Emergency, Doc).

-spec emergency_additional_information(doc()) -> kz_term:api_binary().
emergency_additional_information(Doc) ->
    emergency_additional_information(Doc, 'undefined').

-spec emergency_additional_information(doc(), Default) -> binary() | Default.
emergency_additional_information(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"additional_information">>], Doc, Default).

-spec set_emergency_additional_information(doc(), binary()) -> doc().
set_emergency_additional_information(Doc, EmergencyAdditionalInformation) ->
    kz_json:set_value([<<"emergency">>, <<"additional_information">>], EmergencyAdditionalInformation, Doc).

-spec emergency_country(doc()) -> kz_term:api_binary().
emergency_country(Doc) ->
    emergency_country(Doc, 'undefined').

-spec emergency_country(doc(), Default) -> binary() | Default.
emergency_country(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"country">>], Doc, Default).

-spec set_emergency_country(doc(), binary()) -> doc().
set_emergency_country(Doc, EmergencyCountry) ->
    kz_json:set_value([<<"emergency">>, <<"country">>], EmergencyCountry, Doc).

-spec emergency_county(doc()) -> kz_term:api_binary().
emergency_county(Doc) ->
    emergency_county(Doc, 'undefined').

-spec emergency_county(doc(), Default) -> binary() | Default.
emergency_county(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"county">>], Doc, Default).

-spec set_emergency_county(doc(), binary()) -> doc().
set_emergency_county(Doc, EmergencyCounty) ->
    kz_json:set_value([<<"emergency">>, <<"county">>], EmergencyCounty, Doc).

-spec emergency_floor(doc()) -> kz_term:api_integer().
emergency_floor(Doc) ->
    emergency_floor(Doc, 'undefined').

-spec emergency_floor(doc(), Default) -> integer() | Default.
emergency_floor(Doc, Default) ->
    kz_json:get_integer_value([<<"emergency">>, <<"floor">>], Doc, Default).

-spec set_emergency_floor(doc(), integer()) -> doc().
set_emergency_floor(Doc, EmergencyFloor) ->
    kz_json:set_value([<<"emergency">>, <<"floor">>], EmergencyFloor, Doc).

-spec emergency_house_number(doc()) -> kz_term:api_integer().
emergency_house_number(Doc) ->
    emergency_house_number(Doc, 'undefined').

-spec emergency_house_number(doc(), Default) -> integer() | Default.
emergency_house_number(Doc, Default) ->
    kz_json:get_integer_value([<<"emergency">>, <<"house_number">>], Doc, Default).

-spec set_emergency_house_number(doc(), integer()) -> doc().
set_emergency_house_number(Doc, EmergencyHouseNumber) ->
    kz_json:set_value([<<"emergency">>, <<"house_number">>], EmergencyHouseNumber, Doc).

-spec emergency_house_number_suffix(doc()) -> kz_term:api_binary().
emergency_house_number_suffix(Doc) ->
    emergency_house_number_suffix(Doc, 'undefined').

-spec emergency_house_number_suffix(doc(), Default) -> binary() | Default.
emergency_house_number_suffix(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"house_number_suffix">>], Doc, Default).

-spec set_emergency_house_number_suffix(doc(), binary()) -> doc().
set_emergency_house_number_suffix(Doc, EmergencyHouseNumberSuffix) ->
    kz_json:set_value([<<"emergency">>, <<"house_number_suffix">>], EmergencyHouseNumberSuffix, Doc).

-spec emergency_locality(doc()) -> kz_term:api_binary().
emergency_locality(Doc) ->
    emergency_locality(Doc, 'undefined').

-spec emergency_locality(doc(), Default) -> binary() | Default.
emergency_locality(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"locality">>], Doc, Default).

-spec set_emergency_locality(doc(), binary()) -> doc().
set_emergency_locality(Doc, EmergencyLocality) ->
    kz_json:set_value([<<"emergency">>, <<"locality">>], EmergencyLocality, Doc).

-spec emergency_location_identifier(doc()) -> kz_term:api_integer().
emergency_location_identifier(Doc) ->
    emergency_location_identifier(Doc, 'undefined').

-spec emergency_location_identifier(doc(), Default) -> integer() | Default.
emergency_location_identifier(Doc, Default) ->
    kz_json:get_integer_value([<<"emergency">>, <<"location_identifier">>], Doc, Default).

-spec set_emergency_location_identifier(doc(), integer()) -> doc().
set_emergency_location_identifier(Doc, EmergencyLocationIdentifier) ->
    kz_json:set_value([<<"emergency">>, <<"location_identifier">>], EmergencyLocationIdentifier, Doc).

-spec emergency_name(doc()) -> kz_term:api_binary().
emergency_name(Doc) ->
    emergency_name(Doc, 'undefined').

-spec emergency_name(doc(), Default) -> binary() | Default.
emergency_name(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"name">>], Doc, Default).

-spec set_emergency_name(doc(), binary()) -> doc().
set_emergency_name(Doc, EmergencyName) ->
    kz_json:set_value([<<"emergency">>, <<"name">>], EmergencyName, Doc).

-spec emergency_postal_code(doc()) -> kz_term:api_binary().
emergency_postal_code(Doc) ->
    emergency_postal_code(Doc, 'undefined').

-spec emergency_postal_code(doc(), Default) -> binary() | Default.
emergency_postal_code(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"postal_code">>], Doc, Default).

-spec set_emergency_postal_code(doc(), binary()) -> doc().
set_emergency_postal_code(Doc, EmergencyPostalCode) ->
    kz_json:set_value([<<"emergency">>, <<"postal_code">>], EmergencyPostalCode, Doc).

-spec emergency_region(doc()) -> kz_term:api_binary().
emergency_region(Doc) ->
    emergency_region(Doc, 'undefined').

-spec emergency_region(doc(), Default) -> binary() | Default.
emergency_region(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"region">>], Doc, Default).

-spec set_emergency_region(doc(), binary()) -> doc().
set_emergency_region(Doc, EmergencyRegion) ->
    kz_json:set_value([<<"emergency">>, <<"region">>], EmergencyRegion, Doc).

-spec emergency_street(doc()) -> kz_term:api_binary().
emergency_street(Doc) ->
    emergency_street(Doc, 'undefined').

-spec emergency_street(doc(), Default) -> binary() | Default.
emergency_street(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"street">>], Doc, Default).

-spec set_emergency_street(doc(), binary()) -> doc().
set_emergency_street(Doc, EmergencyStreet) ->
    kz_json:set_value([<<"emergency">>, <<"street">>], EmergencyStreet, Doc).

-spec emergency_street_direction(doc()) -> kz_term:api_binary().
emergency_street_direction(Doc) ->
    emergency_street_direction(Doc, 'undefined').

-spec emergency_street_direction(doc(), Default) -> binary() | Default.
emergency_street_direction(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"street_direction">>], Doc, Default).

-spec set_emergency_street_direction(doc(), binary()) -> doc().
set_emergency_street_direction(Doc, EmergencyStreetDirection) ->
    kz_json:set_value([<<"emergency">>, <<"street_direction">>], EmergencyStreetDirection, Doc).

-spec emergency_street_suffix(doc()) -> kz_term:api_binary().
emergency_street_suffix(Doc) ->
    emergency_street_suffix(Doc, 'undefined').

-spec emergency_street_suffix(doc(), Default) -> binary() | Default.
emergency_street_suffix(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"street_suffix">>], Doc, Default).

-spec set_emergency_street_suffix(doc(), binary()) -> doc().
set_emergency_street_suffix(Doc, EmergencyStreetSuffix) ->
    kz_json:set_value([<<"emergency">>, <<"street_suffix">>], EmergencyStreetSuffix, Doc).

-spec emergency_street_type(doc()) -> kz_term:api_binary().
emergency_street_type(Doc) ->
    emergency_street_type(Doc, 'undefined').

-spec emergency_street_type(doc(), Default) -> binary() | Default.
emergency_street_type(Doc, Default) ->
    kz_json:get_binary_value([<<"emergency">>, <<"street_type">>], Doc, Default).

-spec set_emergency_street_type(doc(), binary()) -> doc().
set_emergency_street_type(Doc, EmergencyStreetType) ->
    kz_json:set_value([<<"emergency">>, <<"street_type">>], EmergencyStreetType, Doc).
