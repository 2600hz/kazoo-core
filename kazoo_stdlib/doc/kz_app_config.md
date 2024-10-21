# KAZOO App Config

When fetching configuration values, this module allows the preferred source of configuration data to be set.

## Getters

The module provides typed getter functions (for instance `get_pos_integer`) of arities 2 and 3.

The first argument is the Erlang application key (or `system_config` category ID) to locate the configuration data, or a tuple `{App, AccountId}` to indicate looking up an account's configuration of `App` first.

The second argument is the `key` which can either be a `binary()`, dot-delimited key (such as `<<"foo.bar">>`) which will be expanded to `[<<"foo">>, <<"bar">>]` or the list of binaries as the key path into the config.

The third argument is a default value to return if `Key` is not found in `App` config.

If a value is found (not the atom 'undefined'), the typed getter function will cast the value to the type denoted in the function name. If the value cannot be cast to the type, the `Default` third argument will be returned.

## Usage examples

```erlang
%% Get from app config
kz_app_config:get_ne_binary(?APP, Key, Default).

%% Get from account config
kz_app_config:get_boolean({?APP, kapps_call:account_id(Call)}, <<"should_check">>, 'true').
```

## Order of lookups

By default, `kapps_config` and `kapps_account_config` modules are used when getting config values.

The first task is to see if an account ID has been included. If so, fetch the account value. If not, fetch the system value.

If no account ID is included, use the app lookup function as described below.

### Account lookup

Using the `kz_account_config` persistent term (defaults to `kapps_account_config` when initialized by kazoo_apps or the local function `get_env` if not set) to get the getter function to use.

If `kapps_account_config` it will use `get_global` which checks the account DB first, then the `system_config` DB if needed (meaning does not walk the account or reseller tree).

### App lookup

Using the `kz_config` persistent term (defaults to `get_env` local function) to find the getter function.

### `get_env` local function

If the getter function is not defined in the persistent_term key, the `get_env` local function will be used.

The first place to query is the App's `env` key in the .app file (using `application:get_env/2`) and the `Key` (or account ID if using an account-specific lookup).

If the `env` doesn't have it, an app-specific JSON file can be loaded and checked. The persistent_term key is `app_settings_{APP}`. The value is a file path to be read off the local disk.

If the JSON file is found, it will be read in, decoded, and stored in persistent_term storage.

If no JSON file is consulted, the OS environment variables will be checked (via `os:getenv/2`). OS keys should be of the form `{APP}_{KEY1}_{KEY2}` and accessed via `kz_app_config:get_binary({APP}, [{KEY1}, {KEY2}])`.
