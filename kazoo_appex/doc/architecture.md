# Appex Client Architecture

When the `appex_client` Erlang application is started, a supervisor and a couple workers are started.

## `appex_client_client`

The HTTP client that communicates with the configured app exchange server API.

## `kappex_controller`

On start up, the process binds itself into `kapps_controller` for fetching apps. When `kapps_controller` cannot find an Erlang application when asked to start it, a routing request will be issued for help (`app.fetch` binding). `kappex_controller` binds for those and, if possible, fetches the app (if the cluster has a subscription to the app) and unpack the archive file make it ready to be started.

If the app is not yet download, a request will be issued to the appex server for access to the Erlang application.

## UI Asset wrapper OTP App

Appex BluePAK is creating a standard Erlang/OTP to wrap the UI. This wrapper app includes a module to integrate the Crossbar
to serve the UI assets file over HTTP to clients.

On startup this module register an extra custom route to the Crossbar, providing a callback so when Crossbar starts on this node, it will adds appex to the running HTTP server routes.

When an UI app starts, the wrapper app will set the app's `metadata.json` paramerter `source_url`. This will allows Monster UI to fetch the app from the route that appex client is set up.
