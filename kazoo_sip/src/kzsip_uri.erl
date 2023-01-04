%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2023, 2600Hz
%%% @doc Parse and manipulate SIP URIs
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzsip_uri).

-export([uris/1
        ,ruri/1
        ,uri/1
        ]).

-export([parse/1
        ,encode/1, encode/2
        ]).

-export([display_name/1, set_display_name/2
        ,scheme/1, set_scheme/2
        ,user/1, set_user/2
        ,host/1, set_host/2
        ,port/1, set_port/2
        ,uri_params/1, set_uri_params/2
        ,extra_params/1, set_extra_params/2
        ]).

-export([get_uri_param/2, get_uri_param/3, set_uri_param/2, set_uri_param/3
        ,get_extra_param/2, get_extra_param/3, set_extra_param/2, set_extra_param/3
        ]).

-ifdef(TEST).
-export([params_to_binary/1
        ]).
-endif.

-include("kazoo_sip.hrl").

-define(DEFAULT_SCHEME, 'sip').
-define(DEFAULT_PORT, 5060).

-type uri_param_key() :: kz_term:ne_binary().
-type uri_param_value() :: binary().
-type uri_param() :: {uri_param_key(), uri_param_value()}.
-type extra_param() :: {uri_param_key(), uri_param_value()}.
-type uri_type() :: 'request' | 'from_uri'.

-type display_name() :: kz_term:api_ne_binary().
-type scheme() :: 'sip' | 'sips'.
-type user() :: kz_term:api_ne_binary().
-type host() :: kz_term:api_ne_binary().
-type uri_port() :: pos_integer().
-type uri_params() :: [uri_param()].
-type extra_params() :: [extra_param()].

-record(sip_uri, {display_name :: display_name()
                 ,scheme = ?DEFAULT_SCHEME :: scheme()
                 ,user :: user()
                 ,host :: host()
                 ,port = ?DEFAULT_PORT :: uri_port()
                 ,uri_params = [] :: uri_params()
                 ,extra_params = [] :: extra_params()
                 }).

-opaque sip_uri() :: #sip_uri{}.
-type uri() :: nklib:uri().
-type uris() :: [uri()].

-export_type([sip_uri/0
             ,uri/0
             ,uris/0
             ,display_name/0
             ,scheme/0
             ,user/0
             ,host/0
             ,port/0
             ,uri_params/0
             ]).

-spec uris(binary() | string() | uri()) -> uris() | 'error'.
uris(Uri) -> nklib_parse_uri:uris(Uri).

