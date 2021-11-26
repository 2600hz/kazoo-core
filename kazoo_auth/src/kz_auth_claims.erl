%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_claims).

-export([id/1]).

-export([account_id/1
        ,owner_id/1
        ,meta_id/1
        ,identity_sig/1
        ]).

%% RFC7519
-export([iss/1, sub/1 ,aud/1
        ,exp/1, nbf/1, iat/1
        ,jti/1
        ]).

-type claims() :: kz_json:object().
-export_type([claims/0]).

-spec id(claims()) -> kz_term:ne_binary().
id(Endpoint) ->
    kz_json:get_ne_binary_value(<<"id">>, Endpoint).

-spec account_id(claims()) -> kz_term:ne_binary().
account_id(Claims) ->
    kz_json:get_ne_binary_value([<<"account_id">>], Claims).

-spec owner_id(claims()) -> kz_term:api_ne_binary().
owner_id(Claims) ->
    kz_json:get_ne_binary_value([<<"owner_id">>], Claims).

-spec meta_id(claims()) -> kz_term:api_ne_binary().
meta_id(Claims) ->
    kz_json:get_ne_binary_value([<<"SIP-Info">>, <<"Endpoint-Meta-ID">>], Claims).

-spec identity_sig(claims()) -> kz_term:api_ne_binary().
identity_sig(Claims) ->
    kz_json:get_ne_binary_value(<<"identity_sig">>, Claims).


%% 4.1.1.  "iss" (Issuer) Claim
%%
%%    The "iss" (issuer) claim identifies the principal that issued the
%%    JWT.  The processing of this claim is generally application specific.
%%    The "iss" value is a case-sensitive string containing a StringOrURI
%%    value.  Use of this claim is OPTIONAL.
-spec iss(claims()) -> kz_term:api_ne_binary().
iss(Claims) ->
    kz_json:get_ne_binary_value(<<"iss">>, Claims).

%% 4.1.2.  "sub" (Subject) Claim
%%
%%    The "sub" (subject) claim identifies the principal that is the
%%    subject of the JWT.  The claims in a JWT are normally statements
%%    about the subject.  The subject value MUST either be scoped to be
%%    locally unique in the context of the issuer or be globally unique.
%%    The processing of this claim is generally application specific.  The
%%    "sub" value is a case-sensitive string containing a StringOrURI
%%    value.  Use of this claim is OPTIONAL.
-spec sub(claims()) -> kz_term:api_ne_binary().
sub(Claims) ->
    kz_json:get_ne_binary_value(<<"sub">>, Claims).

%% 4.1.3.  "aud" (Audience) Claim
%%
%%    The "aud" (audience) claim identifies the recipients that the JWT is
%%    intended for.  Each principal intended to process the JWT MUST
%%    identify itself with a value in the audience claim.  If the principal
%%    processing the claim does not identify itself with a value in the
%%    "aud" claim when this claim is present, then the JWT MUST be
%%    rejected.  In the general case, the "aud" value is an array of case-
%%    sensitive strings, each containing a StringOrURI value.  In the
%%    special case when the JWT has one audience, the "aud" value MAY be a
%%    single case-sensitive string containing a StringOrURI value.  The
%%    interpretation of audience values is generally application specific.
%%    Use of this claim is OPTIONAL.
-spec aud(claims()) -> kz_term:api_ne_binary().
aud(Claims) ->
    kz_json:get_ne_binary_value(<<"aud">>, Claims).

%% 4.1.4.  "exp" (Expiration Time) Claim
%%
%%    The "exp" (expiration time) claim identifies the expiration time on
%%    or after which the JWT MUST NOT be accepted for processing.  The
%%    processing of the "exp" claim requires that the current date/time
%%    MUST be before the expiration date/time listed in the "exp" claim.
%%    Implementers MAY provide for some small leeway, usually no more than
%%    a few minutes, to account for clock skew.  Its value MUST be a number
%%    containing a NumericDate value.  Use of this claim is OPTIONAL.
-spec exp(claims()) -> kz_term:api_number().
exp(Claims) ->
    kz_json:get_number_value(<<"exp">>, Claims).

%% 4.1.5.  "nbf" (Not Before) Claim
%%
%%    The "nbf" (not before) claim identifies the time before which the JWT
%%    MUST NOT be accepted for processing.  The processing of the "nbf"
%%    claim requires that the current date/time MUST be after or equal to
%%    the not-before date/time listed in the "nbf" claim.  Implementers MAY
%%    provide for some small leeway, usually no more than a few minutes, to
%%    account for clock skew.  Its value MUST be a number containing a
%%    NumericDate value.  Use of this claim is OPTIONAL.
-spec nbf(claims()) -> kz_term:api_number().
nbf(Claims) ->
    kz_json:get_number_value(<<"nbf">>, Claims).


%% 4.1.6.  "iat" (Issued At) Claim
%%
%%    The "iat" (issued at) claim identifies the time at which the JWT was
%%    issued.  This claim can be used to determine the age of the JWT.  Its
%%    value MUST be a number containing a NumericDate value.  Use of this
%%    claim is OPTIONAL.
-spec iat(claims()) -> kz_term:api_number().
iat(Claims) ->
    kz_json:get_number_value(<<"iat">>, Claims).

%% 4.1.7.  "jti" (JWT ID) Claim
%%
%%    The "jti" (JWT ID) claim provides a unique identifier for the JWT.
%%    The identifier value MUST be assigned in a manner that ensures that
%%    there is a negligible probability that the same value will be
%%    accidentally assigned to a different data object; if the application
%%    uses multiple issuers, collisions MUST be prevented among values
%%    produced by different issuers as well.  The "jti" claim can be used
%%    to prevent the JWT from being replayed.  The "jti" value is a case-
%%    sensitive string.  Use of this claim is OPTIONAL.
-spec jti(claims()) -> kz_term:api_ne_binary().
jti(Claims) ->
    kz_json:get_ne_binary_value(<<"jti">>, Claims).
