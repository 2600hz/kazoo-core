%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2022, 2600Hz
%%% @doc RA (Raft) integration
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_endpoint_limit_ra).
-behaviour(ra_machine).

-compile({no_auto_import, [apply/3]}).

%% API {
%% Commands
-export([reserve/2
        ,release/1
        ]).
%% Queries
-export([reservations/0
        ,reservations/1
        ,reservations/2
        ]).
%% Helpers
-export([ra_name/0]).
%% }

%% ra_machine callbacks
-export([init/1
        ,apply/3
        ,state_enter/2
        ,tick/2
        ,overview/1
        ]).

-type account_id() :: kz_term:ne_binary().
-type endpoint_id() :: kz_term:ne_binary(). %% Can be the id of either a "user" or a "device".
-type owner_id() :: kz_term:api_ne_binary().
-type uuid() :: kz_term:ne_binary().
-type uuids() :: [uuid()].
-type reserved() :: non_neg_integer().
-type available() :: non_neg_integer().
-type account_map() :: #{endpoint_id() => #{'uuids' => uuids()
                                           ,'limit' => non_neg_integer()
                                           }}.
-type uuid_map() :: #{'account_id' => account_id()
                     ,'endpoint_id' => endpoint_id()
                      %% Only if endpoint's type=device, and it has an owner.
                     ,'owner_id' => owner_id()
                     }.
-type state() :: #{'accounts' => #{account_id() => account_map()}
                  ,'uuids' => #{uuid() => uuid_map()}
                  ,'name' => atom()
                  ,'trans_count' => non_neg_integer() %% Total reservations counter for overview/1 function.
                  }.
-type command() :: {'reserve', {account_id(), endpoint_id()}} |
                   {'release', uuid()} |
                   {'reservations', {account_id() | 'undefined', endpoint_id() | 'undefined'}}.
-type reservations() :: uuids() |
                        #{endpoint_id() => uuids()} |
                        #{account_id() => #{endpoint_id() => uuids()}}.
-type reserve_ok_resp() :: {'ok', uuid(), reserved(), available()}.
-type reserve_error_resp() :: {'error', 486 | 'unknown_command' | 'timeout' | 'invalid_endpoint_id'} |
                              kz_datamgr:data_error().
-type release_resp() :: {'ok', reserved(), available()} | {'error', 'not_found'}.
-type reservations_summary() :: {'ok', reservations()} | {'error', term()}.

-export_type([account_id/0
             ,endpoint_id/0
             ,uuid/0
             ,reserve_ok_resp/0
             ,reserve_error_resp/0
             ,release_resp/0
             ,reservations_summary/0
             ]).

%%%=============================================================================
%%% Commands
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Makes a new reservation if endpoint has not reached limit, yet.
%% @end
%%------------------------------------------------------------------------------
-spec reserve(account_id(), endpoint_id()) -> reserve_ok_resp() | reserve_error_resp().
reserve(AccountId, EndpointId) ->
    process_command({'reserve', {AccountId, EndpointId}}).

%%------------------------------------------------------------------------------
%% @doc Frees EndpointId's reservation.
%% @end
%%------------------------------------------------------------------------------
-spec release(uuid()) -> release_resp().
release(UUID) ->
    process_command({'release', UUID}).

%%%=============================================================================
%%% Queries
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Reservations listing.
%% @end
%%------------------------------------------------------------------------------
-spec reservations() -> reservations_summary().
reservations() ->
    reservations('undefined').

%%------------------------------------------------------------------------------
%% @doc Reservations per Account listing.
%% @end
%%------------------------------------------------------------------------------
-spec reservations(account_id() | 'undefined') -> reservations_summary().
reservations(AccountId) ->
    reservations(AccountId, 'undefined').

%%------------------------------------------------------------------------------
%% @doc Reservations per EndpointId listing.
%% @end
%%------------------------------------------------------------------------------
-spec reservations(account_id() | 'undefined', endpoint_id() | 'undefined') -> reservations_summary().
reservations(AccountId, EndpointId) ->
    kz_log:put_callid(kz_log:get_callid()),
    query_state(reservations_query_fun(AccountId, EndpointId)).

-spec ra_name() -> 'endpoint_limit'.
ra_name() ->
    'endpoint_limit'.

%%%=============================================================================
%%% ra_machine callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec init(map()) -> state().
init(#{'name' := Name}=_Config) ->
    #{'name' => Name
     ,'trans_count' => 0
     ,'accounts' => #{}
     ,'uuids' => #{}
     }.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec apply(ra_machine:command_meta_data(), command(), state()) ->
          {state(), reserve_ok_resp() | release_resp() | reservations_summary(), ra_machine:effects()} |
          {state(), reserve_error_resp()}.
