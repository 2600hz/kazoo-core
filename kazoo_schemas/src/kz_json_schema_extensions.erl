%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2014-2022, 2600Hz
%%% @doc Module for extending schema validation
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_json_schema_extensions).

-export([extra_validator/3]).

-include_lib("kernel/include/inet.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").

-include("kazoo_schemas.hrl").

-define(INVALID_STORAGE_ATTACHMENT_REFERENCE(R)
       ,<<"invalid reference '", R/binary, "' to attachments">>
       ).
-define(INVALID_STORAGE_CONNECTION_REFERENCE(R)
       ,<<"invalid reference '", R/binary, "' to connections">>
       ).

%% options about whether and how to validate hosts (like HTTP servers
%% or SIP realms)
-type host_validation_options() :: #{ip => boolean()
                                    ,dns => boolean()
                                    ,port => boolean()
                                    }.

-spec extra_validator(jesse:json_term(), jesse_state:state(), kz_json_schema:extra_validator_options()) -> jesse_state:state().
extra_validator(Value, State, Options) ->
    Routines = [fun stability_level/3
               ,fun extended_validation/3
               ,fun extended_regexp/3
               ],
    lists:foldl(fun(Fun, AccState) -> Fun(Value, AccState, Options) end, State, Routines).

-spec extended_regexp(jesse:json_term(), jesse_state:state(), kz_json_schema:extra_validator_options()) -> jesse_state:state().
extended_regexp(Value, State, _Options) ->
    Schema = jesse_state:get_current_schema(State),
    case kz_json:is_true(<<"kazoo-regexp">>, Schema, 'false') of
        'true' -> regexp_validation(Value, State);
        'false' -> State
    end.

-spec regexp_validation(jesse:json_term(), jesse_state:state()) -> jesse_state:state().
regexp_validation(Value, State) ->
    case re:compile(Value) of
        {'error', _Reason} ->
            ErrMsg = <<"invalid regular expression: '", Value/binary,"'">>,
            jesse_error:handle_data_invalid({'external_error', ErrMsg}, Value, State);
        _ ->
            State
    end.

-spec extended_validation(jesse:json_term(), jesse_state:state(), kz_json_schema:extra_validator_options()) -> jesse_state:state().
extended_validation(Value, State, _Options) ->
    Schema = jesse_state:get_current_schema(State),
    case kz_json:is_true(<<"kazoo-validation">>, Schema, 'false') of
        'true' -> extra_validation(Value, State);
        'false' -> State
    end.

-spec extra_validation(jesse:json_term(), jesse_state:state()) -> jesse_state:state().
extra_validation(Value, State) ->
    SchemaId = jesse_state:get_current_schema_id(State),
    Path = lists:reverse(jesse_state:get_current_path(State)),

    ElementId = kz_term:to_binary(lists:last(Path)),
    Keys = [SchemaId, ElementId],
    Key = kz_binary:join(lists:filter(fun kz_term:is_not_empty/1, Keys), <<".">>),
    lager:info("extra for ~p : ~p", [Key, Value]),
    extra_validation(Key, Value, State).

extra_validation(<<"metaflow.data">>, Value, State) ->
    JObj = jesse_state:get_current_value(State),
    [_Data | Path] = jesse_state:get_current_path(State),
    Module = jesse_json_path:path(lists:reverse([<<"module">> | Path]), JObj, 'undefined'),
    lager:debug("validating metaflow action '~s' with data ~p", [Module, Value]),
    validate_module_data(<<"metaflows.", Module/binary>>, Value, State);

extra_validation(<<"metaflow.module">>, Value, State) ->
    lager:debug("validating metaflow action '~s'", [Value]),
    Schema = <<"metaflows.", Value/binary>>,
    State1 = jesse_state:resolve_ref(State, Schema),
    State2 = case jesse_state:get_current_schema_id(State1) of
                 Schema -> State1;
                 _OtherSchema -> jesse_error:handle_data_invalid({'external_error', <<"unable to find metaflow schema for module ", Value/binary>>}, Value, State)
             end,
    jesse_state:undo_resolve_ref(State2, State);
extra_validation(<<"callflows.action.data">>, Value, State) ->
    JObj = jesse_state:get_current_value(State),
    [_Data | Path] = jesse_state:get_current_path(State),
    case jesse_json_path:path(lists:reverse([<<"module">> | Path]), JObj, 'undefined') of
        'undefined' -> State;
        Module -> validate_module_data(<<"callflows.", Module/binary>>, Value, State)
    end;
