%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2021, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_scope_expand).
-behaviour(gen_server).

-include("kazoo_auth.hrl").

-export([start_link/0]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-export([lookup_scope/1
        ,lookup_scopes/1
        ,lookup_with_claim/1

        ,flush/0
        ,flush/1
        ]).

-define(SERVER, ?MODULE).
-define(SERVER_TIMEOUT, 20 * ?MILLISECONDS_IN_SECOND).

-define(MAX_EXPAND_LEVEL, 4).

-type state() :: #{}.


%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec lookup_with_claim(kz_json:object()) -> kz_json:object().
lookup_with_claim(Claims) ->
    case kz_json:get_value(<<"scope">>, Claims) of
        'undefined' -> Claims;
        Scopes ->
            kz_json:set_value(<<"scope_expanded">>, lookup_scopes(Scopes), Claims)
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec lookup_scopes(kz_term:ne_binary() | kz_term:ne_binaries()) -> kz_json:object().
lookup_scopes(<<Scope/binary>>) ->
    lookup_scopes(kz_auth_scope:split(Scope));
lookup_scopes([]) ->
    kz_json:new();
lookup_scopes(Scopes) when is_list(Scopes) ->
    try gen_server:call(?MODULE, {'lookup_scopes', Scopes}, ?SERVER_TIMEOUT) of
        Result -> kz_json:from_list(Result)
    catch
        'exit':{'timeout', _} ->
            lager:debug("timed out expanding scopes"),
            kz_json:new();
        _E:_T ->
            lager:debug("got exception when expanding scopes, ~p:~p", [_E, _T]),
            kz_json:new()
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec lookup_scope(kz_term:ne_binary()) -> kz_term:ne_binaries().
lookup_scope(Scope) ->
    try gen_server:call(?MODULE, {'lookup', Scope}, ?SERVER_TIMEOUT) of
        Result -> Result
    catch
        'exit':{'timeout', _} ->
            lager:debug("timed out expanding scope '~p'", [Scope]),
            [];
        _E:_T ->
            lager:debug("got exception when expanding scope '~p', ~p:~p", [Scope, _E, _T]),
            []
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec flush() -> 'ok'.
flush() ->
    gen_server:cast(?MODULE, {'flush', 'all'}).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec flush(kz_term:ne_binary()) -> 'ok'.
flush(Scope) ->
    gen_server:cast(?MODULE, {'flush', Scope}).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?SERVER}, ?MODULE, [], []).

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server
%%
%% @end
%%------------------------------------------------------------------------------
-spec init(list()) -> {'ok', state(), ?MILLISECONDS_IN_SECOND}.
init([]) ->
    lager:info("starting ~p", [?MODULE]),
    {'ok', #{}}.

%%------------------------------------------------------------------------------
%% @doc Handling call messages
%%
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call({'lookup', Scope}, _From, State) ->
    {NewState, _Loop, Result} = lookup_scope(State, Scope, 1),
    {'reply', lists:reverse(Result), NewState};
handle_call({'lookup_scopes', Scopes}, _From, State) ->
    {Result, NewState} = lookup_scopes(Scopes, State, []),
    {'reply', Result, NewState};
handle_call({'debug', 'dump'}, _From, State) ->
    {'reply', State, State};
handle_call(_Request, _From, State) ->
    {'noreply', State}.
    % {'reply', {'error', 'not_implemented'}, State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages
%%
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'flush', 'all'}, _State) ->
    {'noreply', #{}};
handle_cast({'flush', Scope}, State) ->
    {'noreply', maps:remove(Scope, State)};
handle_cast(_Request, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages
%%
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info(_Info, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(Reason, _State) ->
    lager:debug("~s going down: ~p", [?MODULE, Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed
%%
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
lookup_scopes([], State, Acc) ->
    {lists:reverse(Acc), State};
lookup_scopes([Scope | Scopes], State, Acc) ->
    {NewState, _Loop, Result} = lookup_scope(State, Scope, 1),
    lookup_scopes(Scopes, NewState, [{Scope, lists:reverse(Result)} | Acc]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec lookup_scope(state(), kz_term:ne_binary(), non_neg_integer()) -> kz_term:ne_binaries().
lookup_scope(State, Scope, ExpandLevel) ->
    case maps:get(Scope, State, 'undefined') of
        'undefined' ->
            case fetch_expand(State, Scope, ExpandLevel) of
                'undefined' ->
                    {State#{Scope => []}, ExpandLevel, []};
                {NewState, NewExpandLevel, Expand} ->
                    {NewState#{Scope => Expand}, NewExpandLevel, Expand}
            end;
        Result ->
            {State, ExpandLevel, Result}
    end.

fetch_expand(_State, _Scope, ExpandLevel) when ?MAX_EXPAND_LEVEL < ExpandLevel ->
    lager:warning("reached to maximum loop to expand scope '~s', giving up...", [_Scope]),
    'undefined';
fetch_expand(State, Scope, ExpandLevel) ->
    case kz_auth_scope:available_scopes(Scope) of
        [{_DocId, Scopes}] ->
            lists:foldl(fun(InnerScope, {InnerState, InnerExpandLevel, InnerAcc}) ->
                                case lookup_scope(InnerState, InnerScope, InnerExpandLevel) of
                                    {NewState, _NewExpandLevel, []} ->
                                        {NewState, InnerExpandLevel, [InnerScope | InnerAcc]};
                                    {NewState, _NewExpandLevel, InnerScopes} ->
                                        {NewState, InnerExpandLevel, InnerScopes ++ InnerAcc}
                                end
                        end
                       ,{State, ExpandLevel + 1, []}
                       ,Scopes
                       );
        _ -> 'undefined'
    end.
