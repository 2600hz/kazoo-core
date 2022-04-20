%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2020-, Ooma
%%% @doc Number manager module for inteliquent.
%%% @author Ben Bradford, Hai Lei
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_inteliquent).
-behaviour(knm_gen_carrier).

-export([info/0]).
-export([is_local/0]).
-export([find_numbers/3]).
-export([acquire_number/1]).
-export([disconnect_number/1]).
-export([is_number_billable/1]).
-export([should_lookup_cnam/0]).
-export([check_numbers/1]).
-export([check_portability/1]).

-include("knm.hrl").

-define(KNM_CARRIER_NAME, "inteliquent").
-define(KNM_CARRIER_CONFIG_CAT, <<(?KNM_CONFIG_CAT)/binary, ".", ?KNM_CARRIER_NAME>>).
-define(ENABLE_MESSAGING_ON_PHONE_NUMBERS
       ,kapps_config:get_boolean(?KNM_CARRIER_CONFIG_CAT, <<"enable_messaging_on_phone_numbers">>, 'false')
       ).
-define(MESSAGING_TYPE
       ,kapps_config:get_binary(?KNM_CARRIER_CONFIG_CAT, <<"messaging_type">>, <<"SMSMMS">>)
       ).
-define(MESSAGING_CLASS
       ,kapps_config:get_binary(?KNM_CARRIER_CONFIG_CAT, <<"messaging_class">>, <<"P2P">>)
       ).
-define(RELEASE_PHONE_NUMBERS_ON_DISCONNECT
       ,kapps_config:get_boolean(?KNM_CARRIER_CONFIG_CAT, <<"release_phone_numbers_on_disconnect">>, 'false')
       ).
-define(RELEASE_TOLL_FREE_NUMBERS_ON_DISCONNECT
       ,kapps_config:get_boolean(?KNM_CARRIER_CONFIG_CAT, <<"release_toll_free_numbers_on_disconnect">>, 'false')
       ).
-define(TRUNK
       ,kapps_config:get_ne_binary(?KNM_CARRIER_CONFIG_CAT, <<"trunk">>, 'undefined')
       ).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec info() -> map().
info() ->
    #{?CARRIER_INFO_MAX_PREFIX => 3}.

%%------------------------------------------------------------------------------
%% @doc Is this carrier handling numbers local to the system?
%%
%% <div class="notice">A non-local (foreign) carrier module makes HTTP requests.</div>
%% @end
%%------------------------------------------------------------------------------
-spec is_local() -> boolean().
is_local() -> 'false'.

%%------------------------------------------------------------------------------
%% @doc Check with carrier if these numbers are registered with it.
%% @end
%%------------------------------------------------------------------------------
-spec check_numbers(kz_term:ne_binaries()) ->
          {'error', 'not_implemented'}.
check_numbers(_Numbers) -> {'error', 'not_implemented'}.

%%------------------------------------------------------------------------------
%% @doc Query carrier for available numbers that begin with the prefix.
%% Note, this only supports Toll Free or North American numbers due to
%% inteliquent carrier limitations.
%% @end
%%------------------------------------------------------------------------------
-spec find_numbers(kz_term:ne_binary(), pos_integer(), knm_carriers:options()) ->
          {'ok', knm_search:results()}.
find_numbers(<<"+1", NPA:3/binary, _/binary>>=Number, Quantity, Options)
  when ?IS_US_TOLLFREE(NPA) ->
    <<"+1", Prefix/binary>> = Number,
    Results = search_toll_free_numbers(Prefix, Quantity, Options),
    {'ok', Results};
find_numbers(<<"+1", Prefix/binary>>, Quantity, Options) ->
    Results = search_phone_numbers(Prefix, Quantity, Options),
    {'ok', Results};
find_numbers(<<"+",_/binary>>=InternationalNum, _Quantity, _Options) ->
    lager:error("carrier module only supports north american numbers, can not search for ~p", [InternationalNum]),
    knm_errors:by_carrier(?MODULE, <<"international numbers not supported by carrier">>, InternationalNum).