extra_validation(<<"callflows.action.module">>, Value, State) ->
    Schema = <<"callflows.", Value/binary>>,
    State1 = jesse_state:resolve_ref(State, Schema),
    State2 = case jesse_state:get_current_schema_id(State1) of
                 Schema -> State1;
                 _OtherSchema -> jesse_error:handle_data_invalid({'external_error', <<"unable to find callflow schema for module ", Value/binary>>}, Value, State)
             end,
    jesse_state:undo_resolve_ref(State2, State);
extra_validation(<<"webhooks.uri">>, URL, State) ->
    url_validation(URL, State);
extra_validation(<<"callflows.webhook.uri">>, URL, State) ->
    url_validation(URL, State);
extra_validation(<<"callflows.pivot.voice_url">>, URL, State) ->
    url_validation(URL, State);
extra_validation(<<"callflows.record_caller.url">>, URL, State) ->
    storage_url_validation(URL, State);
extra_validation(<<"callflows.record_call.url">>, URL, State) ->
    storage_url_validation(URL, State);
extra_validation(<<"metaflows.pivot.voice_url">>, URL, State) ->
    url_validation(URL, State);
extra_validation(<<"metaflows.record_call.url">>, URL, State) ->
    storage_url_validation(URL, State);
extra_validation(<<"call_recording.parameters.url">>, URL, State) ->
    storage_url_validation(URL, State);
extra_validation(<<"faxbox.notifications.inbound.callback.url">>, URL, State) ->
    url_validation(URL, State);
extra_validation(<<"faxbox.notifications.outbound.callback.url">>, URL, State) ->
    url_validation(URL, State);
extra_validation(<<"storage.attachment.http.url">>, URL, State) ->
    url_validation(URL, State);
extra_validation(<<"resources.server">>, URL, State) ->
    case is_valid_sip_host(URL) of
        'true' -> State;
        'false' -> url_error(URL, State)
    end;
extra_validation(<<"resources.realm">>, URL, State) ->
    case is_valid_sip_host(URL) of
        'true' -> State;
        'false' -> url_error(URL, State)
    end;
extra_validation(<<"storage.plan.database.document.connection">>, Value, State) ->
    JObj = jesse_state:get_current_value(State),
    Keys = kz_json:get_keys(<<"connections">>, JObj),
    case lists:member(Value, Keys) of
        'true' -> State;
        'false' -> jesse_error:handle_data_invalid({'external_error' ,?INVALID_STORAGE_CONNECTION_REFERENCE(Value)}
                                                  ,Value
                                                  ,State
                                                  )
    end;
extra_validation(<<"storage.plan.database.attachment.handler">>, Value, State) ->
    JObj = jesse_state:get_current_value(State),
    Keys = kz_json:get_keys(<<"attachments">>, JObj),
    case lists:member(Value, Keys) of
        'true' -> State;
        'false' -> jesse_error:handle_data_invalid({'external_error', ?INVALID_STORAGE_ATTACHMENT_REFERENCE(Value)}
                                                  ,Value
                                                  ,State
                                                  )
    end;
extra_validation(<<"storage.attachment.google_drive.oauth_doc_id">>, Value, State) ->
    validate_attachment_oauth_doc_id(Value, State);
extra_validation(<<"storage.attachment.google_storage.oauth_doc_id">>, Value, State) ->
    validate_attachment_oauth_doc_id(Value, State);
extra_validation(<<"storage.attachment.onedrive.oauth_doc_id">>, Value, State) ->
    validate_attachment_oauth_doc_id(Value, State);
extra_validation(<<"storage.attachment.dropbox.oauth_doc_id">>, Value, State) ->
    validate_attachment_oauth_doc_id(Value, State);
extra_validation(_Key, _Value, State) ->
    lager:info("extra validation of ~s not handled for value ~p", [_Key, _Value]),
    State.

validate_module_data(Schema, Value, State) ->
    State1 = jesse_state:resolve_ref(State, Schema),
    State2 = case jesse_state:get_current_schema_id(State1) of
                 Schema ->
                     SchemaObj = jesse_state:get_current_schema(State1),
                     jesse_schema_validator:validate_with_state(SchemaObj, Value, State1);
                 _OtherSchema -> State1
             end,
    jesse_state:undo_resolve_ref(State2, State).

