%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_services_standing).

-export([acceptable/1
        ,acceptable/2
        ,call_good_standing/1
        ,call_good_standing/2
        ]).

-include("services.hrl").

-define(DEFAULT_EXPIRATION_S, 5 * ?SECONDS_IN_MINUTE).

-type acceptable_options() :: #{amount => integer()
                                %% Additional units amount to add to the current balance. Default is 0.
                               ,allow_postpay => boolean()
                                %% Should post pay be allowed or not. Default is `false'.
                               ,max_postpay_amount => kz_currency:units()
                                %% Maximum amount of post pay if it is allowed. Default is 0.
                               ,quotes => kz_services_invoices:invoices()
                                %% Should the results come from a cache if present
                               ,cache_acceptable => boolean()
                                %% How long should a account id result be cached
                               ,cache_expiration => non_neg_integer()
                               }.

-type unacceptable_details() :: #{reason => kz_term:ne_binary()
                                 ,message => kz_term:ne_binary()
                                 }.

-type acceptable_return() :: {'true', kz_term:ne_binary()} |
                             {'false', unacceptable_details()}.

-type acceptable_fun()  :: fun((kz_services:services(), acceptable_options()) -> good_funs_ret()).
-type acceptable_funs()  :: [acceptable_fun()].

-export_type([acceptable_options/0
             ,acceptable_return/0
             ]).

%%------------------------------------------------------------------------------
%% @doc Check if the account is in good standing.
%%
%% Good standing rules:
%% * If an account has no service plans assigned, it is in good standing
%% * If an account has service plans and a default payment token it is in good standing
%% * If an account has service plans, post pay is disabled and the balance is greater
%%   than 0 then it is in good standing
%% * If an account has service plans, post pay is enabled, and the balance is greater
%%   than the max post pay amount then the account is in good standing
%% * All other cases the account is not in good standing
%% @end
%%------------------------------------------------------------------------------
%% @equiv acceptable(Thing, 0)
-spec acceptable(kz_term:ne_binary() | kz_services:services()) -> acceptable_return().
acceptable(Thing) ->
    acceptable(Thing, #{}).

-spec acceptable(kz_term:ne_binary() | kz_services:services(), acceptable_options()) -> acceptable_return().
acceptable(?NE_BINARY=Account, Options) ->
    FetchOptions = ['hydrate_plans'],
    acceptable(kz_services:fetch(Account, FetchOptions), Options);
acceptable(Services, Options) ->
    lager:debug("checking if account ~s is in good standing: ~p"
               ,[kz_services:account_id(Services), Options]
               ),
    GoodFuns = [fun should_enforce_good_standing/2
               ,fun no_plan_is_good/2
               ,fun check_bookkeeper/2
               ],
    is_acceptable(Services, Options, GoodFuns).

-spec call_good_standing(kz_term:ne_binary() | kz_services:services()) -> acceptable_return().
call_good_standing(Thing) ->
    call_good_standing(Thing, #{}).

-spec call_good_standing(kz_term:ne_binary() | kz_services:services(), acceptable_options()) -> acceptable_return().
call_good_standing(?NE_BINARY=Account, Options) ->
    FetchOptions = ['hydrate_plans'],
    call_good_standing(kz_services:fetch(Account, FetchOptions), Options);
call_good_standing(Services, Options) ->
    lager:debug("checking if account ~s is in good standing without checking enforce good standing and plans: ~p"
               ,[kz_services:account_id(Services), Options]
               ),
    GoodFuns = [fun check_bookkeeper/2],
    is_acceptable(Services, Options, GoodFuns).

-spec is_acceptable(kz_services:services(), acceptable_options(), list()) -> acceptable_return().
is_acceptable(Services, Options, GoodFuns) ->
    NewOptions = #{amount =>
                       kz_term:to_integer(maps:get('amount', Options, 0))
                  ,allow_postpay =>
                       kz_term:is_true(maps:get('allow_postpay', Options, 'false'))
                  ,max_postpay_amount =>
                       kz_term:to_integer(maps:get('max_postpay_amount', Options, 0))
                  ,quotes =>
                       maps:get('quotes', Options, kz_services:invoices(Services))
                  ,cache_acceptable =>
                       kz_term:is_true(maps:get('cache_acceptable', Options, 'false'))
                  ,cache_expiration =>
                       kz_term:to_integer(maps:get('cache_expiration', Options, ?DEFAULT_EXPIRATION_S))
                  },
    maybe_use_cache(Services, NewOptions, GoodFuns).

-spec maybe_use_cache(kz_services:services(), acceptable_options(), acceptable_funs()) -> acceptable_return().
maybe_use_cache(Services, #{cache_acceptable := 'true'} = Options, GoodFuns) ->
    case kz_cache:peek_local(?CACHE_NAME, cache_key(Services, Options)) of
        {'error', 'not_found'} ->
            Result = acceptable_fold(Services, Options, GoodFuns),
            maybe_cache_result(Services, Options, Result);
        {'ok', {Acceptable, Reason}=Result} ->
            lager:debug("using cached result: ~s ~s"
                       ,[Acceptable, Reason]
                       ),
            Result
    end;
maybe_use_cache(Services, Options, GoodFuns) ->
    acceptable_fold(Services, Options, GoodFuns).

-spec maybe_cache_result(kz_services:services(), acceptable_options(), acceptable_return()) -> acceptable_return().
maybe_cache_result(_Services, _Options, {'false', _Reason}=Result) ->
    Result;
maybe_cache_result(Services, #{cache_expiration := Expiration} = Options, Result) ->
    CacheOptions = [{'expires', Expiration}],
    _ = kz_cache:store_local(?CACHE_NAME, cache_key(Services, Options), Result, CacheOptions),
    Result.

-type cache_key() :: {atom(), kz_term:ne_binary(), non_neg_integer(), boolean()} |
                     {?MODULE, kz_term:ne_binary(), integer()}.
-spec cache_key(kz_services:services(), acceptable_options()) -> cache_key().
cache_key(Services, #{cache_expiration := Expiration}) ->
    AccountId = kz_services:account_id(Services),
    {?MODULE, AccountId, Expiration}.

-spec acceptable_fold(kz_services:services(), acceptable_options(), acceptable_funs()) -> acceptable_return().
acceptable_fold(Services, _Options, []) ->
    Msg = io_lib:format("account ~s is in good standing"
                       ,[kz_services:account_id(Services)]
                       ),
    lager:debug("~s", [Msg]),
    {'true', kz_term:to_binary(Msg)};
acceptable_fold(Services, Options, [Fun | Funs]) ->
    case Fun(Services, Options) of
        {'true', Reason} = _TheGood ->
            lager:debug("account ~s is in good standing: ~s"
                       ,[kz_services:account_id(Services), Reason]
                       ),
            {'true', Reason};
        {'false', Reason} = _TheBad ->
            lager:debug("account ~s is not in good standing: ~p"
                       ,[kz_services:account_id(Services), Reason]
                       ),
            {'false', Reason};
        'not_applicable' -> acceptable_fold(Services, Options, Funs)
    end.

-type good_funs_ret() :: acceptable_return() | 'not_applicable'.

-spec should_enforce_good_standing(kz_services:services(), acceptable_options()) -> good_funs_ret().
should_enforce_good_standing(_Services, _Options) ->
    case ?KZ_SERVICE_ENFORCE_GOOD_STANDING of
        'true' -> 'not_applicable';
        'false' ->
            {'true', <<"good standing not required">>}
    end.

-spec no_plan_is_good(kz_services:services(), acceptable_options()) -> good_funs_ret().
no_plan_is_good(Services, _Options) ->
    case kz_services:has_plans(Services) of
        'true' -> 'not_applicable';
        'false' ->
            lager:info("no plans in services for ~s", [kz_services:account_id(Services)]),
            {'true', <<"no service plans assigned">>}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec check_bookkeeper(kz_services:services(), acceptable_options()) -> good_funs_ret().
check_bookkeeper(Services, #{quotes := Quotes} = Options) ->
    Results =
        kz_services_invoices:foldl(invoices_foldl_fun(Services, Options)
                                  ,[]
                                  ,Quotes
                                  ),
    handle_bookkeeper_results(Results).

-spec handle_bookkeeper_results(any()) -> good_funs_ret().
handle_bookkeeper_results([]) ->
    'not_applicable';
handle_bookkeeper_results([{_Invoice, {'ok', Result}}|Results]) ->
    case kz_json:get_ne_binary_value(<<"Status">>, Result) =:= kzd_services:status_good() of
        'true' -> handle_bookkeeper_results(Results);
        'false' ->
            maybe_smooth_disruptions(Result, Results)
    end;
handle_bookkeeper_results([{_Invoice, _Error}|Results]) ->
    lager:debug("unexpected bookkeeper result: ~p", [_Error]),
    Result = [{<<"Reason">>, <<"bookkeeper_fault">>}
             ,{<<"Message">>, <<"Temporary billing error, please try again later.">>}
             ],
    maybe_smooth_disruptions(kz_json:from_list(Result), Results).

maybe_smooth_disruptions(Result, Results) ->
    RejectReason = kz_json:get_ne_binary_value(<<"Reason">>, Result, <<"bookkeeper_rejection">>),
    case should_smooth_disruptions() of
        'true' ->
            lager:warning("billing error is being ignored for now: ~s", [RejectReason]),
            handle_bookkeeper_results(Results);
        'false' ->
            DefaultMessage = <<"There is a billing issue with this account, please contact your sales representative.">>,
            {'false'
            ,#{reason => RejectReason
              ,message => kz_json:get_ne_binary_value(<<"Message">>, Result, DefaultMessage)
              }
            }
    end.

should_smooth_disruptions() ->
    Config = kapps_config:get_integer(?CONFIG_CAT, <<"days_to_ignore_standing_failures">>, 0),
    should_smooth_disruptions(Config).

should_smooth_disruptions(0) -> 'false';
should_smooth_disruptions(Days) ->
    should_smooth_disruptions(Days, erlang:date()).

should_smooth_disruptions(Days, {_Y, _M, Day}) when Day < Days ->
    lager:warning("smoothing over error on day ~p when ~p days allowable", [Day, Days]),
    'true';
should_smooth_disruptions(_Days, {_Y, _M, _Day}) ->
    lager:info("day ~p outside configured days ~p for smoothing", [_Day, _Days]),
    'false'.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-type invoices_acc() :: [{kz_json:object(), kz_amqp_worker:request_return()}].
-spec invoices_foldl_fun(kz_services:services(), acceptable_options()) ->
          fun((kz_json:object(), invoices_acc()) -> invoices_acc()).
invoices_foldl_fun(Services, Options) ->
    fun(Invoice, Results) ->
            Type = kz_services_invoice:bookkeeper_type(Invoice),
            case kzd_services:default_bookkeeper_type() of
                Type ->
                    Result = kz_json:from_list([{<<"Status">>, kzd_services:status_good()}]),
                    [{Invoice, {'ok', Result}} | Results];
                _DefaultBookkeeperType ->
                    Result = check_bookkeeper(Invoice, Services, Options),
                    [{Invoice, Result} | Results]
            end
    end.

-spec check_bookkeeper(kz_services_invoice:invoice(), kz_services:services(), acceptable_options()) ->
          kz_amqp_worker:request_return().
check_bookkeeper(Invoice, Services, #{amount := Amount}) ->
    Request = [{<<"Account-ID">>, kz_services:account_id(Services)}
              ,{<<"Bookkeeper-ID">>, kz_services_invoice:bookkeeper_id(Invoice)}
              ,{<<"Bookkeeper-Type">>, kz_services_invoice:bookkeeper_type(Invoice)}
              ,{<<"Vendor-ID">>, kz_services_invoice:bookkeeper_vendor_id(Invoice)}
              ,{<<"Items">>
               ,kz_services_items:public_json(
                  kz_services_invoice:items(Invoice)
                 )
               }
              ,{<<"Estimated-Withdrawal">>, Amount}
              ,{<<"Call-ID">>, kz_log:get_callid()}
              | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
              ],
    kz_amqp_worker:call(Request
                       ,fun kapi_bookkeepers:publish_standing_req/1
                       ,fun kapi_bookkeepers:standing_resp_v/1
                       ,2 * ?MILLISECONDS_IN_SECOND
                       ).
