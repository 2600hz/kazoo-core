%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2025, 2600Hz
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

-export([bind/0, unbind/0]).

-export([handle_cache/1]).

-export([flushed/1]).
-export([clear/1]).
-export([cache_lifetime/0]).

-include("kazoo_directory.hrl").

-spec unbind() -> any().
unbind() ->
    kazoo_bindings:flush_mod(?MODULE).

-spec bind() -> any().
bind() ->
    RK = kz_binary:join([<<"kapi.conf">>, kz_term:to_binary(?CACHE_NAME), <<"*.device.*.*">>], <<".">>),
    lager:debug("binding for device created"),
    kazoo_bindings:bind(RK, ?MODULE, 'handle_cache').

-spec handle_cache(kz_json:object()) -> 'ok'.
handle_cache(JObj) ->
    Db = kapi_conf:get_database(JObj),
    Id = kapi_conf:get_id(JObj),
    lager:info("received cache ~s notification for device ~s/~s", [kz_api:event_name(JObj), Db, Id]),
    handle_cache(Db, Id, kzs_util:is_account_db(Db)).

-spec handle_cache(kz_term:ne_binary(), kz_term:ne_binary(), boolean()) -> 'ok'.
handle_cache(_Db, _Id, 'false') -> 'ok';
handle_cache(Db, Id, 'true') ->
    case kz_datamgr:open_doc(Db, Id) of
        {'ok', JObj} -> handle_change(Db, Id, JObj);
        _Else -> 'ok'
    end.

-spec handle_change(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> 'ok'.
handle_change(Db, DeviceId, JObj) ->
    AccountId = kzs_util:format_account_id(Db),
    OwnerIds = owner_ids(JObj),
    Cached = cached_ids(Db, DeviceId),
    OwnerIdsToErase = OwnerIds -- Cached,
    lager:info("handling change for device ~s@~s => owner_ids(~s) , cached(~s)"
              ,[DeviceId
               ,AccountId
               ,kz_binary:join(OwnerIds, <<"|">>)
               ,kz_binary:join(Cached, <<"|">>)
               ]),
    handle_changed(AccountId, OwnerIdsToErase).

handle_changed(_AccountId, []) -> ok;
handle_changed(AccountId, ToErase) ->
    lager:debug("erasing owner_ids ~s", [kz_binary:join(ToErase, <<"|">>)]),
    lists:foreach(fun(Key) -> kz_cache:erase_local(?CACHE_NAME, {Key, AccountId}) end, ToErase).

-spec cached_ids(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binaries().
cached_ids(Db, DeviceId) ->
    MatchSpec = match_doc_changed_keys(Db, DeviceId),
    Objects = ets:select(kz_cache_ets:pointer_tab(?CACHE_NAME), MatchSpec),
    [EndpointId || {EndpointId, _} <- Objects, EndpointId =/= DeviceId].

-spec owner_ids(kz_json:object()) -> kz_term:ne_binaries().
owner_ids(JObj) ->
    [Id || Id <- [kzd_devices:owner_id(JObj) | kzd_devices:hotdesk_ids(JObj, [])],
           'undefined' =/= Id,
           <<>> =/= Id
    ].

-spec match_doc_changed_keys(kz_term:ne_binary(), kz_term:ne_binary()) -> ets:match_spec().
match_doc_changed_keys(Db, Id) ->
    [{#cache_obj{key = '$1', origin = {'db', Db, Id}, _ = '_'}
     ,[]
     ,['$1']
     }
    ].

-spec flushed(atom()) -> 'ok'.
flushed(?CACHE_NAME) ->
    publish_cache_flush(),
    lager:info("directory cache was flushed");
flushed(_Name) -> 'ok'.

-spec clear(kz_term:ne_binary() | kz_term:ne_binaries()) -> 'ok'.
clear([]) ->
    lager:warning("invalid argument : empty EndpointIds");
clear(EndpointId)
  when is_binary(EndpointId) ->
    clear([EndpointId]);
clear(EndpointIds) ->
    case kz_term:is_ne_binaries(EndpointIds) of
        'false' -> lager:warning("invalid argument ~p", [EndpointIds]);
        'true' -> publish_cache_clear(EndpointIds)
    end.

publish_cache_flush() ->
    lager:debug("publishing directory cache flush"),
    Req = [{?KEY_LOG_ID, publish_cache_logid()}
          | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
          ],
    kz_amqp_worker:cast(Req, fun kapi_directory:publish_cache_flush/1).

publish_cache_clear(EndpointIds) ->
    lager:debug("publishing directory cache clear ~s", [kz_binary:join(EndpointIds, <<"|">>)]),
    Req = [{<<"Keys">>, EndpointIds}
          ,{?KEY_LOG_ID, publish_cache_logid()}
          | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
          ],
    kz_amqp_worker:cast(Req, fun kapi_directory:publish_cache_clear/1).

publish_cache_logid() ->
    lists:last(binary:split(kz_term:to_binary(kz_log:get_callid()), <<"|">>, ['global'])).

-spec cache_lifetime() -> timeout().
cache_lifetime() ->
    kz_app_config:get_timeout(?APP, <<"cache_lifetime">>, ?SECONDS_IN_HOUR).
