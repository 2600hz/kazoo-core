%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2024, 2600Hz
%%% @doc Tests for `kapps_config_util' functions
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @author Daniel Finke <danielfinke2011@gmail.com>
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_config_util_tests).

-include_lib("eunit/include/eunit.hrl").

%%%=============================================================================
%%% Eunit Tests
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Test fetching of schemas.
%% @end
%%------------------------------------------------------------------------------
fetch_schema_test_() ->
    {'setup'
    ,fun setup/0
    ,fun cleanup/1
    ,fun(_) -> [fetch_schema_found_tests(), fetch_schema_not_found_tests()] end
    }.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Test fetching of schemas that are known.
%% @end
%%------------------------------------------------------------------------------
fetch_schema_found_tests() ->
    Config = <<"default">>,
    Schema = kz_json:new(),
    meck:expect('kz_json_schema', 'load', fun(_) -> {'ok', Schema} end),

    SystemSchema = kapps_config_util:system_schema(Config),
    AccountSchema = kapps_config_util:account_schema(Config),

    [?_assertEqual(Schema, SystemSchema)
    ,?_assertEqual(Schema, AccountSchema)
    ].

%%------------------------------------------------------------------------------
%% @doc Test fetching of schemas that are not known.
%% @end
%%------------------------------------------------------------------------------
fetch_schema_not_found_tests() ->
    SystemConfig = <<"system">>,
    AccountConfig = <<"account">>,
    AccountConfigWithoutMatchingSystemConfig = <<"account-nomatch">>,
    AccountFallbackSystemSchemaName = kapps_config_util:system_schema_name(AccountConfig),
    Schema = kz_json:new(),
    meck:expect('kz_json_schema'
               ,'load'
               ,fun(SchemaName) ->
                        case SchemaName of
                            AccountFallbackSystemSchemaName -> {'ok', Schema};
                            _ -> {'error', 'not_found'}
                        end
                end
               ),

    SystemSchema = kapps_config_util:system_schema(SystemConfig),
    AccountSchema = kapps_config_util:account_schema(AccountConfig),
    AccountSchemaNoMatch = kapps_config_util:account_schema(AccountConfigWithoutMatchingSystemConfig),

    [?_assertNot(kz_json:is_defined(<<"additionalProperties">>, SystemSchema))
    ,?_assert(kz_json:is_false(<<"additionalProperties">>, AccountSchema))
    ,?_assert(kz_json:is_true(<<"additionalProperties">>, AccountSchemaNoMatch))
    ].

%%------------------------------------------------------------------------------
%% @doc Common test setup.
%% @end
%%------------------------------------------------------------------------------
setup() ->
    meck:new('kz_json_schema').

%%------------------------------------------------------------------------------
%% @doc Common test cleanup.
%% @end
%%------------------------------------------------------------------------------
cleanup(_) ->
    meck:unload().
