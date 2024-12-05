%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Accessors for `presence' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_presence).

-export([new/0]).
-export([action/1, action/2, set_action/2]).
-export([reset/1, reset/2, set_reset/2]).
-export([state/1, state/2, set_state/2]).
-export([presence_id/1, presence_id/2, set_presence_id/2]).

-export([type/0]).

-export([list_presence/1]).
-export([fetch_presence/2]).
-export([update_presence/3]).

-export([rollover/3]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"presence">>).
-define(TYPE, <<"presence">>).

-define(PRESENCE_ID, <<"presence_id">>).
-define(PRESENCE_STATE, <<"state">>).

-define(CB_LIST, <<"presence/crossbar_listing">>).
-define(CB_LIST_BY_PRESENCE, <<"presence/listing_by_presence">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec action(doc()) -> kz_term:api_object().
action(Doc) ->
    action(Doc, 'undefined').

-spec action(doc(), Default) -> kz_json:object() | Default.
action(Doc, Default) ->
    kz_json:get_json_value([<<"action">>], Doc, Default).

-spec set_action(doc(), kz_json:object()) -> doc().
set_action(Doc, Action) ->
    kz_json:set_value([<<"action">>], Action, Doc).

-spec reset(doc()) -> kz_term:api_boolean().
reset(Doc) ->
    reset(Doc, 'undefined').

-spec reset(doc(), Default) -> boolean() | Default.
reset(Doc, Default) ->
    kz_json:get_boolean_value([<<"reset">>], Doc, Default).

-spec set_reset(doc(), boolean()) -> doc().
set_reset(Doc, Reset) ->
    kz_json:set_value([<<"reset">>], Reset, Doc).

-spec state(doc()) -> kz_term:api_object().
state(Doc) ->
    state(Doc, 'undefined').

-spec state(doc(), Default) -> kz_json:object() | Default.
state(Doc, Default) ->
    kz_json:get_json_value([?PRESENCE_STATE], Doc, Default).

-spec set_state(doc(), kz_json:object()) -> doc().
set_state(Doc, State) ->
    kz_json:set_value([?PRESENCE_STATE], State, Doc).

-spec presence_id(doc()) -> kz_term:api_object().
presence_id(Doc) ->
    presence_id(Doc, 'undefined').

-spec presence_id(doc(), Default) -> kz_json:object() | Default.
presence_id(Doc, Default) ->
    kz_json:get_json_value([?PRESENCE_ID], Doc, Default).

-spec set_presence_id(doc(), kz_json:object()) -> doc().
set_presence_id(Doc, PresenceId) ->
    kz_json:set_value([?PRESENCE_ID], PresenceId, Doc).

-spec type() -> kz_term:ne_binary().
type() -> ?TYPE.

-spec update_presence(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:object()} |
          kz_datamgr:data_error().
update_presence(AccountId, PresenceId, PresenceState) ->
    JObj = update_public_fields(new(), PresenceId, PresenceState),
    PresenceDoc = update_pvt_fields(JObj, AccountId),
    lager:debug("saving the presence doc for presence id ~s with state ~s", [PresenceId, PresenceState]),
    kazoo_modb:save_doc(AccountId, PresenceDoc).

-spec update_public_fields(kz_json:object(), kz_term:ne_binary(), kz_term:ne_binary()) ->
          kz_json:object().
update_public_fields(JObj, PresenceId, PresenceState) ->
    Setters = [{fun set_state/2, PresenceState}
              ,{fun set_presence_id/2, PresenceId}
              ],
    kz_doc:setters(JObj, Setters).

-spec update_pvt_fields(kz_json:object(), kz_term:ne_binary()) ->
          kz_json:object().
update_pvt_fields(JObj, AccountId) ->
    kz_doc:update_pvt_parameters(JObj
                                ,kazoo_modb:get_modb(AccountId)
                                ,[{'type', ?TYPE}]
                                ).

-spec list_presence(kz_term:ne_binary()) ->
          {'ok', kz_json:objects()} |
          kz_datamgr:data_error().
list_presence(AccountId) ->
    ViewOptions = ['reduce'
                  ,'group'
                  ,'missing_as_error'
                  ,{'result_key', <<"value">>}
                  ],
    case kazoo_modb:get_results(AccountId, ?CB_LIST_BY_PRESENCE, ViewOptions) of
        {'ok', []} ->
            {'ok', []};
        {'ok', JObjs} ->
            {'ok'
            ,kz_json:from_list(lists:map(fun normalize_presence_state/1, JObjs))
            };
        {'error', _Reason} = Error ->
            {Year, Month, _} = erlang:date(),
            lager:warning("failed to list manual presence for ~s ~p-~p: ~p"
                         ,[AccountId, Year, Month, _Reason]
                         ),
            Error
    end.

-spec fetch_presence(kz_term:ne_binary(), kz_term:ne_binary()) ->
          {'ok', kz_json:objects()} |
          kz_data:data_error().
fetch_presence(AccountId, PresenceId) ->
    ViewOptions = ['reduce'
                  ,'group'
                  ,{'startkey', [PresenceId]}
                  ,{'endkey', [PresenceId, kz_json:new()]}
                  ,{'result_key', <<"value">>}
                  ],
    case kazoo_modb:get_results(AccountId, ?CB_LIST_BY_PRESENCE, ViewOptions) of
        {'ok', []} ->
            {Year, Month, _} = erlang:date(),
            lager:info("no presence state for ~s of ~s ~p-~p"
                      ,[PresenceId, AccountId, Year, Month]
                      ),
            {'error', 'not_found'};
        {'ok', JObjs} ->
            {'ok'
            ,kz_json:from_list(lists:map(fun normalize_presence_state/1, JObjs))
            };
        {'error', _Reason} = Error ->
            {Year, Month, _} = erlang:date(),
            lager:warning("failed to fetch manual presence id ~s for ~s ~p-~p: ~p"
                         ,[PresenceId, AccountId, Year, Month, _Reason]
                         ),
            Error
    end.

-spec normalize_presence_state(kz_json:object()) ->
          {kz_term:api_binary(), kz_term:api_binary()}.
normalize_presence_state(JObj) ->
    {kz_json:get_binary_value(?PRESENCE_ID, JObj)
    ,kz_json:get_binary_value(?PRESENCE_STATE, JObj)
    }.

-spec rollover(kz_term:ne_binary(), kz_time:year(), kz_time:month()) -> 'ok'.
rollover(AccountId, Year, Month) ->
    NewMODb = kzs_util:format_account_mod_id(AccountId, Year, Month),
    PrevMODb = kzs_util:format_account_modb(kazoo_modb_util:prev_year_month_mod(NewMODb)
                                           ,'encoded'
                                           ),
    lager:debug("creating snapshots for account ~s presence in month ~p-~p"
               ,[AccountId, Year, Month]
               ),
    PresenceDocIds = list_previous_presence(PrevMODb),
    save_presence_to_modb(PrevMODb, NewMODb, PresenceDocIds).

-spec list_previous_presence(kz_term:ne_binary()) -> kz_term:ne_binaries().
list_previous_presence(MODB) ->
    ViewOptions = ['reduce'
                  ,'group'
                  ,'missing_as_error'
                  ,{'result_key', <<"value">>}
                  ],
    case kazoo_modb:get_results(MODB, ?CB_LIST_BY_PRESENCE, ViewOptions) of
        {'ok', []} ->
            lager:debug("no manual presence for ~s", [MODB]),
            [];
        {'ok', JObjs} ->
            lists:map(fun kz_doc:id/1, JObjs);
        {'error', _Reason} ->
            lager:warning("failed to list manual presence from ~s: ~p"
                         ,[MODB, _Reason]
                         ),
            []
    end.

-spec save_presence_to_modb(kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binaries()) -> 'ok'.
save_presence_to_modb(PrevMODb, NewMODb, []) ->
    lager:debug("completed of copying presence snapshots from ~s to ~s"
               ,[PrevMODb, NewMODb]
               );
save_presence_to_modb(PrevMODb, NewMODb, [DocId|DocIds]) ->
    case kazoo_modb:copy_doc(PrevMODb, DocId, NewMODb, DocId) of
        {'ok', _} ->
            lager:debug("copied presence snapshot ~s from ~s to ~s"
                       ,[DocId, PrevMODb, NewMODb]
                       );
        {'error', 'conflict'} ->
            lager:info("conflict when saving presence snapshot ~s from ~s to ~s"
                      ,[DocId, PrevMODb, NewMODb]
                      );
        {'error', _R} ->
            lager:warning("failed to store presence snapshot ~s from ~s to ~s: ~p"
                         ,[DocId, PrevMODb, NewMODb, _R]
                         )
    end,
    save_presence_to_modb(PrevMODb, NewMODb, DocIds).