apply(_CmdMD, {'reserve', {AccountId, EndpointId}}, State) ->
    kz_log:put_callid(kz_log:get_callid()),
    make_reservation(State, AccountId, EndpointId);
apply(_CmdMD, {'release', UUID}, State) ->
    kz_log:put_callid(kz_log:get_callid()),
    release_reservation(State, UUID);
apply(_CmdMD, _Cmd, State) ->
    lager:debug("received unknown command: ~p", [_Cmd]),
    {State, {'error', 'unknown_command'}}.

%%------------------------------------------------------------------------------
%% @doc Triggered every time there is a ra_state change for this node.
%% @end
%%------------------------------------------------------------------------------
-spec state_enter(ra_server:ra_state(), state()) -> ra_machine:effects().
state_enter(_RaState, _State) ->
    lager:debug("entering into ~s ra_state", [_RaState]),
    [].

%%------------------------------------------------------------------------------
%% @doc Triggered every `_Ts'ms.
%% @end
%%------------------------------------------------------------------------------
-spec tick(non_neg_integer(), state()) -> ra_machine:effects().
tick(_Ts, _State) ->
    [].

%%------------------------------------------------------------------------------
%% @doc Triggered when `sys:get_state(?MODULE:ra_name())' is executed.
%% @end
%%------------------------------------------------------------------------------
-spec overview(state()) -> map().
overview(#{'name' := Name, 'trans_count' := Total}) ->
    #{'type' => Name
     ,'reservations' => Total
     }.

%%%=============================================================================
%%% Helpers
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec process_command(command()) -> reserve_ok_resp() | reserve_error_resp() | release_resp().
process_command(Cmd) ->
    case ra:process_command(ra_name(), Cmd) of
        {'timeout', _} ->
            {'error', 'timeout'};
        {'error', _}=Error ->
            Error;
        {'ok', Reply, _ServerId} ->
            Reply
    end.

-spec make_reservation(state(), account_id(), endpoint_id()) ->
          {state(), reserve_ok_resp(), ra_machine:effects()} |
          {state(), reserve_error_resp()}.
make_reservation(State, AccountId, EndpointId) ->
    lager:debug("trying to make a reservation for ~s/~s", [AccountId, EndpointId]),
    Endpoint = kz_endpoint:get(EndpointId, AccountId),
    make_reservation(State, AccountId, EndpointId, Endpoint).

-spec make_reservation(state(), account_id(), endpoint_id(), kz_endpoint:std_return()) ->
          {state(), reserve_ok_resp(), ra_machine:effects()} |
          {state(), reserve_error_resp()}.
make_reservation(State, _AccountId, _EndpointId, {'error', _}=Err) ->
    lager:debug("failed to reserve because endpoint load failed with: ~p", [Err]),
    {State, Err};
make_reservation(State, AccountId, EndpointId, {'ok', Endpoint}) ->
    Limit = endpoint_limit(Endpoint),
    ReservedCount = length(endpoint_reserved_from_state(State, AccountId, EndpointId)),
    lager:debug("endpoint ~s: limit=~B, reserved=~B", [kz_doc:id(Endpoint), Limit, ReservedCount]),
    Owner = owner_endpoint(AccountId, kzd_endpoint:owner_id(Endpoint)),
    OwnerId = kz_doc:id(Owner),
    %% If owner(if any)'s limit is set, that limit will be used, otherwise, 'infinity' will be used in order
    %% to maybe (if endpoint's Limit > ReservedCount) allow the reservation to be added to the device.
    OwnerLimit = endpoint_limit(Owner, 'infinity'),
    OwnerReservedCount = length(endpoint_reserved_from_state(State, AccountId, kz_doc:id(Owner))),
    lager:debug("owner ~s: limit=~p, reserved=~B", [OwnerId, OwnerLimit, OwnerReservedCount]),
    case Limit > ReservedCount %% First, make sure the actual endpoint has room for another reservation.
        andalso OwnerLimit > OwnerReservedCount %% In case endpoint=device and has a owner with a limit set.
    of
        'true' ->
            UUID = kz_binary:rand_uuid(),
            lager:debug("adding ~s reservation for ~s/~s", [UUID, AccountId, EndpointId]),
            NewReservedCount = ReservedCount + 1,
            Accounts = kz_maps:get('accounts', State),
            BaseUUIDMap = #{'account_id' => AccountId, 'endpoint_id' => EndpointId},
            UUIDMap = maybe_link_owner_id(BaseUUIDMap, OwnerId),
            {State#{'accounts' => kz_maps:put(AccountId
                                             ,Accounts
                                             ,lists:foldl(
                                                fun(JObj, Acc) ->
                                                        fold_add_reservation(Acc, UUID, JObj)
                                                end
                                               ,kz_maps:get(AccountId, Accounts, #{})
                                               ,[Endpoint, Owner]
                                               )
                                             )
                    %% Used to find the account_id, endpoint_id, and maybe the owner_id when releasing
                    %% a reservation.
                   ,'uuids' => kz_maps:put(UUID, kz_maps:get('uuids', State), UUIDMap)
                   ,'trans_count' => kz_maps:get('trans_count', State) + 1
                   }
            ,{'ok', UUID, NewReservedCount, Limit - NewReservedCount}
            ,[]
            };
        'false' ->
            lager:debug("either endpoint or owner has reached the limit, denying reservation"),
            {State, {'error', 486}}
    end.