%%------------------------------------------------------------------------------
%% @doc Acquire a given number from carrier.
%% @end
%%------------------------------------------------------------------------------
-spec acquire_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
acquire_number(KnmNumber) ->
    case knm_inteliquent_util:number(KnmNumber) of
        <<"+1", NPA:3/binary, _/binary>> when ?IS_US_TOLLFREE(NPA) ->
            acquire_toll_free_number(KnmNumber);
        <<"+1", _Number/binary>> ->
            acquire_phone_number(KnmNumber);
        <<"+",_/binary>>=InternationalNum ->
            lager:error("carrier module only supports north american numbers, can not acquire number ~p", [InternationalNum]),
            knm_errors:by_carrier(?MODULE, <<"international numbers not supported by carrier">>, InternationalNum)
    end.

%%------------------------------------------------------------------------------
%% @doc Depending on the config either return number back to carrier or do
%% nothing.
%% @end
%%------------------------------------------------------------------------------
-spec disconnect_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
disconnect_number(KnmNumber) ->
    case knm_inteliquent_util:number(KnmNumber) of
        <<"+1", NPA:3/binary, _/binary>> when ?IS_US_TOLLFREE(NPA) ->
            maybe_disconnect_toll_free_number(KnmNumber);
        <<"+1", _Number/binary>> ->
            maybe_disconnect_phone_number(KnmNumber);
        <<"+",_/binary>>=InternationalNum ->
            lager:error("carrier module only supports north american numbers, can not disconnect number ~p", [InternationalNum]),
            knm_errors:by_carrier(?MODULE, <<"international numbers not supported by carrier">>, InternationalNum)
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec is_number_billable(knm_phone_number:pn_record()) -> boolean().
is_number_billable(_Number) -> 'true'.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec should_lookup_cnam() -> boolean().
should_lookup_cnam() -> 'true'.

