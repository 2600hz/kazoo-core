%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2025, 2600Hz
%%% @doc Maintenance commands for 3rd party attachments
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_attachments_maintenance).

-export([retry_failed_uploads/0
        ,retry_failed_account/1
        ,retry_failed_account_modb/3
        ]).

-elvis([{elvis_style, no_debug_call, disable}]).

-define(SUMMARY_VIEW, <<"recordings/crossbar_listing">>).

-spec retry_failed_uploads() -> 'ok'.
retry_failed_uploads() ->
    AccountIds = kapps_util:get_all_accounts('raw'),
    Results = lists:foldl(fun retry_failed_account/2, #{}, AccountIds),
    print_results(Results).

-spec retry_failed_account(kz_term:ne_binary()) -> 'ok'.
retry_failed_account(AccountId) ->
    Results = lists:foldl(fun retry_failed_account/2, #{}, [AccountId]),
    print_results(Results).

retry_failed_account(AccountId, Results) ->
    {Year, Month, _} = erlang:date(),
    retry_failed_account_modb(AccountId, Results, Year, Month).

-spec retry_failed_account_modb(kz_term:ne_binary(), kz_term:ne_binary() | kz_time:year(), kz_term:ne_binary() | kz_time:month()) ->
          'ok'.
retry_failed_account_modb(AccountId, <<Year/binary>>, <<Month/binary>>) ->
    retry_failed_account_modb(AccountId, kz_term:to_binary(Year), kz_term:to_integer(Month));
retry_failed_account_modb(AccountId, Year, Month) ->
    Results = retry_failed_account_modb(AccountId, #{}, Year, Month),
    print_results(Results).

retry_failed_account_modb(AccountId, Results, Year, Month) ->
    MODB = kazoo_modb:get_modb(AccountId, Year, Month),
    case kz_datamgr:get_results(MODB, ?SUMMARY_VIEW, []) of
        {'ok', []} -> Results; % no recordings to handle
        {'error', E} -> % view error
            Results#{[AccountId, Year, Month] => {'error', E}};
        {'ok', ViewResults} ->
            Result = retry_failed_account_recordings(MODB, [kz_doc:id(ViewResult) || ViewResult <- ViewResults]),
            Results#{[AccountId, Year, Month] => Result}
    end.

retry_failed_account_recordings(MODB, RecordingIds) ->
    AccountId = kzs_util:format_account_id(MODB),
    lists:foldl(fun(RecordingId, Result) ->
                        parse_recording(AccountId, MODB, RecordingId, Result)
                end
               ,#{}
               ,RecordingIds
               ).

parse_recording(AccountId, MODB, RecordingId, Result) ->
    case kz_datamgr:open_cache_doc(MODB, RecordingId) of
        {'error', _Read}=Error ->
            Result#{RecordingId => Error};
        {'ok', RecordingMeta} ->
            upload_recording(AccountId, MODB, RecordingId, RecordingMeta, Result, kz_doc:attachment_names(RecordingMeta))
    end.

upload_recording(AccountId, MODB, RecordingId, RecordingMeta, Result, []) ->
    Name = kz_json:get_ne_binary_value(<<"name">>, RecordingMeta), % "739c7f65f011783f977999680bb38853.mp3"

    Wildcard = <<"/tmp/*_", Name/binary>>, % /tmp/{UUID}_{Name.mp3}
    case filelib:wildcard(kz_term:to_list(Wildcard)) of
        [] ->
            Result#{RecordingId => {'error', <<"No files found for filepath ", Wildcard/binary>>}};
        [File|_]=Files->
            case file:read_file(File) of
                {'ok', MP3} ->
                    case kz_datamgr:put_attachment(MODB, RecordingId, Name, MP3, [{'content-type', <<"audio/mpeg">>}]) of
                        {'ok', _} ->
                            cleanup_files(Files),
                            Result#{RecordingId => {'ok', list_to_binary(["file ", File, " saved"])}};
                        {'ok', _, _} ->
                            cleanup_files(Files),
                            Result#{RecordingId => {'ok', list_to_binary(["file ", File, " saved"])}};
                        {'error', _Fail} ->
                            Result#{RecordingId => {'error', list_to_binary(["file ", File, " failed to upload"])}}
                    end;
                {'error', _E} ->
                    io:format("| ~s | ~s | ~s file ~s failed to open ~p~n", [AccountId, RecordingId, Name, File, _E])
            end
    end;
upload_recording(_AccountId, _MODB, _RecordingId, _Meta, Result, _Atts) -> Result.

cleanup_files(Files) ->
    lists:foreach(fun cleanup_file/1, Files).

cleanup_file(File) ->
    case file:delete(File) of
        'ok' -> io:format("deleted file ~s~n", [File]);
        {'error', _E} -> io:format("error deleting file ~s: ~p~n", [File, _E])
    end.

%% Results :: #{[AccountId, Year, Month] => Result}
%% Result :: #{RecordingId => {'ok', <<Reason/binary>>} |  %% per RecordingId
%%                            {'error', <<Reason/binary>> | kz_data:error()}
%%            } |
%%           {'error', E}}; %% view read error
print_results(Results) ->
    Headers = [<<"AccountId">>, <<"Year">>, <<"Month">>, <<"RecordingId">>, <<"Result">>],
    Rows = maps:fold(fun collect_result/3, [], Results),
    io:format("~nResults of MODB cleanup:~n", []),
    kz_log:print_table([Headers | Rows], #{header_divider => $=}).

collect_result([AccountId, Year, Month], {'error', _E}, Acc) ->
    io:format("failed to read from MODB ~s:~p:~p: ~p~n", [AccountId, Year, Month, _E]),
    Acc;
collect_result([AccountId, Year, Month], Result, Acc) ->
    {_A, _Y, _M, Acc1} = maps:fold(fun collect_recording_result/3
                                  ,{AccountId, Year, Month, Acc}
                                  ,Result
                                  ),
    Acc1.

collect_recording_result(RecordingId, {'ok', Upload}, {AccountId, Year, Month, Acc}) ->
    {AccountId, Year, Month, [[AccountId, Year, Month, RecordingId, Upload] | Acc]};
collect_recording_result(RecordingId, {'error', Fail}, {AccountId, Year, Month, Acc}) ->
    {AccountId, Year, Month, [[AccountId, Year, Month, RecordingId, Fail] | Acc]}.
