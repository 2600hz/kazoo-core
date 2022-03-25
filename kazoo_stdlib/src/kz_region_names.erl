%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2022-, Ooma Inc
%%% @author Micah Warren
%%% @doc Lookup short names for countries, states, or provinces.
%%%
%%% An efficient way to store data that does not need to be updated at run-time
%%% but needs to be accessible to multiple modules is in a module with
%%% lookup functions. This prevents us from having to rebuild a dictionary at
%%% run-time. We have the pattern matching available, and if we need to update
%%% the data table, we can just swap the module.
%%%
%%% In the future, once we target erlang runtime 21 or newer, we should likely
%%% move to using persistent_term for this sort of thing.
%%% @end
%%%-----------------------------------------------------------------------------

-module(kz_region_names).

-define(UNKNOWN_CASE, <<>>).

-export([to_short_code/1, to_short_code/2
        ,lookup_usa/1
        ,lookup_canada/1
        ]).


%%------------------------------------------------------------------------------
%% @doc This is the same as calling `to_short_code/2' with
%% `[<<"usa">>, <<"candada">>]' as the first arugment.
%% @end
%%------------------------------------------------------------------------------
-spec to_short_code(kz_term:binary()) -> {'ok', kz_term:ne_binary()} | {'error', 'not_found'}.
to_short_code(StateOrProvince) ->
    to_short_code([<<"usa">>, <<"canada">>], StateOrProvince).

%%------------------------------------------------------------------------------
%% @doc Given a list (or single) candidate country, return the abbreviation or
%% short code for the given state/province/region.
%%
%% When specifying a country or region, case is ignored.
%%
%% When specifying multiple countries, they are tried in the given order.
%% Searching stops as soon as a match is found.
%%
%% Currently supported counties:
%%
%% +---------------------------|----------------------------------------------------|
%% | Country Proper Name       | Binaries that represent it                         |
%% +---------------------------|----------------------------------------------------|
%% | United States of American | "usa", "united states", "united states of america" |
%% +---------------------------|----------------------------------------------------|
%% | Canada                    | "canada"                                           |
%% +---------------------------+----------------------------------------------------|
%% @end
%%------------------------------------------------------------------------------
-spec to_short_code(kz_term:binary() | kz_term:binaries(), kz_term:binary()) -> {'ok', kz_term:ne_binary()} | {'error', 'not_found'}.
to_short_code([], _Region) ->
    {'error', 'not_found'};
to_short_code(Country, Region) when is_binary(Country) ->
    NormalizedCountry = normalize_country_name(Country),
    NormalizedRegion = normalize_region(Region),
    to_short_code_impl(NormalizedCountry, NormalizedRegion);
to_short_code([Country | Countries], Region) ->
    case to_short_code(Country, Region) of
        {'error', _} ->
            to_short_code(Countries, Region);
        Ok ->
            Ok
    end.

-spec normalize_country_name(kz_term:binary()) -> kz_term:binary().
normalize_country_name(InitialName) ->
    LowerCase = kz_term:to_lower_binary(InitialName),
    lookup_country(LowerCase).

-spec normalize_region(kz_term:binary()) -> kz_term:binary().
normalize_region(InitialName) ->
    kz_term:to_lower_binary(InitialName).


-spec lookup_country(kz_term:binary()) -> kz_term:binary().
lookup_country(<<"usa">> = Out) ->
    Out;
lookup_country(<<"united states">>) ->
    <<"usa">>;
lookup_country(<<"united states of america">>) ->
    <<"usa">>;
lookup_country(<<"canada">> = Out) ->
    Out;
lookup_country(_UnknownCountry) ->
    ?UNKNOWN_CASE.

-spec to_short_code_impl(kz_term:binary(), kz_term:binary()) -> {'ok', kz_term:ne_binary()} | {'error', 'not_found'}.
to_short_code_impl(<<"usa">>, Region) ->
    lookup_usa(Region);
to_short_code_impl(<<"canada">>, Region) ->
    lookup_canada(Region);
to_short_code_impl(?UNKNOWN_CASE, _Region) ->
    {'error', 'not_found'}.

