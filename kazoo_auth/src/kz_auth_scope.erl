%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2020, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope).

-export([bin_to_list/1, bin_to_list/2
        ,claims/1
        ,default/0
        ,parse/1, parse/2
        ,parse_raw/1, parse_raw/2
        ]).

-include("kz_auth_scope.hrl").

%%------------------------------------------------------------------------------
%% @doc Split binary into list of binaries
%% @end
%%------------------------------------------------------------------------------
-spec bin_to_list(kz_term:binary()) -> kz_term:binaries().
bin_to_list(ScopeBin) ->
    bin_to_list(ScopeBin, ?SCOPE_SEPARATORS).

-spec bin_to_list(kz_term:binary(), kz_term:binary() | kz_term:binaries()) -> kz_term:binaries().
bin_to_list(ScopeBin, Separator) when is_binary(Separator) ->
    bin_to_list(ScopeBin, [Separator]);
bin_to_list(ScopeBin, Separator) ->
    binary:split(ScopeBin, Separator, ['global', 'trim_all']).

%%------------------------------------------------------------------------------
%% @doc default scopes
%% @end
%%------------------------------------------------------------------------------
-spec default() -> kz_term:ne_binary().
default() -> kz_binary:join(?DEFAULT_SCOPES, ?SPACE_SEP).

%%------------------------------------------------------------------------------
%% @doc Resolve claims from props
%% @end
%%------------------------------------------------------------------------------
-spec claims(kz_term:proplist()) -> kz_term:proplist().
claims(Props) ->
    Raw = proplists:get_value(<<"scope">>, Props, default()),
                                                % ensure we always include default scopes
    Props0 = normalize_scopes([Raw, default()], Props),
    map_claims_to_props(Props0).

%%------------------------------------------------------------------------------
%% @doc Normalize scope claim
%% @end
%%------------------------------------------------------------------------------
-spec normalize_scopes(kz_term:binary() | kz_term:binaries(), kz_term:proplist()) -> kz_term:proplist().
normalize_scopes(Scopes, Props) when is_list(Scopes) ->
    ScopeBin = concat_scope_bin(Scopes),
    normalize_scopes(ScopeBin, Props);
normalize_scopes(ScopeBin, Props) when is_binary(ScopeBin) ->
    Scopes = bin_to_list(ScopeBin),
    Routines = [{fun maybe_dedupe_scopes/2, Scopes}
               ],
    Fun = fun({F, S}, P) -> F(S, P) end,
    Scopes0 = lists:foldl(Fun, Scopes, Routines),
    props:set_value(<<"scope">>, concat_scope_bin(Scopes0), Props).

%%------------------------------------------------------------------------------
%% @doc Remove duplicate scopes from claim
%% @end
%%------------------------------------------------------------------------------
-spec maybe_dedupe_scopes(kz_term:binaries(), kz_term:binaries()) -> kz_term:binaries().
maybe_dedupe_scopes(Scopes, _) -> lists:usort(Scopes).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec map_claims_to_props(kz_term:proplist()) -> kz_term:proplist().
map_claims_to_props(Props) ->
    Raw = proplists:get_value(<<"scope">>, Props),
    Scopes = parse_raw(Raw),
    map_claims_to_props(Props, Scopes).

-spec map_claims_to_props(kz_term:proplist(), scopes()) -> kz_term:proplist().
map_claims_to_props(Props, Scopes) ->
    case kz_scope_db:scopes() of
        {'ok', Doc} ->
            map_claims_to_props(Props, Scopes, Doc);
        {'error', _} -> Props
    end.

