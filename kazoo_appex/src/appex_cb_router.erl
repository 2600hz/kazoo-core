%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(appex_cb_router).
-behaviour(cowboy_rest).
-include_lib("kazoo_stdlib/include/kz_types.hrl").

%% Get things into position
-export([start_link/0
        ,stop_link/0
        ,route_paths/0
        ,source_url/2

        ,assets_dir/2, asset_path/3
        ]).

%% Cowboy REST callbacks
%% These service requests made the a UI app's source_url, overridden
%% by the appex_client wrapper given to each UI app
-export([init/2
        ,allowed_methods/2
        ,content_types_provided/2
        ,resource_exists/2
        ,to_response/2
        ]).

%% {PathMatch, Handler, InitialState}
%% {PathMatch, Constraints, Handler, InitialState}
-type cowboy_paths() :: list().

-spec start_link() -> 'ignore'.
start_link() ->
    lager:info("starting UI asset router"),
    Handlers = lists:usort([kz_term:to_binary(?MODULE)
                           | kapps_config:get_ne_binaries(<<"crossbar">>, <<"cowboy_custom_routes_handlers">>, [])
                           ]
                          ),
    _ = kapps_config:set(<<"crossbar">>, <<"cowboy_custom_routes_handlers">>, Handlers),
    'ignore'.

-spec stop_link() -> 'ok'.
stop_link() ->
    'ok'.

-spec route_paths() -> cowboy_paths().
route_paths() ->
    [{<<"/ui/[...]">>, ?MODULE, []}].

%% @doc APIUrl should be scheme://host:port/v2
%% returns scheme://host:port/ui/{APP-Vsn}
-spec source_url(kz_term:ne_binary(), kz_term:ne_binary()) ->
          kz_term:ne_binary().
source_url(<<APIUrl/binary>>, <<AppDir/binary>>) ->
    binary:replace(kz_http_util:uri(APIUrl, [AppDir]), <<"v2">>, <<"ui">>).

-spec assets_dir(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:ne_binary().
assets_dir(BasePath, AppDir) ->
    filename:join([BasePath, AppDir, "priv", "assets"]).

-spec asset_path(kz_term:ne_binary(), kz_term:ne_binary(), file:name_all()) -> kz_term:ne_binary().
asset_path(BasePath, AppDir, "/priv/assets/"++AssetFile) ->
    asset_path(BasePath, AppDir, AssetFile);
asset_path(BasePath, AppDir, <<"/priv/assets/", AssetFile/binary>>) ->
    asset_path(BasePath, AppDir, AssetFile);
asset_path(BasePath, AppDir, "priv/assets/"++AssetFile) ->
    asset_path(BasePath, AppDir, AssetFile);
asset_path(BasePath, AppDir, <<"priv/assets/", AssetFile/binary>>) ->
    asset_path(BasePath, AppDir, AssetFile);
asset_path(BasePath, AppDir, AssetFile) ->
    filename:join([assets_dir(BasePath, AppDir), AssetFile]).

%% the app's asset filepath
-type context() :: file:filename_all() | 'undefined'.

%% @doc initialize Cowboy REST routing
-spec init(cowboy_req:req(), kz_term:proplist()) ->
          {'cowboy_rest', cowboy_req:req(), context()}.
init(Req, _Opts) ->
    lager:info("~s: ~s?~s from ~s"
              ,[cowboy_req:method(Req)
               ,cowboy_req:path(Req)
               ,kz_term:to_binary(cowboy_req:qs(Req))
               ,get_client_ip(Req)
               ]
              ),
    {'cowboy_rest', Req, 'undefined'}.

-spec get_client_ip(cowboy_req:req()) -> kz_term:ne_binary().
get_client_ip(Req) ->
    {Peer, _PeerPort} = cowboy_req:peer(Req),
    case cowboy_req:header(<<"x-forwarded-for">>, Req) of
        'undefined' -> <<"ip ", (kz_network_utils:iptuple_to_binary(Peer))/binary>>;
        ForwardIP ->
            <<"x-forward-for ", ForwardIP/binary, " and peer ip ", (kz_network_utils:iptuple_to_binary(Peer))/binary>>
    end.

-spec allowed_methods(cowboy_req:req(), context()) ->
          {[binary()], cowboy_req:req(), context()}.
allowed_methods(Req, Context) ->
    {[<<"GET">>, <<"OPTIONS">>], Req, Context}.

%% @doc /ui/{App-Vsn}/path/to/asset.foo => priv/assets/{App-Vsn}/path/to/asset.foo
-spec resource_exists(cowboy_req:req(), context()) ->
          {boolean(), cowboy_req:req(), context()}.
resource_exists(Req, Context) ->
    case cowboy_req:path_info(Req) of
        [AppDir | AssetPath] ->
            resource_exists(Req, Context, AppDir, AssetPath);
        _Parts ->
            lager:info("invalid path_info ~p", [_Parts]),
            {'false', Req, Context}
    end.

%% @doc verify the URI path is valid, the app exists, and the asset exists
-spec resource_exists(cowboy_req:req(), context(), kz_term:ne_binary(), kz_term:ne_binaries()) ->
          {boolean(), cowboy_req:req(), context()}.
resource_exists(Req, _Context, AppDir, AssetPath) ->
    AssetFilename = asset_path(appex_bluepak:base_path(), AppDir, filename:join(AssetPath)),
    lager:info("looking for asset in ~s", [AssetFilename]),
    case filelib:is_regular(AssetFilename) of
        'false' -> {'false', Req, AssetFilename};
        'true' ->
            ContentType = kz_mime:from_filename(AssetFilename),
            lager:info("content type for ~s: ~s", [AssetFilename, ContentType]),
            Headers = [{<<"access-control-allow-origin">>, <<"*">>}
                      ,{<<"access-control-allow-methods">>, <<"GET">>}
                      ,{<<"access-control-allow-headers">>, <<"content-type, depth, user-agent, x-http-method-override, x-file-size, x-requested-with, if-modified-since, x-file-name, cache-control, x-auth-token, x-kazoo-cluster-id, if-match, authorization">>}
                      ,{<<"access-control-expose-headers">>, <<"content-type, x-auth-token, x-request-id, x-kazoo-cluster-id, location, etag">>}
                      ,{<<"access-control-max-age">>, kz_term:to_binary(?SECONDS_IN_DAY)}
                      ,{<<"content-type">>, ContentType}
                      ],
            {'true'
            ,cowboy_req:set_resp_headers(maps:from_list(Headers), Req)
            ,AssetFilename
            }
    end.

-spec content_types_provided(cowboy_req:req(), context()) ->
          {[{{binary(), binary(), '*'}, atom()}], cowboy_req:req(), context()}.
content_types_provided(Req, Context) ->
    {[{{<<"*">>, <<"*">>, '*'}, 'to_response'}], Req, Context}.

-spec to_response(cowboy_req:req(), context()) ->
          {{'sendfile', 0, pos_integer(), context()}, cowboy_req:req(), context()}.
to_response(Req, AssetFilename) ->
    Len = filelib:file_size(AssetFilename),
    {{'sendfile', 0, Len, AssetFilename}, Req, AssetFilename}.
