%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_endpoint_maintenance).

-export([flush/0]).
-export([migrate_softphone_to_ms_teams/1, migrate_softphone_to_ms_teams/2]).

-include("kazoo_endpoint.hrl").

-spec flush() -> 'ok'.
flush() ->
    kz_cache:flush_local(?CACHE_NAME).

-spec migrate_softphone_to_ms_teams(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} | {'error', any()}.
migrate_softphone_to_ms_teams(AccountId, DeviceId) ->
    migrate_softphone_to_ms_teams(kz_datamgr:open_cache_doc(AccountId, DeviceId)).

-spec migrate_softphone_to_ms_teams({'ok', kz_json:object()} | {'error', any()}) ->
          {'ok', kz_json:object()} | {'error', any()}.
migrate_softphone_to_ms_teams({'ok', _DevDoc} = Dev) ->
    migrate_softphone_to_ms_teams(Dev, 0, 3);
migrate_softphone_to_ms_teams({'error', _Err} = Error) ->
    lager:debug("failed to load device's document from db: ~p", [Error]),
    Error.


%% Helpers

%%------------------------------------------------------------------------------
%% MS Teams
%%------------------------------------------------------------------------------
-spec migrate_softphone_to_ms_teams({'ok', kz_json:object()}, 0..3, 0..3) ->
          {'ok', kz_json:object()} | {'error', 'unable_to_migrate'}.
migrate_softphone_to_ms_teams({'ok', Doc} = Dev, Try, MaxTries)
  when Try < MaxTries ->
    DocId = kz_doc:id(Doc),
    MSTeamsDefaults = ms_teams_device_defaults(),
    MSTeamsType = kzd_devices:device_type(MSTeamsDefaults),
    MSTeamsDoc = kz_json:merge(Doc, MSTeamsDefaults),
    case kz_datamgr:save_doc(kz_doc:account_db(Doc), MSTeamsDoc) of
        {'ok', NewDoc} ->
            lager:info("softphone ~s migrated to ~s successfully", [DocId, MSTeamsType]),
            {'ok', NewDoc};
        Err ->
            lager:debug("(~p/~p) failed to migrate softphone ~s to ~s with error: ~p",
                        [Try+1, MaxTries, DocId, MSTeamsType, Err]),
            %% Teammate may try to register (migrate) all the devices at the same time because it
            %% performs registrations every once in a while, so, sleeping at random times may give
            %% the db a rest between migrations.
            timer:sleep(rand:uniform(200)), %% sleep between 1-200 milliseconds.
            migrate_softphone_to_ms_teams(Dev, Try+1, MaxTries)
    end;
migrate_softphone_to_ms_teams({'ok', _AuthUser}, MaxTries, MaxTries) ->
    lager:warning("unable to migrate after ~p tries, forbid registration", [MaxTries]),
    {'error', 'unable_to_migrate'}.

-spec ms_teams_device_defaults() -> kz_json:object().
ms_teams_device_defaults() ->
    Fns = [{fun kzd_devices:set_media/2, ms_teams_device_default_media()}
          ,{fun kzd_devices:set_caller_id_options/2, ms_teams_device_default_caller_id_options()}
          ,{fun kzd_devices:set_sip_ignore_completed_elsewhere/2, 'false'}
          ,{fun kzd_devices:set_device_type/2, <<"teammate">>}
          ],
    kz_json:exec_first(Fns, kz_json:new()).

-spec ms_teams_device_default_media() -> kz_json:object().
ms_teams_device_default_media() ->
    kz_json:from_list_recursive([{<<"audio">>
                                 ,[{<<"codecs">>, [<<"PCMU">>, <<"PCMA">>]}]
                                 }
                                ,{<<"encryption">>
                                 ,[{<<"enforce_security">>, 'true'}
                                  ,{<<"methods">>, [<<"srtp">>]}
                                  ]
                                 }
                                ,{<<"video">>
                                 ,[{<<"codecs">>, []}]
                                 }
                                ,{<<"webrtc">>, 'false'}
                                ]
                               ,#{ascii_list_enforced => 'false'}
                               ).

-spec ms_teams_device_default_caller_id_options() -> kz_json:object().
ms_teams_device_default_caller_id_options() ->
    kz_json:from_list([{<<"outbound_privacy">>, <<"none">>}
                      ]).
