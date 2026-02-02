%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2015-2026, 2600Hz
%%% @doc HTTP helper functions for Kazoo
%%% @author Mark Magnusson
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_http_util).

-export([urldecode/1, urldecode/2
        ,urlencode/1, urlencode/2
        ,uri/2, resolve_uri/2
        ,parse_query_string/1
        ,parse_query_arrays/1, parse_query_arrays/2
        ,urlsplit/1
        ,urlunsplit/1
        ,location_host/1, location_port/1, location_username/1, location_password/1
        ,json_to_querystring/1, json_to_querystring/2
        ,props_to_querystring/1, props_to_querystring/2
        ,http_code_to_status_line/1
        ,get_resp_header/2, get_resp_header/3
        ,encode_multipart/1, encode_multipart/2
        ,create_boundary/0

        ,client_ip_blacklist/0, set_client_ip_blacklist/1
        ,client_host_blacklist/0, set_client_host_blacklist/1
        ,client_port_blacklist/0, set_client_port_blacklist/1
        ]).

-ifdef(TEST).
-export([resolve_uri_path/2]).
-endif.

-include_lib("kazoo_stdlib/include/kazoo_json.hrl").
-include("kz_web.hrl").

-type split_url() :: {scheme(), location(), resource_path(), querystring(), fragment()}.

-export_type([scheme/0
             ,location/0
             ,resource_path/0
             ,querystring/0
             ,fragment/0
             ,split_url/0
             ]).

-define(INVALID_HOSTS, kapps_config:get(?APP_NAME
                                       ,[<<"client">>, <<"blacklist">>, <<"hosts">>]
                                       ,[<<"localhost">>, <<"localhost.localdomain">>]
                                       )).
-define(SET_INVALID_HOSTS(Hosts), kapps_config:set_default(?APP_NAME
                                                          ,[<<"client">>, <<"blacklist">>, <<"hosts">>]
                                                          ,Hosts
                                                          )).

-define(INVALID_NETWORK_CIDRS, kapps_config:get(?APP_NAME
                                               ,[<<"client">>, <<"blacklist">>, <<"cidrs">>]
                                               ,[<<"127.0.0.1/32">>
                                                ,<<"0.0.0.0/32">>
                                                ]
                                               )).

-define(SET_INVALID_NETWORK_CIDRS(Cidrs), kapps_config:set_default(?APP_NAME
                                                                  ,[<<"client">>, <<"blacklist">>, <<"cidrs">>]
                                                                  ,Cidrs
                                                                  )).

-define(INVALID_PORTS, kapps_config:get_integers(?APP_NAME
                                                ,[<<"client">>, <<"blacklist">>, <<"ports">>]
                                                ,[5984, 5984, 15984, 15986 % couchdb
                                                 ,4369                     % epmd
                                                 ,15672                    % rabbit mgmt
                                                 ,22002                    % haproxy stats
                                                 ]
                                                )).
-define(SET_INVALID_PORTS(Ports), kapps_config:set_default(?APP_NAME
                                                          ,[<<"client">>, <<"blacklist">>, <<"ports">>]
                                                          ,Ports
                                                          )).

-spec urldecode(kz_term:text()) -> kz_term:text().
urldecode(URL) -> urldecode(URL, 'rfc').

%%------------------------------------------------------------------------------
%% @doc 'legacy' vs 'rfc'.
%%
%% 'legacy' treats '+' as a space (in addition to %20) RFC-1738
%% 'rfc' only treats %20 as a space, RFC-3986.
%% @end
%%------------------------------------------------------------------------------
-spec urldecode(kz_term:text(), 'rfc' | 'legacy') -> kz_term:text().
urldecode(URL, 'rfc') ->
    urldecode_percent20(URL);
urldecode(URL, 'legacy') ->
    urldecode_plus(kz_term:to_binary(URL)).

urldecode_percent20(Binary) when is_binary(Binary) ->
    kz_term:to_binary(kz_http_uri:decode(kz_term:to_list(Binary)));
urldecode_percent20(String) when is_list(String) ->
    kz_http_uri:decode(String);
urldecode_percent20(Atom) when is_atom(Atom) ->
    kz_term:to_atom(kz_http_uri:decode(kz_term:to_list(Atom)), 'true').

-spec urlencode(kz_term:text()) -> kz_term:text().
urlencode(URL) -> urlencode(URL, 'rfc').

-spec urlencode(kz_term:text(), 'rfc' | 'legacy') -> kz_term:text().
urlencode(URL, 'rfc') ->
    %% alsk known as RFC-3986 spaces serialization
    urlencode_percent20(URL);
urlencode(URL, 'legacy') ->
    %% also known as RFC-1738 serialization
    urlencode_plus(kz_term:to_binary(URL)).

-spec urlencode_percent20(kz_term:text()) -> kz_term:text().
urlencode_percent20(Binary) when is_binary(Binary) ->
    kz_term:to_binary(kz_http_uri:encode(kz_term:to_list(Binary)));
urlencode_percent20(String) when is_list(String) ->
    kz_http_uri:encode(String);
urlencode_percent20(Atom) when is_atom(Atom) ->
    kz_term:to_atom(kz_http_uri:encode(kz_term:to_list(Atom)), 'true');
urlencode_percent20(Any) ->
    urlencode_percent20(kz_term:to_binary(Any)).

%%------------------------------------------------------------------------------
%% @doc URL decodes a URL encoded string.
%% @end
%%------------------------------------------------------------------------------
-spec urldecode_plus(binary()) -> binary().
urldecode_plus(Source) ->
    urldecode_plus(Source, <<>>).

-spec urldecode_plus(binary(), binary()) -> binary().
urldecode_plus(<<>>, Acc) ->
    Acc;

urldecode_plus(<<$+, R/binary>>, Acc) ->
    urldecode_plus(R, <<Acc/binary, " ">>);