-spec ruri(uri()) -> binary().
ruri(#uri{scheme='undefined'}=Uri) -> nklib_unparse:uri3(Uri#uri{scheme=?DEFAULT_SCHEME});
ruri(Uri) -> nklib_unparse:uri3(Uri).

-spec uri(uri()) -> binary().
uri(#uri{scheme='undefined'}=Uri) -> nklib_unparse:uri(Uri#uri{scheme=?DEFAULT_SCHEME});
uri(Uri) -> nklib_unparse:uri(Uri).

-spec parse(kz_term:ne_binary()) -> sip_uri().
parse(BinURI) ->
    URIRegex = <<"^" %% Start.
                ,(maybe_match_display_name(BinURI))/binary %%                               -> `"display name" '
                ,"<?" %% Optional <.                                                        -> "display name" `<'
                ,(maybe_match_scheme(BinURI))/binary %% Default: ?DEFAULT_SCHEME.           -> "display name" <`scheme:'
                ,"(?<user>", (match('user'))/binary, ")" %% URI's user.                     -> "display name" <scheme:`user'
                ,"@" %%                                                                     -> "display name" <scheme:user`@'
                ,"(?<host>", (match('host'))/binary, ")" %% URI's host.                     -> "display name" <scheme:user@`host'
                ,":?" %% Optional :. Only available when a value for port is provided.      -> "display name" <scheme:user@host`:'
                ,"(?<port>[\\d]*)?" %% Optional port. Default: ?DEFAULT_PORT.               -> "display name" <scheme:user@host:`port'
                ,"(?<uri_params>.*)?" %% Optional URI parameters.        -> "display name" <scheme:user@host:port`;transport=tcp;nat=yes,from-offnet=true'
                ,(maybe_match_closing_angle(BinURI))/binary %% Optional > character.        -> "display name" <scheme:user@host:port`>'
                ,"(?<extra_params>.*)" %% Optional extra parameters.                        -> "display name" <scheme:user@host:port;transport=tcp;nat=yes,from-offnet=true>`;tag=random;expires=3600;q=0.7'
                ,"$" %% end
               >>,
    case re:run(BinURI, URIRegex, [{'capture', 'all', 'binary' }]) of
        'nomatch' ->
            throw({'invalid_uri', BinURI});
        {'match', [_, DisplayName, Scheme, User, Host, Port, URIParams, ExtraParams]} ->
            build_sip_uri([{<<"display_name">>, DisplayName}
                          ,{<<"scheme">>, Scheme}
                          ,{<<"user">>, User}
                          ,{<<"host">>, Host}
                          ,{<<"port">>, Port}
                          ,{<<"uri_params">>, URIParams}
                          ,{<<"extra_params">>, ExtraParams}
                          ])
    end.

-spec encode(sip_uri()) -> kz_term:ne_binary().
encode(#sip_uri{} = SIP_URI) ->
    encode(SIP_URI, 'request'). %% Keep current functionality.

%%%-----------------------------------------------------------------------------
%% @doc Differences between Request-URI (RURI) and From-URI types encoding
%% request ``(scheme:user@host:port;uri_params)'':
%%  - Not &lt;&gt; enclosure.
%%  - Not display_name.
%%  - When port=?DEFAULT_PORT, it is not included.
%%  - Not extra_params.
%%
%% from ``(display_name <scheme:user@host:port;uri_params>;extra_params)'':
%%  - &lt;&gt; enclosure is only used when display_name and/or extra_params was/were provided.
%%  - Port is included, even if port=?DEFAULT_PORT.
%%  - Includes extra_params (if any).
%%% @end
%%%-----------------------------------------------------------------------------
-spec encode(sip_uri(), uri_type()) -> kz_term:ne_binary().
encode(#sip_uri{scheme=S, user=U, host=H, port=5060, uri_params=URIParams}, 'request') ->
    list_to_binary([atom_to_list(S), ":", U, "@", H, params_to_binary(URIParams)]);
encode(#sip_uri{scheme=S, user=U, host=H, port=P, uri_params=URIParams}, 'request') ->
    URIParamsBin = params_to_binary(URIParams),
    list_to_binary([atom_to_list(S), ":", U, "@", H, ":", integer_to_list(P), URIParamsBin]);
encode(#sip_uri{display_name = DisplayName
               ,scheme = Scheme
               ,user = User
               ,host = Host
               ,port = Port
               ,uri_params = URIParams
               ,extra_params = ExtraParams
               }
      ,'from'
      ) ->
    {Open, Close} = case not kz_term:is_empty(DisplayName)
                        orelse not kz_term:is_empty(ExtraParams)
                    of
                        'true' -> {<<"<">>, <<">">>};
                        'false' -> {<<>>, <<>>}
                    end,
    <<(maybe_format_display_name(DisplayName))/binary
     ,Open/binary
     ,(kz_term:to_binary(Scheme))/binary
     ,":"
     ,User/binary
     ,"@"
     ,Host/binary
     ,":"
     ,(kz_term:to_binary(Port))/binary
     ,(params_to_binary(URIParams))/binary
     ,Close/binary
     ,(params_to_binary(ExtraParams))/binary
    >>.

-spec display_name(sip_uri()) -> display_name().
display_name(#sip_uri{display_name=DisplayName}) -> DisplayName.

-spec set_display_name(sip_uri(), display_name()) -> sip_uri().
set_display_name(#sip_uri{}=Sip, DisplayName) ->
    Sip#sip_uri{display_name=DisplayName}.

-spec scheme(sip_uri()) -> scheme().
scheme(#sip_uri{scheme=S}) -> S.

-spec set_scheme(sip_uri(), scheme()) -> sip_uri().
set_scheme(#sip_uri{}=Sip, S) ->
    Sip#sip_uri{scheme=S}.

-spec user(sip_uri()) -> user().
user(#sip_uri{user=U}) -> U.

-spec set_user(sip_uri(), user()) -> sip_uri().
set_user(#sip_uri{}=Sip, U) ->
    Sip#sip_uri{user=U}.

-spec host(sip_uri()) -> host().
host(#sip_uri{host=H}) -> H.

-spec set_host(sip_uri(), host()) -> sip_uri().
set_host(#sip_uri{}=Sip, H) ->
    Sip#sip_uri{host=H}.

-spec port(sip_uri()) -> uri_port().
port(#sip_uri{port=P}) -> P.

-spec set_port(sip_uri(), uri_port()) -> sip_uri().
set_port(#sip_uri{}=Sip, P) ->
    Sip#sip_uri{port=P}.

-spec uri_params(sip_uri()) -> uri_params().
uri_params(#sip_uri{uri_params=URIParams}) -> URIParams.

-spec set_uri_params(sip_uri(), uri_params()) -> sip_uri().
set_uri_params(#sip_uri{}=Sip, URIParams) ->
    Sip#sip_uri{uri_params=URIParams}.

-spec extra_params(sip_uri()) -> extra_params().
extra_params(#sip_uri{extra_params=ExtraParams}) -> ExtraParams.

-spec set_extra_params(sip_uri(), extra_params()) -> sip_uri().
set_extra_params(#sip_uri{}=Sip, ExtraParams) ->
    Sip#sip_uri{extra_params=ExtraParams}.

-spec get_uri_param(uri_param_key(), sip_uri()) -> uri_param_value() | 'undefined'.
get_uri_param(Param, #sip_uri{}=Sip) ->
    get_uri_param(Param, Sip, 'undefined').

-spec get_uri_param(uri_param_key(), sip_uri(), Default) -> uri_param_value() | Default.
get_uri_param(Param, #sip_uri{}=Sip, Default) ->
    props:get_binary_value(Param, uri_params(Sip), Default).

-spec set_uri_param(uri_param(), sip_uri()) -> sip_uri().
set_uri_param({Param, Value}, #sip_uri{}=Sip) ->
    set_uri_param(Param, Value, Sip).

-spec set_uri_param(uri_param_key(), uri_param_value(), sip_uri()) -> sip_uri().
set_uri_param(Param, Value, #sip_uri{}=Sip) ->
    set_uri_params(Sip, props:set_value(Param, Value, uri_params(Sip))).

-spec get_extra_param(uri_param_key(), sip_uri()) -> uri_param_value() | 'undefined'.
get_extra_param(Param, #sip_uri{}=Sip) ->
    get_extra_param(Param, Sip, 'undefined').

-spec get_extra_param(uri_param_key(), sip_uri(), Default) -> uri_param_value() | Default.
get_extra_param(Param, #sip_uri{}=Sip, Default) ->
    props:get_binary_value(Param, extra_params(Sip), Default).

-spec set_extra_param(extra_param(), sip_uri()) -> sip_uri().
set_extra_param({Param, Value}, #sip_uri{}=Sip) ->
    set_extra_param(Param, Value, Sip).

-spec set_extra_param(uri_param_key(), uri_param_value(), sip_uri()) -> sip_uri().
set_extra_param(Param, Value, #sip_uri{}=Sip) ->
    set_extra_params(Sip, props:set_value(Param, Value, extra_params(Sip))).



%% Helpers
-spec build_sip_uri(kz_term:proplist()) -> sip_uri().
build_sip_uri(PropsURI) ->
    build_sip_uri(PropsURI, #sip_uri{}).

-spec build_sip_uri(kz_term:proplist(), sip_uri()) -> sip_uri().
build_sip_uri([], Sip) ->
    Sip;
build_sip_uri([{<<"scheme">>, <<>>} | RemProps], Sip) ->
    build_sip_uri(RemProps, set_scheme(Sip, ?DEFAULT_SCHEME));
%% NOTE: if kz_term:to_atom/1 is used to convert <<"sip">> and <<"sips">>, it won't work with tests.
%% Tests fail because 'sips' atom does not exist at tests runtime.
build_sip_uri([{<<"scheme">>, <<"sip">>} | RemProps], Sip) ->
    build_sip_uri(RemProps, set_scheme(Sip, 'sip'));
build_sip_uri([{<<"scheme">>, <<"sips">>} | RemProps], Sip) ->
    build_sip_uri(RemProps, set_scheme(Sip, 'sips'));
build_sip_uri([{<<"port">>, <<>>} | RemProps], Sip) ->
    build_sip_uri(RemProps, set_port(Sip, ?DEFAULT_PORT));
build_sip_uri([{<<"port">>, Port} | RemProps], Sip) ->
    build_sip_uri(RemProps, set_port(Sip, kz_term:to_integer(Port)));
build_sip_uri([{<<"uri_params">>, URIParams} | RemProps], Sip) ->
    build_sip_uri(RemProps, set_uri_params(Sip, binary_to_params(URIParams)));
build_sip_uri([{<<"extra_params">>, ExtraParams} | RemProps], Sip) ->
    build_sip_uri(RemProps, set_extra_params(Sip, binary_to_params(ExtraParams)));
build_sip_uri([{Key, Value} | RemProps], Sip) ->
    SetFun = kz_term:to_atom(<<"set_", Key/binary>>),
    build_sip_uri(RemProps, ?MODULE:SetFun(Sip, kz_binary:strip(Value))).

%%%-----------------------------------------------------------------------------
%% @doc If display_name was provided, match it. Otherwise, match empty (positional results).
%% @end
%%%-----------------------------------------------------------------------------
-spec maybe_match_display_name(kz_term:ne_binary()) -> kz_term:ne_binary().
maybe_match_display_name(URIBin) ->
    %% Subject starts with 1 (or more) alphanumeric value(s), maybe (required if more than 1 word)
    %% enclosed within "" followed by at least 1 space.
    Regex = <<"^\"?", (match('display_name'))/binary, "\"?\\s+">>, %% e.g.: "display name ", "display_name", "d1splay n6m3", displayname, etc.
    maybe_match_display_name(URIBin, kz_binary:matches(URIBin, Regex)).

-spec maybe_match_display_name(kz_term:ne_binary(), boolean()) -> kz_term:ne_binary().
maybe_match_display_name(_URIBin, 'true') ->
    <<"\"?" %% Optional opening ".
     ,"(?<display_name>", (match('display_name'))/binary, ")" %% Display name.
     ,"\"?\\s+" %% Optional closing " and at least 1 space.
    >>;
maybe_match_display_name(_URIBin, 'false') ->
    <<"(?<display_name>)?">>. %% {<<"display_name">>, <<>>}.

%%%-----------------------------------------------------------------------------
%% @doc If scheme was provided, match it. Otherwise, match empty (positional results).
%% @end
%%%-----------------------------------------------------------------------------
-spec maybe_match_scheme(kz_term:ne_binary()) -> kz_term:ne_binary().
maybe_match_scheme(URIBin) ->
    %% Match scheme (sip(s)) followed by :, then an alphanumeric value, an @, finish with another alphanumeric value.
    Regex = <<(match('scheme'))/binary, ":", (match('user'))/binary, "@", (match('host'))/binary>>, %% e.g.: "sip:user@host", "sip:u-s3_r@h0.st", etc.
    maybe_match_scheme(URIBin, kz_binary:matches(URIBin, Regex)).

-spec maybe_match_scheme(kz_term:ne_binary(), boolean()) -> kz_term:ne_binary().
maybe_match_scheme(_URIBin, 'true') ->
    <<"(?<scheme>", (match('scheme'))/binary, "):">>; %% Scheme sip(s) followed by :.
maybe_match_scheme(_URIBin, 'false') ->
    <<"(?<scheme>)?">>. %% {<<"scheme">>, <<>>}. Later set to {<<"scheme">>, ?DEFAULT_SCHEME}.

%% Maybe match closing angle bracket (>).
-spec maybe_match_closing_angle(kz_term:ne_binary()) -> binary().
maybe_match_closing_angle(URIBin) ->
    RegexesAndExpected = [{<<"^.*<.+>$">>, <<">">>} %% name <scheme:user@host;uri=params;go=here>
                         ,{<<"^.*<.+>;.*$">>, <<">;">>} %% name <scheme:user@host;uri=params;go=here>;extra_params=go_here
                         ,{<<"^.*\\\"<.+>\\\".*$">>, <<>>} %% name scheme:user@host;complex=uri_params;for=example;+sip.instance="<urn:uuid:00000000-0000-1000-8000-000A95A0E128>"
                         ,{<<"^.*<.+>\s*;.*$">>, <<">\s*;">>} %% Space between URI and extra_params: name <scheme:user@host> ;extra_params=go_here
                         ,{<<".*">>, <<>>} %% Not URI angle brackets enclosure.
                         ],
    maybe_match_closing_angle(URIBin, RegexesAndExpected).

-spec maybe_match_closing_angle(kz_term:ne_binary(), [{kz_term:ne_binary(), binary()}]) -> binary().
maybe_match_closing_angle(URIBin, [{Regex, Match} | Rem]) ->
    case kz_binary:matches(URIBin, Regex) of
        'true' -> Match;
        'false' -> maybe_match_closing_angle(URIBin, Rem)
    end.

-spec match('display_name' | 'scheme' | 'user' | 'host') -> kz_term:ne_binary().
match('display_name') ->
    <<"[\\w\\d\\s_]+">>; %% word character(s), digit(s), space(s), and/or _.
match('scheme') ->
    <<"sips?">>; %% sip or sips.
match('user') ->
    <<"[\\w\\d_\+]+">>; %% word character(s), digit(s), _, and/or +.
match('host') ->
    <<"[\\w\\d\.]+">>. %% word character(s), digit(s), and/or ..

%% Converts a binary into a [{binary(), binary()}] proplist.
-spec binary_to_params(binary()) -> uri_params() | extra_params().
binary_to_params(Params) ->
    kz_binary:to_proplist(Params, <<";">>, <<"=">>).

%% Converts a [{binary(), binary()}] proplist into a binary.
-spec params_to_binary(uri_params() | extra_params()) -> binary().
params_to_binary(Params) ->
    lists:foldl(fun fold_params_to_binary/2, <<>>, Params).

-spec fold_params_to_binary(uri_param() | extra_param(), binary()) -> binary().
fold_params_to_binary({Key, Value}, Acc) ->
    <<Acc/binary, ";", Key/binary, "=", Value/binary>>.

%% If display_name provided, quote it when encoding sip_uri.
-spec maybe_format_display_name(binary()) -> binary().
maybe_format_display_name(<<>>) -> <<>>;
maybe_format_display_name(DisplayName) -> <<"\"", DisplayName/binary, "\" ">>.
