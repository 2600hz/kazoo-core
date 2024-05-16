%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `service_plan_item' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_service_plan_item).

-export([new/0]).
-export([activation_charge/1, activation_charge/2, set_activation_charge/2]).
-export([as/1, as/2, set_as/2]).
-export([cascade/1, cascade/2, set_cascade/2]).
-export([discounts/1, discounts/2, set_discounts/2]).
-export([discounts_cumulative/1, discounts_cumulative/2, set_discounts_cumulative/2]).
-export([discounts_cumulative_maximum/1, discounts_cumulative_maximum/2, set_discounts_cumulative_maximum/2]).
-export([discounts_cumulative_rate/1, discounts_cumulative_rate/2, set_discounts_cumulative_rate/2]).
-export([discounts_cumulative_rates_rate/2, discounts_cumulative_rates_rate/3, set_discounts_cumulative_rates_rate/3]).
-export([discounts_cumulative_rates/1, discounts_cumulative_rates/2, set_discounts_cumulative_rates/2]).
-export([discounts_single/1, discounts_single/2, set_discounts_single/2]).
-export([discounts_single_rate/1, discounts_single_rate/2, set_discounts_single_rate/2]).
-export([discounts_single_rates_rate/2, discounts_single_rates_rate/3, set_discounts_single_rates_rate/3]).
-export([discounts_single_rates/1, discounts_single_rates/2, set_discounts_single_rates/2]).
-export([flat_rate/1, flat_rate/2, set_flat_rate/2]).
-export([flat_rates_rate/2, flat_rates_rate/3, set_flat_rates_rate/3]).
-export([flat_rates/1, flat_rates/2, set_flat_rates/2]).
-export([markup_type/1, markup_type/2, set_markup_type/2]).
-export([maximum/1, maximum/2, set_maximum/2]).
-export([minimum/1, minimum/2, set_minimum/2]).
-export([name/1, name/2, set_name/2]).
-export([prorate/1, prorate/2, set_prorate/2]).
-export([prorate_additions/1, prorate_additions/2, set_prorate_additions/2]).
-export([prorate_removals/1, prorate_removals/2, set_prorate_removals/2]).
-export([quantity/1, quantity/2, set_quantity/2]).
-export([quantity_category/1, quantity_category/2, set_quantity_category/2]).
-export([quantity_name/1, quantity_name/2, set_quantity_name/2]).
-export([rate/1, rate/2, set_rate/2]).
-export([rates_rate/2, rates_rate/3, set_rates_rate/3]).
-export([rates/1, rates/2, set_rates/2]).
-export([step/1, step/2, set_step/2]).
-export([taxes/1, taxes/2, set_taxes/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"service_plan.item">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec activation_charge(doc()) -> number().
activation_charge(Doc) ->
    activation_charge(Doc, 0.0).

-spec activation_charge(doc(), Default) -> number() | Default.
activation_charge(Doc, Default) ->
    kz_json:get_float_value([<<"activation_charge">>], Doc, Default).

-spec set_activation_charge(doc(), number()) -> doc().
set_activation_charge(Doc, ActivationCharge) ->
    kz_json:set_value([<<"activation_charge">>], ActivationCharge, Doc).

-spec as(doc()) -> kz_term:api_binary().
as(Doc) ->
    as(Doc, 'undefined').

-spec as(doc(), Default) -> binary() | Default.
as(Doc, Default) ->
    kz_json:get_binary_value([<<"as">>], Doc, Default).

-spec set_as(doc(), binary()) -> doc().
set_as(Doc, As) ->
    kz_json:set_value([<<"as">>], As, Doc).

-spec cascade(doc()) -> boolean().
cascade(Doc) ->
    cascade(Doc, 'false').

-spec cascade(doc(), Default) -> boolean() | Default.
cascade(Doc, Default) ->
    kz_json:get_boolean_value([<<"cascade">>], Doc, Default).

-spec set_cascade(doc(), boolean()) -> doc().
set_cascade(Doc, Cascade) ->
    kz_json:set_value([<<"cascade">>], Cascade, Doc).

-spec discounts(doc()) -> kz_term:api_object().
discounts(Doc) ->
    discounts(Doc, 'undefined').

-spec discounts(doc(), Default) -> kz_json:object() | Default.
discounts(Doc, Default) ->
    kz_json:get_json_value([<<"discounts">>], Doc, Default).

-spec set_discounts(doc(), kz_json:object()) -> doc().
set_discounts(Doc, Discounts) ->
    kz_json:set_value([<<"discounts">>], Discounts, Doc).

-spec discounts_cumulative(doc()) -> kz_term:api_object().
discounts_cumulative(Doc) ->
    discounts_cumulative(Doc, 'undefined').

-spec discounts_cumulative(doc(), Default) -> kz_json:object() | Default.
discounts_cumulative(Doc, Default) ->
    kz_json:get_json_value([<<"discounts">>, <<"cumulative">>], Doc, Default).

-spec set_discounts_cumulative(doc(), kz_json:object()) -> doc().
set_discounts_cumulative(Doc, DiscountsCumulative) ->
    kz_json:set_value([<<"discounts">>, <<"cumulative">>], DiscountsCumulative, Doc).

-spec discounts_cumulative_maximum(doc()) -> kz_term:api_integer().
discounts_cumulative_maximum(Doc) ->
    discounts_cumulative_maximum(Doc, 'undefined').

-spec discounts_cumulative_maximum(doc(), Default) -> integer() | Default.
discounts_cumulative_maximum(Doc, Default) ->
    kz_json:get_integer_value([<<"discounts">>, <<"cumulative">>, <<"maximum">>], Doc, Default).

-spec set_discounts_cumulative_maximum(doc(), integer()) -> doc().
set_discounts_cumulative_maximum(Doc, DiscountsCumulativeMaximum) ->
    kz_json:set_value([<<"discounts">>, <<"cumulative">>, <<"maximum">>], DiscountsCumulativeMaximum, Doc).

-spec discounts_cumulative_rate(doc()) -> kz_term:api_number().
discounts_cumulative_rate(Doc) ->
    discounts_cumulative_rate(Doc, 'undefined').

-spec discounts_cumulative_rate(doc(), Default) -> number() | Default.
discounts_cumulative_rate(Doc, Default) ->
    kz_json:get_float_value([<<"discounts">>, <<"cumulative">>, <<"rate">>], Doc, Default).

-spec set_discounts_cumulative_rate(doc(), number()) -> doc().
set_discounts_cumulative_rate(Doc, DiscountsCumulativeRate) ->
    kz_json:set_value([<<"discounts">>, <<"cumulative">>, <<"rate">>], DiscountsCumulativeRate, Doc).

-spec discounts_cumulative_rates_rate(doc(), kz_json:key()) -> kz_term:api_number().
discounts_cumulative_rates_rate(Doc, Rate) ->
    discounts_cumulative_rates_rate(Doc, Rate, 'undefined').

-spec discounts_cumulative_rates_rate(doc(), kz_json:key(), Default) -> number() | Default.
discounts_cumulative_rates_rate(Doc, Rate, Default) ->
    kz_json:get_float_value([<<"discounts">>, <<"cumulative">>, <<"rates">>, Rate], Doc, Default).

-spec set_discounts_cumulative_rates_rate(doc(), kz_json:key(), number()) -> doc().
set_discounts_cumulative_rates_rate(Doc, Rate, Value) ->
    kz_json:set_value([<<"discounts">>, <<"cumulative">>, <<"rates">>, Rate], Value, Doc).

-spec discounts_cumulative_rates(doc()) -> kz_term:api_object().
discounts_cumulative_rates(Doc) ->
    discounts_cumulative_rates(Doc, 'undefined').

-spec discounts_cumulative_rates(doc(), Default) -> kz_json:object() | Default.
discounts_cumulative_rates(Doc, Default) ->
    kz_json:get_json_value([<<"discounts">>, <<"cumulative">>, <<"rates">>], Doc, Default).

-spec set_discounts_cumulative_rates(doc(), kz_json:object()) -> doc().
set_discounts_cumulative_rates(Doc, DiscountsCumulativeRates) ->
    kz_json:set_value([<<"discounts">>, <<"cumulative">>, <<"rates">>], DiscountsCumulativeRates, Doc).

-spec discounts_single(doc()) -> kz_term:api_object().
discounts_single(Doc) ->
    discounts_single(Doc, 'undefined').

-spec discounts_single(doc(), Default) -> kz_json:object() | Default.
discounts_single(Doc, Default) ->
    kz_json:get_json_value([<<"discounts">>, <<"single">>], Doc, Default).

-spec set_discounts_single(doc(), kz_json:object()) -> doc().
set_discounts_single(Doc, DiscountsSingle) ->
    kz_json:set_value([<<"discounts">>, <<"single">>], DiscountsSingle, Doc).

-spec discounts_single_rate(doc()) -> kz_term:api_number().
discounts_single_rate(Doc) ->
    discounts_single_rate(Doc, 'undefined').

-spec discounts_single_rate(doc(), Default) -> number() | Default.
discounts_single_rate(Doc, Default) ->
    kz_json:get_float_value([<<"discounts">>, <<"single">>, <<"rate">>], Doc, Default).

-spec set_discounts_single_rate(doc(), number()) -> doc().
set_discounts_single_rate(Doc, DiscountsSingleRate) ->
    kz_json:set_value([<<"discounts">>, <<"single">>, <<"rate">>], DiscountsSingleRate, Doc).

-spec discounts_single_rates_rate(doc(), kz_json:key()) -> kz_term:api_number().
discounts_single_rates_rate(Doc, Rate) ->
    discounts_single_rates_rate(Doc, Rate, 'undefined').

-spec discounts_single_rates_rate(doc(), kz_json:key(), Default) -> number() | Default.
discounts_single_rates_rate(Doc, Rate, Default) ->
    kz_json:get_float_value([<<"discounts">>, <<"single">>, <<"rates">>, Rate], Doc, Default).

-spec set_discounts_single_rates_rate(doc(), kz_json:key(), number()) -> doc().
set_discounts_single_rates_rate(Doc, Rate, Value) ->
    kz_json:set_value([<<"discounts">>, <<"single">>, <<"rates">>, Rate], Value, Doc).

-spec discounts_single_rates(doc()) -> kz_term:api_object().
discounts_single_rates(Doc) ->
    discounts_single_rates(Doc, 'undefined').

-spec discounts_single_rates(doc(), Default) -> kz_json:object() | Default.
discounts_single_rates(Doc, Default) ->
    kz_json:get_json_value([<<"discounts">>, <<"single">>, <<"rates">>], Doc, Default).

-spec set_discounts_single_rates(doc(), kz_json:object()) -> doc().
set_discounts_single_rates(Doc, DiscountsSingleRates) ->
    kz_json:set_value([<<"discounts">>, <<"single">>, <<"rates">>], DiscountsSingleRates, Doc).

-spec flat_rate(doc()) -> number().
flat_rate(Doc) ->
    flat_rate(Doc, 0.0).

-spec flat_rate(doc(), Default) -> number() | Default.
flat_rate(Doc, Default) ->
    kz_json:get_float_value([<<"flat_rate">>], Doc, Default).

-spec set_flat_rate(doc(), number()) -> doc().
set_flat_rate(Doc, FlatRate) ->
    kz_json:set_value([<<"flat_rate">>], FlatRate, Doc).

-spec flat_rates_rate(doc(), kz_json:key()) -> kz_term:api_number().
flat_rates_rate(Doc, FlatRate) ->
    flat_rates_rate(Doc, FlatRate, 'undefined').

-spec flat_rates_rate(doc(), kz_json:key(), Default) -> number() | Default.
flat_rates_rate(Doc, FlatRate, Default) ->
    kz_json:get_float_value([<<"flat_rates">>, FlatRate], Doc, Default).

-spec set_flat_rates_rate(doc(), kz_json:key(), number()) -> doc().
set_flat_rates_rate(Doc, FlatRate, Value) ->
    kz_json:set_value([<<"flat_rates">>, FlatRate], Value, Doc).

-spec flat_rates(doc()) -> kz_json:object().
flat_rates(Doc) ->
    flat_rates(Doc, kz_json:new()).

-spec flat_rates(doc(), Default) -> kz_json:object() | Default.
flat_rates(Doc, Default) ->
    kz_json:get_json_value([<<"flat_rates">>], Doc, Default).

-spec set_flat_rates(doc(), kz_json:object()) -> doc().
set_flat_rates(Doc, FlatRates) ->
    kz_json:set_value([<<"flat_rates">>], FlatRates, Doc).

-spec markup_type(doc()) -> kz_term:api_binary().
markup_type(Doc) ->
    markup_type(Doc, 'undefined').

-spec markup_type(doc(), Default) -> binary() | Default.
markup_type(Doc, Default) ->
    kz_json:get_binary_value([<<"markup_type">>], Doc, Default).

-spec set_markup_type(doc(), binary()) -> doc().
set_markup_type(Doc, MarkupType) ->
    kz_json:set_value([<<"markup_type">>], MarkupType, Doc).

-spec maximum(doc()) -> kz_term:api_integer().
maximum(Doc) ->
    maximum(Doc, 'undefined').

-spec maximum(doc(), Default) -> integer() | Default.
maximum(Doc, Default) ->
    kz_json:get_integer_value([<<"maximum">>], Doc, Default).

-spec set_maximum(doc(), integer()) -> doc().
set_maximum(Doc, Maximum) ->
    kz_json:set_value([<<"maximum">>], Maximum, Doc).

-spec minimum(doc()) -> integer().
minimum(Doc) ->
    minimum(Doc, 0).

-spec minimum(doc(), Default) -> integer() | Default.
minimum(Doc, Default) ->
    kz_json:get_integer_value([<<"minimum">>], Doc, Default).

-spec set_minimum(doc(), integer()) -> doc().
set_minimum(Doc, Minimum) ->
    kz_json:set_value([<<"minimum">>], Minimum, Doc).

-spec name(doc()) -> kz_term:api_binary().
name(Doc) ->
    name(Doc, 'undefined').

-spec name(doc(), Default) -> binary() | Default.
name(Doc, Default) ->
    kz_json:get_binary_value([<<"name">>], Doc, Default).

-spec set_name(doc(), binary()) -> doc().
set_name(Doc, Name) ->
    kz_json:set_value([<<"name">>], Name, Doc).

-spec prorate(doc()) -> kz_term:api_object().
prorate(Doc) ->
    prorate(Doc, 'undefined').

-spec prorate(doc(), Default) -> kz_json:object() | Default.
prorate(Doc, Default) ->
    kz_json:get_json_value([<<"prorate">>], Doc, Default).

-spec set_prorate(doc(), kz_json:object()) -> doc().
set_prorate(Doc, Prorate) ->
    kz_json:set_value([<<"prorate">>], Prorate, Doc).

-spec prorate_additions(doc()) -> boolean().
prorate_additions(Doc) ->
    prorate_additions(Doc, 'true').

-spec prorate_additions(doc(), Default) -> boolean() | Default.
prorate_additions(Doc, Default) ->
    kz_json:get_boolean_value([<<"prorate">>, <<"additions">>], Doc, Default).

-spec set_prorate_additions(doc(), boolean()) -> doc().
set_prorate_additions(Doc, ProrateAdditions) ->
    kz_json:set_value([<<"prorate">>, <<"additions">>], ProrateAdditions, Doc).

-spec prorate_removals(doc()) -> boolean().
prorate_removals(Doc) ->
    prorate_removals(Doc, 'false').

-spec prorate_removals(doc(), Default) -> boolean() | Default.
prorate_removals(Doc, Default) ->
    kz_json:get_boolean_value([<<"prorate">>, <<"removals">>], Doc, Default).

-spec set_prorate_removals(doc(), boolean()) -> doc().
set_prorate_removals(Doc, ProrateRemovals) ->
    kz_json:set_value([<<"prorate">>, <<"removals">>], ProrateRemovals, Doc).

-spec quantity(doc()) -> kz_term:api_object().
quantity(Doc) ->
    quantity(Doc, 'undefined').

-spec quantity(doc(), Default) -> kz_json:object() | Default.
quantity(Doc, Default) ->
    kz_json:get_json_value([<<"quantity">>], Doc, Default).

-spec set_quantity(doc(), kz_json:object()) -> doc().
set_quantity(Doc, Quantity) ->
    kz_json:set_value([<<"quantity">>], Quantity, Doc).

-spec quantity_category(doc()) -> kz_term:api_binary().
quantity_category(Doc) ->
    quantity_category(Doc, 'undefined').

-spec quantity_category(doc(), Default) -> binary() | Default.
quantity_category(Doc, Default) ->
    kz_json:get_binary_value([<<"quantity">>, <<"category">>], Doc, Default).

-spec set_quantity_category(doc(), binary()) -> doc().
set_quantity_category(Doc, QuantityCategory) ->
    kz_json:set_value([<<"quantity">>, <<"category">>], QuantityCategory, Doc).

-spec quantity_name(doc()) -> kz_term:api_binary().
quantity_name(Doc) ->
    quantity_name(Doc, 'undefined').

-spec quantity_name(doc(), Default) -> binary() | Default.
quantity_name(Doc, Default) ->
    kz_json:get_binary_value([<<"quantity">>, <<"name">>], Doc, Default).

-spec set_quantity_name(doc(), binary()) -> doc().
set_quantity_name(Doc, QuantityName) ->
    kz_json:set_value([<<"quantity">>, <<"name">>], QuantityName, Doc).

-spec rate(doc()) -> number().
rate(Doc) ->
    rate(Doc, 0.0).

-spec rate(doc(), Default) -> number() | Default.
rate(Doc, Default) ->
    kz_json:get_float_value([<<"rate">>], Doc, Default).

-spec set_rate(doc(), number()) -> doc().
set_rate(Doc, Rate) ->
    kz_json:set_value([<<"rate">>], Rate, Doc).

-spec rates_rate(doc(), kz_json:key()) -> kz_term:api_number().
rates_rate(Doc, Rate) ->
    rates_rate(Doc, Rate, 'undefined').

-spec rates_rate(doc(), kz_json:key(), Default) -> number() | Default.
rates_rate(Doc, Rate, Default) ->
    kz_json:get_float_value([<<"rates">>, Rate], Doc, Default).

-spec set_rates_rate(doc(), kz_json:key(), number()) -> doc().
set_rates_rate(Doc, Rate, Value) ->
    kz_json:set_value([<<"rates">>, Rate], Value, Doc).

-spec rates(doc()) -> kz_json:object().
rates(Doc) ->
    rates(Doc, kz_json:new()).

-spec rates(doc(), Default) -> kz_json:object() | Default.
rates(Doc, Default) ->
    kz_json:get_json_value([<<"rates">>], Doc, Default).

-spec set_rates(doc(), kz_json:object()) -> doc().
set_rates(Doc, Rates) ->
    kz_json:set_value([<<"rates">>], Rates, Doc).

-spec step(doc()) -> integer().
step(Doc) ->
    step(Doc, 1).

-spec step(doc(), Default) -> integer() | Default.
step(Doc, Default) ->
    kz_json:get_integer_value([<<"step">>], Doc, Default).

-spec set_step(doc(), integer()) -> doc().
set_step(Doc, Step) ->
    kz_json:set_value([<<"step">>], Step, Doc).

-spec taxes(doc()) -> kz_term:api_objects().
taxes(Doc) ->
    taxes(Doc, 'undefined').

-spec taxes(doc(), Default) -> kz_json:objects() | Default.
taxes(Doc, Default) ->
    kz_json:get_list_value([<<"taxes">>], Doc, Default).

-spec set_taxes(doc(), kz_json:objects()) -> doc().
set_taxes(Doc, Taxes) ->
    kz_json:set_value([<<"taxes">>], Taxes, Doc).