%%------------------------------------------------------------------------------
%% @doc Lookup the states and territories of the United States of America. The
%% state / territory name must the official name or abbreviation, in all lower
%% case. For example, if you wanted the capital of the country "Washington DC",
%% you would use `<<"disctrict of columbia">>' or `<<"dc">>' as the input.
%% @end.
%%------------------------------------------------------------------------------
-spec lookup_usa(kz_term:binary()) -> {'ok', kz_term:ne_binary()} | {'error', 'not_found'}.
lookup_usa(<<"alabama">>) -> {'ok', <<"AL">>};
lookup_usa(<<"alaska">>) -> {'ok', <<"AK">>};
lookup_usa(<<"american samoa">>) -> {'ok', <<"AS">>};
lookup_usa(<<"arizona">>) -> {'ok', <<"AZ">>};
lookup_usa(<<"arkansas">>) -> {'ok', <<"AR">>};
lookup_usa(<<"california">>) -> {'ok', <<"CA">>};
lookup_usa(<<"colorado">>) -> {'ok', <<"CO">>};
lookup_usa(<<"connecticut">>) -> {'ok', <<"CT">>};
lookup_usa(<<"delaware">>) -> {'ok', <<"DE">>};
lookup_usa(<<"district of columbia">>) -> {'ok', <<"DC">>};
lookup_usa(<<"federated states of micronesia">>) -> {'ok', <<"FM">>};
lookup_usa(<<"florida">>) -> {'ok', <<"FL">>};
lookup_usa(<<"georgia">>) -> {'ok', <<"GA">>};
lookup_usa(<<"guam">>) -> {'ok', <<"GU">>};
lookup_usa(<<"hawaii">>) -> {'ok', <<"HI">>};
lookup_usa(<<"idaho">>) -> {'ok', <<"ID">>};
lookup_usa(<<"illinois">>) -> {'ok', <<"IL">>};
lookup_usa(<<"indiana">>) -> {'ok', <<"IN">>};
lookup_usa(<<"iowa">>) -> {'ok', <<"IA">>};
lookup_usa(<<"kansas">>) -> {'ok', <<"KS">>};
lookup_usa(<<"kentucky">>) -> {'ok', <<"KY">>};
lookup_usa(<<"louisiana">>) -> {'ok', <<"LA">>};
lookup_usa(<<"maine">>) -> {'ok', <<"ME">>};
lookup_usa(<<"marshall islands">>) -> {'ok', <<"MH">>};
lookup_usa(<<"maryland">>) -> {'ok', <<"MD">>};
lookup_usa(<<"massachusetts">>) -> {'ok', <<"MA">>};
lookup_usa(<<"michigan">>) -> {'ok', <<"MI">>};
lookup_usa(<<"minnesota">>) -> {'ok', <<"MN">>};
lookup_usa(<<"mississippi">>) -> {'ok', <<"MS">>};
lookup_usa(<<"missouri">>) -> {'ok', <<"MO">>};
lookup_usa(<<"montana">>) -> {'ok', <<"MT">>};
lookup_usa(<<"nebraska">>) -> {'ok', <<"NE">>};
lookup_usa(<<"nevada">>) -> {'ok', <<"NV">>};
lookup_usa(<<"new hampshire">>) -> {'ok', <<"NH">>};
lookup_usa(<<"new jersey">>) -> {'ok', <<"NJ">>};
lookup_usa(<<"new mexico">>) -> {'ok', <<"NM">>};
lookup_usa(<<"new york">>) -> {'ok', <<"NY">>};
lookup_usa(<<"north carolina">>) -> {'ok', <<"NC">>};
lookup_usa(<<"north dakota">>) -> {'ok', <<"ND">>};
lookup_usa(<<"northern mariana islands">>) -> {'ok', <<"MP">>};
lookup_usa(<<"ohio">>) -> {'ok', <<"OH">>};
lookup_usa(<<"oklahoma">>) -> {'ok', <<"OK">>};
lookup_usa(<<"oregon">>) -> {'ok', <<"OR">>};
lookup_usa(<<"palau">>) -> {'ok', <<"PW">>};
lookup_usa(<<"pennsylvania">>) -> {'ok', <<"PA">>};
lookup_usa(<<"puerto rico">>) -> {'ok', <<"PR">>};
lookup_usa(<<"rhode island">>) -> {'ok', <<"RI">>};
lookup_usa(<<"south carolina">>) -> {'ok', <<"SC">>};
lookup_usa(<<"south dakota">>) -> {'ok', <<"SD">>};
lookup_usa(<<"tennessee">>) -> {'ok', <<"TN">>};
lookup_usa(<<"texas">>) -> {'ok', <<"TX">>};
lookup_usa(<<"utah">>) -> {'ok', <<"UT">>};
lookup_usa(<<"vermont">>) -> {'ok', <<"VT">>};
lookup_usa(<<"virgin islands">>) -> {'ok', <<"VI">>};
lookup_usa(<<"virginia">>) -> {'ok', <<"VA">>};
lookup_usa(<<"washington">>) -> {'ok', <<"WA">>};
lookup_usa(<<"west virginia">>) -> {'ok', <<"WV">>};
lookup_usa(<<"wisconsin">>) -> {'ok', <<"WI">>};
lookup_usa(<<"wyoming">>) -> {'ok', <<"WY">>};
%% and now, the short-code identity
lookup_usa(<<"al">>) -> {'ok', <<"AL">>};
lookup_usa(<<"ak">>) -> {'ok', <<"AK">>};
lookup_usa(<<"as">>) -> {'ok', <<"AS">>};
lookup_usa(<<"az">>) -> {'ok', <<"AZ">>};
lookup_usa(<<"ar">>) -> {'ok', <<"AR">>};
lookup_usa(<<"ca">>) -> {'ok', <<"CA">>};
lookup_usa(<<"co">>) -> {'ok', <<"CO">>};
lookup_usa(<<"ct">>) -> {'ok', <<"CT">>};
lookup_usa(<<"de">>) -> {'ok', <<"DE">>};
lookup_usa(<<"dc">>) -> {'ok', <<"DC">>};
lookup_usa(<<"fm">>) -> {'ok', <<"FM">>};
lookup_usa(<<"fl">>) -> {'ok', <<"FL">>};
lookup_usa(<<"ga">>) -> {'ok', <<"GA">>};
lookup_usa(<<"gu">>) -> {'ok', <<"GU">>};
lookup_usa(<<"hi">>) -> {'ok', <<"HI">>};
lookup_usa(<<"id">>) -> {'ok', <<"ID">>};
lookup_usa(<<"il">>) -> {'ok', <<"IL">>};
lookup_usa(<<"in">>) -> {'ok', <<"IN">>};
lookup_usa(<<"ia">>) -> {'ok', <<"IA">>};
lookup_usa(<<"ks">>) -> {'ok', <<"KS">>};
lookup_usa(<<"ky">>) -> {'ok', <<"KY">>};
lookup_usa(<<"la">>) -> {'ok', <<"LA">>};
lookup_usa(<<"me">>) -> {'ok', <<"ME">>};
lookup_usa(<<"mh">>) -> {'ok', <<"MH">>};
lookup_usa(<<"md">>) -> {'ok', <<"MD">>};
lookup_usa(<<"ma">>) -> {'ok', <<"MA">>};
lookup_usa(<<"mi">>) -> {'ok', <<"MI">>};
lookup_usa(<<"mn">>) -> {'ok', <<"MN">>};
lookup_usa(<<"ms">>) -> {'ok', <<"MS">>};
lookup_usa(<<"mo">>) -> {'ok', <<"MO">>};
lookup_usa(<<"mt">>) -> {'ok', <<"MT">>};
lookup_usa(<<"ne">>) -> {'ok', <<"NE">>};
lookup_usa(<<"nv">>) -> {'ok', <<"NV">>};
lookup_usa(<<"nh">>) -> {'ok', <<"NH">>};
lookup_usa(<<"nj">>) -> {'ok', <<"NJ">>};
lookup_usa(<<"nm">>) -> {'ok', <<"NM">>};
lookup_usa(<<"ny">>) -> {'ok', <<"NY">>};
lookup_usa(<<"nc">>) -> {'ok', <<"NC">>};
lookup_usa(<<"nd">>) -> {'ok', <<"ND">>};
lookup_usa(<<"mp">>) -> {'ok', <<"MP">>};
lookup_usa(<<"oh">>) -> {'ok', <<"OH">>};
lookup_usa(<<"ok">>) -> {'ok', <<"OK">>};
lookup_usa(<<"or">>) -> {'ok', <<"OR">>};
lookup_usa(<<"pw">>) -> {'ok', <<"PW">>};
lookup_usa(<<"pa">>) -> {'ok', <<"PA">>};
lookup_usa(<<"pr">>) -> {'ok', <<"PR">>};
lookup_usa(<<"ri">>) -> {'ok', <<"RI">>};
lookup_usa(<<"sc">>) -> {'ok', <<"SC">>};
lookup_usa(<<"sd">>) -> {'ok', <<"SD">>};
lookup_usa(<<"tn">>) -> {'ok', <<"TN">>};
lookup_usa(<<"tx">>) -> {'ok', <<"TX">>};
lookup_usa(<<"ut">>) -> {'ok', <<"UT">>};
lookup_usa(<<"vt">>) -> {'ok', <<"VT">>};
lookup_usa(<<"vi">>) -> {'ok', <<"VI">>};
lookup_usa(<<"va">>) -> {'ok', <<"VA">>};
lookup_usa(<<"wa">>) -> {'ok', <<"WA">>};
lookup_usa(<<"wv">>) -> {'ok', <<"WV">>};
lookup_usa(<<"wi">>) -> {'ok', <<"WI">>};
lookup_usa(<<"wy">>) -> {'ok', <<"WY">>};
%% and the fall-through
lookup_usa(_) -> {'error', 'not_found'}.

