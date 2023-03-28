#!/bin/bash

pushd "$(dirname "${0}")" > /dev/null || exit 1

_clean="${1}"

# ISO3166-alpha2 to dialcode (ITU) module generator.
ITU="../src/knm_iso3166a2_itu.erl"
ITU_SRC="../src/knm_iso3166a2_itu.erl.src"
ITU_FILE="../dialcodes.json"
ITU_URL="https://raw.githubusercontent.com/mledoze/countries/c212082894e48e8be123dad5dea7d9e6abc0c1b9/countries.json"

# ISO3166_utils module generator.
ISO3166="../src/knm_iso3166_util.erl"
ISO3166_SRC="../src/knm_iso3166_util.erl.src"

# official list https://www.itu.int/pub/T-SP-E.164D
# but there are newer ones… https://www.itu.int/pub/T-SP-OB
#
# maintained & good enough https://raw.githubusercontent.com/mledoze/countries/master/countries.json
#
# http://country.io/phone.json
#
# http://www.andrewpatton.com/countrylist.csv
# https://raw.githubusercontent.com/OpenBookPrices/country-data/master/data/countries.csv
# https://raw.githubusercontent.com/datasets/country-codes/master/data/country-codes.csv
# https://www.worlddata.info/downloads/countrycodes.csv
# https://commondatastorage.googleapis.com/ckannet-storage/2011-11-25T132653/iso_3166_2_countries.csv
#
# https://countrycode.org/
# https://en.wikipedia.org/wiki/List_of_country_calling_codes

if [ -n "${_clean}" ] && [ "${_clean}" = "clean" ]; then
    rm -rf "${ITU_FILE}"
    rm -rf "${ITU}"
    rm -rf "${ISO3166}"
    exit 0
fi

if [ ! -f "${ITU_FILE}" ]; then
    wget -qO "${ITU_FILE}" "${ITU_URL}"
fi

if [ ! -f "${ITU}" ]; then
    cat "${ITU_SRC}" > "${ITU}"
    python3 -c 'import json; [print("to_itu(<<\"", l["cca2"], "\">>) -> <<\"+", l["callingCode"][0], "\">>;", sep="") for l in sorted(json.load(open("dialcodes.json")), key=lambda l: l["cca2"]) if len(l["callingCode"]) > 0]' >> "${ITU}"
    echo 'to_itu(_) -> <<>>.' >> "${ITU}"
fi

if [ ! -f "${ISO3166}" ]; then
    cat "${ISO3166_SRC}" > "${ISO3166}"
    python3 -c 'import json; [print("country(<<\"", l["cca2"], "\">>) -> country(<<\"", l["cca3"], "\">>);\ncountry(<<\"", l["cca3"], "\">>) -> #{a2 =>  <<\"", l["cca2"], "\">>, a3 => <<\"", l["cca3"], "\">>, itu => <<\"+", l["callingCode"][0], "\">>};", sep="") for l in sorted(json.load(open("dialcodes.json")), key=lambda l: l["cca2"]) if len(l["callingCode"]) > 0]' >> "${ISO3166}"
    echo 'country(_) -> {error, invalid_country}.' >> "${ISO3166}"
fi
