%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2015-2025, 2600Hz
%%% @doc
%%% @author Peter Defebvre
%%% @author Pierre Fenoll
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_numbers).

%% CRUD Operations
-export([create/2
        ,delete/2
        ,get/1, get/2
        ,release/1, release/2
        ,update/2, update/3
        ]).

%% Special CRUD operations
-export([assign_to_app/2, assign_to_app/3
        ,lookup_account/1
        ,move/2, move/3
        ,reserve/2
        ]).

%% Other operations
-export([account_listing/1
        ,emergency_enabled/1
        ,free/1
        ,validate_ownership/2
        ,cache_key/1
        ,is_number_billable/1

        ,maybe_account_limited/2
        ,maybe_reseller_limited/2
        ]).

-include("knm.hrl").

%% {{{ Types
-type lookup_error() :: 'not_reconcilable' |
                        'not_found' |
                        'unassigned' |
                        {'not_in_service', kz_term:ne_binary()} |
                        {'account_disabled', kz_term:ne_binary()}.

-type lookup_return() :: {'ok', kz_term:ne_binary(), knm_options:extra_options()} |
                         {'error', lookup_error()}.

-type number_thing() :: kz_term:ne_binary().
-type number_things() :: [number_thing()].

-type return() :: {'ok', kz_json:objects()} |
                  {'ok', kz_json:objects(), knm_errors:proplist()} |
                  {'dry_run', knm_pipe:quotes()}.
%% }}}

-export_type([lookup_error/0
             ,lookup_return/0
             ,return/0
             ]).

%%%=============================================================================
%%% CRUD functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Attempts to create a new single number or a list of numbers in DB or
%% modify ones.
%% @end
%%------------------------------------------------------------------------------
-spec create(number_thing() | number_things(), knm_options:options()) -> return().
create(Num, Options) when is_binary(Num) ->
    handle_result(knm_ops:create([Num], Options));
create(Nums, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:create/2, [Nums, Options], Options).

%%------------------------------------------------------------------------------
%% @doc Remove number(s) from the system without doing any state checking.
%%
%% Sounds too harsh for you? You are looking for release/1,2.
%% @end
%%------------------------------------------------------------------------------
-spec delete(number_thing() | number_things(), knm_options:options()) -> return().
delete(Num, Options) when is_binary(Num) ->
    handle_result(knm_ops:delete([Num], Options));
delete(Nums, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:delete/2, [Nums, Options], Options).

%%------------------------------------------------------------------------------
%% @doc Attempts to get a single or a list of numbers from DB.
%% @end
%%------------------------------------------------------------------------------
-spec get(number_thing() | number_things()) -> return().
get(Num) -> get(Num, knm_options:default()).

-spec get(number_thing() | number_things(), knm_options:options()) -> return().
get(Num, Options) when is_binary(Num) ->
    handle_result(knm_ops:get([Num], Options));
get(Nums, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:get/2, [Nums, Options], Options).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec release(number_thing() | number_things()) -> return().
release(Num) -> release(Num, knm_options:default()).

-spec release(number_thing() | number_things(), knm_options:options()) -> return().
release(Num, Options) when is_binary(Num) ->
    handle_result(knm_ops:release([Num], Options));
release(Nums, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:release/2, [Nums, Options], Options).

%%------------------------------------------------------------------------------
%% @doc Attempts to update some phone_number fields.
%%
%% <div class="notice">will always result in a phone_number save.</div>
%% @end
%%------------------------------------------------------------------------------
-spec update(number_thing() | number_things(), knm_phone_number:set_functions()) -> return().
update(Num, Routines) ->
    update(Num, Routines, knm_options:default()).

-spec update(number_thing() | number_things(), knm_phone_number:set_functions(), knm_options:options()) -> return().
update(Num, Routines, Options) when is_binary(Num) ->
    handle_result(knm_ops:update([Num], Routines, Options));
update(Nums, Routines, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:update/3, [Nums, Routines, Options], Options).

%%%=============================================================================
%%% Special CRUD operation functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec assign_to_app(number_thing() | number_things(), kz_term:api_ne_binary()) -> return().
assign_to_app(Num, App) ->
    assign_to_app(Num, App, knm_options:default()).

-spec assign_to_app(number_thing() | number_things(), kz_term:api_ne_binary(), knm_options:options()) -> return().
assign_to_app(Num, App, Options) when is_binary(Num) ->
    handle_result(knm_ops:assign_to_app([Num], App, Options));
