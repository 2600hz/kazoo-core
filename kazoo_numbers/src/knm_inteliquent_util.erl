%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2020-, Ooma
%%% @doc Util functions for the inteliquent carrier integration.
%%% @author Ben Bradford, Hai Lei
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_inteliquent_util).

-export([request/3, request/4
        ,safe_request/2, safe_request/3, safe_request/4
        ,number/1
        ,set_config/1, set_config/2, set_a_config/3
        ,wrapped_account_set/4
        ]).

-include("knm.hrl").

-define(CARRIER, 'knm_inteliquent').
-define(MOD_CONFIG_CAT, <<(?KNM_CONFIG_CAT)/binary, ".inteliquent">>).

-define(KEY,kapps_config:get_string(?MOD_CONFIG_CAT, <<"key">>)).
-define(SECRET,kapps_config:get_string(?MOD_CONFIG_CAT, <<"secret">>)).
-define(USE_PRODUCTION(AccountId),kapps_account_config:get_global(AccountId, ?MOD_CONFIG_CAT, <<"use_production">>, 'false')).

-define(PRODUCTION_DOMAIN, "services.inteliquent.com").
-define(SANDBOX_DOMAIN, "services-sandbox.inteliquent.com").

%%------------------------------------------------------------------------------
%% @doc Rather than need to set configuration manually, call this and it will
%% do so. Generally only useful for testing or initial set-up, but it's nicer
%% than needing to manually create documents in the database. For setting for
%% a specific account, use `set_config/2'.
%% @end
%%------------------------------------------------------------------------------
-type api_key_config() :: {'api_key', kz_term:ne_binary()}.
-type api_secret_config() :: {'api_secret', kz_term:ne_binary()}.
-type use_production_config() :: {'use_production', boolean()}.
-type config_option() ::
        api_key_config() |
        api_secret_config() |
        use_production_config().
-spec set_config([ config_option() ]) -> kz_okko:okko(term(), config_option()).
set_config(ConfigOpts) ->
    kz_okko:foldl(fun set_a_config_by_opt/1, ConfigOpts).

%%------------------------------------------------------------------------------
%% @doc The meaty potatoes of above.
%% @end
%%------------------------------------------------------------------------------
-spec set_a_config_by_opt(config_option()) ->
          {'ok', {kz_term:ne_binary(), term()}} |
          {'error', term()}.
set_a_config_by_opt({'api_key', Key}) ->
    set_a_config('api_key', <<"key">>, Key);
set_a_config_by_opt({'api_secret', Secret}) ->
    set_a_config('api_secret', <<"secret">>, Secret);
set_a_config_by_opt({'use_production', Bool}) ->
    set_a_config('use_production', <<"use_production">>, Bool);
set_a_config_by_opt(Whatever) ->
    {'error', {'invalid_config_opt', Whatever}}.

%%------------------------------------------------------------------------------
%% @doc Set a single configuration value. The config key is any arbitrary term
%% used by the caller as an alias to the key. If you are calling this directly
%% (rather than it being called through `set_config/1') then it doesn't matter
%% what it is.
%% @end
%%------------------------------------------------------------------------------
-spec set_a_config(ConfigKey, kz_term:ne_binary(), Value) ->
          {'ok', {ConfigKey, Value}} |
          {'error', term()}
              when Value :: kz_json:json_term().
set_a_config(ConfigKey, Key, Value) ->
    case kapps_config:set_default(?MOD_CONFIG_CAT, Key, Value) of
        'ok' -> {'ok', {ConfigKey, Value}};
        {'ok', _} -> {'ok', {ConfigKey, Value}};
        Else -> Else
    end.

%%------------------------------------------------------------------------------
%% @doc Rather than set configuration by modifying the database directly, this
%% allows you to set it in 1 go. This is mainly to avoid typos in document names
%% or fields.
%% @end
%%------------------------------------------------------------------------------
-spec set_config(kz_term:ne_binary(), [ config_option()]) -> kz_okko:okko(term(), config_option()).
set_config(AccountId, ConfigOpts) ->
    kz_okko:foldl(set_account_config_fold(AccountId), ConfigOpts).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec set_account_config_fold(kz_term:ne_binary()) -> fun((config_option()) -> {'ok', {kz_term:ne_binary(), term()}} | {'error', term()}).
set_account_config_fold(AccountId) ->
    fun(ConfigOption) ->
            set_an_account_config(AccountId, ConfigOption)
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec set_an_account_config(kz_term:ne_binary(), config_option()) -> {'ok', {term(), term()}} | {'error', term()}.
set_an_account_config(AccountId, {'api_key', Key}) ->
    wrapped_account_set(AccountId, 'api_key', <<"key">>, Key);
set_an_account_config(AccountId, {'api_secret', Secret}) ->
    wrapped_account_set(AccountId, 'api_secret', <<"secret">>, Secret);
set_an_account_config(AccountId, {'use_production', Bool}) ->
    wrapped_account_set(AccountId, 'use_production', <<"use_production">>, Bool);
