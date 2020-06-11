%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc
%%% @author Hesaam Farhang
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzc_all_docs).

-export([metadata/2
        ]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec metadata('options' | 'query_fields', kz_term:ne_binary()) -> any().
metadata('build_key_fun', _View) -> 'undefined';
metadata('databases_fun', _View) -> 'undefined';
metadata('options', _View) -> [];
metadata('query_fields', _View) -> [<<"doc_id">>].