assign_to_app(Nums, App, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:assign_to_app/3, [Nums, App, Options], Options).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec lookup_account(kz_term:api_ne_binary()) -> lookup_return().
-ifdef(TEST).
lookup_account('undefined') ->
    {'error', 'not_reconcilable'};
lookup_account(<<Num/binary>>) ->
    NormalizedNum = knm_converters:normalize(Num),
    fetch_account_from_number(NormalizedNum).
-else.
lookup_account('undefined') ->
    {'error', 'not_reconcilable'};
lookup_account(<<Num/binary>>) ->
    NormalizedNum = knm_converters:normalize(Num),
    CacheKey = cache_key(Num),
    case kz_cache:peek_local(?CACHE_NAME, CacheKey) of
        {'ok', Ok} -> Ok;
        {'error', 'not_found'} ->
            case fetch_account_from_number(NormalizedNum) of
                {'ok', _, _}=Ok ->
                    NumberDb = knm_converters:to_db(NormalizedNum),
                    CacheProps = [{'origin', [{'db', NumberDb, NormalizedNum}]}],
                    kz_cache:store_local(?CACHE_NAME, CacheKey, Ok, CacheProps),
                    Ok;
                Else -> Else
            end
    end.
-endif.

-spec cache_key(kz_term:ne_binary()) -> {'account_lookup', kz_term:ne_binary()}.
cache_key(Number) ->
    NormalizedNum = knm_converters:normalize(Number),
    {'account_lookup', NormalizedNum}.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec move(number_thing() | number_things(), kz_term:ne_binary()) -> return().
move(Num, MoveTo) ->
    move(Num, MoveTo, knm_options:default()).

-spec move(number_thing() | number_things(), kz_term:ne_binary(), knm_options:options()) -> return().
move(Num, MoveTo, Options) when is_binary(Num) ->
    handle_result(knm_ops:move([Num], MoveTo, Options));
move(Nums, MoveTo, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:move/3, [Nums, MoveTo, Options], Options).

%%------------------------------------------------------------------------------
%% @doc Fetches then transitions existing number(s) to the reserved state.
%% @end
%%------------------------------------------------------------------------------
-spec reserve(number_thing() | number_things(), knm_options:options()) -> return().
reserve(Num, Options) when is_binary(Num) ->
    handle_result(knm_ops:reserve([Num], Options));
reserve(Nums, Options) when is_list(Nums) ->
    maybe_parallelize_ops(fun knm_ops:reserve/2, [Nums, Options], Options).

%%%=============================================================================
%%% Other functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc List an account's phone numbers and statuses.
%% Does not go through sub accounts.
%% @end
%%------------------------------------------------------------------------------
-spec account_listing(kz_term:ne_binary()) -> [{kz_term:ne_binary(), kz_json:object()}].
account_listing(<<Account/binary>>) ->
    AccountDb = kzs_util:format_account_db(Account),
    case kz_datamgr:get_results(AccountDb, <<"phone_numbers/crossbar_listing">>) of
        {'ok', []} ->
            lager:debug("account ~s holds no numbers", [AccountDb]),
            [];
        {'ok', JObjs} ->
            [{kz_doc:id(JObj), kz_json:get_value(<<"value">>, JObj)}
             || JObj <- JObjs
            ];
        {'error', 'not_found'=_R} ->
            lager:error("error listing numbers for ~s: ~p", [AccountDb, _R]),
            [];
        {'error', R} ->
            lager:error("error listing numbers for ~s: ~p", [AccountDb, R]),
            %% FIXME: why throw?
            throw(R)
    end.

%%------------------------------------------------------------------------------
%% @doc Given a Number, finds out if it is a billable number or not by calling
%% its carrier module.
%% @end
%%------------------------------------------------------------------------------
-spec is_number_billable(kz_term:ne_binary() | kz_json:object()) -> boolean().
is_number_billable(<<Number/binary>>) ->
    case knm_phone_number:fetch(Number) of
        {'ok', PN} -> knm_carriers:is_number_billable(PN);
        {'error', _Reason} -> 'true'
    end;
is_number_billable(JObj) ->
    case kz_json:is_json_object(JObj) of
        'true' ->
            knm_carriers:is_number_billable(knm_phone_number:from_json_with_options(JObj, []));
        'false' -> 'true'
    end.

