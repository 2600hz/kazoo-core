%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2017-2025, 2600Hz
%%% @doc Kazoo OTP (one-time password) multi factor authenticator.
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_mfa_otp).

-export([authenticate/2]).

-include("kazoo_auth.hrl").

%%------------------------------------------------------------------------------
%% @doc Takes the configuration and authenticate the `Claims'.
%% First request is always result in a signed signature response. When `Claims'
%% has the Duo response to the sign signature, it will verifies this Duo's response.
%% @end
%%------------------------------------------------------------------------------
-spec authenticate(kz_term:proplist(), kz_json:object()) -> mfa_result().
authenticate(Claims, _JObj) ->
    AccountId = props:get_value(<<"account_id">>, Claims),
    UserId = props:get_value(<<"owner_id">>, Claims),

    authenticate(AccountId, UserId
                ,props:get_ne_binary_value(<<"mfa_resp">>, Claims)
                ).

authenticate(_AccountId, _UserId, 'undefined') ->
    lager:debug("challenging ~s in ~s for OTP key", [_UserId, _AccountId]),
    Resp = [{<<"provider_name">>, <<"otp">>}
           ,{<<"key_type">>, <<"totp">>}
           ],
    {'error', 401, kz_json:from_list(Resp)};
authenticate(AccountId, UserId, TOTP) ->
    TOTPs = tuple_to_list(kz_auth_otp:totp(AccountId, UserId)),
    lager:debug("comparing TOTP ~p against KAZOO codes: ~p", [TOTP, TOTPs]),
    case lists:member(TOTP, TOTPs) of
        'true' -> {'ok', 'authenticated'};
        'false' -> {'error', 'unauthorized'}
    end.