urldecode_plus(<<$%, H, L, R/binary>>, Acc) ->
    Code  = <<H, L>>,
    Ascii = list_to_integer(binary_to_list(Code), 16),

    urldecode_plus(R, <<Acc/binary, Ascii>>);

urldecode_plus(<<H, R/binary>>, Acc) ->
    urldecode_plus(R, <<Acc/binary, H>>).

%%------------------------------------------------------------------------------
%% @doc URL encodes a string.
%% @end
%%------------------------------------------------------------------------------
-spec urlencode_plus(binary()) -> binary().
urlencode_plus(Source) when is_binary(Source) ->
    urlencode_plus(Source, <<>>).

-spec urlencode_plus(binary(), binary()) -> binary().
urlencode_plus(<<>>, Acc) ->
    Acc;

urlencode_plus(<<$\s, R/binary>>, Acc) ->
    urlencode_plus(R, <<Acc/binary, $+>>);

urlencode_plus(<<C, R/binary>>, Acc) ->
    case C of
        $. -> urlencode_plus(R, <<Acc/binary, C>>);
        $- -> urlencode_plus(R, <<Acc/binary, C>>);
        $~ -> urlencode_plus(R, <<Acc/binary, C>>);
        $_ -> urlencode_plus(R, <<Acc/binary, C>>);
        C when C >= $0
               andalso C=< $9 ->
            urlencode_plus(R, <<Acc/binary, C>>);
        C when C >= $a
               andalso C=< $z ->
            urlencode_plus(R, <<Acc/binary, C>>);
        C when C >= $A
               andalso C=< $Z ->
            urlencode_plus(R, <<Acc/binary, C>>);
        _NotSafe ->
            SafeChar = encode_char(C),
            urlencode_plus(R, <<Acc/binary, "%", SafeChar/binary>>)
    end.

%%------------------------------------------------------------------------------
%% @doc Converts a single character to its base-16 %-encoded form.
%% @end
%%------------------------------------------------------------------------------
-spec encode_char(integer()) -> binary().
encode_char(Char) ->
    case integer_to_list(Char, 16) of
        Val when length(Val) < 2 -> list_to_binary(["0", Val]);
        ProperLen                -> list_to_binary(ProperLen)
    end.

%%------------------------------------------------------------------------------
%% @doc Parses a query string and returns a list of key-value pairs.
%% If the input string contains a `?' then everything after the `?' will
%% be treated as the query string, otherwise the entire input is treated
%% as the query string. The return key-value pairs will be URL decoded.
%% @end
%%------------------------------------------------------------------------------
-spec parse_query_string(binary()) -> [{binary(), binary()}].
parse_query_string(Source) ->
    parse_query_string('key', Source, <<>>, <<>>, []).

-spec parse_query_string(atom(), binary(), binary(), binary(), list()) -> list().
parse_query_string(_State, <<>>, <<>>, _ValAcc, RetAcc) ->
    RetAcc;

parse_query_string(_State, <<>>, KeyAcc, ValAcc, RetAcc) ->
    Key = urldecode(KeyAcc, 'legacy'),
    Val = urldecode(ValAcc, 'legacy'),

    RetAcc ++ [{Key, Val}];

parse_query_string(_State, <<$?, R/binary>>, _KeyAcc, _ValAcc, _RetAcc) ->
    parse_query_string('key', R, <<>>, <<>>, []);

parse_query_string('key', <<$=, R/binary>>, KeyAcc, _ValAcc, RetAcc) ->
    parse_query_string('val', R, KeyAcc, <<>>, RetAcc);

parse_query_string('key', <<$;, R/binary>>, KeyAcc, _ValAcc, RetAcc) ->
    Key = urldecode(KeyAcc, 'legacy'),

    parse_query_string('key', R, <<>>, <<>>, RetAcc ++ [{Key, <<>>}]);

parse_query_string('key', <<$&, R/binary>>, KeyAcc, _ValAcc, RetAcc) ->
    Key = urldecode(KeyAcc, 'legacy'),

    parse_query_string('key', R, <<>>, <<>>, RetAcc ++ [{Key, <<>>}]);

parse_query_string('val', <<$;, R/binary>>, KeyAcc, ValAcc, RetAcc) ->
    Key = urldecode(KeyAcc, 'legacy'),
    Val = urldecode(ValAcc, 'legacy'),

    parse_query_string('key', R, <<>>, <<>>, RetAcc ++ [{Key, Val}]);

parse_query_string('val', <<$&, R/binary>>, KeyAcc, ValAcc, RetAcc) ->
    Key = urldecode(KeyAcc, 'legacy'),
    Val = urldecode(ValAcc, 'legacy'),

    parse_query_string('key', R, <<>>, <<>>, RetAcc ++ [{Key, Val}]);

parse_query_string('key', <<C, R/binary>>, KeyAcc, ValAcc, RetAcc) ->
    parse_query_string('key', R, <<KeyAcc/binary, C>>, ValAcc, RetAcc);

parse_query_string('val', <<C, R/binary>>, KeyAcc, ValAcc, RetAcc) ->
    parse_query_string('val', R, KeyAcc, <<ValAcc/binary, C>>, RetAcc).