validate_attachment_oauth_doc_id(Value, State) ->
    lager:debug("validating oauth_doc_id: ~s", [Value]),
    case kz_datamgr:open_doc(<<"system_auth">>, Value) of
        {'ok', _Obj} ->
            State;
        {'error', 'empty_doc_id'} ->
            ErrorMsg = <<"empty oauth_doc_id">>,
            jesse_error:handle_data_invalid({'external_error', ErrorMsg}, Value, State);
        {'error', 'not_found'} ->
            ErrorMsg = <<"Invalid oauth_doc_id: ", Value/binary>>,
            lager:debug("~s", [ErrorMsg]),
            jesse_error:handle_data_invalid({'external_error', ErrorMsg}, Value, State);
        {'error', _Err} ->
            ErrorMsg = <<"Error validating oauth_doc_id: ", Value/binary>>,
            lager:debug("~s : ~p", [ErrorMsg, _Err]),
            jesse_error:handle_data_invalid({'external_error', ErrorMsg}, Value, State)
    end.

-spec stability_level(jesse:json_term(), jesse_state:state(), kz_json_schema:extra_validator_options()) -> jesse_state:state().
stability_level(Value, State, Options) ->
    Schema = jesse_state:get_current_schema(State),
    SystemSL = props:get_ne_binary_value('stability_level', Options),
    ParamSL = kz_json:get_value(<<"stability_level">>, Schema),
    maybe_check_param_stability_level(SystemSL, ParamSL, Value, State).

maybe_check_param_stability_level('undefined', _ParamSL, _Value, State) ->
    State; %% SystemSL is undefined, skip checking
maybe_check_param_stability_level(_SystemSL, 'undefined', _Value, State) ->
    State; %% ParamSL is undefined, skip checking
maybe_check_param_stability_level(SystemSL, ParamSL, Value, State) ->
    SystemSLInt = stability_level_to_int(SystemSL),
    ParamSLInt = stability_level_to_int(ParamSL),
    case check_param_stability_level(SystemSLInt, ParamSLInt) of
        'valid' ->
            State;
        'invalid' ->
            ErrorMsg = <<"Disallowed parameter, it has lower stability level ("
                        ,ParamSL/binary, ") than system's stability level ("
                        ,SystemSL/binary, ")"
                       >>,
            lager:debug("~s", [ErrorMsg]),
            jesse_error:handle_data_invalid({'external_error', ErrorMsg}, Value, State)
    end.

check_param_stability_level(SystemSLInt, ParamSLInt) when ParamSLInt < SystemSLInt ->
    'invalid';
check_param_stability_level(_SystemSLInt, _ParamSLInt) ->
    'valid'.

-spec stability_level_to_int(kz_term:ne_binary()) -> pos_integer().
stability_level_to_int(<<"stable">>) -> 3;
stability_level_to_int(<<"beta">>) -> 2;
stability_level_to_int(<<"alpha">>) -> 1.

url_validation(URL, State) ->
    case is_valid_client_url(URL) of
        'true' -> State;
        'false' -> url_error(URL, State)
    end.

storage_url_validation(<<"http", _/binary>>=URL, State) ->
    url_validation(URL, State);
storage_url_validation(<<"ftp", _/binary>>=URL, State) ->
    case is_valid_ftp_url(URL) of
        'true' -> State;
        'false' -> url_error(URL, State)
    end;
storage_url_validation(<<"sftp", _/binary>>=URL, State) ->
    case is_valid_sftp_url(URL) of
        'true' -> State;
        'false' -> url_error(URL, State)
    end;
storage_url_validation(URL, State) ->
    url_error(URL, State).

is_valid_client_url({Scheme, Host, _Path, _QueryString, _Fragment}) ->
    lists:all(fun is_valid_url_part/1
             ,[{fun is_valid_scheme/1, Scheme}
              ,{fun is_valid_host/1, Host}
              ]
             );
is_valid_client_url(<<URL/binary>>) ->
    is_valid_client_url(kz_http_util:urlsplit(URL)).

is_valid_url_part({Fun, Part}) ->
    Fun(Part).

is_valid_scheme(<<"http">>) -> 'true';
is_valid_scheme(<<"https">>) -> 'true';
is_valid_scheme(_) -> 'false'.

