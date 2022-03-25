%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2022-, Ooma Inc
%%% @doc Handle e911 provisioning using Inteliquent
%%%
%%% @author Micah Warren
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_inteliquent_e911).
-behaviour(knm_gen_provider).

-export([save/1
        ,delete/1
        ]).

-include("knm.hrl").

-define(MOD_CONFIG_CAT, <<(?KNM_CONFIG_CAT)/binary, ".inteliquent">>).
-define(AUTO_PROVISION(AccountId), kapps_account_config:get_global(AccountId, ?MOD_CONFIG_CAT, <<"auto_provision_e911">>, 'false')).


%%------------------------------------------------------------------------------
%% @doc This function is called each time a number is saved, and will
%% provision e911 or remove the number depending on the state
%% @end
%%------------------------------------------------------------------------------
-spec save(knm_number:knm_number()) -> knm_number:knm_number().
save(Number) ->
    State = knm_phone_number:state(knm_number:phone_number(Number)),
    save(Number, State).

-spec save(knm_number:knm_number(), kz_term:ne_binary()) -> knm_number:knm_number().
save(Number, ?NUMBER_STATE_RESERVED) ->
    maybe_update_e911(Number);
save(Number, ?NUMBER_STATE_IN_SERVICE) ->
    maybe_update_e911(Number);
save(Number, ?NUMBER_STATE_PORT_IN) ->
    maybe_update_e911(Number);
save(Number, _State) ->
    delete(Number).

%%------------------------------------------------------------------------------
%% @doc This function is called each time a number is deleted, and will
%% provision e911 or remove the number depending on the state
%% @end
%%------------------------------------------------------------------------------
-spec delete(knm_number:knm_number()) -> knm_number:knm_number().
delete(Number) ->
    HasFeature = has_e911_feature(Number),
    Flow = [kz_result:map(fun(_) -> Number end)
           ,kz_result:and_then(fun remove_number/1)
           ,kz_result:map(fun(NewNumber) -> knm_providers:deactivate_feature(NewNumber, ?FEATURE_E911) end)
           ],
    Result = kz_result:flow(HasFeature, Flow),
    case Result of
        {'error', 'no_e911_feature'} ->
            Number;
        {'error', E} ->
            lager:error("information delete failed: ~p", [E]),
            dispatch_error(E, Number)
    end.


%%------------------------------------------------------------------------------
%% @doc Do we have the e911 feature on this number?
%% @end
%%------------------------------------------------------------------------------
-spec has_e911_feature(knm_number:knm_number()) -> kz_result:result('no_e911_feature', kz_json:object()).
has_e911_feature(Number) ->
    PhoneNumber = knm_number:phone_number(Number),
    HasFeature = knm_phone_number:feature(PhoneNumber, ?FEATURE_E911),
    kz_result:from_maybe('no_e911_feature', HasFeature).


%%------------------------------------------------------------------------------
%% @doc Attempt to update e911 information remotely.
%% @end
%%------------------------------------------------------------------------------
-spec maybe_update_e911(knm_number:knm_number()) -> knm_number:knm_number().
maybe_update_e911(Number) ->
    PhoneNumber = knm_number:phone_number(Number),
    RunMode = case knm_phone_number:dry_run(PhoneNumber) of
                  'true' ->
                      'dry_run';
                  'false' ->
                      'wet_run'
              end,
    CurrentE911 = has_e911_feature(Number),
    E911 = kz_json:get_ne_value(?FEATURE_E911, knm_phone_number:doc(knm_number:phone_number(Number))),
    IsUnchanged = case {CurrentE911, E911} of
                      {{'error', 'no_e911_feature'}, 'undefined'} -> 'true';
                      {{'error', 'no_e911_feature'}, _} -> 'false';
                      {{'ok', _CurrentJson}, 'undefined'} -> 'false';
                      {{'ok', CurrentJson}, E911} -> kz_json:are_equal(CurrentJson, E911)
                  end,
    Changed = case IsUnchanged of
                  'true' -> 'unchanged';
                  'false' -> 'updated'
              end,
    NewAsMaybe = empty_json_as_maybe(E911),
    maybe_update_e911(Number, RunMode, Changed, NewAsMaybe).

%%------------------------------------------------------------------------------
%% @doc The meaty potatos of above.
%% @end.
%%------------------------------------------------------------------------------
-spec maybe_update_e911(knm_number:knm_number(), 'wet_run' | 'dry_run', 'unchanged' | 'updated', 'undefined' | kz_json:json_object()) -> knm_number:knm_number().
maybe_update_e911(Number, 'dry_run', _Changed, 'undefined') ->
    lager:debug("dry run: information has been removed, updating upstream"),
    knm_providers:deactivate_feature(Number, ?FEATURE_E911);