%%------------------------------------------------------------------------------
%% @doc Normalize already parsed query string and create nested objects when
%% the name of sub-keys are surrounded by square brackets.
%%
%% The intended input is `cow_qs:parse_qs/1` output.
%%
%% Implementation is based on `qs' NPM package.
%% https://github.com/ljharb/qs
%%
%% Some QS examples (don't forget to call `cow_qs:parse/1' first):
%%
%% ```
%% foo[bar]=baz --> { foo { bar: 'baz' } }
%% a%5Bb%5D=c --> { a: { b: 'c' } }
%% foo[bar][baz]=foobarbaz --> { foo: { bar: { baz: 'foobarbaz' } } }
%% a[b][c][d][e][f][g][h][i]=j    (limited to 5 children deep by default)
%%              --> { a: { b: { c: { d: { e: { f: '[g][h][i]': 'j' } } } } } }
%%
%% a[1]=b&a[15]=c   --> { a: ['b', 'c'] }
%% a=b,c --> { a: ['b', 'c'] } (when comma_array set to true)
%% '''
%% @end
%%------------------------------------------------------------------------------
-spec parse_query_arrays(QueryString :: kz_term:proplist()) -> kz_term:proplist().
parse_query_arrays(QS) ->
    parse_query_arrays(QS, #{}).

-define(DEFAULT_EMPTY, '$empty').
-define(DEFAULT_ARRAY_OPTIONS, #{array_limits => 25
                                ,comma_array => 'false'
                                ,compact_arrays => 'true'
                                ,depth => 5
                                }).

-spec parse_query_arrays(QueryString :: kz_term:proplist() | kz_json:object(), Options :: map()) -> kz_term:proplist().
parse_query_arrays(QS, Opts) when is_list(QS) ->
    #{'compact_arrays' := ShouldCompact} = Options = maps:merge(?DEFAULT_ARRAY_OPTIONS, Opts),
    Parsed = lists:foldl(fun({K, V}, Acc) -> parse_query_array(K, V, Acc, Options) end
                        ,kz_json:new()
                        ,primarily_merge(QS, Options)
                        ),
    case ShouldCompact of
        'true' ->
            kz_json:to_proplist(kz_json:compact_arrays(Parsed, #{default_empty => ?DEFAULT_EMPTY}));
        'false' ->
            kz_json:to_proplist(Parsed)
    end;
parse_query_arrays(QsJObj, _Options) ->
    parse_query_arrays(kz_json:recursive_to_proplist(QsJObj)).


%% This is primarily for handling cases when the key is explicit and we are expanding
%% comma separated string to array.
primarily_merge([], _) ->
    [];
primarily_merge([{<<>>, _} | T], Options) ->
    primarily_merge(T, Options);
primarily_merge([{K, V} | T], Options) ->
    NewV = explicit_array_item(K, V),
    case props:get_value(K, T) of
        'undefined' ->
            [{K, NewV} | primarily_merge(T, Options)];
        _ ->
            {OtherVs, NewT} = take_element(K, T, [], [], Options),
            [{K, combine(NewV, OtherVs)} | primarily_merge(NewT, Options)]
    end.

take_element(_, [], ElmAcc, QSAcc, _) ->
    {lists:reverse(ElmAcc), lists:reverse(QSAcc)};
take_element(Key, [{Key, Val}|QS], ElmAcc, QSAcc, Options) ->
    take_element(Key, QS, [Val | ElmAcc], QSAcc, Options);
take_element(Key, [Elm|QS], ElmAcc, QSAcc, Options) ->
    take_element(Key, QS, ElmAcc, [Elm|QSAcc], Options).

%% if value is list and key is explicit array `[]' then treat the whole value
%% as a single array item.
explicit_array_item(Key, Value) when is_list(Value) ->
    case lists:reverse(get_all_brackets(Key)) of
        [<<"[]">>|_] -> [Value];
        _ -> Value
    end;
explicit_array_item(_K, Value) ->
    Value.

parse_query_array(Key, Value, Acc, Options) ->
    ParentName = get_array_name(Key),
    Children = get_all_brackets(Key),

    NewValue = maybe_comma_to_array(Value, Options),
    NewJObj = parse_query_object(ParentName, Children, NewValue, Options),

    kz_json:qsjs_merge(Acc, NewJObj, #{default_empty => ?DEFAULT_EMPTY}).

get_array_name(Key) ->
    case re:run(Key, <<"\\[[^[\\]]*]">>) of
        'nomatch' -> Key;
        {'match', [{BracketStart, _}]} ->
            binary:part(Key, 0, BracketStart)
    end.

get_all_brackets(Key) ->
    case re:run(Key, <<"\\[[^[\\]]*]">>, ['global', {'capture', 'all', 'binary'}]) of
        'nomatch' -> [];
        {'match', Brackets} -> [K || [K] <- Brackets]
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
parse_query_object(<<>>, Children, Value, Options) ->
    parse_query_object(Children, Value, Options);
parse_query_object(ParentName, Children, Value, Options) ->
    parse_query_object([ParentName | Children], Value, Options).

parse_query_object([Parent | Rest]=Ks, Value, Options) ->
    case allow_nested_depth(Rest, Options) of
        {[], _} when Rest =/= [] ->
            %% if max depth is reached just wrap whatever is left
            %% to treat them as the inner most value.
            lists:foldl(fun(FoldK, Acc) -> parse_query_object1(FoldK, Acc, Options) end
                       ,Value
                       ,[kz_binary:join([<<"[">>, Ks, <<"]">>], <<>>)]
                       );
        {_AllowedKs, []} ->
            lists:foldl(fun(FoldK, Acc) -> parse_query_object1(FoldK, Acc, Options) end
                       ,Value
                       ,lists:reverse(Ks)
                       );
        {AllowedKs, NotAllowedKs} ->
            %% wrap whatever is left to treat them as the inner most value.
            lists:foldl(fun(FoldK, Acc) -> parse_query_object1(FoldK, Acc, Options) end
                       ,Value
                       ,[kz_binary:join([<<"[">>, NotAllowedKs, <<"]">>], <<>>) | lists:reverse([Parent | AllowedKs])]
                       )
    end.

parse_query_object1(<<"[]">>, Value, _Options) ->
    combine([], Value);
parse_query_object1(Key, Value, Options) ->
    CleanKey = remove_brackets(Key),
    IsJsonNum = is_json_array_index(Key, Options, CleanKey),
    case IsJsonNum of
        'true' ->
            Size = kz_term:to_integer(CleanKey),
            lists:append(empty_array(Size), [Value]);
        'false' ->
            kz_json:from_list([{CleanKey, Value}])
    end.

empty_array(Size) ->
    lists:foldl(fun(_, Acc) -> [?DEFAULT_EMPTY | Acc] end, [], lists:seq(1, Size)).

-spec combine(list(), list() | any()) -> list().
combine(ListA, ListB)
  when is_list(ListA)
       andalso is_list(ListB) ->
    lists:append(ListA, ListB);
combine(List, NonList)
  when is_list(List)
       andalso not is_list(NonList) ->
    lists:append(List, [NonList]);
combine(NonList, ListB)
  when not is_list(NonList)
       andalso is_list(ListB) ->
    [NonList | ListB];
combine(NonListA, NonListB) ->
    [NonListA, NonListB].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec remove_brackets(binary()) -> binary().
remove_brackets(<<"[">> = Bin) ->
    Bin;
remove_brackets(<<"[", Rest/binary>> = Bin) ->
    case binary:last(Rest) of
        $] -> binary:part(Rest, 0, byte_size(Rest) - 1);
        _ -> Bin
    end;
