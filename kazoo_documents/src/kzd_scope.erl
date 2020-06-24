-module(kzd_scope).

-export([claims/1
        ,mod/1
        ,privileges/1
        ]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec claims(doc()) -> kz_term:api_binaries().
claims(Doc) ->
    kz_json:get_value(<<"claims">>, Doc, []).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec mod(doc()) -> kz_term:api_binary().
mod(Doc) ->
    kz_json:get_ne_binary_value(<<"module">>, Doc, 'undefined').

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec privileges(doc()) -> kz_term:api_binaries().
privileges(Doc) ->
    kz_json:get_value(<<"privileges">>, Doc, []).
