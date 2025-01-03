%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_client_config).

-export([is_enabled/0, set_is_enabled/1
        ,cluster_id/0
        ,cluster_secret/0, set_cluster_secret/1
        ,app_exchange_url/0, set_app_exchange_url/1
        ,fetch_timer_s/0, set_fetch_timer_s/1
        ,http_timeout_s/0, set_http_timeout_s/1
        ,api_url/0, set_api_url/1
        ,marketplace_url/0, set_marketplace_url/1

        ,system_configs/0, system_configs/1

        ,is_configured/0
        ,get_public_configs/0, get_public_configs/1

        ,config_cat/0

        ,find_api_url/0
        ,is_aio_cluster/0, set_is_aio_cluster/1
        ]).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include("appex_client.hrl").

-spec is_enabled() -> boolean().
is_enabled() ->
    kapps_config:is_true(?CONFIG_CAT, <<"enabled">>, 'false').

-spec set_is_enabled(boolean()) -> boolean().
set_is_enabled(Bool) ->
    {'ok', _} = kapps_config:set_boolean(?CONFIG_CAT, <<"enabled">>, Bool),
    Bool.

-spec cluster_id() -> kz_term:ne_binary().
cluster_id() ->
    kzd_cluster:id().

-spec cluster_secret() -> kz_term:api_ne_binary().
cluster_secret() ->
    kapps_config:get_ne_binary(?CONFIG_CAT, <<"cluster_secret">>, default_value('cluster_secret')).

-spec set_cluster_secret(kz_term:ne_binary() | 'null') -> kz_term:api_ne_binary().
set_cluster_secret('null') ->
    {'ok', _} = kapps_config:set(?CONFIG_CAT, <<"cluster_secret">>, 'null'),
    'undefined';
set_cluster_secret(<<ClusterSecret/binary>>) ->
    {'ok', _} = kapps_config:set_string(?CONFIG_CAT, <<"cluster_secret">>, ClusterSecret),
    ClusterSecret.

-spec app_exchange_url() -> kz_term:api_ne_binary().
app_exchange_url() ->
    kapps_config:get_ne_binary(?CONFIG_CAT,<<"app_exchange_url">>, default_value('app_exchange_url', <<"https://api.marketplace.2600hz.com">>)).

-spec set_app_exchange_url(kz_term:ne_binary() | 'null') -> kz_term:api_ne_binary().
set_app_exchange_url('null') ->
    {'ok', _} = kapps_config:set(?CONFIG_CAT, <<"app_exchange_url">>, 'null'),
    'undefined';
set_app_exchange_url(<<URL/binary>>) ->
    {'ok', _} = kapps_config:set_string(?CONFIG_CAT, <<"app_exchange_url">>, URL),
    URL.

-spec api_url() -> kz_term:api_ne_binary().
api_url() ->
    kapps_config:get_ne_binary(?CONFIG_CAT, <<"api_url">>, default_value('api_url')).

