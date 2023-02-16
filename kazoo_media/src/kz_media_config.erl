%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_media_config).

-export([record_min_sec/0
        ,call_recording_extension/0
        ,should_store_recordings/0
        ]).

-include("kazoo_media.hrl").

-spec record_min_sec() -> non_neg_integer().
record_min_sec() ->
    kapps_config:get_integer(?CONFIG_CAT, <<"record_min_sec">>, 0).

-spec call_recording_extension() -> kz_term:ne_binary().
call_recording_extension() ->
    kapps_config:get_ne_binary(?CONFIG_CAT, [<<"call_recording">>, <<"extension">>], <<"mp3">>).

-spec should_store_recordings() -> boolean().
should_store_recordings() ->
    kapps_config:get_is_true(?CONFIG_CAT, <<"store_recordings">>, 'false').
