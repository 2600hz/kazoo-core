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

-export([bind/0, unbind/0]).

-export([handle_cache/1]).

-export([flushed/1]).
-export([clear/1]).

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
    handle_cache(Db, Id, kzs_util:is_account_db(Db)).

-spec handle_cache(kz_term:ne_binary(), kz_term:ne_binary(), boolean()) -> 'ok'.
handle_cache(_Db, _Id, 'false') -> 'ok';
handle_cache(Db, Id, 'true') ->
    case kz_datamgr:open_doc(Db, Id) of
        {'ok', JObj} -> handle_change(Db, Id, JObj);
        _Else -> 'ok'
    end.

-spec handle_change(kz_term:ne_binary(), kz_term:ne_binary(), kz_json:object()) -> 'ok'.
handle_change(Db, Id, JObj) ->
    AccountId = kzs_util:format_account_id(Db),
    lager:info("handling change for device ~s/~s", [AccountId, Id]),
    Ids = owner_ids(JObj),
    Cached = cached_ids(Db, Id),
    _ = [kz_cache:erase_local(?CACHE_NAME, {CachedId, AccountId}) || CachedId <- Ids -- Cached],
    'ok'.

-spec cached_ids(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binaries().
cached_ids(Db, Id) ->
    MatchSpec = match_doc_changed_keys(Db, Id),
    Objects = ets:select(kz_cache_ets:pointer_tab(?CACHE_NAME), MatchSpec),
    [CachedId || {CachedId, _} <- Objects, CachedId =/= Id].

-spec owner_ids(kz_json:object()) -> kz_term:ne_binaries().
owner_ids(JObj) ->
    props:filter_undefined([kzd_devices:owner_id(JObj) | kzd_devices:hotdesk_ids(JObj, [])]).

-spec match_doc_changed_keys(kz_term:ne_binary(), kz_term:ne_binary()) -> ets:match_spec().
match_doc_changed_keys(Db, Id) ->
    [{#cache_obj{key = '$1', origin = {'db', Db, Id}, _ = '_'}
     ,[]
     ,['$1']
     }
    ].

-spec flushed(atom()) -> 'ok'.
flushed(?CACHE_NAME) ->
    Req = kz_api:default_headers(?APP_NAME, ?APP_VERSION),
    _ = kz_amqp_worker:cast(Req, fun kapi_directory:publish_cache_flush/1),
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
        'true' ->
            Req = [{<<"Keys">>, EndpointIds} | kz_api:default_headers(?APP_NAME, ?APP_VERSION)],
            kz_amqp_worker:cast(Req, fun kapi_directory:publish_cache_clear/1)
    end.
