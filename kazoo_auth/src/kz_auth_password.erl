%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc All your password security compliance needs.
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_password).

-export([enforce/3
        ,validate_password/1, validate_password/2
        ]).

-include("kazoo_auth.hrl").

-define(PASS_LEN_REGEX, kz_json:from_list(
                          [{<<"regex">>, <<"^.{10,}$">>}
                          ,{<<"message">>, <<"minimum password length is 10 characters">>}
                          ]
                         )
       ).
-define(PASS_LOW_CASE_REGEX, kz_json:from_list(
                               [{<<"regex">>, <<"[a-z]">>}
                               ,{<<"message">>, <<"at least one lower case character is required">>}
                               ]
                              )
       ).
-define(PASS_UP_CASE_REGEX, kz_json:from_list(
                              [{<<"regex">>, <<"[A-Z]">>}
                              ,{<<"message">>, <<"at least one upper case character is required">>}
                              ]
                             )
       ).
-define(PASS_DIGIT_REGEX, kz_json:from_list(
                            [{<<"regex">>, <<"[0-9]">>}
                            ,{<<"message">>, <<"at least one digit is required">>}
                            ]
                           )
       ).
-define(PASS_SPECIAL_REGEX, kz_json:from_list(
                              [{<<"regex">>, <<"[^a-zA-Z0-9]">>}
                              ,{<<"message">>, <<"at least one special character is required">>}
                              ]
                             )
       ).

-define(DEFAULT_STRENGTH_REGEXES
       ,kz_json:from_list(
          [{<<"minimum_length">>, ?PASS_LEN_REGEX}
          ,{<<"lower_case">>, ?PASS_LOW_CASE_REGEX}
          ,{<<"upper_case">>, ?PASS_UP_CASE_REGEX}
          ,{<<"digit">>, ?PASS_DIGIT_REGEX}
          ,{<<"special">>, ?PASS_SPECIAL_REGEX}
          ]
         )
       ).

-type enforce_resp() :: {'valid', kz_term:ne_binary()} |
                        {'invalid', kz_term:ne_binaries()}.

-export_type([enforce_resp/0]).

-define(MOD_CAT, <<(?CONFIG_CAT)/binary, ".password">>).

-define(SHOULD_ENFORCE_STRENGTH(AccountId)
       ,kz_term:is_true(
          kapps_account_config:get_with_strategy(<<"global_merge">>, AccountId, ?MOD_CAT, <<"should_enforce_strength">>, 'false')
         )
       ).

-define(SHOULD_PREVENT_REUSE(AccountId)
       ,kz_term:is_true(
          kapps_account_config:get_with_strategy(<<"global_merge">>, AccountId, ?MOD_CAT, <<"should_prevent_reuse">>, 'false')
         )
       ).

-define(STRENGTH_REGEXES(AccountId)
       ,kapps_account_config:get_with_strategy(<<"global_merge">>, AccountId, ?MOD_CAT, <<"strength_regexes">>, ?DEFAULT_STRENGTH_REGEXES)
       ).

%%------------------------------------------------------------------------------
%% @doc Enforce password security compliance.
%%
%% This will use account or reseller or system to enforce the desire security
%% level for password.
%% @end
%%------------------------------------------------------------------------------
-spec enforce(AccountId::kz_term:api_ne_binary(), User::kz_json:object(), Password::kz_term:ne_binary()) ->
          enforce_resp().
enforce(AccountId, User, Password) ->
    case maybe_prevent_reuse(User, Password, ?SHOULD_PREVENT_REUSE(AccountId)) of
        {'valid', _} ->
            maybe_enforce(AccountId, Password, ?SHOULD_ENFORCE_STRENGTH(AccountId));
        {'invalid', _}=Invalid ->
            Invalid
    end.

%%------------------------------------------------------------------------------
%% @doc Validate that the password is conforming to configured security level
%% for passwords.
%%
%% This uses system settings.
%% @equiv validate_password('undefined', Password)
%% @end
%%------------------------------------------------------------------------------
-spec validate_password(Password::kz_term:ne_binary()) -> enforce_resp().
validate_password(Password) ->
    validate_password('undefined', Password).

%%------------------------------------------------------------------------------
%% @doc Validate that the password is conforming to configured security level
%% for passwords.
%%
%% This uses account level, reseller or system settings.
%% @end
%%------------------------------------------------------------------------------
-spec validate_password(AccountId::kz_term:api_ne_binary(), Password::kz_term:ne_binary()) -> enforce_resp().
validate_password(AccountId, Password) ->
    Regexes = ?STRENGTH_REGEXES(AccountId),
    case kz_json:foldl(fun do_validate_password/3, {Password, []}, Regexes) of
        {_Password, []} ->
            {'valid', Password};
        {_Password, Errors} ->
            {'invalid', Errors}
    end.

-spec maybe_prevent_reuse(kz_json:object(), kz_term:ne_binary(), boolean()) -> enforce_resp().
maybe_prevent_reuse(_User, Password, 'false') ->
    {'valid', Password};
maybe_prevent_reuse(User, Password, 'true') ->
    Username = kzd_users:username(User),
    {MD5, SHA1} = kzd_module_utils:pass_hashes(Username, Password),
    case kzd_users:md5_auth(User) =:= MD5
        andalso kzd_users:sha1_auth(User) =:= SHA1
    of
        'true' ->
            lager:debug("enforcing password strength: cannot use same password"),
            {'invalid', [<<"cannot use same password">>]};
        'false' ->
            {'valid', Password}
    end.

-spec maybe_enforce(kz_term:api_ne_binary(), kz_term:ne_binary(), boolean()) -> enforce_resp().
maybe_enforce(_AccountId, Password, 'false') ->
    {'valid', Password};
maybe_enforce(AccountId, Password, 'true') ->
    validate_password(AccountId, Password).

-type valid_acc() :: {kz_term:ne_binary(), kz_term:ne_binaries()}.
-spec do_validate_password(kz_term:ne_binary(), kz_json:object(), valid_acc()) -> valid_acc().
do_validate_password(Name, StrengthRegex, {Password, Errors}) ->
    Regex = kz_json:get_ne_binary_value(<<"regex">>, StrengthRegex),
    Message = kz_json:get_ne_binary_value(<<"message">>, StrengthRegex, Name),
    try kz_term:is_ne_binary(Regex)
             andalso re:run(Password, Regex)
    of
        'false' ->
            lager:error("regex for ~s is empty, password validation regex can not be empty", [Name]),
            {Password, [Message | Errors]};
        {'match', _} ->
            {Password, Errors};
        'nomatch' ->
            lager:debug("enforcing password strength: ~s", [Message]),
            {Password, [Message | Errors]}
    catch _E:_T:_ST ->
            lager:error("bad password validation regex, regex(~s): ~p", [Name, Regex]),
            {Password, [Message | Errors]}
    end.
