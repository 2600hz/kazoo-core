-module(reupload).

-export([reupload/0
        ,reupload_account/1
        ,reupload_account_modb/3
        ]).

-include("kz_data.hrl").

-elvis([{elvis_style, no_debug_call, disable}]).

-define(SUMMARY_VIEW, <<"recordings/crossbar_listing">>).

-spec reupload() -> 'ok'.
reupload() ->
    io:format("AccountId,RecordingId,Status~n"),
    AccountIds = kapps_util:get_all_accounts('raw'),
    lists:foreach(fun reupload_account/1, AccountIds).

-spec reupload_account(kz_term:ne_binary()) -> 'ok'.
reupload_account(AccountId) ->
    io:format("~n"),
    {Year, Month, _} = erlang:date(),
    reupload_account_modb(AccountId, Year, [Month, Month-1]).

-spec reupload_account_modb(kz_term:ne_binary(), kz_term:ne_binary() | pos_integer(), kz_term:ne_binary() | [integer()]) ->
          'ok'.
reupload_account_modb(AccountId, <<Year/binary>>, <<Month/binary>>) ->
    reupload_account_modb(AccountId, kz_term:to_binary(Year), [kz_term:to_integer(Month)]);
reupload_account_modb(_AccountId, _Year, []) -> 'ok';
reupload_account_modb(AccountId, Year, [Month | Months]) ->
    MODB = kazoo_modb:get_modb(AccountId, Year, Month),
    case kz_datamgr:get_results(MODB, ?SUMMARY_VIEW, []) of
        {'ok', []} -> reupload_account_modb(AccountId, Year, Months);
        {'error', _} -> reupload_account_modb(AccountId, Year, Months);
        {'ok', ViewResults} ->
            reupload_account_recordings(MODB, [kz_doc:id(ViewResult) || ViewResult <- ViewResults]),
            reupload_account_modb(AccountId, Year, Months)
    end.

reupload_account_recordings(MODB, RecordingIds) ->
    AccountId = kzs_util:format_account_id(MODB),
    lists:foreach(fun(RecordingId) ->
                          parse_recording(AccountId, MODB, RecordingId)
                  end
                 ,RecordingIds
                 ).

parse_recording(AccountId, MODB, RecordingId) ->
    case kz_datamgr:open_cache_doc(MODB, RecordingId) of
        {'error', _Read} ->
            io:format("| ~s | ~s | ~p~n", [AccountId, RecordingId, _Read]);
        {'ok', RecordingMeta} ->
            upload_recording(AccountId, RecordingId, MODB, RecordingMeta, kz_doc:attachment_names(RecordingMeta))
    end.

upload_recording(AccountId, RecordingId, MODB, RecordingMeta, []) ->
    Name = kz_json:get_ne_binary_value(<<"name">>, RecordingMeta), % "739c7f65f011783f977999680bb38853.mp3"

    Wildcard = <<"/tmp/*_", Name/binary>>, % /tmp/{UUID}_{Name.mp3}
    case filelib:wildcard(kz_term:to_list(Wildcard)) of
        [] ->
            io:format("| ~s | ~s | ~s not found~n", [AccountId, RecordingId, Wildcard]);
        [File|_] ->
            case file:read_file(File) of
                {'ok', MP3} ->
                    case kz_datamgr:put_attachment(MODB, RecordingId, Name, MP3, [{'content-type', <<"audio/mpeg">>}]) of
                        {'ok', _} ->
                            io:format("| ~s | ~s | ~s file ~s found, saved~n", [AccountId, RecordingId, Name, File]);
                        {'ok', _, _} ->
                            io:format("| ~s | ~s | ~s file ~s found, saved~n", [AccountId, RecordingId, Name, File]);
                        {'error', _Fail} ->
                            io:format("| ~s | ~s | ~s file ~s found, failed to save: ~p~n", [AccountId, RecordingId, Name, File, _Fail])
                    end;
                {'error', _E} ->
                    io:format("| ~s | ~s | ~s file ~s failed to open ~p~n", [AccountId, RecordingId, Name, File, _E])
            end
    end;
upload_recording(_AccountId, _RecordingId, _MODB, _Meta, _Atts) -> 'ok'.