remove_brackets(Val) ->
    Val.

-spec is_json_array_index(binary(), Options::map(), binary()) -> boolean().
is_json_array_index(Key, #{array_limits := Limits}, CleanKey) ->
    try kz_term:to_integer(CleanKey) of
        Integer ->
            Key =/= CleanKey
                andalso kz_term:to_binary(Integer) =:= CleanKey %% e.g. 1 =/= "01"
                andalso Integer >= 0
                andalso Integer =< Limits
    catch
        'error':'badarg' -> 'false'
    end.

-spec allow_nested_depth([binary()], Options::map()) -> {[binary()], [binary()]}.
allow_nested_depth(Keys, #{depth := Depth})
  when is_integer(Depth)
       andalso Depth >= 0 ->
    try lists:split(Depth, Keys)
    catch
        'error':'badarg' ->
            {Keys, []}
    end;
allow_nested_depth(Keys, _) ->
    {Keys, []}.

-spec maybe_comma_to_array(term(), Options::map()) -> term().
maybe_comma_to_array(Value, #{comma_array := 'true'})
  when is_binary(Value) ->
    case binary:match(Value, <<",">>) of
        'nomatch' -> Value;
        {_, _} -> binary:split(Value, <<",">>, ['global'])
    end;
maybe_comma_to_array(Value, Options) when is_list(Value) ->
    [maybe_comma_to_array(V, Options) || V <- Value];
maybe_comma_to_array(Value, _) ->
    Value.


%%------------------------------------------------------------------------------
%% @doc Splits a URL
%%
%% Parts will be scheme, location, path, query, fragment parts, and optionally
%% username/password if HTTP Basic Auth creds are included
%% @end
%%------------------------------------------------------------------------------
-type scheme() :: binary().
-type host() :: binary() | {binary(), inet:port_number()}.
-type username() :: binary().
-type password() :: binary().
-type location() :: host() | {host(), username(), password()}.
-type resource_path() :: binary().
-type querystring() :: iodata().
-type fragment() :: binary().

-spec location_host(location()) -> binary().
location_host(<<Host/binary>>) -> Host;
location_host({<<Host/binary>>, Port}) when is_integer(Port) -> Host;
location_host({Host, <<_/binary>>, <<_/binary>>}) -> location_host(Host).

-spec location_port(location()) -> inet:port_number() | 'undefined'.
location_port(<<_/binary>>) -> 'undefined';
location_port({<<_/binary>>, Port}) when is_integer(Port) -> Port;
location_port({Host, _Username, _Password}) -> location_host(Host).

-spec location_username(location()) -> binary() | 'undefined'.
location_username(<<_/binary>>) -> 'undefined';
location_username({<<_/binary>>, _Port}) when is_integer(_Port) -> 'undefined';
location_username({_Host, <<Username/binary>>, _Password}) -> Username.

-spec location_password(location()) -> binary() | 'undefined'.
location_password(<<_/binary>>) -> 'undefined';
location_password({<<_/binary>>, _Port}) when is_integer(_Port) -> 'undefined';
location_password({_Host, <<_/binary>>, <<Password/binary>>}) -> Password.

-spec urlsplit(binary()) -> split_url() | {'error', 'invalid_uri'}.
urlsplit(Source) ->
    case uri_string:parse(Source) of
        {'error', 'invalid_uri', _} ->
            lager:info("failed to parse URL ~s", [Source]),
            {'error', 'invalid_uri'};
        Parsed ->
            {maps:get('scheme', Parsed, <<>>)
            ,parsed_host(Parsed)
            ,maps:get('path', Parsed, <<>>)
            ,maps:get('query', Parsed, <<>>)
            ,maps:get('fragment', Parsed, <<>>)
            }
    end.

%% username:password@host:port
parsed_host(#{host := Host, port := Port, userinfo := UserInfo}) ->
    UserPass = binary:split(UserInfo, <<":">>),
    list_to_tuple([{Host, Port} | UserPass]);
parsed_host(#{host := Host, userinfo := UserInfo}) ->
    UserPass = binary:split(UserInfo, <<":">>),
    list_to_tuple([Host | UserPass]);
parsed_host(#{host := Host, port := Port}) ->
    {Host, Port};
parsed_host(Parsed) ->
    maps:get('host', Parsed, <<>>).

%%------------------------------------------------------------------------------
%% @doc Joins the elements of a URL together.
%% @end
%%------------------------------------------------------------------------------
-spec urlunsplit(split_url()) -> binary().
urlunsplit({S, N, P, Q, F}) ->
    Us = case S of <<>> -> <<>>; _ -> [S, "://"] end,
    Uq = case Q of <<>> -> <<>>; _ -> [$?, Q] end,
    Uf = case F of <<>> -> <<>>; _ -> [$#, F] end,

    iolist_to_binary([Us, location_to_binary(N), P, Uq, Uf]).

location_to_binary(<<Location/binary>>) -> Location;
location_to_binary({<<Location/binary>>, Port}) when is_integer(Port) ->
    [Location, ":", kz_term:to_list(Port)];
location_to_binary({Host, <<Username/binary>>, <<Password/binary>>}) ->
    [Username, ":", Password, "@", location_to_binary(Host)].

%%------------------------------------------------------------------------------
%% @doc Convert JSON object to encoded query string.
%%
%% Example: take JObj
%% `{key1: val1, key2: [v2_1, v2_2], key3: {k3_1: v3_1}}'
%% will returns:
%% `key=val&key2[]=v2_1&key2[]=v2_2&key3[key3_1]=v3_1'
%% @end
%%------------------------------------------------------------------------------

-define(DEFAULT_ENCODE_QS_OPTS, #{keep_null => 'true' %% old behaviour
                                 ,array_format => 'brackets'
                                 ,array_index_start => 0
                                 ,encode_keys => 'true'
                                 ,encode_values => 'true'
                                 ,encode_keys_type => 'rfc' %% old bahviour
                                 ,encode_values_type => 'legacy' %% old bahviour
                                 ,allow_empty_strings => 'true' %% old behaviour
                                 ,add_query_prefix => 'false'
                                 ,return => 'list' %% old behaviour
                                 }
       ).
%% See https://github.com/ljharb/qs
%% implementing these features remains open to the reader (add the feature to parser too):
%% - 'array_format: comman': a=b,c,d
%%     - comma_round_trip
%% - allow_empty_arrays: foo[]&bar=baz
%% - allowDots and encodeDotInKeys
%% - delimiter (none of our parser support any delimiterr other than &)
%% - null handling
%%     - our parser doesn't strictNullHandling like qs does, it treats it as empty string
%%       even cow_qs doesn't support it: `a&b=lol' parses as `[{<<"a">>, true},{<<"b">>, <<"lol">>}]'
-type qs_encode_opts() :: #{keep_null => boolean()
                           ,array_format => 'indices' | 'brackets' | 'repeat' %% | 'comma'
                           ,array_index_start => non_neg_integer()
                           ,encode_keys => boolean()
                           ,encode_values => boolean()
                           ,encode_keys_type => 'legacy' | 'rfc'
                           ,encode_values_type => 'legacy' | 'rfc'
                           ,allow_empty_strings => boolean()
                           ,add_query_prefix => boolean() | 'even_on_empty'
                           ,return => 'list' | 'binary'
                           }.

-spec json_to_querystring(object()) -> iodata().
json_to_querystring(JObj) -> json_to_querystring(JObj, #{}, []).

%% if Prefix is empty, don't wrap keys in array tags, otherwise Prefix[key]=value
-spec json_to_querystring(object(), qs_encode_opts()) -> iodata().
json_to_querystring(JObj, Options) ->
    json_to_querystring(JObj, Options, []).

-spec json_to_querystring(object(), qs_encode_opts(), list()) -> iodata().
json_to_querystring(JObj, Opts0, Prefix) ->
    Options = maps:merge(?DEFAULT_ENCODE_QS_OPTS, Opts0),
    {Vs, Ks} = kz_json:get_values(JObj),
    maybe_add_prefix(Options, fold_kvs(Options, Ks, Vs, Prefix, [])).

-spec props_to_querystring(kz_term:proplist()) -> iodata().
props_to_querystring(Props) ->
    props_to_querystring(Props, #{}, []).

-spec props_to_querystring(kz_term:proplist(), qs_encode_opts()) -> iodata().
props_to_querystring(Props, Options) ->
    props_to_querystring(Props, Options, []).

-spec props_to_querystring(kz_term:proplist(), qs_encode_opts(), list()) -> iodata().
props_to_querystring(Props, Opts0, Prefix) ->
    Options = maps:merge(?DEFAULT_ENCODE_QS_OPTS, Opts0),
    {Vs, Ks} = props:get_values_and_keys(Props),
    maybe_add_prefix(Options, fold_kvs(Options, [kz_term:to_binary(K) || K <- Ks], Vs, Prefix, [])).

maybe_add_prefix(#{add_query_prefix := QueryPrefix}=Options, Encoded) ->
    case {QueryPrefix, kz_term:to_binary(Encoded)} of
        {'even_on_empty', <<>>} -> return_as(Options, [<<"?">> | Encoded]);
        {'even_on_empty', _Bin} -> return_as(Options, [<<"?">> | Encoded]);
        {'true', <<>>} -> return_as(Options, Encoded);
        {'true', _Bin} -> return_as(Options, [<<"?">> | Encoded]);
        {_, _Bin} -> return_as(Options, Encoded)
    end.

return_as(#{return := 'binary'}, Encoded) -> kz_term:to_binary(Encoded);
return_as(#{return := 'list'}, Encoded) -> Encoded.

%% foreach key/value pair, encode the key/value with the prefix and prepend the &
%% if the last key/value pair, encode the key/value with the prefix, prepend to accumulator
%% and reverse the list (putting the key/value at the end of the list)
-spec fold_kvs(qs_encode_opts(), keys(), json_terms(), list(), iodata()) -> iodata().
fold_kvs(_Options, [], [], _, Acc) -> Acc;
fold_kvs(Options, [K], [V], Prefix, Acc) ->
    case encode_kv(Options, Prefix, K, V) of
        ?DEFAULT_EMPTY ->
            case Acc of
                [<<"&">> | A] -> lists:reverse(A);
                _ -> lists:reverse(Acc)
            end;
        Encoded -> lists:reverse([Encoded | Acc])
    end;
fold_kvs(Options, [K|Ks], [V|Vs], Prefix, Acc) ->
    case encode_kv(Options, Prefix, K, V) of
        ?DEFAULT_EMPTY ->
            fold_kvs(Options, Ks, Vs, Prefix, Acc);
        Encoded ->
            fold_kvs(Options, Ks, Vs, Prefix, [<<"&">>, Encoded | Acc])
    end.

-define(ARRAY_PLACEHOLDER(Index), {'array', Index}).
-define(NESTED_ARRAY, {'nested'}).

-spec encode_kv(qs_encode_opts(), list(), key() | {'nested'}, json_term() | json_terms() | kz_term:proplist()) -> iodata() | ?DEFAULT_EMPTY.
%% array values
encode_kv(_, _, _, []) -> ?DEFAULT_EMPTY;
encode_kv(Options, Prefix0, K, [{_, _}|_]=Props) -> props_to_querystring(Props, Options, add_to_prefix(Options, Prefix0, K));
encode_kv(#{array_index_start := Index}=Options, Prefix0, K, Vs) when is_list(Vs) ->
    Prefix = add_to_prefix(Options, Prefix0, K),
    encode_array(Options, Prefix, Index, Vs, []);

%% scalar values, just encode it (url-encoded)
encode_kv(#{allow_empty_strings := 'true'}=Options, Prefix, K, <<>>) ->
    final_encode_kv(Options, Prefix, K, <<"=">>, <<>>);
encode_kv(_Options, _Prefix, _K, <<>>) -> ?DEFAULT_EMPTY;
encode_kv(Options, Prefix, K, V) when is_binary(V) -> final_encode_kv(Options, Prefix, K, <<"=">>, V);
encode_kv(Options, Prefix, K, V) when is_number(V) -> final_encode_kv(Options, Prefix, K, <<"=">>, V);
encode_kv(Options, Prefix, K, 'true') -> final_encode_kv(Options, Prefix, K, <<"=">>, <<"true">>);
encode_kv(Options, Prefix, K, 'false') -> final_encode_kv(Options, Prefix, K, <<"=">>, <<"false">>);
encode_kv(_, _, _, 'undefined') -> ?DEFAULT_EMPTY;
encode_kv(#{keep_null := 'true'}=Options, Prefix, K, 'null') ->
    final_encode_kv(Options, Prefix, K, <<"=">>, <<"null">>);
encode_kv(_, _, _, 'null') -> ?DEFAULT_EMPTY;
encode_kv(Options, Prefix, K, V) when is_atom(V) ->
    final_encode_kv(Options, Prefix, K, <<"=">>, V);

%% JObj values
encode_kv(_, _, _, ?EMPTY_JSON_OBJECT) -> ?DEFAULT_EMPTY;
encode_kv(Options, Prefix, K, ?JSON_WRAPPER(_)=JObj) ->
    json_to_querystring(JObj, Options, add_to_prefix(Options, Prefix, K)).

add_to_prefix(_, Prefix, ?NESTED_ARRAY) -> Prefix;
add_to_prefix(_, [], K) ->
    %% key:{k1:v1, k2:v2} => key[k1]=v1&key[k2]=v2
    %% if no prefix is present, use just key to prefix the key/value pairs in the jobj
    [K];
add_to_prefix(Options, Prefix, K) ->
    %% if a prefix is defined, nest the key in square brackets
    Prefix ++ [format_array(Options, K)].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec final_encode_kv(qs_encode_opts(), list() | binary(), key() | binary() | {'nested'}, kz_term:ne_binary(), string() | binary() | atom() | number()) -> iodata().
final_encode_kv(Options, Prefix0, K, Sep, V) ->
    Value = encode_value(Options, V),
    case encode_prefix(Options, lists:flatten(Prefix0), []) of
        <<>> -> [encode_key(Options, K), Sep, Value];
        EncodedPrefix -> [EncodedPrefix, make_format_array(Options, K), Sep, Value]
    end.

make_format_array(_, ?NESTED_ARRAY) -> <<>>;
make_format_array(Options, K) -> encode_key(Options, format_array(Options, K)).

encode_prefix(_, [], Acc) -> kz_term:to_binary(lists:reverse(Acc));
encode_prefix(Options, [<<>>|Bins], Acc) ->
    encode_prefix(Options, Bins, Acc);
encode_prefix(Options, [?ARRAY_PLACEHOLDER(Index)|Bins], Acc) ->
    EncodedKey = encode_key(Options, format_array(Options, ?ARRAY_PLACEHOLDER(Index))),
    encode_prefix(Options, Bins, [EncodedKey|Acc]);
encode_prefix(Options, [Bin|Bins], Acc) ->
    encode_prefix(Options, Bins, [encode_key(Options, Bin)|Acc]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec encode_array(qs_encode_opts(), list(), any(), [string()|kz_term:proplist_property()|kz_json:object()], iolist()) -> iodata().
encode_array(Options, Prefix, Index, [V], []) ->
    maybe_nested_array(Options, Prefix, Index, V);
encode_array(Options, Prefix, Index, [V], Acc) ->
    case maybe_nested_array(Options, Prefix, Index, V) of
        ?DEFAULT_EMPTY -> lists:reverse(Acc);
        NestedEncoded -> lists:reverse([NestedEncoded | Acc])
    end;
encode_array(Options, Prefix, Index, [V|Vs], Acc) ->
    case maybe_nested_array(Options, Prefix, Index, V) of
        ?DEFAULT_EMPTY -> encode_array(Options, Prefix, Index, Vs, Acc);
        Encoded -> encode_array(Options, Prefix, Index+1, Vs, [<<"&">>, Encoded | Acc])
    end;
encode_array(_, _, _, [], Acc) -> lists:reverse(Acc).

maybe_nested_array(_, _, _, []) ->
    ?DEFAULT_EMPTY;
maybe_nested_array(Options, Prefix, Index, Vs) when is_list(Vs) ->
    encode_kv(Options, Prefix ++ [?ARRAY_PLACEHOLDER(Index)], ?NESTED_ARRAY, Vs);
maybe_nested_array(Options, Prefix, Index, {InnerK, InnerV}) ->
    %% element of a nested proplist
    encode_kv(Options, Prefix ++ [?ARRAY_PLACEHOLDER(Index)], InnerK, InnerV);
maybe_nested_array(Options, Prefix, Index, V) ->
    encode_kv(Options, Prefix ++ [?ARRAY_PLACEHOLDER(Index)], ?NESTED_ARRAY, V).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
format_array(#{array_format := 'indices'}, ?ARRAY_PLACEHOLDER(Index)) ->
    %% a[0]=b&a[1]=c
    kz_term:to_binary([<<"[">>, kz_term:to_binary(Index), <<"]">>]);
format_array(#{array_format := 'repeat'}, ?ARRAY_PLACEHOLDER(_Index)) ->
    %% a=b&a=c
    <<>>;
%% format_array(#{array_format := 'comma'}, ?ARRAY_PLACEHOLDER(_Index)) ->
%%     %% we don't support comma array format, lazy to write it :(
%%     %% a=b,c
format_array(_Options, ?ARRAY_PLACEHOLDER(_Index)) ->
    %% default to 'brackets', the old behaviour
    %% a[]=b&a[]=c
    <<"[]">>;
format_array(_Options, V) ->
    kz_term:to_binary([<<"[">>, kz_term:to_binary(V), <<"]">>]).

encode_key(#{encode_keys := 'true'}=Options, V) ->
    kz_term:to_binary(urlencode(kz_term:to_binary(V), encode_type(Options, 'encode_keys_type')));
encode_key(_O, V) ->
    kz_term:to_binary(V).

encode_value(#{encode_values := 'true'}=Options, V) ->
    kz_term:to_binary(urlencode(kz_term:to_binary(V), encode_type(Options, 'encode_values_type')));
encode_value(_O, V) ->
    kz_term:to_binary(V).

encode_type(Options, K) -> maps:get(K, Options, 'legacy').

%%------------------------------------------------------------------------------
%% @doc Converts HTTP status code to reason.
%% @end
%%------------------------------------------------------------------------------
-spec http_code_to_status_line(atom() | pos_integer()) -> kz_term:ne_binary().
%% 4×× Client Error
http_code_to_status_line(400) -> <<"Bad Request">>;
http_code_to_status_line(401) -> <<"Unauthorized">>;
http_code_to_status_line(402) -> <<"Payment Required">>;
http_code_to_status_line(403) -> <<"Forbidden">>;
http_code_to_status_line(404) -> <<"Not Found">>;
http_code_to_status_line(405) -> <<"Method Not Allowed">>;
http_code_to_status_line(406) -> <<"Not Acceptable">>;
http_code_to_status_line(407) -> <<"Proxy Authentication Required">>;
http_code_to_status_line(408) -> <<"Request Timeout">>;
http_code_to_status_line(409) -> <<"Conflict">>;
http_code_to_status_line(410) -> <<"Gone">>;
http_code_to_status_line(411) -> <<"Length Required">>;
http_code_to_status_line(412) -> <<"Precondition Failed">>;
http_code_to_status_line(413) -> <<"Payload Too Large">>;
http_code_to_status_line(414) -> <<"Request-URI Too Long">>;
http_code_to_status_line(415) -> <<"Unsupported Media Type">>;
http_code_to_status_line(416) -> <<"Requested Range Not Satisfiable">>;
http_code_to_status_line(417) -> <<"Expectation Failed">>;
http_code_to_status_line(418) -> <<"I'm a teapot">>;
http_code_to_status_line(421) -> <<"Misdirected Request">>;
http_code_to_status_line(422) -> <<"Unprocessable Entity">>;
http_code_to_status_line(423) -> <<"Locked">>;
http_code_to_status_line(424) -> <<"Failed Dependency">>;
http_code_to_status_line(426) -> <<"Upgrade Required">>;
http_code_to_status_line(428) -> <<"Precondition Required">>;
http_code_to_status_line(429) -> <<"Too Many Requests">>;
http_code_to_status_line(431) -> <<"Request Header Fields Too Large">>;
http_code_to_status_line(444) -> <<"Connection Closed Without Response">>;
http_code_to_status_line(451) -> <<"Unavailable For Legal Reasons">>;
http_code_to_status_line(499) -> <<"Client Closed Request">>;
%% 5×× Server Error
http_code_to_status_line(500) -> <<"Internal Server Error">>;
http_code_to_status_line(501) -> <<"Not Implemented">>;
http_code_to_status_line(502) -> <<"Bad Gateway">>;
http_code_to_status_line(503) -> <<"Service Unavailable">>;
http_code_to_status_line(504) -> <<"Gateway Timeout">>;
http_code_to_status_line(505) -> <<"HTTP Version Not Supported">>;
http_code_to_status_line(506) -> <<"Variant Also Negotiates">>;
http_code_to_status_line(507) -> <<"Insufficient Storage">>;
http_code_to_status_line(508) -> <<"Loop Detected">>;
http_code_to_status_line(510) -> <<"Not Extended">>;
http_code_to_status_line(511) -> <<"Network Authentication Required">>;
http_code_to_status_line(599) -> <<"Network Connect Timeout Error">>.

-spec get_resp_header(kz_http:field(), kz_http:headers()) -> kz_http:value() | 'undefined'.
get_resp_header(RespHeader, RespHeaders) ->
    get_resp_header(RespHeader, RespHeaders, 'undefined').

-spec get_resp_header(kz_http:field(), kz_http:headers(), Default) -> kz_http:value() | Default.
get_resp_header(RespHeader, RespHeaders, Default) ->
    props:get_value(kz_term:to_lower_string(RespHeader)
                   ,[{kz_term:to_lower_string(K), V} || {K, V} <- RespHeaders]
                   ,Default
                   ).

-type part() :: {binary(), kz_term:proplist()}.
-type parts() :: [part()].

-spec encode_multipart(parts()) -> binary().
encode_multipart(Parts) ->
    encode_multipart(Parts, create_boundary()).

-spec encode_multipart(parts(), binary()) -> binary().
encode_multipart(Parts, Boundary) ->
    encode_multipart(Parts, Boundary, <<>>).

-spec encode_multipart(parts(), binary(), binary()) -> binary().
encode_multipart([], Boundary, Encoded) ->
    Close = <<"\r\n--" , Boundary/binary, "--">>,
    <<Encoded/binary, Close/binary>>;
encode_multipart([{Body, Headers} | Parts], Boundary, Encoded) ->
    Delimiter = <<"\r\n--" ,Boundary/binary, "\r\n">>,
    H = encode_multipart_headers(Headers),
    Acc = <<Encoded/binary, Delimiter/binary, H/binary, Body/binary>>,
    encode_multipart(Parts, Boundary, Acc).

-spec encode_multipart_headers(kz_term:proplist()) -> binary().
encode_multipart_headers(Headers) ->
    encode_multipart_headers(Headers, <<>>).

-spec encode_multipart_headers(kz_term:proplist(), binary()) -> binary().
encode_multipart_headers([], <<>>) -> <<>>;
encode_multipart_headers([], Encoded) -> <<Encoded/binary, "\r\n">>;
encode_multipart_headers([{K, V} | Headers], Encoded) ->
    Acc = <<Encoded/binary, K/binary, ": ", V/binary, "\r\n">>,
    encode_multipart_headers(Headers, Acc).

-spec create_boundary() -> kz_term:ne_binary().
create_boundary() ->
    cow_multipart:boundary().

-spec resolve_uri(nonempty_string() | kz_term:ne_binary(), nonempty_string() | kz_term:api_ne_binary()) -> kz_term:ne_binary().
resolve_uri(Raw, 'undefined') -> kz_term:to_binary(Raw);
resolve_uri(_Raw, <<"http", _/binary>> = Abs) -> Abs;
resolve_uri(<<_/binary>> = RawPath, <<_/binary>> = Relative) ->
    Path = resolve_uri_path(RawPath, Relative),
    kz_binary:join(Path, <<"/">>);
resolve_uri(RawPath, Relative) ->
    resolve_uri(kz_term:to_binary(RawPath), kz_term:to_binary(Relative)).

-spec resolve_uri_path(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binaries().
resolve_uri_path(RawPath, Relative) ->
    PathTokensRev = lists:reverse(binary:split(RawPath, <<"/">>, ['global'])),
    UrlTokens = binary:split(Relative, <<"/">>, ['global']),
    lists:reverse(
      lists:foldl(fun resolve_uri_fold/2, PathTokensRev, UrlTokens)
     ).

-spec resolve_uri_fold(kz_term:ne_binary(), kz_term:ne_binaries()) -> kz_term:ne_binaries().
resolve_uri_fold(<<"..">>, []) -> [];
resolve_uri_fold(<<"..">>, [_ | PathTokens]) -> PathTokens;
resolve_uri_fold(<<".">>, PathTokens) -> PathTokens;
resolve_uri_fold(<<>>, PathTokens) -> PathTokens;
resolve_uri_fold(Segment, [<<>>|DirTokens]) -> [Segment|DirTokens];
resolve_uri_fold(Segment, [LastToken|DirTokens]=PathTokens) ->
    case filename:extension(LastToken) of
        <<>> ->
            %% no extension, append Segment to Tokens
            [Segment | PathTokens];
        _Ext ->
            %% Extension found, append Segment to DirTokens
            [Segment|DirTokens]
    end.

-spec uri(kz_term:ne_binary(), kz_term:ne_binaries()) -> kz_term:ne_binary().
uri(BaseUrl, Tokens) ->
    [Pro, Url] = binary:split(BaseUrl, <<"://">>),
    Uri = filename:join([Url | Tokens]),
    <<Pro/binary, "://", Uri/binary>>.

-spec client_ip_blacklist() -> kz_term:api_ne_binaries().
client_ip_blacklist() -> ?INVALID_NETWORK_CIDRS.

-spec set_client_ip_blacklist(kz_term:ne_binaries()) -> kz_term:ne_binaries().
set_client_ip_blacklist(Blacklist) ->
    {'ok', _} = ?SET_INVALID_NETWORK_CIDRS(Blacklist),
    client_ip_blacklist().

-spec client_host_blacklist() -> kz_term:api_ne_binaries().
client_host_blacklist() -> ?INVALID_HOSTS.

-spec set_client_host_blacklist(kz_term:ne_binaries()) -> kz_term:ne_binaries().
set_client_host_blacklist([_|_]=Blacklist) ->
    {'ok', _} = ?SET_INVALID_HOSTS(Blacklist),
    client_host_blacklist().

-spec client_port_blacklist() -> [inet:port_number()].
client_port_blacklist() -> ?INVALID_PORTS.

-spec set_client_port_blacklist(kz_term:ne_binaries()) -> [inet:port_number()].
set_client_port_blacklist([_|_]=Blacklist) ->
    {'ok', _} = ?SET_INVALID_PORTS(Blacklist),
    client_port_blacklist().
