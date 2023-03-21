%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2020, 2600Hz
%%% @doc
%%% @author Karl Anderson
%%% @author James Aimonetti
%%% @author Luis Azedo
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_directory_cache).

-export([flush/0]).
-export([clear/0
        ,clear/1]).
-export([flushed/1]).

-include("kazoo_directory.hrl").

-spec flush() -> 'ok'.
flush() ->
    kz_cache:flush_local(?CACHE_NAME).

-spec clear() -> 'ok'.
clear() ->
    Req = kz_api:default_headers(?APP_NAME, ?APP_VERSION),
    'ok' = kz_amqp_worker:cast(Req, fun kapi_directory:publish_cache_flush/1),
    lager:info("published directory cache flush").

-spec clear(kz_term:ne_binary() | kz_term:ne_binaries()) -> 'ok'.
clear([]) -> 'ok';
clear(EndpointId)
  when is_binary(EndpointId) ->
    clear([EndpointId]);
clear(EndpointIds) ->
    Req = [{<<"Keys">>, EndpointIds} | kz_api:default_headers(?APP_NAME, ?APP_VERSION)],
    kz_amqp_worker:cast(Req, fun kapi_directory:publish_cache_clear/1),
    _ = [lager:info("published directory cache clear for ~s", [EndpointId])
         || EndpointId <- EndpointIds
        ],
    'ok'.

-spec flushed(atom()) -> 'ok'.
flushed(?CACHE_NAME) ->
    'ok' = clear(),
    lager:info("directory cache was flushed");
flushed(_Name) -> 'ok'.