-spec release_reservation(state(), uuid()) -> {state(), release_resp(), ra_machine:effects()}.
release_reservation(State, UUID) ->
    lager:debug("trying to release ~s", [UUID]),
    release_reservation(State, UUID, kz_maps:get(['uuids', UUID], State)).

-spec release_reservation(state(), uuid(), {account_id(), endpoint_id()} | 'undefined') ->
          {state(), release_resp(), ra_machine:effects()}.
release_reservation(State, UUID, 'undefined') ->
    lager:debug("reservation ~s not found", [UUID]),
    {State, {'error', 'not_found'}};
release_reservation(#{'trans_count' := TransCount, 'accounts' := AccountsMap}=State
                   ,UUID
                   ,#{'account_id' := AccountId, 'endpoint_id' := EndpointId}=UUIDMap
                   ) ->
    lager:debug("releasing ~s reservation from ~s/~s", [UUID, AccountId, EndpointId]),
    AccountMap = kz_maps:get(AccountId, AccountsMap),
    NewAccountMap = lists:foldl(fun(Id, Acc) -> release_from(Acc, UUID, Id) end
                               ,AccountMap
                               ,[EndpointId, kz_maps:get('owner_id', UUIDMap)]
                               ),
    NewReservedCount = length(endpoint_reserved_from_account(NewAccountMap, EndpointId)),
    %% Get the limit from the AccountMap, not from NewAccountMap, as it may not contain the
    %% endpoint's information anymore after releasing the current UUID.
    Limit = endpoint_limit_from_account(AccountMap, EndpointId),
    {State#{'accounts' => kz_maps:put(AccountId, AccountsMap, NewAccountMap)
            %% Remove uuids->uuid key from state.
           ,'uuids' => kz_maps:remove(UUID, kz_maps:get('uuids', State))
           ,'trans_count' => TransCount - 1
           }
    ,{'ok', NewReservedCount, Limit - NewReservedCount}
    ,[]
    }.

-spec reservations_query_fun(account_id() | 'undefined', endpoint_id() | 'undefined') ->
          fun((state()) -> reservations()).
reservations_query_fun('undefined', _EndpointId) -> %% List all the existing reservations.
    fun(State) ->
            kz_maps:remove(['name', 'trans_count', 'uuids'], State) end;