-spec maybe_account_limited(kz_term:api_ne_binary() | knm_options:extra_options(), kz_json:object()) -> boolean() | 'not_exported'.
maybe_account_limited(Options, JObj) when is_list(Options) ->
    knm_carriers:maybe_account_limited(Options, JObj);
maybe_account_limited(Number, JObj) ->
    case lookup_account(Number) of
        {'ok', _AccountId, Props} ->
            lager:debug("number ~s belongs to ~s", [Number, _AccountId]),
            maybe_account_limited(Props, JObj);
        {'error', _R} ->
            lager:warning("error confirming number ~s: ~p"
                         ,[Number, _R]
                         ),
            'true'
    end.

-spec maybe_reseller_limited(kz_term:ne_binary() | knm_options:extra_options(), kz_json:object()) -> boolean() | 'not_exported'.
maybe_reseller_limited(Options, JObj) when is_list(Options) ->
    knm_carriers:maybe_reseller_limited(Options, JObj);
maybe_reseller_limited(Number, JObj) ->
    case lookup_account(Number) of
        {'ok', _AccountId, Props} ->
            lager:debug("number ~s belongs to ~s", [Number, _AccountId]),
            maybe_reseller_limited(Props, JObj);
        {'error', _R} ->
            lager:warning("error confirming number ~s: ~p"
                         ,[Number, _R]
                         ),
            'true'
    end.

%%------------------------------------------------------------------------------
%% @doc Find an account's phone numbers that have emergency services enabled
%% @end
%%------------------------------------------------------------------------------
-spec emergency_enabled(kz_term:ne_binary()) -> kz_term:ne_binaries().
emergency_enabled(<<Account/binary>>) ->
    [Num || {Num, JObj} <- account_listing(Account),
            Features <- [kz_json:get_list_value(<<"features">>, JObj, [])],
            lists:member(?FEATURE_E911, Features)
    ].

%%------------------------------------------------------------------------------
%% @doc Release all of an account's numbers
%% @end
%%------------------------------------------------------------------------------
-spec free(kz_term:ne_binary()) -> 'ok'.
free(<<Account/binary>>) ->
    AccountDb = kzs_util:format_account_db(Account),
    {Numbers, _NumbersData} = lists:unzip(account_listing(AccountDb)),
    case release(Numbers) of
        {'dry_run', _} ->
            %% should not happen, but dialyzer...
            'ok';
        {'ok', Success} ->
            lager:debug("successfully released ~p numbers from ~s", [length(Success), Account]);
        {'ok', Success, Failed} ->
            lager:debug("successfully released ~p from ~s", [length(Success), Account]),
            lists:foreach(fun ({Num, R}) ->
                                  lager:error("error when releasing ~s from ~s: ~p", [Num, Account, R])
                          end
                         ,Failed
                         )
    end.