maybe_update_e911(Number, 'dry_run', 'unchanged', _) ->
    Number;
maybe_update_e911(Number, 'dry_run', 'updated', E911) ->
    lager:debug("dry run: information has beenchanged: ~s", [kz_json:encode(E911)]),
    knm_providers:activate_feature(Number, {?FEATURE_E911, E911});
maybe_update_e911(Number, 'wet_run', _Changed, 'undefined') ->
    lager:debug("information has been removed, updating upstream"),
    case remove_number(Number) of
        'ok' ->
            knm_providers:deactivate_feature(Number, ?FEATURE_E911);
        {'error', E} ->
            lager:error("information delete failed: ~p", [E]),
            dispatch_error(E, Number)
    end;
maybe_update_e911(Number, 'wet_run', 'unchanged', _) ->
    Number;
maybe_update_e911(Number, 'wet_run', 'updated', E911) ->
    lager:debug("information has been changed: ~s", [kz_json:encode(E911)]),
    case update_e911(Number, E911) of
        'ok' ->
            knm_providers:activate_feature(Number, {?FEATURE_E911, E911});
        {'error', E} ->
            lager:error("information update failed: ~p", [E]),
            dispatch_error(E, Number)
    end.

%%------------------------------------------------------------------------------
%% @doc On an error, create the expected error and throw it.
%% @end.
%%------------------------------------------------------------------------------
-spec dispatch_error(any(), kz_term:ne_binary()) -> no_return().
dispatch_error({http_error, 401, _Headers, _Body}, Number) ->
    knm_errors:by_carrier(?MODULE, 'unauthorized', Number);
dispatch_error({http_error, _SomeCode, _Headers, _Body}, Number) ->
    knm_errors:unspecified('provider_failed', Number);
dispatch_error({'unsupported_classification' = Reason, _}, Number) ->
    knm_errors:invalid(Number, Reason);
dispatch_error('invalid_submission' = Reason, Number) ->
    knm_errors:invalid(Number, Reason);
dispatch_error('malformed_return_body' = Reason, Number) ->
    knm_errors:by_carrier(?MODULE, Reason, Number);
dispatch_error(Other, Number) ->
    Iolist = io_lib:format("~p", [Other]),
    knm_errors:unspecified(iolist_to_binary(Iolist), Number).