%%------------------------------------------------------------------------------
%% @doc Lookup the provinces and territories of Canada. To get the short code,
%% the input must be the proper name or official abbreviation all lower cased.
%% For example, "Prince Edward Island" is `<<"prince edward island">>' or
%% `<<"pe">>'.
%% @end
%%------------------------------------------------------------------------------
-spec lookup_canada(kz_term:binary()) -> {'ok', kz_term:ne_binary()} | {'error', 'not_found'}.
lookup_canada(<<"alberta">>) -> {'ok', <<"AB">>};
lookup_canada(<<"british columbia">>) -> {'ok', <<"BC">>};
lookup_canada(<<"manitoba">>) -> {'ok', <<"MB">>};
lookup_canada(<<"new brunswick">>) -> {'ok', <<"NB">>};
lookup_canada(<<"newfoundland">>) -> {'ok', <<"NL">>};
lookup_canada(<<"labrador">>) -> {'ok', <<"NL">>};
lookup_canada(<<"newfoundland and labrador">>) -> {'ok', <<"NL">>};
lookup_canada(<<"northwest territories">>) -> {'ok', <<"NT">>};
lookup_canada(<<"nova scotia">>) -> {'ok', <<"NS">>};
lookup_canada(<<"nunavut">>) -> {'ok', <<"NU">>};
lookup_canada(<<"ontario">>) -> {'ok', <<"ON">>};
lookup_canada(<<"prince edward island">>) -> {'ok', <<"PE">>};
lookup_canada(<<"quebec">>) -> {'ok', <<"QC">>};
lookup_canada(<<"saskatchewan">>) -> {'ok', <<"SK">>};
lookup_canada(<<"yukon">>) -> {'ok', <<"YT">>};
%% and now the short codes
lookup_canada(<<"ab">>) -> {'ok', <<"AB">>};
lookup_canada(<<"bc">>) -> {'ok', <<"BC">>};
lookup_canada(<<"mb">>) -> {'ok', <<"MB">>};
lookup_canada(<<"nb">>) -> {'ok', <<"NB">>};
lookup_canada(<<"nl">>) -> {'ok', <<"NL">>};
lookup_canada(<<"nt">>) -> {'ok', <<"NT">>};
lookup_canada(<<"ns">>) -> {'ok', <<"NS">>};
lookup_canada(<<"nu">>) -> {'ok', <<"NU">>};
lookup_canada(<<"on">>) -> {'ok', <<"ON">>};
lookup_canada(<<"pe">>) -> {'ok', <<"PE">>};
lookup_canada(<<"qc">>) -> {'ok', <<"QC">>};
lookup_canada(<<"sk">>) -> {'ok', <<"SK">>};
lookup_canada(<<"yt">>) -> {'ok', <<"YT">>};
%% and the fall-through.
lookup_canada(_) -> {'error', 'not_found'}.
