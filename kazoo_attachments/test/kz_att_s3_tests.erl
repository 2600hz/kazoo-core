%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2023, 2600Hz
%%% @doc S3 attachment handler tests
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%% @author Daniel Finke <danielfinke2011@gmail.com>
%%%-----------------------------------------------------------------------------
-module(kz_att_s3_tests).

-include_lib("eunit/include/eunit.hrl").

%%%=============================================================================
%%% Eunit Tests
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Test fetching attachments.
%% @end
%%------------------------------------------------------------------------------
fetch_attachment_test_() ->
    Content = <<>>,
    Headers = [{'content', Content}],

    {'setup'
    ,fun setup/0
    ,fun cleanup/1
    ,[fun() ->
              allow_metadata_credentials('true'),
              meck:expect('erlcloud_s3', 'get_object', fun(_, _, _, _) -> Headers end),

              RetrievalMap = #{bucket => "bucket"},
              RetrievalKey = base64:encode(term_to_binary({RetrievalMap, <<>>})),
              HandlerProps = kz_json:from_list([{<<"S3">>, RetrievalKey}]),
              Resp = kz_att_s3:fetch_attachment(HandlerProps, <<>>, <<>>, <<>>),

              ?assertEqual(Resp, {'ok', Content})
      end
     ]
    }.

%%------------------------------------------------------------------------------
%% @doc Test putting attachments depending on whether metadata credentials are
%% allowed and credentials are manually added.
%% @end
%%------------------------------------------------------------------------------
metadata_credentials_test_() ->
    BaseSettings = #{bucket => "bucket"},
    Headers = ['header'],

    MockPutObject = fun() ->
                            meck:expect('erlcloud_s3'
                                       ,'put_object'
                                       ,fun(_, _, _, _, _, _) -> Headers end
                                       )
                    end,

    {'setup'
    ,fun setup/0
    ,fun cleanup/1
    ,[fun() ->
              allow_metadata_credentials('false'),
              MockPutObject(),

              Resp = kz_att_s3:put_attachment(
                       BaseSettings#{key => <<>>, secret => <<>>}, <<>>, <<>>, <<>>, <<>>, []
                      ),

              ?assertMatch({'ok', [{'attachment', _}
                                  ,{'headers', Headers}
                                  ]}, Resp)
      end
     ,fun() ->
              allow_metadata_credentials('true'),
              MockPutObject(),

              Resp = kz_att_s3:put_attachment(BaseSettings, <<>>, <<>>, <<>>, <<>>, []),

              ?assertMatch({'ok', [{'attachment', _}
                                  ,{'headers', Headers}
                                  ]}, Resp)
      end
     ,fun() ->
              allow_metadata_credentials('false'),
              meck:expect('kz_att_error', 'new', fun(Reason, _) -> {'error', Reason} end),

              Resp = kz_att_s3:put_attachment(BaseSettings, <<>>, <<>>, <<>>, <<>>, []),

              ?assertEqual({'error', <<"Forbidden">>}, Resp)
      end
     ]
    }.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Common test setup.
%% @end
%%------------------------------------------------------------------------------
setup() ->
    meck:new('erlcloud_s3'),

    meck:new('kz_att_error'),
    meck:expect('kz_att_error', 'fetch_routines', fun(_, _, _, _) -> [] end),
    meck:expect('kz_att_error', 'put_routines', fun(_, _, _, _, _, _) -> [] end),

    meck:new('kz_att_util'),
    meck:expect('kz_att_util', 'format_url', fun(_, _, _) -> <<>> end),

    meck:new('kapps_config').

%%------------------------------------------------------------------------------
%% @doc Common test cleanup.
%% @end
%%------------------------------------------------------------------------------
cleanup(_) ->
    meck:unload().

%%------------------------------------------------------------------------------
%% @doc Mock allowing metadata credentials.
%% @end
%%------------------------------------------------------------------------------
allow_metadata_credentials(Allow) ->
    meck:expect('kapps_config'
               ,'get_boolean'
               ,fun(_, <<"allow_metadata_credentials">>, _) -> Allow end
               ).
