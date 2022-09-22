-module(kz_privacy_tests).

-include_lib("eunit/include/eunit.hrl").

should_hide_realm_test_() ->
    Test = fun kz_privacy:should_hide_realm/3,

    HideEverythingJObj = kazoo_privacy('enable'),
    KazooMethod = <<"kazoo">>,
    SIPMethod = <<"sip">>,
    HideRealm = 'true',

    [{"If should_hide_number=false, method/=kazoo, and/or should_hide_realm=false, do NOT hide realm"
     ,[{"should_hide_number=false"
       ,?_assertMatch('false', Test(set_should_hide_number(HideEverythingJObj, 'false'), HideRealm, KazooMethod))
       }
      ,{"Method=sip"
       ,?_assertMatch('false', Test(set_method(HideEverythingJObj, <<"sip">>), HideRealm, SIPMethod))
       }
      ,{"should_hide_realm=false"
       ,?_assertMatch('false', Test(HideEverythingJObj, not HideRealm, KazooMethod))
       }
      ]
     }
    ,{"If should_hide_number=true, method=kazoo, and should_hide_realm=true, hide realm"
     ,?_assertMatch('true', Test(HideEverythingJObj, HideRealm, KazooMethod))
     }
    ].


hide_from_uri_test_() ->
    NameSet = {Name, _AName} = {<<"name">>, kz_privacy:anonymous_caller_id_name()},
    NumberSet = {Number, _ANumber} = {<<"number">>, kz_privacy:anonymous_caller_id_number()},
    RealmSet = {Realm, _ARealm} = {<<"realm.test">>, kz_privacy:anonymous_caller_id_realm()},

    BaseFromURI = <<Number/binary, "@", Realm/binary>>,
    FromURIs = [BaseFromURI %% number@realm.test
               ,<<BaseFromURI/binary, ":7000;tag=example">> %% number@realm.test:7000;tag=example
               ,<<"\"", Name/binary, "\" ", BaseFromURI/binary, ":7000;tag=example">> %% "name" number@realm.test:7000;tag=example
               ,<<"\"", Name/binary, "\" <sip:", BaseFromURI/binary, ":7000;tag=example">> %% "name" <sip:number@realm.test:7000;tag=example>
               ,<<"\"", Name/binary, "\" <sip:", BaseFromURI/binary, ":7000>;tag=example">> %% "name" <sip:number@realm.test:7000>;tag=example
               ,<<Name/binary, " <sip:", BaseFromURI/binary, ":7000>;tag=example">> %% name <sip:number@realm.test:7000>;tag=example
               ,<<Name/binary, " <sips:", BaseFromURI/binary, ":7000>;tag=example">> %% name <sip:number@realm.test:7000>;tag=example
               ,<<Name/binary, " <sip:", BaseFromURI/binary, ":7000> ;tag=example">> %% name <sip:number@realm.test:7000> ;tag=example (space between URI and URI parameters)
               ],

    HideName = HideNumber = HideRealm = 'true', %% Improve readability (hopefully)

    %% Everything is disabled but the method.
    HideNothingJObj = set_method(kazoo_privacy('disable'), <<"kazoo">>),
    OnlyHideNumberJObj = set_should_hide_number(HideNothingJObj, HideNumber),

    [{"Hide nothing, return same from-uri"
     ,build_hide_from_uri_tests(FromURIs, HideNothingJObj, [])
     }
    ,{"Only hide name"
     ,build_hide_from_uri_tests(FromURIs, set_should_hide_name(HideNothingJObj, HideName), [NameSet])
     }
    ,{"Only hide number"
     ,build_hide_from_uri_tests(FromURIs, OnlyHideNumberJObj, [NumberSet])
     }
    ,{"Hide realm (and number)" %% Hide number is required for hide realm.
     ,build_hide_from_uri_tests(FromURIs, OnlyHideNumberJObj, [NumberSet, RealmSet], HideRealm)
     }
    ,{"Hide everything"
     ,build_hide_from_uri_tests(FromURIs, kazoo_privacy('enable'), [NameSet, NumberSet, RealmSet], HideRealm)
     }
    ].

-spec build_hide_from_uri_tests(kz_term:ne_binaries(), kz_json:object(), [{kz_term:ne_binary(), kz_term:ne_binary()}]) ->
          [{number(), function()}].
build_hide_from_uri_tests(FromURIs, JObj, ReplacePL) ->
    build_hide_from_uri_tests(FromURIs, JObj, ReplacePL, 'false').

-spec build_hide_from_uri_tests(kz_term:ne_binaries(), kz_json:object(), [{kz_term:ne_binary(), kz_term:ne_binary()}], boolean()) ->
          [{number(), function()}].
build_hide_from_uri_tests(FromURIs, JObj, ReplacePL, ShouldHideRealm) ->
    Test = fun kz_privacy:hide_from_uri/3,
    [?_assertEqual(binary_replace(FURI, ReplacePL),
                   Test(JObj, FURI, [{'should_hide_realm', ShouldHideRealm}, {'method', <<"kazoo">>}]))
     || FURI <- FromURIs].



%% Helpers

-spec kazoo_privacy('enable' | 'disable') -> kz_json:object().
kazoo_privacy(EnableOrDisable) ->
    kazoo_privacy(EnableOrDisable, kz_json:new()).

-spec kazoo_privacy('enable' | 'disable', kz_json:object()) -> kz_json:object().
kazoo_privacy('enable', JObj) ->
    Routines = [{fun set_should_hide_number/2, 'true'}
               ,{fun set_should_hide_name/2, 'true'}
               ,{fun set_method/2, <<"kazoo">>}
               ],
    apply_kazoo_privacy(JObj, Routines);
kazoo_privacy('disable', JObj) ->
    Routines = [{fun set_should_hide_number/2, 'false'}
               ,{fun set_should_hide_name/2, 'false'}
               ,{fun set_method/2, <<"sip">>}
               ],
    apply_kazoo_privacy(JObj, Routines).

-type routine_value() :: boolean() | kz_term:ne_binary().
-spec apply_kazoo_privacy(kz_json:object(), [{fun((kz_json:object(), routine_value()) -> kz_json:object()), routine_value()}]) -> kz_json:object().
apply_kazoo_privacy(JObj, Routines) ->
    kz_doc:setters(JObj, Routines).

-spec set_should_hide_number(kz_json:object(), boolean()) -> kz_json:object().
set_should_hide_number(JObj, ShouldHide) ->
    kz_json:set_value(<<"Privacy-Hide-Number">>, ShouldHide, JObj).

-spec set_should_hide_name(kz_json:object(), boolean()) -> kz_json:object().
set_should_hide_name(JObj, ShouldHide) ->
    kz_json:set_value(<<"Privacy-Hide-Name">>, ShouldHide, JObj).

%% `Method=none' is only expected to be set by stepswitch_bridge when call is to an emergency number.
%% Method: <<"sip">> | <<"none">> | <<"kazoo">>
-spec set_method(kz_json:object(), kz_term:ne_binary()) -> kz_json:object().
set_method(JObj, Method) ->
    kz_json:set_value(<<"Privacy-Method">>, Method, JObj).

-spec binary_replace(kz_term:ne_binary(), kz_term:proplist()) -> kz_term:ne_binary().
binary_replace(Subject, Replacements) ->
    lists:foldl(fun({Pat, Rep}, Sub) -> binary:replace(Sub, Pat, Rep) end, Subject, Replacements).