-spec set_api_url(kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
set_api_url(URL) ->
    %% TODO: we need to re-configure running mui apps source_url
    {'ok', _} = kapps_config:set_string(?CONFIG_CAT, <<"api_url">>, URL),
    URL.

-spec find_api_url() -> {'ok', kz_term:ne_binary()} | {'error', 'no_api_url'}.
find_api_url() ->
    case api_url() of
        'undefined' ->
            try kz_network_utils:resolve(kz_term:to_binary(kz_network_utils:get_hostname())
                                        ,get_resolve_options()
                                        )
            of
                [] ->
                    lager:error("unable to detect localhost api_url, please configure api_url in appex_client"),
                    {'error', 'no_api_url'};
                [IP|_] ->
                    lager:info("using current hostmachine address ~s as api_url", [IP]),
                    {'ok', IP}
            catch
                _E:_T:_ST ->
                    lager:error("unable to detect localhost api_url, please configure api_url in appex_client"),
                    {'error', 'no_api_url'}
            end;
        ApiUrl ->
            {'ok', ApiUrl}
    end.

-spec get_resolve_options() -> kz_term:proplist().
get_resolve_options() ->
    case kapps_config:is_true(?CONFIG_CAT, <<"use_tcp">>, 'false') of
        'true' -> kz_network_utils:default_options();
        'false' -> props:set_value('usevc', 'false', kz_network_utils:default_options())
    end.

-spec marketplace_url() -> kz_term:api_ne_binary().
marketplace_url() ->
    kapps_config:get_ne_binary(?CONFIG_CAT, <<"marketplace_url">>, default_value('marketplace_url', <<"https://marketplace.2600hz.com">>)).

-spec set_marketplace_url(kz_term:api_ne_binary()) -> kz_term:api_ne_binary().
set_marketplace_url(URL) ->
    {'ok', _} = kapps_config:set_string(?CONFIG_CAT, <<"marketplace_url">>, URL),
    URL.

-spec is_aio_cluster() -> boolean().
is_aio_cluster() ->
    kapps_config:is_true(?CONFIG_CAT, <<"is_aio_cluster">>, 'false').

-spec set_is_aio_cluster(boolean()) -> boolean().
set_is_aio_cluster(Bool) ->
    {'ok', _} = kapps_config:set_boolean(?CONFIG_CAT, <<"is_aio_cluster">>, Bool),
    Bool.

-spec fetch_timer_s() -> pos_integer().
fetch_timer_s() ->
    kapps_config:get_integer(?CONFIG_CAT, <<"fetch_timer_s">>, ?SECONDS_IN_HOUR).

-spec set_fetch_timer_s(kz_term:ne_binary() | pos_integer()) -> pos_integer().
set_fetch_timer_s(TimeoutS) ->
    {'ok', _} = kapps_config:set_integer(?CONFIG_CAT, <<"fetch_timer_s">>, TimeoutS),
    TimeoutS.

-spec http_timeout_s() -> pos_integer().
http_timeout_s() ->
    kapps_config:get_integer(?CONFIG_CAT, <<"http_timeout_s">>, ?SECONDS_IN_MINUTE).

-spec set_http_timeout_s(pos_integer()) -> pos_integer().
set_http_timeout_s(TimeoutS) ->
    {'ok', _} = kapps_config:set_integer(?CONFIG_CAT, <<"http_timeout_s">>, TimeoutS),
    TimeoutS.

-spec default_value(atom()) -> kz_term:api_ne_binary().
default_value(Key) ->
    default_value(Key, 'undefined').

-spec default_value(atom(), Value) -> Value.
default_value(Key, Default) ->
    case application:get_env('kazoo_appex', Key, Default) of
        'undefined' -> Default;
        {'ok', Value} -> Value;
        Default -> Default
    end.

-spec system_configs() -> kz_json:object().
system_configs() ->
    system_configs('false').

-spec system_configs(boolean()) -> kz_json:object().
system_configs(Verbose) ->
    kz_json:set_values([{<<"system_memory">>, erlang:memory('total')}
                       ,{<<"system_info">>, system_info()}
                       ,{<<"code">>, code_info(Verbose)}
                       ]
                      ,kz_json:new()
                      ).

-spec system_info() -> kz_json:object().
system_info() ->
    kz_json:from_list([{<<"version">>, kz_term:to_binary(erlang:system_info('version'))}
                      ,{<<"otp_release">>, kz_term:to_binary(erlang:system_info('otp_release'))}
                      ,{<<"otp_version">>, kapps_util:otp_version()}
                      ,{<<"system_architecture">>, kz_term:to_binary(erlang:system_info('system_architecture'))}
                      ,{<<"logical_processors">>, erlang:system_info('logical_processors')}
                      ]).

-define(CODE_MODULES, ["code", "code_server"]).
-spec code_info(boolean()) -> kz_json:object().
code_info(Verbose) ->
    kz_json:from_list([{<<"lib_dir">>, kz_term:to_binary(code:lib_dir())}
                      ,{<<"functions">>, functions(?CODE_MODULES, Verbose)}
                      ]).

-spec functions([string()], boolean()) -> kz_term:api_object().
functions(_Modules, 'false') ->
    'undefined';
functions(Modules, 'true') ->
    lists:foldl(fun function_sigs/2, kz_json:new(), Modules).

-spec function_sigs(string(), kz_json:object()) -> kz_json:object().
function_sigs(Module, Acc) ->
    gen_file_signatures(code:where_is_file(Module ++ ".beam"), Acc, Module).

gen_file_signatures(File, Sigs, "code"=Module) ->
    Fs = [{'load_binary', 3}],
    gen_file_signatures(File, Sigs, Module, Fs);
gen_file_signatures(File, Sigs, "code_server"=Module) ->
    Fs = [{'do_load_binary', 5}
         ,{'try_load_module', 5}
         ,{'try_load_module_1', 5}
         ,{'try_load_module_2', 6}
         ,{'try_load_module_3', 6}
         ],
    gen_file_signatures(File, Sigs, Module, Fs);
gen_file_signatures(File, Sigs, "erlang"=Module) ->
    Fs = [{'load_module', 2}
         ,{'is_binary', 1}
         ,{'finish_loading', 1}
         ],
    gen_file_signatures(File, Sigs, Module, Fs);
gen_file_signatures(_File, Sigs, _Module) ->
    Sigs.

gen_file_signatures(File, Sigs, Module, Fs) ->
    {'ok', {_M, MD5}} = beam_lib:md5(File),
    ModuleName = kz_term:to_atom(Module, 'true'),
    Application = get_application(File),
    SigsAcc =  kz_json:set_value([Application, kz_term:to_binary(Module), <<"md5">>]
                                ,kz_term:to_hex_binary(MD5)
                                ,Sigs
                                ),
    case beam_lib:chunks(File, ['abstract_code']) of
        {'ok', {_, [{'abstract_code', {_,AC}}]}} ->
            gen_function_signatures(ModuleName, Application, AC, Fs, SigsAcc);
        _Error ->
            SigsAcc
    end.

gen_function_signatures(Module, Application, AbstractCode, Fs, Sigs) ->
    FunClauses = [{Name, Arity, Clauses}
                  || {'function', _L, Name, Arity, Clauses} <- AbstractCode,
                     lists:member({Name, Arity}, Fs)
                 ],
    get_function_signatures(Module, Application, FunClauses, Sigs).

get_function_signatures(Module, Application, FunClauses, Sigs) ->
    lists:foldl(fun(FunClause, Acc) ->
                        get_function_signature(Module, Application, FunClause, Acc)
                end
               ,Sigs
               ,FunClauses
               ).

get_function_signature(Module, Application, {Function, Arity, Clauses}, Sigs) ->
    ClausesBin = erlang:term_to_binary(Clauses),
    Hash = kz_term:to_hex_binary(crypto:hash('md5', ClausesBin)),

    kz_json:insert_value([Application
                         ,kz_term:to_binary(Module)
                         ,iolist_to_binary([atom_to_list(Function), "/", integer_to_list(Arity)])
                         ]
                        ,Hash
                        ,Sigs
                        ).

get_application(File) ->
    kz_term:to_binary(filename:basename(filename:dirname(filename:dirname(File)))).

-spec get_public_configs() -> {'ok' | 'error', kz_json:object()}.
get_public_configs() ->
    get_public_configs(appex_client_client:maybe_get_cluster()).

-spec get_public_configs({'ok', kz_json:object()} | {'error', kz_json:object() | 'not_linked'}) ->
          {'ok' | 'error', kz_json:object()}.
get_public_configs({'ok', Cluster}) ->
    {'ok'
    ,kz_json:from_list(
       [{<<"cluster_id">>, kzd_cluster:id()}
       ,{<<"enabled">>, is_enabled()}
       ,{<<"app_exchange_url">>, app_exchange_url()}
       ,{<<"api_url">>, api_url()}
       ,{<<"marketplace_url">>, marketplace_url()}
       ,{<<"is_linked">>, kz_term:is_not_empty(cluster_secret())}
       ,{<<"is_aio_cluster">>, is_aio_cluster()}
       ,{<<"name">>, kz_json:get_ne_binary_value(<<"name">>, Cluster)}
       ,{<<"kazoo_version">>, kz_json:get_ne_binary_value(<<"kazoo_version">>, Cluster)}
       ]
      )
    };
get_public_configs({'error', 'not_linked'}) ->
    {'ok'
    ,kz_json:from_list(
       [{<<"cluster_id">>, kzd_cluster:id()}
       ,{<<"enabled">>, is_enabled()}
       ,{<<"app_exchange_url">>, app_exchange_url()}
       ,{<<"api_url">>, api_url()}
       ,{<<"marketplace_url">>, marketplace_url()}
       ,{<<"is_linked">>, kz_term:is_not_empty(cluster_secret())}
       ,{<<"is_aio_cluster">>, is_aio_cluster()}
       ]
      )
    };
get_public_configs({'error', ErrorJObj}) ->
    {'error', ErrorJObj}.

-spec config_cat() -> kz_term:ne_binary().
config_cat() -> ?CONFIG_CAT.

-spec is_configured() -> boolean().
is_configured() ->
    Config = kz_json:from_list(
               [{<<"cluster_id">>, cluster_id()}
               ,{<<"cluster_secret">>, cluster_secret()}
               ,{<<"app_exchange_url">>, app_exchange_url()}
               ]
              ),
    is_configured(Config).

-spec is_configured(kz_json:object()) -> boolean().
is_configured(Config) ->
    lists:foldl(fun(Key, Acc) -> is_defined(Key, Config, Acc) end
               ,'true'
               ,[<<"cluster_id">>
                ,<<"cluster_secret">>
                ,<<"app_exchange_url">>
                ]
               ).

-spec is_defined(kz_json:key(), kz_json:object(), boolean()) -> boolean().
is_defined(Key, JObj, Acc) ->
    case kz_json:get_ne_value(Key, JObj) of
        'undefined' ->
            'false';
        _Val ->
            Acc
    end.
