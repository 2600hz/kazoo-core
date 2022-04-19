%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2021, 2600Hz
%%% @doc A Number Manager module for carrier: telnyx.com
%%% @author Pierre Fenoll
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_telnyx).
-behaviour(knm_gen_carrier).

-export([info/0]).
-export([is_local/0]).
-export([find_numbers/3]).
-export([acquire_number/1]).
-export([disconnect_number/1]).
-export([is_number_billable/1]).
-export([should_lookup_cnam/0]).
-export([check_numbers/1]).
-export([check_portability/1]).

-include("knm.hrl").
-include("knm_telnyx.hrl").

-define(MOD_CONFIG_CAT, <<(?KNM_CONFIG_CAT)/binary, ".telnyx">>).

-define(IS_SANDBOX_PROVISIONING_TRUE
       ,kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"sandbox_provisioning">>, 'false')
       ).
-define(IS_PROVISIONING_ENABLED
       ,kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"enable_provisioning">>, 'true')
       ).
-define(SHOULD_KEEP_BEST_EFFORT
       ,kapps_config:get_is_true(?MOD_CONFIG_CAT, <<"should_keep_best_effort">>, 'false')
       ).

%%% API

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec info() -> map().
info() ->
    #{?CARRIER_INFO_MAX_PREFIX => 3
     }.

%%------------------------------------------------------------------------------
%% @doc Is this carrier handling numbers local to the system?
%%
%% <div class="notice">A non-local (foreign) carrier module makes HTTP requests.</div>
%% @end
%%------------------------------------------------------------------------------
-spec is_local() -> boolean().
is_local() -> 'false'.

-spec is_number_billable(knm_phone_number:pn_record()) -> 'true'.
is_number_billable(_PN) -> 'true'.

%%------------------------------------------------------------------------------
%% @doc Check with carrier if these numbers are registered with it.
%% @end
%%------------------------------------------------------------------------------
-spec check_numbers(kz_term:ne_binaries()) -> {'ok', kz_json:object()} |
          {'error', any()}.
check_numbers(_Numbers) -> {'error', 'not_implemented'}.