set_an_account_config(_AccountId, Whatever) ->
    {'error', {'invalid_config_opt', Whatever}}.

%%------------------------------------------------------------------------------
%% @doc Set a configuration for only the given account. The config tag is only
%% used for the return value.
%% @end
%%------------------------------------------------------------------------------
-spec wrapped_account_set(kz_term:ne_binary(), ConfigTag, kz_term:ne_binary(), Value) -> {'ok', {ConfigTag, Value}} | {'error', term()}.
wrapped_account_set(AccountId, ConfigTag, ConfigKey, ConfigValue) ->
    try kapps_account_config:set(AccountId, ?MOD_CONFIG_CAT, ConfigKey, ConfigValue) of
        _SomeJObj ->
            {'ok', {ConfigTag, ConfigValue}}
    catch
        What:Why ->
            lager:error("setting config ~s to ~p failed for account ~s failed due to crash: ~p:~p", [ConfigKey, ConfigValue, AccountId, What, Why]),
            {'error', #{ 'config' => {ConfigTag, ConfigValue}, 'crash' => {What, Why}}}
    end.

%%------------------------------------------------------------------------------
%% @doc Get the base url from the configuration. This allows a system to be
%% configured as either for testing or live without needing to re-compile the
%% code. The configuration is the property key of "use_production" with the
%% default of `false'. This means if one has not bothered to configure the
%% system for e911, it will not be contacting a real 911 system.
%%
%% Eventually this should be moved out of always contacting the database and
%% into `persistent_term', but that will only happen when we are on erlang 21+.
%% @end
%%------------------------------------------------------------------------------
-spec get_base_url(kz_term:api_ne_binary()) -> string().
get_base_url(AccountId) ->
    case ?USE_PRODUCTION(AccountId) of
        'true' ->
            "https://" ?PRODUCTION_DOMAIN "/Services/2.0.0/";
        'false' ->
            lager:warning("currently configured to use the sandbox for account ~s! To ensure the changes you make are properly saved, set '~s' to 'true'.", [AccountId, "number_manager.inteliquent -> use_production"]),
            "https://" ?SANDBOX_DOMAIN "/Services/2.0.0/";
        _NotBoolean ->
            lager:warning("the configured value for '~s' is not a boolean in either the account config for ~s or the system_config database. Update it to 'true' to use inqt's production service; we default to the sandbox.", ["number_manager.inteliquent -> use_production", AccountId]),
            "https://" ?SANDBOX_DOMAIN "/Services/2.0.0/"
    end.

-type malformed_return_body() :: {'malformed_return_body', kz_http:headers(), kz_http:http_body()}.
-type http_not_ok() :: {pos_integer(), kz_http:headers(), kz_http:http_body()}.
-type safe_return() ::
        {'ok', kz_json:object()} |
        {'error', malformed_return_body()} |
        {'error', 'saved_to_file'} |
        {'error', http_not_ok()} |
        {'error', term()}.

%%------------------------------------------------------------------------------
%% @doc Same as calling `safe_request/4' with the 3rd argument as an emtpy json
%% object, and the 4th arugment as `true'.
%% @end
%%------------------------------------------------------------------------------
-spec safe_request(kz_term:ne_binary(), [file:name_all()]) -> safe_return().
safe_request(AccountId, Path) ->
    safe_request(AccountId, Path, kz_json:new(), 'true').

%%------------------------------------------------------------------------------
%% @doc Same as calling `safe_request/4' with the 4th argument as `true'.
%% @end
%%------------------------------------------------------------------------------
-spec safe_request(kz_term:ne_binary(), [file:name_all()], kz_json:object()) -> safe_return().
safe_request(AccountId, Path, ReqJObj) ->
    safe_request(AccountId, Path, ReqJObj, 'true').

%%------------------------------------------------------------------------------
%% @doc Similar to `request/4', but does not make any assumptions about what to
%% do with the response beyond a basic json-decode. Thus why it doesn't take a
%% `Number' argument.
%%
%% The inqt api is bad.
%%
%% All requests are `post', even those that should just be a `get'.
%%
%% Many requests require a privateKey within the payload, but not all. The
%% effort required to make the api appealing so users of this module are not
%% burdened with needed to know useless information (like if the api key needs
%% to be in the request body _too_) is far beyond what is required at the time
%% this function was created. As such: I'm sorry.
%% @end
%%------------------------------------------------------------------------------
-spec safe_request(kz_term:ne_binary(), [file:name_all()], kz_json:object(), boolean()) -> safe_return().
safe_request(AccountId, Path, ReqJObj, AddApiKeyToBody) ->
    Url = url(AccountId, Path),
    Headers = http_headers(ReqJObj),
    Body = body(ReqJObj, AddApiKeyToBody, list_to_binary(?KEY)),
    Result = kz_http:post(Url, Headers, Body),
    massage_safe_result(Result).

url(AccountId, Path) ->
    BaseUrl = get_base_url(AccountId),
    JoinedAsBinary = filename:join(Path),
    Joined = binary_to_list(JoinedAsBinary),
    BaseUrl ++ Joined.

body(JObj, 'false', _) ->
    kz_json:encode(JObj);
body(JObj, 'true', ApiKey) ->
    NewObj = kz_json:set_value(<<"privateKey">>, ApiKey, JObj),
    body(NewObj, 'false', ApiKey).

massage_safe_result({'ok', 200, _Headers, ""}) ->
    {'ok', kz_json:new()};
massage_safe_result({'ok', 200, Headers, Body}) ->
    try kz_json:decode(Body) of
        JObj ->
            lager:debug("blerg and the response body is: ~p", [JObj]),
            MaybeStatusCode = kz_json:get_integer_value(<<"statusCode">>, JObj),
            MaybeStatusString = kz_json:get_binary_value(<<"status">>, JObj),
            massage_safe_result({'fake_ok', MaybeStatusCode, Headers, {MaybeStatusString, JObj}})
    catch
        'error':'badarg' ->
            {'error', {'malformed_return_body', Headers, Body}}
    end;
massage_safe_result({'ok', NotOk, Headers, Body}) ->
    DecodedError = try kz_json:decode(Body) of
                       JObj ->
                           JObj
                   catch
                       'error':'badarg' ->
                           Body
                   end,
    {'error', {'http_error', NotOk, Headers, DecodedError}};
massage_safe_result({'ok', 'saved_to_file'}) ->
    {'error', 'saved_to_file'};
massage_safe_result({'fake_ok', 200, _, JObj}) ->
    {'ok', JObj};
massage_safe_result({'fake_ok', NotOk, Headers, JObj}) ->
    {'error', {'http_error', NotOk, Headers, JObj}};
massage_safe_result({'error', _} = Result) ->
    Result.


%%------------------------------------------------------------------------------
%% @doc Send the API request to inteliquent and parse the response into a JObj.
%% Throw an error if the request is not successful.
%% @end
%%------------------------------------------------------------------------------
-spec request('post', [file:name_all()], kz_json:object()) ->
          kz_json:object() | no_return().
request('post', Path, ReqJObj) ->
    request('post', Path, ReqJObj, <<"unknown">>).

-spec request('post', [file:name_all()], kz_json:object(), kz_term:ne_binary() |  knm_number:knm_number()) ->
          kz_json:object() | no_return().
request('post', Path, ReqJObj, Number) ->
    Url = url('undefined', Path),
    Headers = http_headers(ReqJObj),
    Body = body(ReqJObj),
    lager:debug("api request to ~p with data ~p" , [Url, Body]),
    Resp =  kz_http:post(kz_term:to_list(Url), Headers, Body),
    process_response(Resp, Number).

%%------------------------------------------------------------------------------
%% @doc Construct the api request headers with basic auth.
%% @end
%%------------------------------------------------------------------------------
-spec http_headers(kz_json:object()) -> kz_term:proplist().
http_headers(BodyJObj) ->
    [{"Accept", "application/json"}
    ,{"Authorization", "Basic " ++ basic_auth()}
    ,{"User-Agent", ?KNM_USER_AGENT}
    | [{"Content-Type", "application/json"} || not kz_json:is_empty(BodyJObj)]
    ].

%%------------------------------------------------------------------------------
%% @doc Construct the api request body string by addign the private key for auth
%% and encoding the JObj.
%% @end
%%------------------------------------------------------------------------------
-spec body(kz_json:object()) -> kz_term:text().
body(JObj) ->
    UpdatedJObj = kz_json:set_value(<<"privateKey">>, kz_term:to_binary(?KEY), JObj),
    kz_json:encode(UpdatedJObj).

%%------------------------------------------------------------------------------
%% @doc Parse the API request response into a JObj.
%% Throw an error if the request was not successful.
%% @end
%%------------------------------------------------------------------------------
-spec process_response(kz_http:ret(), kz_term:ne_binary() |  knm_number:knm_number()) -> kz_json:object() | no_return().
process_response({'ok', Code, _Headers, <<"{",_/binary>>=Response}, Number) ->
    ResponseBody = kz_json:decode(Response),
    case kz_json:get_value(<<"status">>, ResponseBody) of
        <<"Success">> ->
            lager:debug("api request response: (~p) ~p" , [Code, ResponseBody]),
            ResponseBody;
        _Error ->
            lager:error("api request error: (~p) ~p" , [Code, ResponseBody]),
            knm_errors:by_carrier(?CARRIER, Code, Number)
    end;
process_response({'error', Reason}=_Error, Number) ->
    lager:error("api request error: ~p", [_Error]),
    knm_errors:by_carrier(?CARRIER, kz_term:to_binary(Reason), Number).

%%------------------------------------------------------------------------------
%% @doc Extract the number from a `knm_number:knm_number()'.
%% @end
%%------------------------------------------------------------------------------
-spec number(knm_number:knm_number()) -> kz_term:ne_binary().
number(KnmNumber) ->
    PhoneNumber = knm_number:phone_number(KnmNumber),
    knm_phone_number:number(PhoneNumber).



basic_auth() ->
    base64:encode_to_string(iolist_to_binary([?KEY, $:, ?SECRET])).