reservations_query_fun(AccountId, 'undefined') -> %% List account's reservations.
    fun(State) -> kz_maps:get(['accounts', AccountId], State, #{}) end;
reservations_query_fun(AccountId, EndpointId) -> %% List endpoint's reservations.
    fun(State) -> kz_maps:get(['accounts', AccountId, EndpointId], State, []) end.

-spec query_state(fun((state()) -> reservations())) -> reservations_summary().
query_state(Fun) ->
    case ra:local_query(ra_name(), Fun) of
        {'timeout', _}=_Error ->
            lager:debug("timed out querying state with error: ~p", [_Error]),
            {'error', 'timeout'};
        {'error', _}=Error ->
            lager:debug("failed to query state with error: ~p", [Error]),
            Error;
        {'ok', {_RaIdxTerm, Reservations}, _ServerId} ->
            {'ok', Reservations}
    end.

-spec endpoint_limit(kz_json:object()) -> kz_term:api_non_neg_integer().
endpoint_limit(Endpoint) ->
    endpoint_limit(Endpoint, 'undefined').

-spec endpoint_limit(kz_json:object(), Default) -> non_neg_integer() | Default.
endpoint_limit(Endpoint, Default) ->
    kzd_call_limits:max_concurrent(kzd_endpoint:call_limits(Endpoint), Default).

-spec endpoint_reserved_from_state(state(), account_id(), endpoint_id() | owner_id()) -> uuids().
endpoint_reserved_from_state(_State, _AccountId, 'undefined') ->
    %% Expected to happen only for unassigned endpoints.
    [];
endpoint_reserved_from_state(State, AccountId, EndpointId) ->
    kz_maps:get(['accounts', AccountId, EndpointId, 'uuids'], State, []).

%% This function is intended to only be used by the endpoint itself, not its owner (if any). It is
%% used to calculate the new reserved and available response values after releasing a reservation.
-spec endpoint_reserved_from_account(account_map(), endpoint_id()) -> uuids().
endpoint_reserved_from_account(AccountMap, EndpointId) ->
    kz_maps:get([EndpointId, 'uuids'], AccountMap, []).

-spec owner_endpoint(account_id(), kz_term:api_ne_binary()) -> kz_json:object().
owner_endpoint(_AccountId, 'undefined') ->
    kz_json:new();
owner_endpoint(AccountId, OwnerId) ->
    case kz_endpoint:get(OwnerId, AccountId) of
        {'ok', OwnerDoc} ->
            OwnerDoc;
        {'error', _}=_Err ->
            lager:debug("error building ~s/~s (owner) endpoint: ~p", [AccountId, OwnerId, _Err]),
            kz_json:new()
    end.

-spec maybe_link_owner_id(uuid_map(), owner_id()) -> uuid_map().
maybe_link_owner_id(UUIDMap, 'undefined') ->
    UUIDMap;
maybe_link_owner_id(UUIDMap, <<OwnerId/binary>>) ->
    kz_maps:put('owner_id', UUIDMap, OwnerId).

-spec fold_add_reservation(account_map(), uuid(), kz_json:object()) -> account_map().
fold_add_reservation(AccountAcc, UUID, Endpoint) ->
    fold_add_reservation(AccountAcc, UUID, Endpoint, kz_doc:id(Endpoint)).

-spec fold_add_reservation(account_map(), uuid(), kz_json:object(), kz_term:api_ne_binary()) -> account_map().
fold_add_reservation(AccountAcc, _UUID, _Endpoint, 'undefined') ->
    %% Expected to happen only for unassigned endpoints.
    AccountAcc;
fold_add_reservation(AccountAcc, UUID, Endpoint, <<EndpointId/binary>>) ->
    Reserved = kz_maps:get([EndpointId, 'uuids'], AccountAcc, []),
    kz_maps:put(EndpointId
               ,AccountAcc
               ,#{'uuids' => [UUID | Reserved]
                  %% Used later at release step for the response.
                  %% To avoid fetching endpoint information again.
                 ,'limit' => endpoint_limit(Endpoint)
                 }
               ).

%% Only meant to be used when releasing a reservation, and only intended for the actual endpoint_id,
%% not its owner (if any).
-spec endpoint_limit_from_account(account_map(), endpoint_id()) -> kz_term:api_non_neg_integer().
endpoint_limit_from_account(AccountMap, EndpointId) ->
    kz_maps:get([EndpointId, 'limit'], AccountMap).

-spec release_from(account_map(), uuid(), endpoint_id() | owner_id()) -> account_map().
release_from(AccountAcc, _UUID, 'undefined') ->
    %% Expected to happen only for unassigned endpoints.
    AccountAcc;
release_from(AccountAcc, UUID, <<EndpointId/binary>>) ->
    Reserved = kz_maps:get([EndpointId, 'uuids'], AccountAcc, []),
    release_from(AccountAcc, UUID, EndpointId, Reserved).

-spec release_from(account_map(), uuid(), owner_id(), uuids()) -> account_map().
release_from(AccountAcc, _UUID, <<_EndpointId/binary>>, []) ->
    %% This may happen in very special scenario where endpoint's type=device and
    %% EndpointId=Owner's id, so maybe device was unassigned when call started and got assigned
    %% before call ended.
    AccountAcc;
release_from(AccountAcc, UUID, <<EndpointId/binary>>, Reserved) ->
    case lists:delete(UUID, Reserved) of
        %% If endpoint's reservations list is empty, better to delete endpoint's object from state.
        [] -> kz_maps:remove(EndpointId, AccountAcc);
        NewReserved -> kz_maps:put([EndpointId, 'uuids'], AccountAcc, NewReserved)
    end.