%%------------------------------------------------------------------------------
%% @doc Return true if the numbers are all owned by the account, else return the
%% tuple where the first element is `false' and the second is a list of all the
%% numbers that are not owned by the account.
%% @end
%%------------------------------------------------------------------------------
-spec validate_ownership(kz_term:ne_binary(), number_thing() | number_things()) -> 'true' | {'false', number_things()}.
validate_ownership(AccountId, Number) when is_binary(Number) ->
    validate_ownership(AccountId, [Number]);
validate_ownership(_AccountId, []) -> 'true';
validate_ownership(AccountId, Numbers) when is_list(Numbers) ->
    Options = [{'auth_by', AccountId}],
    case ?MODULE:get(Numbers, Options) of
        {'dry_run', _} ->
            %% should not happen, but dialyzer...
            'true';
        {'ok', _Success} ->
            'true';
        {'ok', _Success, Failed} ->
            case lists:foldl(fun validate_ownership_fold/2, [], Failed) of
                [] -> 'true';
                Unauthorized -> {'false', Unauthorized}
            end
    end.

-spec validate_ownership_fold({number_thing(), atom() | kz_json:object() | any()}, number_things()) -> number_things().
validate_ownership_fold({_, Reason}, UnauthorizedAcc) when is_atom(Reason) ->
    %% Ignoring atom reasons, i.e. 'not_found' or 'not_reconcilable'
    UnauthorizedAcc;
validate_ownership_fold({Number, ReasonJObj}, UnauthorizedAcc) ->
    case kz_json:is_json_object(ReasonJObj)
        andalso kz_json:get_value(<<"error">>, ReasonJObj)
    of
        <<"forbidden">> -> [Number|UnauthorizedAcc];
        _ -> UnauthorizedAcc
    end.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec maybe_parallelize_ops(fun(), [any()], knm_options:options()) -> return().
maybe_parallelize_ops(Fun, [Nums | RestArgs]=Args, Options) ->
    FunInfo = erlang:fun_info(Fun),
    FunName = props:get_value('name', FunInfo),
    case knm_options:no_parallel(Options, knm_config:should_parallelize_operations()) of
        'false' ->
            handle_result(erlang:apply(Fun, Args));
        'true' ->
            case kz_term:break_list(lists:uniq(Nums), knm_config:parallel_batch_size()) of
                [] ->
                    merge_results([], Options);
                [_Group] ->
                    %% doesn't worth the effort, run immediatly
                    handle_result(erlang:apply(Fun, Args));
                [_|_]=Grouped ->
                    PidRefs = [kz_process:spawn_monitor(fun perform_parallel_ops/4
                                                       ,[self(), Fun, Group, RestArgs]
                                                       )
                               || Group <- Grouped
                              ],
                    lager:debug("spawned ~p operation into ~b processes: ~p", [FunName, length(Grouped), PidRefs]),
                    merge_results(wait_for_pid_refs(PidRefs), Options)
            end
    end.

-spec perform_parallel_ops(pid(), fun(), any(), knm_options:options()) -> 'ok'.
perform_parallel_ops(Collector, Fun, Nums, Args) ->
    lager:md([{'log_prefix', kz_term:to_binary(self())}] ++ lager:md()),
    Result = erlang:apply(Fun, [Nums | Args]),
    Collector ! {'number_result', Result},
    'ok'.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_result(knm_pipe:collection()) -> return().
handle_result(Collection) ->
    Successes = [knm_phone_number:to_public_json(PN)
                 || PN <- knm_pipe:succeeded(Collection)
                ],
    case {knm_options:dry_run(knm_pipe:options(Collection))
         ,kz_term:is_empty(knm_pipe:failed(Collection))
         }
    of
        {'true', 'true'} ->
            {'dry_run', knm_pipe:quotes(Collection)};
        {'false', 'true'} ->
            {'ok', Successes};
        {_, 'false'} ->
            {'ok', Successes, knm_errors:failed_to_proplist(knm_pipe:failed(Collection))}
    end.

-spec merge_results([knm_pipe:collection()], knm_options:options()) -> return().
merge_results([], _Options) ->
    {'ok', []};
merge_results(Collections, Options) ->
    Successes = merge_succeeded(Collections),
    Failed = merge_failed(Collections),
    Quotes = merge_quotes(Collections),
    case {knm_options:dry_run(Options)
         ,kz_term:is_empty(Failed)
         }
    of
        {'true', 'true'} ->
            {'dry_run', Quotes};
        {'false', 'true'} ->
            {'ok', Successes};
        {_, 'false'} ->
            {'ok', Successes, Failed}
    end.

merge_succeeded(Collections) ->
    [knm_phone_number:to_public_json(PN)
     || Collection <- Collections,
        PN <- knm_pipe:succeeded(Collection)
    ].

merge_failed(Collections) ->
    knm_errors:failed_to_proplist(
      lists:foldl(fun(Collection, AccMap) -> maps:merge(AccMap, knm_pipe:failed(Collection)) end
                 ,#{}
                 ,Collections
                 )
     ).

%% FIXME: this is broken
merge_quotes(Collections) ->
    lager:warning("merging spawned quotes is not supported, you are on your own"),
    %% in reality you must group invoices from all collections by their bookkeeper
    %% then for each bookkeepr go deep and merge all items (rates and billable, changes, etc...), activations, total and etc..
    %% good luck with that! i am signing off...
    [Invoice
     || Collection <- Collections,
        Invoice <- get_quotes(Collection)
    ].

get_quotes(Collection) ->
    case knm_pipe:quotes(Collection) of
        'undefined' -> [];
        Invoices -> Invoices
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec wait_for_pid_refs(kz_term:pid_refs()) -> [knm_pipe:collection()].
wait_for_pid_refs([]) ->
    lager:info("no workers started"),
    [];
wait_for_pid_refs(PidRefs) ->
    wait_for_pid_refs(PidRefs, [], 0).

-spec wait_for_pid_refs(kz_term:pid_refs(), [knm_pipe:collection()], non_neg_integer()) -> [knm_pipe:collection()].
wait_for_pid_refs([], Results, Total) ->
    lager:info("processed ~p workers",[Total]),
    Results;
wait_for_pid_refs(PidRefs, Results, Total) ->
    receive
        {'number_result', Result} ->
            wait_for_pid_refs(PidRefs, [Result|Results], Total);
        {'DOWN', Ref, 'process', Pid, Reason} ->
            handle_down_pid_ref(Pid, Ref, PidRefs, Results, Total, Reason)
    end.

handle_down_pid_ref(Pid, Ref, PidRefs, Results, Total, Reason) ->
    case lists:keytake(Pid, 1, PidRefs) of
        'false' ->
            wait_for_pid_refs(PidRefs, Results, Total);
        {'value', {Pid, Ref}, NewPidRefs} ->
            maybe_log_down_reason(Pid, Reason),
            wait_for_pid_refs(NewPidRefs, Results, Total+1)
    end.

maybe_log_down_reason(_Pid, 'normal') -> 'ok';
maybe_log_down_reason(Pid, Reason) -> lager:info("worker pid ~p died: ~p", [Pid, Reason]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec fetch_account_from_number(kz_term:ne_binary()) -> lookup_return().
fetch_account_from_number(Num) ->
    case knm_phone_number:fetch(Num) of
        {'ok', PN} -> check_number(PN);
        {'error', _}=Error -> maybe_fetch_account_from_ports(Num, Error)
    end.

-spec check_number(knm_phone_number:pn_record()) -> lookup_return().
check_number(PN) ->
    AssignedTo = knm_phone_number:assigned_to(PN),
    case kz_term:is_empty(AssignedTo) of
        'true' -> {'error', 'unassigned'};
        'false' ->
            States = [?NUMBER_STATE_PORT_IN
                     ,?NUMBER_STATE_IN_SERVICE
                     ,?NUMBER_STATE_PORT_OUT
                     ,?NUMBER_STATE_RESERVED
                     ],
            case lists:member(knm_phone_number:state(PN), States) of
                'true' -> check_account(PN);
                'false' -> {'error', {'not_in_service', AssignedTo}}
            end
    end.

-spec check_account(knm_phone_number:pn_record()) -> lookup_return().
check_account(PN) ->
    AssignedTo = knm_phone_number:assigned_to(PN),
    case kzd_accounts:is_enabled(AssignedTo) of
        'false' -> {'error', {'account_disabled', AssignedTo}};
        'true' ->
            Props = [{'pending_port', knm_phone_number:state(PN) =:= ?NUMBER_STATE_PORT_IN}
                    ,{'local', knm_phone_number:module_name(PN) =:= ?CARRIER_LOCAL}
                    ,{'module_name', knm_phone_number:module_name(PN)}
                    ,{'number', knm_phone_number:number(PN)}
                    ,{'account_id', AssignedTo}
                    ,{'prepend', knm_lib:feature_prepend(PN)}
                    ,{'inbound_cnam', knm_lib:feature_inbound_cname(PN)}
                    ,{'ringback_media', knm_lib:find_early_ringback(PN)}
                    ,{'transfer_media', knm_lib:find_transfer_ringback(PN)}
                    ,{'force_outbound', knm_lib:is_force_outbound(PN)}
                    ,{'caller_display_name', knm_lib:feature_caller_display_name(PN)}
                    ],
            {'ok', AssignedTo, Props}
    end.

-spec maybe_fetch_account_from_ports(kz_term:ne_binary(), {'error', any()}) -> lookup_return().
maybe_fetch_account_from_ports(Num, Error) ->
    case knm_config:should_fetch_account_from_ports() of
        'false' -> Error;
        'true' -> fetch_account_from_ports(Num, Error)
    end.

-spec fetch_account_from_ports(kz_term:ne_binary(), {'error', any()}) -> lookup_return().
fetch_account_from_ports(Num, Error) ->
    case knm_port_request:get(Num) of
        {'error', _E} -> Error;
        {'ok', Port} ->
            AccountId = kz_doc:account_id(Port),
            Props = [{'pending_port', 'true'}
                    ,{'local', 'true'}
                    ,{'number', Num}
                    ,{'account_id', AccountId}
                     %% No prepend
                    ,{'inbound_cnam', 'false'}
                     %% No ringback_media
                     %% No transfer_media
                    ,{'force_outbound', 'true'}
                     %% No outbound display name
                    ],
            {'ok', AccountId, Props}
    end.