-spec map_claims_to_props(kz_term:proplist(), scopes(), kz_doc:doc()) -> kz_term:proplist().
map_claims_to_props(Props, Scopes, _Doc) ->
    Fun = fun(#scope{scope=S}, Acc) ->
                  lager:debug("mapping scope ~p", [S]),
                  case kz_scope_db:has_scope(S) of
                    'true' ->
                      Scope = kz_scope_db:scope(S),
                      Claims = map_claims(Props, Scope),
                      props:filter_undefined(Claims) ++ Acc;
                    'false' -> Acc
                  end
          end,
    lists:foldl(Fun, Props, Scopes).

%%------------------------------------------------------------------------------
%% @doc map claims to kazoo props
%% @end
%%------------------------------------------------------------------------------
-spec map_claims(kz_term:proplist(), kz_doc:docs()) -> kz_term:proplist().
map_claims(Props, []) ->
    Props;
map_claims(Props, JObj) ->
    Module = kz_term:to_atom(kz_json:get_ne_binary_value(<<"module">>, JObj, 'undefined'), 'true'),
    lager:debug("claim mapping module configured ~p", [Module]),
    map_claims(Props, JObj, Module).

-spec map_claims(kz_term:proplist(), kz_doc:doc(), atom()) -> kz_term:proplist().
map_claims(Props, JObj, 'null') ->
    map_claims(Props, JObj, 'undefined');
map_claims(Props, JObj, 'undefined') ->
    Claims = kzd_scope:claims(JObj),
    Fun = fun(Claim, Acc) ->
                  lager:debug("attempting to map claim: ~p", [Claim]),
                  case Claim of
                      [] -> [];
                      [Key, Map] ->
                          Val = props:get_value(Map, Props),
                          props:set_value(Key, Val, Acc);
                      Key      ->
                          Val = props:get_value(Key, Props),
                          props:set_value(Key, Val, Acc)
                  end
          end,
    lists:foldl(Fun, Props, Claims);
map_claims(Props, JObj, Module) ->
    Claims = kzd_scope:claims(JObj),
    lager:debug("mapping claims with module ~p", [Module]),
    (Module):map(Claims, Props).

%%------------------------------------------------------------------------------
%% @doc parses scope term into a scope record
%% @end
%%------------------------------------------------------------------------------
-spec parse(kz_term:binary()) -> scope().
parse(Scope) ->
    parse(Scope, 'undefined').

-spec parse(kz_term:binary() | kz_term:binaries(), kz_term:binary()) -> scope().
parse(Scope, PrivLevel) when is_binary(Scope) ->
    Parsed = bin_to_list(Scope, ?ENTITY_SEP),
    parse(Parsed, PrivLevel);
parse([Scope], PrivLevel) ->
    #scope {role=PrivLevel
           ,scope=Scope
           };
parse([Scope, Permission], PrivLevel) ->
    #scope{role=PrivLevel
          ,scope=Scope
          ,privileges=Permission
          }.

%%------------------------------------------------------------------------------
%% @doc parses binary into list of scope records
%% @end
%%------------------------------------------------------------------------------
-spec parse_raw(kz_term:binary() | kz_term:binaries()) -> scopes().
parse_raw(Scopes) ->
    parse_raw(Scopes, 'undefined').

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec parse_raw(kz_term:binary() | kz_term:binaries(), kz_term:binary()) -> scopes().
parse_raw(ScopeBin, PrivLevel) when is_binary(ScopeBin) ->
    Scopes = bin_to_list(ScopeBin),
    parse_raw_scopes(lists:usort(Scopes), PrivLevel);
parse_raw(Scopes, PrivLevel) when is_list(Scopes) ->
    ScopeBin = concat_scope_bin(Scopes),
    parse_raw(ScopeBin, PrivLevel).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec parse_raw_scopes(kz_term:binaries(), kz_term:binary()) -> scopes().
parse_raw_scopes(Scopes, PrivLevel) ->
    Fun = fun(S, A) -> [parse(S, PrivLevel) | A] end,
    lists:foldl(Fun, [], Scopes).

%%------------------------------------------------------------------------------
%% @doc parses binary into list of scope records
%% @end
%%------------------------------------------------------------------------------
-spec concat_scope_bin(kz_term:binaries()) -> kz_term:binary().
concat_scope_bin(Scopes) when is_list(Scopes) ->
    binstr:join(Scopes, ?SPACE_SEP).
