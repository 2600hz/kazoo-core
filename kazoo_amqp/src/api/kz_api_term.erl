%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_api_term).

-export([is_boolean_or_ne_binaries/1]).

-export([validator_properties/1]).

-spec is_boolean_or_ne_binaries(term()) -> boolean().
is_boolean_or_ne_binaries(Term) ->
    kz_term:is_not_empty(Term)
        andalso (is_boolean(Term)
                 orelse kz_term:is_ne_binaries(Term)).

-spec validator_properties(atom()) -> kz_json:object().
validator_properties('is_boolean_or_ne_binaries') ->
    kz_json:from_list([{<<"type">>, [<<"boolean">>, <<"array">>]}
                      ,{<<"items">>, kz_json:from_list([{<<"type">>, <<"string">>}])}
                      ,{<<"minItems">>, 1}
                      ]).
