%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_log_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").

%% Just to please coverage :)
log_test_() ->
    ST = try throw('just_for_fun')
         catch
             ?STACKTRACE(_E, _R, Stack)
             Stack
             end,
    [?_assertEqual('ok', kz_log:log_stacktrace(ST))].

put_callid_test_() ->
    ApiCallId = [{<<"Call-ID">>, <<"bla">>}],
    [?_assertEqual(<<"bla">>, begin kz_log:put_callid(<<"bla">>), kz_log:get_callid() end)
    ,?_assertEqual('bla', begin kz_log:put_callid('bla'), kz_log:get_callid() end)
    ,?_assertEqual(<<"bla">>, begin kz_log:put_callid(ApiCallId), kz_log:get_callid() end)
    ,?_assertEqual(<<"bla">>, begin kz_log:put_callid(kz_json:from_list(ApiCallId)), kz_log:get_callid() end)
    ,?_assert(is_integer(begin kz_process:set_startup(), kz_process:startup() end))
    ].

log_redacted_test_() ->
    User = kz_binary:rand_hex(5),
    Pass = kz_binary:rand_hex(5),
    URL = <<"server.tld/some/path">>,

    %% test URL BasicAuth cred stripping
    [?_assertEqual(<<"http://", URL/binary>>, kz_log:redactor(<<"http://", URL/binary>>))
    ,?_assertEqual(<<"https://", URL/binary>>, kz_log:redactor(<<"https://", URL/binary>>))

    ,?_assertEqual(<<"http://", URL/binary>>, kz_log:redactor(<<"http://", User/binary, ":", Pass/binary, "@", URL/binary>>))
    ,?_assertEqual(<<"https://", URL/binary>>, kz_log:redactor(<<"https://", User/binary, ":", Pass/binary, "@", URL/binary>>))

    ,?_assertEqual(<<"amqp://", URL/binary>>, kz_log:redactor(<<"amqp://", User/binary, ":", Pass/binary, "@", URL/binary>>))
    ,?_assertEqual(<<"amqps://", URL/binary>>, kz_log:redactor(<<"amqps://", User/binary, ":", Pass/binary, "@", URL/binary>>))

     %% redact JSON password field
    ,?_assertEqual(<<"{\"password\":\"***REDACTED***\",\"foo\":\"bar\"}">>
                  ,kz_log:redactor(<<"{\"password\":\"", Pass/binary, "\",\"foo\":\"bar\"}">>)
                  )
     %% spaces preserved in JSON
    ,?_assertEqual(<<"{\"password\" : \"***REDACTED***\" , \"foo\" : \"bar\"}">>
                  ,kz_log:redactor(<<"{\"password\" : \"", Pass/binary, "\" , \"foo\" : \"bar\"}">>)
                  )
    ].
