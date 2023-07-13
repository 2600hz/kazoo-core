## SUP Commands for Kazoo UI Application Maintenance

This is SUP command maintenance module to work specifically with new Kazoo UI Application
document.

For old legacy maintenance commands please refer to [Kazoo Document
Maintenance](./kazoo_ui_apps_maintenance.md).

| Function | Arguments | Description |
| -------- | --------- | ----------- |
| `init_app/1` | `(AppPath)` | |
| `init_app/2` | `(AppPath,ApiUrl)` | |
| `init_apps/1` | `(AppsPath)` | |
| `init_apps/2` | `(AppsPath,ApiUrl)` | |
| `refresh_app/1` | `(AppPath)` | |
| `refresh_app/2` | `(AppPath,ApiUrl)` | |
| `refresh_apps/1` | `(AppsPath)` | |
| `refresh_apps/2` | `(AppsPath,ApiUrl)` | |

# Initializing or Refreshing Apps

> **NOTE** These commands are only for legacy proposes, we recommend to use the API to
> initialize or refresh UI apps metadata or use 2600Hz Marketplace

This is simple version of the old `init_apps` but for new UI application docs. It will
search a path to find apps to read its `metadata/app.json` file. Then for each metadata
found it will check the master account db and either create the new doc if it is missing or
merge and update it. It also deletes and re-upload all images (icon and screenshots).

> **NOTE** Please note that new `app.json` requires `_id` field. This is a unique ID for
> the app across all platforms. 2600Hz Marketplace will generate a universal unique ID for
> the app.

- `init_apps/1,2`: equivalent of calling `refresh_apps/1,2`
- `init_app/1,2`: equivalent of calling `refresh_app/1,2`
- `refresh_apps/1,2`: search for all apps under the `AppsPath`, calling `refresh_app/2` for each app
- `refresh_apps/1,2`: will read the app's metadata and either create or update it in  account db