%%------------------------------------------------------------------------------
%% @doc Check if the numbers are portable.
%% @end
%%------------------------------------------------------------------------------
-spec check_portability(kz_term:ne_binaries()) -> kz_okko:okko({kz_term:ne_binary(), kz_term:ne_binary()}, {kz_term:ne_binary(), #{}}).
check_portability(Numbers) ->
    %% inteliquent wants numbers normalized different from how kazoo normalizes
    %% them. So, we'll go ahead and do that. But to ensure we provide a valid
    %% response to kazoo, we need to map from the mutilated numbers.
    StrippedToInputMap = build_input_map(Numbers),
    Stripped = maps:keys(StrippedToInputMap),
    InnerMostList = [kz_json:from_list([{<<"tn">>, Number}]) || Number <- Stripped ],
    TnItem = kz_json:from_list([{<<"tnItem">>, InnerMostList}]),
    Payload = kz_json:from_list([{<<"tnList">>, TnItem}]),
    Response = knm_inteliquent_util:safe_request('undefined', [<<"portInAvailability">>], Payload, 'true'),
    %% now we have gotten the data back, we need to run a bunch of sanity checks
    %% and build up the okko.
    %% so first up, did we get a valid json object back?
    ResponseAsMapFun = kz_result:and_then(fun(JObj) ->
                                                  case kz_json:to_map(JObj) of
                                                      Map when is_map(Map) ->
                                                          {'ok', Map};
                                                      _NotMap ->
                                                          {'error', {'malformed_return_body', [], JObj}}
                                                  end
                                          end),
    %% If the inteliquent response says it was a success, is it a success we can
    %% actually understand and map back to a number we were given?
    MappedSuccessFun = kz_result:map(fun(Success) ->
                                             process_check_portability_success(Success,StrippedToInputMap)
                                     end),
    %% If it wasn't a success, we can at least log the error.
    MappedAndLoggedError = kz_result:map_error(fun process_check_portability_error/1),
    Flowed = kz_result:flow(Response
                            ,[ResponseAsMapFun
                             ,MappedSuccessFun
                             ,MappedAndLoggedError
                             ]),
    kz_result:with_default(Flowed, kz_okko:empty_okko()).

%%------------------------------------------------------------------------------
%% @doc inteliquent wants numbers normalized differently from how kazoo normalizes
%% them for many api operations. This does the needful.
%% @end
%%------------------------------------------------------------------------------
-spec kz_number_to_intq(kz_term:ne_binary()) -> kz_term:ne_binary().
kz_number_to_intq(<<"+1", Number/binary>>) ->
    Number;
kz_number_to_intq(<<"+", Number/binary>>) ->
    Number;
kz_number_to_intq(Number) ->
    Number.

%%------------------------------------------------------------------------------
%% @doc Given a list of kazoo formatted numbers, generate a map of the intq
%% formatted numbers pointing to the orginal.
%% @end
%%------------------------------------------------------------------------------
-spec build_input_map(kz_term:ne_binaries()) -> #{ kz_term:ne_binary() := kz_term:ne_binary()}.
build_input_map(KazooNumbers) ->
    lists:foldl(fun build_input_map_accumulator/2, #{}, KazooNumbers).

%%------------------------------------------------------------------------------
%% @doc Does the fold above.
%% @end
%%------------------------------------------------------------------------------
-spec build_input_map_accumulator(kz_term:ne_binary(), #{ kz_term:ne_binary() := kz_term:ne_binary()}) -> #{ kz_term:ne_binary() := kz_term:ne_binary()}.
build_input_map_accumulator(KazooNumber, InputMap) ->
    StrippedNumber = kz_number_to_intq(KazooNumber),
    maps:put(StrippedNumber, KazooNumber, InputMap).

%%------------------------------------------------------------------------------
%% @doc If inteliquent says the operation was successful, in theory we can
%% destructure it and build an okko of those numbers that worked and not.
%% This also filters out numbers that intq is telling us about, but we cant'
%% map back.
%% @end
%%------------------------------------------------------------------------------
-spec process_check_portability_success(map(), #{binary() => binary()}) -> kz_okko:okko({kz_term:ne_binary(), kz_term:ne_binary()}, {kz_term:ne_binary(), #{}}).
process_check_portability_success(Result, InputMap) ->
    AllResultList = maps:get(<<"serviceAvailable">>, Result, []),
    OkkoFoldFun = fun(NumberResult) ->
                          case maps:get(<<"isPortable">>, NumberResult, 'false') of
                              'true' ->
                                  {'ok', NumberResult};
                              'false' ->
                                  {'error', NumberResult}
                          end
                  end,
    BaseOkko = kz_okko:foldl(OkkoFoldFun, AllResultList),
                                                % now make sure the numbers intq gave back to us actaully map back to a
                                                % number we wanted to actually check. Dump those that do not map back.
    ValidNumberMapper = fun(NumberResult) ->
                                IntqNumber = maps:get(<<"telephoneNumber">>, NumberResult, <<>>),
                                case maps:find(IntqNumber, InputMap) of
                                    {'ok', PhoneNumber} ->
                                        {'true', {PhoneNumber, #{}}};
                                    'error' ->
                                        'false'
                                end
                        end,
    BadNumberMapper = fun(NumberResult) ->
                              IntqNumber = maps:get(<<"telephoneNumber">>, NumberResult, <<>>),
                              case maps:find(IntqNumber, InputMap) of
                                  'error' ->
                                      'false';
                                  {'ok', PhoneNumber} ->
                                      Reason = maps:get(<<"notPortableReason">>, NumberResult, <<>>),
                                      {'true', {PhoneNumber, Reason}}
                              end
                      end,
    kz_okko:filtermap_both(BaseOkko, BadNumberMapper, ValidNumberMapper).

%%------------------------------------------------------------------------------
%% @doc For http errors or otherwise, we'll just log them and say we know
%% nothing.
%% @end
%%------------------------------------------------------------------------------
-spec process_check_portability_error(knm_inteliquent_util:safe_return()) -> kz_okko:okko({kz_term:ne_binary(), kz_term:ne_binary()}, {kz_term:ne_binary(), #{}}).
process_check_portability_error(Error) ->
    case Error of
        {'error', {'http_error', 500, _Headers, _Body}}  ->
            lager:error("error from inteliquent's portability check api. This usually means we sent something wrong, so retrying won't work; it's a program bug. Full error: ~p", [Error]);
        {'error', {'http_error', 409, _Headers, _Body}} ->
            lager:error("one or more of the numbers submitted for portability check was invalid. Inteliquent does not accept numbers with the country code prepended, nor numbers of incorrect length. Full error: ~p", [Error]);
        {'error', {'http_error', 401, _Headers, _Body}} ->
            lager:error("authorization error from inteliquent when doing portability check; is the correct api_key and api_secret set? For number porting, we do not have account specific settings. Full error: ~p", [Error]);
        _ ->
            lager:error("error doing portabilty check; I have no advice to give. Full error: ~p", [Error])
    end,
    Error.


%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Search for phone numbers with a number prefix.
%% @end
%%------------------------------------------------------------------------------
-spec search_phone_numbers(kz_term:ne_binary(), pos_integer(), knm_carriers:options()) -> knm_search:results().
search_phone_numbers(Prefix, Quantity, Options) ->
    lager:debug("searching for phone numbers with prefix ~p, limit ~p, options ~p", [Prefix, Quantity, Options]),
    Request = generate_search_request_body(Prefix, Quantity),
    ResponseBodyJObj = knm_inteliquent_util:request('post', ["tnInventory"], Request, Prefix),
    ResponseDataJObjs = kz_json:get_value(<<"tnResult">>, ResponseBodyJObj, []),
    process_search_number_response(ResponseDataJObjs, <<"telephoneNumber">>, Options).

%%------------------------------------------------------------------------------
%% @doc Search for toll free numbers with a number prefix.
%% @end
%%------------------------------------------------------------------------------
-spec search_toll_free_numbers(kz_term:ne_binary(), pos_integer(), knm_carriers:options()) ->
          knm_search:results().
search_toll_free_numbers(Prefix, Quantity, Options) ->
    lager:debug("searching for toll free numbers with prefix ~p, limit ~p, options ~p", [Prefix, Quantity, Options]),
    Request = generate_search_request_body(Prefix, Quantity),
    ResponseBodyJObj = knm_inteliquent_util:request('post', ["tfInventory"], Request, Prefix),
    ResponseDataJObjs = kz_json:get_value([<<"tfList">>, <<"tfItem">>], ResponseBodyJObj, []),
    process_search_number_response(ResponseDataJObjs, <<"tn">>, Options).

%%------------------------------------------------------------------------------
%% @doc Generate the search request body payload.
%% @end
%%------------------------------------------------------------------------------
-spec generate_search_request_body(kz_term:ne_binary(), pos_integer()) -> kz_json:object().
generate_search_request_body(Prefix, Quantity) ->
    NumberWildcard = generate_number_wildcard(Prefix),
    kz_json:from_list([{<<"tnWildcard">>, NumberWildcard}
                      ,{<<"quantity">>, Quantity}
                      ]).

%%------------------------------------------------------------------------------
%% @doc For a given number prefix, return a wildcard that can be used in the
%% number search request `tfWildcard' or `tnWildcard' fields.
%%
%% Ten digit telephone number; end * and % as wildcards. () implies match
%% everything and % implies match that specific digit position.
%% For Example: *233 will match all tns that have 233 in them such as 2345672334
%% as well as 2331231234. Another example would be 233%55 would match 2342337556
%% as well as 7892334559.
%% @end
%%------------------------------------------------------------------------------
-spec generate_number_wildcard(kz_term:ne_binary()) -> kz_term:ne_binary().
generate_number_wildcard(<<_:10/binary>>=FullNumber) -> FullNumber;
generate_number_wildcard(NumberPrefix) -> <<NumberPrefix/binary, "*">>.

%%------------------------------------------------------------------------------
%% @doc Convert the API search response into `knm_phone_number:pn_records()' format.
%% @end
%%------------------------------------------------------------------------------
-spec process_search_number_response(kz_json:objects(), kz_json:get_key(), knm_carriers:options()) ->
          knm_serach:results().
process_search_number_response(NumberDataJObjs, NumberFieldKey, Options) ->
    QueryId = knm_search:query_id(Options),
    lists:map(fun(NumberDataJObj) ->
                      Number = knm_converters:normalize(kz_json:get_value(NumberFieldKey, NumberDataJObj)),
                      {QueryId, {Number, ?MODULE, ?NUMBER_STATE_DISCOVERY, NumberDataJObj}}
              end
             ,NumberDataJObjs
             ).

%%------------------------------------------------------------------------------
%% @doc Order a phone number.
%% @end
%%------------------------------------------------------------------------------
-spec acquire_phone_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
acquire_phone_number(KnmNumber) ->
    Number = knm_inteliquent_util:number(KnmNumber),
    lager:debug("atempting to acquire phone number ~p", [Number]),
    TnItem = generate_tn_item(KnmNumber),
    Request = kz_json:set_value([<<"tnOrder">>, <<"tnList">>, <<"tnItem">>], [TnItem], kz_json:new()),
    ResponseBodyJObj = knm_inteliquent_util:request('post', ["tnOrder"], Request, Number),
    process_acquire_number_response(KnmNumber, ResponseBodyJObj).

%%------------------------------------------------------------------------------
%% @doc Order a toll free number.
%% @end
%%------------------------------------------------------------------------------
-spec acquire_toll_free_number(knm_phone_number:pn_number()) -> knm_phone_number:pn_number().
acquire_toll_free_number(KnmNumber) ->
    Number = knm_inteliquent_util:number(KnmNumber),
    lager:debug("atempting to acquire toll free number ~p", [Number]),
    TnItem = generate_tn_item(KnmNumber),
    RequestSansProductAbbr = kz_json:set_value([<<"tfOrder">>, <<"tnList">>, <<"tnItem">>], [TnItem], kz_json:new()),
    Request = kz_json:set_value(<<"productAbbr">>, <<"8XXAVAIL">>, RequestSansProductAbbr),
    ResponseBodyJObj = knm_inteliquent_util:request('post', ["tfOrder"], Request, Number),
    process_acquire_number_response(KnmNumber, ResponseBodyJObj).

%%------------------------------------------------------------------------------
%% @doc Generate the tnItem part of inteliquent `tnOrder' and `tfOrder' request.
%% @end
%%------------------------------------------------------------------------------
-spec generate_tn_item(knm_phone_number:pn_record()) -> kz_json:object().
generate_tn_item(KnmNumber) ->
    <<"+1", Number/binary>> = knm_inteliquent_util:number(KnmNumber),
    TnItem = kz_json:set_value(<<"tn">>, Number, kz_json:new()),
    Funs = [fun maybe_add_trunk_group/2
           ,fun add_account_info_as_note/2
           ,fun maybe_enable_messaging/2
           ],
    lists:foldl(fun(F, TnItemAcc) -> F(TnItemAcc, KnmNumber) end
               ,TnItem
               ,Funs
               ).

%%------------------------------------------------------------------------------
%% @doc Add the trunk group from the configs.
%% First check if there is a trunk group defined for this node and if not then
%% use the `default' trunk defined.
%% If no trunk group is found then the `TnItem' is returned without a
%% `trunkGroup' set.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_add_trunk_group(kz_json:object()) -> kz_json:object().
maybe_add_trunk_group(TnItem) ->
    case ?TRUNK of
        'undefined' ->
            lager:warning("no trunk found in config, not assigning number to any trunk"),
            TnItem;
        Trunk ->
            lager:debug("inteliquent trunk found in config: ~s", [Trunk]),
            kz_json:set_value(<<"trunkGroup">>, Trunk, TnItem)
    end.

-spec maybe_add_trunk_group(kz_json:object(), knm_phone_number:pn_record()) -> kz_json:object().
maybe_add_trunk_group(TnItem, _KnmNumber) ->
    maybe_add_trunk_group(TnItem).

%%------------------------------------------------------------------------------
%% @doc Add the account info to the order request in the `tnNote' section of the
%% number.
%% @end
%%------------------------------------------------------------------------------
-spec add_account_info_as_note(kz_json:object(), knm_phone_number:pn_record()) -> kz_json:object().
add_account_info_as_note(TnItem, KnmNumber) ->
    {AccountId, AccountName, AccountRealm} = get_account_info_from_number(KnmNumber),
    Note = kz_term:to_binary([AccountName, " - ", AccountId, " - ", AccountRealm]),
    lager:debug("adding note to number: ~p", [Note]),
    kz_json:set_value(<<"tnNote">>, Note, TnItem).

%%------------------------------------------------------------------------------
%% @doc Get the account id, realm and name from a `knmNumber'.
%% If the numbers `assigned_to' is `undefined' then use the numbers
%% `prev_assigned_to' account id.
%% @end
%%------------------------------------------------------------------------------
-spec get_account_info_from_number(knm_phone_number:pn_record()) -> {kz_term:ne_binary(), kz_term:ne_binary(), kz_term:ne_binary()}.
get_account_info_from_number(KnmNumber) ->
    PhoneNumber = knm_phone_number:number(KnmNumber),
    AccountId = case knm_phone_number:assign_to(PhoneNumber) of
                    'undefined' -> knm_phone_number:prev_assigned_to(PhoneNumber);
                    AccId -> AccId
                end,
    lager:debug("AccountId ~p", [AccountId]),
    AccountName = kzd_accounts:fetch_name(AccountId),
    AccountRealm = kzd_accounts:fetch_realm(AccountId),
    {AccountId, AccountName, AccountRealm}.

%%------------------------------------------------------------------------------
%% @doc Depending on the config, choose to add messagingfeatures to the TnItem
%% request body for non toll free numbers.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_enable_messaging(kz_json:object(), knm_phone_number:pn_record()) -> kz_json:object().
maybe_enable_messaging(TnItem, KnmNumber) ->
    case {knm_inteliquent_util:number(KnmNumber), ?ENABLE_MESSAGING_ON_PHONE_NUMBERS} of
        {<<"+1", NPA:3/binary, _/binary>>, _}  when ?IS_US_TOLLFREE(NPA) ->
            TnItem;
        {_Number, 'true'} ->
            lager:debug("enabling messaging services on number ~s", [_Number]),
            kz_json:set_values([{[<<"tnFeature">>, <<"messaging">>, <<"messageType">>], ?MESSAGING_TYPE}
                               ,{[<<"tnFeature">>, <<"messaging">>, <<"messageClass">>], ?MESSAGING_CLASS}
                               ]
                              ,TnItem
                              );
        {_Number, _} ->
            TnItem
    end.

%%------------------------------------------------------------------------------
%% @doc Process the acquire number / order response and add the order_id to the
%% `knm_phone_number:pn_record()' response.
%% @end
%%------------------------------------------------------------------------------
-spec process_acquire_number_response(knm_phone_number:pn_record(), kz_json:object()) -> knm_phone_number:pn_record().
process_acquire_number_response(KnmNumber, ResponseJObj) ->
    OrderId = kz_json:get_value(<<"orderId">>, ResponseJObj),
    OrderData = kz_json:set_value(<<"order_id">>, OrderId, kz_json:new()),
    knm_phone_number:update_carrier_data(KnmNumber, OrderData).

%%------------------------------------------------------------------------------
%% @doc Depending on the config value `?RELEASE_PHONE_NUMBERS_ON_DISCONNECT'
%% either release the phone number back to the carrier or we add a note to the
%% to the number.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_disconnect_phone_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
maybe_disconnect_phone_number(KnmNumber) ->
    <<"+1", _Number/binary>> = knm_inteliquent_util:number(KnmNumber),
    case ?RELEASE_PHONE_NUMBERS_ON_DISCONNECT of
        'true' ->
            lager:debug("releasing phone number ~p to carrier", [_Number]),
            disconnect_number_with_api_path(KnmNumber, ["tnDisconnect"]);
        'false' ->
            lager:debug("not releasing phone number ~p to carrier", [_Number]),
            try_add_disconnect_note(KnmNumber)
    end.

%%------------------------------------------------------------------------------
%% @doc Depending on the config value `?RELEASE_TOLL_FREE_NUMBERS_ON_DISCONNECT'
%% either release the toll free number back to the carrier or do nothing.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_disconnect_toll_free_number(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
maybe_disconnect_toll_free_number(KnmNumber) ->
    <<"+1", _Number/binary>> = knm_inteliquent_util:number(KnmNumber),
    case ?RELEASE_TOLL_FREE_NUMBERS_ON_DISCONNECT of
        'true' ->
            lager:debug("releasing toll free number ~p to carrier", [_Number]),
            disconnect_number_with_api_path(KnmNumber, ["tfDisconnect"]);
        'false' ->
            lager:debug("not releasing toll free number ~p to carrier", [_Number]),
            try_add_disconnect_note(KnmNumber)
    end.

%%------------------------------------------------------------------------------
%% @doc Try and add a note to say its disconnected to the number and catch any
%% errors.
%% @end
%%------------------------------------------------------------------------------
-spec try_add_disconnect_note(knm_phone_number:pn_record()) -> knm_phone_number:pn_record().
try_add_disconnect_note(KnmNumber) ->

    {AccountId, AccountName, AccountRealm} = get_account_info_from_number(KnmNumber),
    Note = kz_term:to_binary(["NUMBER DISCONNECTED IN KAZOO - Previousy assigned to - ", AccountName, " - ", AccountId, " - ", AccountRealm]),
    <<"+1", Number/binary>> = knm_inteliquent_util:number(KnmNumber),
    TnItem = kz_json:set_values([{<<"tn">>, Number}
                                ,{<<"tnNote">>, Note}
                                ], kz_json:new()),
    Request = kz_json:set_value([<<"tnNote">>, <<"tnList">>, <<"tnItem">>], [TnItem], kz_json:new()),
    try knm_inteliquent_util:request('post', ["tnNoteUpdate"], Request, Number) of
        _ ->
            lager:debug("added disconnection note to the number ~p, Note: ~p", [Number, Note]),
            KnmNumber
    catch
        _Throw ->
            lager:error("failed to add a disconnection note to the number ~p, Error: ~p", [Number, _Throw]),
            KnmNumber
    end.

%%------------------------------------------------------------------------------
%% @doc Disconnect / release a number using the API Path for phone numbers
%% (`["tnDisconnect"]') or toll free numbers (`["tfDisconnect"]').
%% @end
%%------------------------------------------------------------------------------
-spec disconnect_number_with_api_path(knm_phone_number:pn_record(), [file:name_all()]) ->
          knm_phone_number:pn_record().
disconnect_number_with_api_path(KnmNumber, ApiPath) ->
    <<"+1", Number/binary>> = knm_inteliquent_util:number(KnmNumber),
    TnItem = kz_json:set_value(<<"tn">>, Number, kz_json:new()),
    Request = kz_json:set_value([<<"tnList">>, <<"tnItem">>], [TnItem], kz_json:new()),
    _ = knm_inteliquent_util:request('post', ApiPath, Request, Number),
    KnmNumber.