%%------------------------------------------------------------------------------
%% @doc Check with carrier if these numbers are portable
%% @end
%%------------------------------------------------------------------------------
-spec check_portability(kz_term:ne_binaries()) -> kz_okko:okko({kz_term:ne_binary(), kz_term:ne_binary()}, {kz_term:ne_binary(), #{}}).
check_portability(Numbers) ->
    Jobj = portability(Numbers),
    case kz_json:to_map(Jobj) of
        #{ <<"phone_numbers">> := PhoneNumbersRaw} when is_list(PhoneNumbersRaw) ->
            PhoneNumbers = [ Map || Map <- PhoneNumbersRaw, maps:is_key(<<"phone_number">>, Map) ],
            OkkoFun = fun partition_portabilty_result/1,
            kz_okko:foldl(OkkoFun, PhoneNumbers);
        _InvalidObj ->
            lager:debug("expected a json object with a key of 'phone_numbers' that is a list, not: ~p", [Jobj]),
            kz_okko:empty_okko()
    end.

partition_portabilty_result(Jobj) ->
    PhoneNumber = maps:get(<<"phone_number">>, Jobj),
    IsPortable = maps:get(<<"portable">>, Jobj, 'false'),
    case IsPortable of
        'false' ->
            NotPortableReason = maps:get(<<"not_portable_reason">>, Jobj, 'null'),
            {'error', {PhoneNumber, NotPortableReason}};
        'true' ->
            {'ok', {PhoneNumber, #{}}}
    end.

%%------------------------------------------------------------------------------
%% @doc Query the system for a quantity of available numbers in a rate center
%% @end
%%------------------------------------------------------------------------------
-spec find_numbers(kz_term:ne_binary(), pos_integer(), knm_search:options()) ->
          {'ok', knm_search:results()}.
find_numbers(<<"+1", NPA:3/binary, _/binary>>=Num, Quantity, Options)
  when ?IS_US_TOLLFREE(NPA) ->
    Results = search_numbers('tollfree', Quantity, NPA, get_nxx(Num)),
    {'ok', format_search_numbers_resp(Results, Options)};

find_numbers(<<"+1", NPA:3/binary, _/binary>>=Num, Quantity, Options) ->
    Results = search_numbers('npa', Quantity, NPA, get_nxx(Num)),
    {'ok', format_search_numbers_resp(Results, Options)};

find_numbers(<<"+",_/binary>>=_InternationalNum, Quantity, Options) ->
    Country = knm_search:country(Options),
    Results = search_numbers('region', Quantity, Country, 'undefined'),
    {'ok', format_international_numbers_search_resp(Results, Options)}.

%%------------------------------------------------------------------------------
%% @doc For a given Number, parse out the NXX value.
%% Return `undefined' if the NXX value can not be parsed.
%% @end
%%------------------------------------------------------------------------------
-spec get_nxx(kz_term:ne_binary()) -> kz_term:api_ne_binary().
get_nxx(<<_PlusOneAreaCode:5/binary, NXX:3/binary, _/binary>>) -> NXX;
get_nxx(_) -> 'undefined'.

%%------------------------------------------------------------------------------
%% @doc Acquire a given number from the carrier
%% @end
%%------------------------------------------------------------------------------
-spec acquire_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
acquire_number(PN) ->
    Debug = ?IS_SANDBOX_PROVISIONING_TRUE,
    case ?IS_PROVISIONING_ENABLED of
        'false' when Debug ->
            lager:debug("allowing sandbox provisioning"),
            PN;
        'false' ->
            knm_errors:unspecified('provisioning_disabled', PN);
        'true' ->
            Num = knm_phone_number:number(PN),
            Req = kz_json:from_list([{<<"requested_numbers">>, [Num]}
                                    ]),
            Rep = knm_telnyx_util:req('post', ["number_orders"], Req),
            case kz_json:get_ne_binary_value(<<"id">>, Rep) of
                'undefined' ->
                    lager:debug("order failure: ~s", [kz_json:encode(Rep)]),
                    Reason = kz_json:get_ne_binary_value(<<"message">>, Rep),
                    knm_errors:by_carrier(?MODULE, Reason, Num);
                OrderId ->
                    Data = kz_json:from_list([{<<"order_id">>, OrderId}]),
                    knm_phone_number:update_carrier_data(PN, Data)
            end
    end.

%%------------------------------------------------------------------------------
%% @doc Release a number from the routing table
%% @end
%%------------------------------------------------------------------------------
-spec disconnect_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
disconnect_number(PN) ->
    Debug = ?IS_SANDBOX_PROVISIONING_TRUE,
    case ?IS_PROVISIONING_ENABLED of
        'true' -> PN;
        'false' when Debug ->
            lager:debug("allowing sandbox provisioning"),
            PN;
        'false' ->
            knm_errors:unspecified('provisioning_disabled', PN)
    end.

-spec should_lookup_cnam() -> boolean().
should_lookup_cnam() -> 'true'.


%%% Internals

-type kind() :: 'npa' | 'tollfree' | 'region'.
-spec search_numbers(kind(), pos_integer(), kz_term:ne_binary(), kz_term:api_ne_binary()) ->
          kz_json:objects().
search_numbers(SearchKind, Quantity, Prefix, NXX) ->
    Descriptor = kz_json:from_list(search_prefix(SearchKind, Prefix, NXX)),
    Req = kz_json:from_list(
            [{<<"search_type">>, search_kind(SearchKind)}
            ,{<<"search_descriptor">>, Descriptor}
            ,{<<"limit">>, Quantity}
            ,{<<"with_result">>, 'true'}
            ]),
    Rep = knm_telnyx_util:req('post', ["number_searches"], Req),
    case SearchKind of
        'region' -> kz_json:get_value(<<"inexplicit_result">>, Rep);
        _ -> kz_json:get_value(<<"result">>, Rep)
    end.

-spec format_search_numbers_resp(kz_json:objects(), knm_search:options()) -> knm_search:results().
format_search_numbers_resp(JObjs, Options) ->
    QID = knm_search:query_id(Options),
    [{QID, {Num, ?MODULE, ?NUMBER_STATE_DISCOVERY, Data}}
     || Data <- JObjs,
        Num <- [kz_json:get_ne_binary_value(<<"number_e164">>, Data)]
    ].

-spec format_international_numbers_search_resp(kz_json:objects(), knm_search:options()) -> knm_search:results().
format_international_numbers_search_resp(JObjs, Options) ->
    Dialcode = knm_search:dialcode(Options),
    QID = knm_search:query_id(Options),
    [{QID, {Num, ?MODULE, ?NUMBER_STATE_DISCOVERY, Data}}
     || Data <- JObjs,
        Num0 <- [kz_json:get_ne_binary_value(<<"area_code">>, Data)],
        Num <- [ugly_hack(Dialcode, Num0)]
    ].

%%TODO: once Telnyx gives back real numbers, remove this.
%% Right now international search returns only prefixes.
ugly_hack(Dialcode, Num) ->
    kz_binary:pad(<<Dialcode/binary, Num/binary>>, 9, <<"0">>).

-spec search_kind(kind()) -> integer().
search_kind('npa') -> ?SEARCH_TYPE_NPA;
search_kind('region') -> ?SEARCH_TYPE_INTERNATIONAL;
search_kind('tollfree') -> ?SEARCH_TYPE_TOLEFREE.

-spec search_prefix(kind(), kz_term:ne_binary(), kz_term:api_ne_binary()) -> kz_json:json_proplist().
search_prefix('tollfree', NPA, 'undefined') ->
    [{<<"npa">>, NPA}
    ,should_keep_best_effort()
    ];
search_prefix('tollfree', NPA, NXX) ->
    [{<<"nxx">>, NXX}
    ,should_keep_best_effort()
    |search_prefix('tollfree', NPA, 'undefined')
    ];
search_prefix('region', Country, _) ->
    [{<<"country_iso">>, Country}
    ,should_keep_best_effort()
    ];
search_prefix('npa', NPA, 'undefined') ->
    [{<<"npa">>, NPA}
    ,should_keep_best_effort()
    ];
search_prefix('npa', NPA, NXX) ->
    [{<<"nxx">>, NXX}
    ,should_keep_best_effort()
    |search_prefix('npa', NPA, 'undefined')
    ].

-spec should_keep_best_effort() -> {kz_term:ne_binary(), boolean()}.
should_keep_best_effort() -> {<<"best_effort">>, ?SHOULD_KEEP_BEST_EFFORT}.

-spec portability(kz_term:ne_binaries()) -> kz_json:object().
portability(Numbers) ->
    FormattedNumbers = lists:map(
                         fun(Num) -> kz_json:set_value(<<"phone_number">>, Num, kz_json:new()) end
                        ,Numbers
                        ),
    Req = kz_json:from_list([{<<"phone_numbers">>, FormattedNumbers}]),
    knm_telnyx_util:req('post', ["porting/portability_checks"], Req).

%%% End of Module