%%------------------------------------------------------------------------------
%% @doc Transforms a potentially "empty" json into either `undefined' or the
%% value itself if it is not "empty".
%% @end
%%------------------------------------------------------------------------------
-spec empty_json_as_maybe(kz_json:object()) -> 'undefined' | kz_json:object().
empty_json_as_maybe(JObj) ->
    FilterEmptyValues = fun({_, V}) ->
                                not kz_term:is_empty(V)
                        end,
    FilteredJObj = kz_json:filter(FilterEmptyValues, JObj),
    case kz_json:is_empty(FilteredJObj) of
        'true' ->
            'undefined';
        'false' ->
            FilteredJObj
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec update_e911(knm_number:number(), kz_json:json()) -> 'ok' | {'error', term()}.
update_e911(Number, E911) ->
    PhoneNumber = knm_number:phone_number(Number),
    Did = knm_phone_number:number(PhoneNumber),
    case supported_classification(Did) of
        'false' -> {'error', {'unsupported_classification', Did}};
        'true' -> update_e911(PhoneNumber, E911, knm_converters:to_npan(Did))
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec update_e911(knm_phone_number:knm_phone_number(), kz_json:object(), kz_type:ne_binary()) -> 'ok' | {'error', term()}.
update_e911(PhoneNumber, E911, Npan) ->
    AccountId = knm_phone_number:assign_to(PhoneNumber),
    AutoProvision = ?AUTO_PROVISION(AccountId),
    do_update_e911(E911, AccountId, Npan, AutoProvision).


%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec do_update_e911(kz_json:object(), kz_term:ne_binary(), kz_term:ne_binary(), boolean()) -> 'ok' | {'error', term()}.
do_update_e911(E911, AccountId, Npan, AutoProvision) ->
    Properties = [{<<"tn">>, Npan} | address_fields(E911)],
    Json = kz_json:from_list(Properties),
    case knm_inteliquent_util:safe_request(AccountId, [<<"tnE911">>], Json, 'true') of
        {'ok', RespData} -> handle_update_resp(RespData);
        {'error', {'http_error', 400, _, RespData}} ->
            lager:error("unable to update e911, got a 400 back.~n    Resquest body: ~p~n    Response body: ~p", [Json, RespData]),
            {'error', 'invalid_submission'};
        {'error', {'http_error', 409, _, RespData}} ->
            lager:error("unable to update e911 due to invalid address.~n  Request body: ~p~n    Response body: ~p", [Json, RespData]),
            {'error', 'invalid_submission'};
        {'error', {'http_error', 414, _RespHeaders, {<<"e911 not activated for customer">>, _}}} when AutoProvision ->
            provision(E911, AccountId, Npan);
        {'error', {'malformed_return_body', _RespHeaders, RespData}} ->
            lager:error("not certain if worked; response from inqt was not valid json.~n  Request body: ~p~n    Response body: ~p", [Json, RespData]),
            {'error', 'malformed_return_body'};
        {'error', {'http_error', Code, RespHeaders, RespData}} = Error ->
            lager:error("unable to update e911.~n  Request Body: ~p~n  Response Code: ~p~n  ResponseHeaders: ~p~n  Response Body: ~p", [Json, Code, RespHeaders, RespData]),
            Error;
        {'error', _} = Error ->
            Error
    end.

provision(E911, AccountId, Npan) ->
    RawAddressFields = provision_fields(E911),
    E911Json = kz_json:from_list(RawAddressFields),
    TnFeature = kz_json:from_list([{<<"e911">>, E911Json}]),
    TnItem = kz_json:from_list([{<<"tn">>, Npan}, {<<"tnFeature">>, TnFeature}]),
    TnItems = kz_json:from_list([{<<"tnItem">>, [ TnItem ]}]),
    FeatureOrder = kz_json:from_list([{<<"tnList">>, TnItems}]),
    Json = kz_json:from_list([{<<"tnFeatureOrder">>, FeatureOrder}]),
    case knm_inteliquent_util:safe_request(AccountId, [<<"tnFeatureOrder">>], Json, 'true') of
        {'ok', _RespData} ->
            do_update_e911(E911, AccountId, Npan, 'false');
        {'error', {'http_error', 400, _, RespData}} ->
            lager:error("unable to provision e911, got a 400 back.~n    Resquest body: ~p~n    Response body: ~p", [Json, RespData]),
            {'error', 'invalid_submission'};
        {'error', {'http_error', 409, _, RespData}} ->
            lager:error("unable to provision e911 due to invalid address.~n  Request body: ~p~n    Response body: ~p", [Json, RespData]),
            {'error', 'invalid_submission'};
        {'error', {'malformed_return_body', _RespHeaders, RespData}} ->
            lager:error("not certain if worked; response from inqt was not valid json.~n  Request body: ~p~n    Response body: ~p", [Json, RespData]),
            {'error', 'malformed_return_body'};
        {'error', {'http_error', 426, _RespHeaders, {<<"Account not 911-enabled, remove e911 from request.">>, _}}} ->
            lager:info("provider says the account (on their side) is not allowed to set e911 information."),
            {'error', 'service_restriction'};
        {'error', {'http_error', Code, RespHeaders, RespData}} = Error ->
            lager:error("unable to provision e911.~n  Request Body: ~p~n  Response Code: ~p~n  ResponseHeaders: ~p~n  Response Body: ~p", [Json, Code, RespHeaders, RespData]),
            Error;
        {'error', _} = Error ->
            Error
    end.

provision_fields(E911) ->
    Name = kz_json:get_binary_value(<<"customer_name">>, E911, 'undefined'),
    StreetAddress = kz_json:get_binary_value(<<"street_address">>, E911, <<>>),
    {StreetNum, StreetName} = address_parts(StreetAddress),
    Location = kz_json:get_binary_value(<<"extended_adresss">>, E911, 'undefined'),
    City = kz_json:get_binary_value(<<"locality">>, E911, 'undefined'),
    StateName = kz_json:get_binary_value(<<"region">>, E911, 'undefined'),
    State = get_state_province_abbreviation(StateName),
    PostalCode = kz_json:get_binary_value(<<"postal_code">>, E911, 'undefined'),
    UnfilteredProps =
        [{<<"name">>, Name}
        ,{<<"origStreetNum">>, StreetNum}
        ,{<<"origStreetInfo">>, StreetName}
        ,{<<"origLocation">>, Location}
        ,{<<"origCity">>, City}
        ,{<<"origState">>, State}
        ,{<<"origPostalCode">>, PostalCode}
        ,{<<"removeTnFeature">>, <<"N">>}
        ],
    props:filter_undefined(UnfilteredProps).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_update_resp(term()) -> 'ok'.
handle_update_resp(_ResponseData) ->
    lager:debug("TODO sync up kazoo address data with intq address data, as inqt may have changed some things"),
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Removes the e911 information from the given number.
%% @end
%%------------------------------------------------------------------------------
-spec remove_number(knm_number:number()) -> 'ok' | {'error', term()}.
remove_number(Number) ->
    PhoneNumber = knm_number:phone_number(Number),
    Did = knm_phone_number:number(PhoneNumber),
    Npan = knm_converters:to_npan(Did),
    AccountId = knm_phone_number:assigned_to(PhoneNumber),
    Properties = [{<<"tn">>, Npan} ,{<<"removeE911">>, <<"Y">>} ],
    Json = kz_json:from_list(Properties),
    case knm_inteliquent_util:safe_request(AccountId, [<<"tnE911">>], Json, 'true') of
        {'ok', _} ->
            'ok';
        {'error', {'malformed_return_body', _, Body}} ->
            lager:error("unable to determine if e911 has been removed as return from inqt was not parsable: ~p", [Body]),
            {'error', 'malformed_return_body'};
        {'error', {'http_error', Code, _RespHeaders, RespBody}} = Error ->
            lager:error("unable to remove e911 from ~p.  Request Body: ~p~n  Response Code: ~p~n  Response Body: ~p", [Json, Code, RespBody]),
            Error;
        {'error', _} = Error ->
            Error
    end.

%%------------------------------------------------------------------------------
%% @doc Turn the e911 json into a proplist appropriate for inteliquent
%% consumption.
%% @end
%%------------------------------------------------------------------------------
-spec address_fields(kz_json:object()) -> proplist:proplist().
address_fields(E911) ->
    Name = kz_json:get_binary_value(<<"customer_name">>, E911, 'undefined'),
    StreetAddress = kz_json:get_binary_value(<<"street_address">>, E911, <<>>),
    {StreetNum, StreetName} = address_parts(StreetAddress),
    Location = kz_json:get_binary_value(<<"extended_adresss">>, E911, 'undefined'),
    City = kz_json:get_binary_value(<<"locality">>, E911, 'undefined'),
    StateName = kz_json:get_binary_value(<<"region">>, E911, 'undefined'),
    State = get_state_province_abbreviation(StateName),
    PostalCode = kz_json:get_binary_value(<<"postal_code">>, E911, 'undefined'),
    UnfilteredProps =
        [{<<"name">>, Name}
        ,{<<"streetNum">>, StreetNum}
        ,{<<"streetInfo">>, StreetName}
        ,{<<"location">>, Location}
        ,{<<"city">>, City}
        ,{<<"state">>, State}
        ,{<<"postalCode">>, PostalCode}
        ,{<<"removeE911">>, <<"N">>}
        ],
    props:filter_undefined(UnfilteredProps).

%%------------------------------------------------------------------------------
%% @doc Spit a street address into the street number and name.
%% @end
%%------------------------------------------------------------------------------
-spec address_parts(binary()) -> {binary(), binary()}.
address_parts(Address) ->
    case binary:split(Address, <<" ">>) of
        [Address1] -> {<<>>, Address1};
        [StreetNum, StreetName] ->
            try kz_term:to_integer(StreetNum) of
                _ -> {StreetNum, StreetName}
            catch
                error:badarg -> {<<>>, Address}
            end
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec get_state_province_abbreviation(kz_term:ne_binary()) -> kz_term:ne_binary().
get_state_province_abbreviation(StateOrProvince) ->
    Countries = [<<"usa">>, <<"canada">>],
    case kz_region_names:to_short_code(Countries, StateOrProvince) of
        {'ok', ShortCode} ->
            ShortCode;
        {'error', 'not_found'} ->
            knm_errors:invalid('undefined', <<"invalid state or province">>)
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec supported_classification(kz_term:ne_binary()) -> boolean().
supported_classification(DID) ->
    case knm_converters:classify(DID) of
        <<"did_us">> -> 'true';
        <<"tollfree_us">> -> 'true';
        Classification ->
            lager:error("unsupported number classification ~s (only North American numbers are supported by acrovoice)", [Classification]),
            'false'
    end.