is_valid_ftp_url(#{scheme := "ftp", host := Host}) ->
    is_valid_host(kz_term:to_binary(Host));
is_valid_ftp_url(#{scheme := "ftps", host := Host, userinfo := UserPass}) ->
    lists:all(fun is_valid_url_part/1
             ,[{fun is_valid_ftp_userpass/1, string:tokens(UserPass, ":")}
              ,{fun is_valid_host/1, kz_term:to_binary(Host)}
              ]
             );
is_valid_ftp_url(<<URL/binary>>) ->
    is_valid_ftp_url(uri_string:parse(kz_term:to_list(URL)));
is_valid_ftp_url(_URL) ->
    'false'.

is_valid_sftp_url(#{scheme := "sftp", host := Host, userinfo := UserPass}) ->
    lists:all(fun is_valid_url_part/1
             ,[{fun is_valid_ftp_userpass/1, string:tokens(UserPass, ":")}
              ,{fun is_valid_host/1, kz_term:to_binary(Host)}
              ]
             );
is_valid_sftp_url(<<URL/binary>>) ->
    is_valid_sftp_url(uri_string:parse(kz_term:to_list(URL)));
is_valid_sftp_url(_URL) ->
    'false'.

is_valid_ftp_userpass([_User, _Pass]) -> 'true';
is_valid_ftp_userpass(_) -> 'false'.

is_valid_sip_host(<<"sip:", _/binary>>=URI) ->
    case kzsip_uri:uris(URI) of
        'error' ->
            lager:info("invalid host '~s', unable to parse", [URI]),
            'false';
        [SIPURI] ->
            lager:info("parsed URI: ~p", [SIPURI]),
            Host = kzsip_uri:host(SIPURI),
            lager:info("got URI host ~s", [Host]),
            is_valid_sip_host(Host, kapps_config:is_true(?CONFIG_CAT, <<"validate_sip_hosts">>, 'true'))
    end;
is_valid_sip_host(Host) ->
    lager:info("turning host '~s' into SIP URI", [Host]),
    is_valid_sip_host(<<"sip:nouser@", Host/binary>>).

is_valid_sip_host(Host, 'true') ->
    is_valid_host(Host, #{ip => 'true', dns => 'true'});
is_valid_sip_host(_Host, 'false') ->
    'true'.

-spec is_valid_host(kz_http_util:location() | inet:ip_address()) -> boolean().
is_valid_host(Host) ->
    is_valid_host(Host, #{ip => 'true', dns => 'true'}).

-spec is_valid_host(kz_http_util:location() | inet:ip_address(), host_validation_options()) -> boolean().
is_valid_host(_Host, #{ip := 'false', dns := 'false'}) ->
    lager:debug("configured not to validate hosts, allowing ~s", [_Host]),
    'true';
is_valid_host(<<Host/binary>>, ValidationOptions) ->
    is_valid_host(kz_term:to_lower_binary(Host), kz_network_utils:is_ip(Host), ValidationOptions);
is_valid_host({Host, Port}, ValidationOptions) when is_integer(Port) ->
    is_valid_host(Host, ValidationOptions)
        andalso is_valid_port(Port, ValidationOptions);
is_valid_host({Host, _Username, _Password}, ValidationOptions) ->
    is_valid_host(Host, ValidationOptions);
is_valid_host(?IPV4=IP, ValidationOptions) ->
    is_valid_host(kz_network_utils:iptuple_to_binary(IP), ValidationOptions);
is_valid_host(?IPV6=IP, ValidationOptions) ->
    is_valid_host(kz_network_utils:iptuple_to_binary(IP), ValidationOptions).

-spec is_valid_host(kz_term:ne_binary(), boolean(), host_validation_options()) -> boolean().
is_valid_host(Host, 'true', ValidationOptions) ->
    is_valid_host_value(Host, 'true', kz_http_util:client_ip_blacklist(), ValidationOptions);
is_valid_host(Host, 'false', #{dns := ValidateDNS}=ValidationOptions) ->
    is_valid_host_value(Host, 'false', kz_http_util:client_host_blacklist(), ValidationOptions)
        andalso is_valid_dns(Host, ValidateDNS).

url_error(URL, State) ->
    lager:info("client URL '~s' not valid", [URL]),
    jesse_error:handle_data_invalid({'external_error', <<"invalid client URL">>}, URL, State).

-spec is_valid_host_value(kz_term:ne_binary(), boolean(), kz_term:api_ne_binaries(), host_validation_options()) -> boolean().
is_valid_host_value(_Host, _IsIp, 'undefined', _ValidationOptions) -> 'true';
is_valid_host_value(_Host, 'true', _Blacklist, #{ip := 'false'}) ->
    lager:debug("not configured to validate IPs, allowing ~s", [_Host]),
    'true';
is_valid_host_value(Host, IsIp, Blacklist, ValidationOptions) ->
    not lists:any(fun(B) -> is_host_blacklisted(Host, IsIp, B, ValidationOptions) end, Blacklist).

is_host_blacklisted(Host, _IsIp, Host, _ValidationOptions) ->
    lager:debug("host matches blacklisted value ~s", [Host]),
    'true';
is_host_blacklisted(Host, 'true', CIDR, #{ip := 'true'}) ->
    %% Host is an IP address, check CIDRS
    is_host_blacklisted_cidr(Host, CIDR)
        orelse is_host_blacklisted_restricted_ip(Host);
is_host_blacklisted(Host, 'false', Host, _ValidationOptions) ->
    %% Host is a hostname that matches a blacklisted host
    lager:info("host ~s is restricted by config", [Host]),
    'true';
is_host_blacklisted(_Host, 'false', _BlockedHost, _ValidationOptions) ->
    %% Host is not blacklisted
    'false'.

is_host_blacklisted_cidr(Host, CIDR) ->
    case kz_network_utils:verify_cidr(Host, CIDR) of
        'false' -> 'false';
        'true' ->
            lager:info("host ~s is part of restricted CIDR ~s", [Host, CIDR]),
            'true'
    end.

is_host_blacklisted_restricted_ip(Host) ->
    is_host_blacklisted_restricted_ip(Host
                                     ,kapps_config:is_true(<<"kazoo_web">>, <<"allow_restricted_ips">>, 'true')
                                     ).

is_host_blacklisted_restricted_ip(_Host, 'true') -> 'false';
is_host_blacklisted_restricted_ip(Host, 'false') ->
    case kz_network_utils:is_restricted_ip(Host) of
        'false' -> 'false';
        'true' ->
            lager:info("host ~s is part of restricted IP space", [Host]),
            'true'
    end.

is_valid_port(Port, ValidationOptions) ->
    is_valid_port(Port, ValidationOptions, kz_http_util:client_port_blacklist()).

-spec is_valid_port(inet:port_number(), host_validation_options(), [inet:port_number()]) -> boolean().
is_valid_port(Port, #{port := 'true'}, BlockedPorts) ->
    case lists:member(Port, BlockedPorts) of
        'false' -> 'true';
        'true' ->
            lager:info("port ~p is blocked via configuration", [Port]),
            'false'
    end;
is_valid_port(_Port, _ValidationOptions, _BlockedPorts) ->
    'true'.

-ifdef(TEST).
%% when running local tests don't check DNS for hostnames
is_valid_dns(_Host, _Bool) -> 'true'.
-else.

-spec is_valid_dns(kz_term:ne_binary(), boolean()) -> boolean().
is_valid_dns(Host, 'false') ->
    lager:debug("this cluster is not validating DNS, accepting ~s", [Host]),
    'true';
is_valid_dns(Host, 'true') ->
    Options = kz_network_utils:default_options(),

    LookupOptions =
        case kz_network_utils:find_nameservers(Host) of
            [] -> Options;
            Nameservers ->
                lager:info("adding nameservers for ~s: ~p", [Host, Nameservers]),
                kz_network_utils:set_option_nameservers(Options, Nameservers)
        end,

    case kz_network_utils:lookup_dns(kz_binary:remove_white_spaces(Host), 'a', LookupOptions) of
        {'ok', []} ->
            maybe_local_dns(Host);
        {'ok', Lookup} ->
            lists:all(fun is_valid_host/1, Lookup)
    end.

maybe_local_dns(Host) ->
    HostL = kz_term:to_list(Host),
    case inet:gethostbyname(HostL) of
        {'ok', #hostent{h_name = HostL,
                        h_addrtype = 'inet',
                        h_length = 4,
                        h_addr_list = [?IPV4=IP|_]
                       }
        } ->
            lager:info("host ~s defined locally as ~p", [Host, IP]),
            is_valid_host(IP);
        {'ok', _HostEnt} ->
            lager:info("got a host rec but didn't match ~s: ~p", [Host, _HostEnt]),
            'false';
        {'error', 'nxdomain'} ->
            lager:info("no DNS setup (nxdomain) for ~s", [Host]),
            'false';
        {'error', _E} ->
            lager:info("failed to get DNS for host ~s: ~p", [Host, _E]),
            'false'
    end.
-endif.
