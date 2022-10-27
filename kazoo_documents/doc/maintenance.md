## SUP-able functions

| Function | Arguments | Description |
| -------- | --------- | ----------- |
| `app/1` | `(AppNameOrId)` | |
| `fix_apps_store_SUPP_212/1` | `(AppId)` | |
| `fix_apps_store_SUPP_212/2` | `(AppId,SecondsToRelax)` | |
| `fix_apps_store_SUPP_212/3` | `(AppId,SecondsToRelax,WriteLoopLimit) | (AppIds,SecondsToRelax,WriteLoopLimit)` | |
| `apps/0` |  | |
| `init_app/1` | `(AppPath)` | |
| `init_app/2` | `(AppPath,AppUrl)` | |
| `init_apps/1` | `(AppsPath)` | |
| `init_apps/2` | `(AppsPath,AppUrl)` | |
| `refresh_app/1` | `(AppPath)` | |
| `refresh_app/2` | `(AppPath,AppUrl)` | |
| `refresh_apps/1` | `(AppsPath)` | |
| `refresh_apps/2` | `(AppsPath,AppUrl)` | |
| `set_app_description/2` | `(AppId,Value)` | |
| `set_app_extended_description/2` | `(AppId,Value)` | |
| `set_app_features/2` | `(AppId,Value)` | |
| `set_app_field/3` | `(AppId,Field,Value)` | |
| `set_app_icon/2` | `(AppId,PathToPNGIcon)` | |
| `set_app_label/2` | `(AppId,Value)` | |
| `set_app_screenshots/2` | `(AppId,PathToScreenshotsFolder)` | |


## `fix_apps_store_SUPP_212/1`, `fix_apps_store_SUPP_212/2`, `fix_apps_store_SUPP_212/3`

Fixes the problem introduced by `rename_app` command, by checking all apps_store docs in all accounts and check if the given app ids don't have the required field `allowed_users`.

The rename command was install the app for all accounts without checking first the account has the app or not. This also causes crashes in services run due to missing required field `allowed_users`.

Usage:

```
$ sup kazoo_documents_maintenance fix_apps_store_SUPP_212 {APP_ID}
$ sup kazoo_documents_maintenance fix_apps_store_SUPP_212 {APP_ID} {SecondsToRelax}
$ sup kazoo_documents_maintenance fix_apps_store_SUPP_212 {APP_ID} {SecondsToRelax} {WriteLoopLimit}
```

* `{APP_ID}`: ID of the app that causing the problem, required.
* `{SecondsToRelax}`: Optional, indicate how much to sleep between each loop in seconds, default is 10 seconds. Useful to let CouchDB cool down.
* `{WriteLoopLimit}`: Optional, indicate limit per loop, default is 200 Account DB per loop. Useful to let CouchDB to cool down and not exhausting the file descriptor in database rapidly.
