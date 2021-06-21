## SUP-able functions

| Function | Arguments | Description |
| -------- | --------- | ----------- |
| `app/1` | `(AppNameOrId)` | |
| `apps/0` |  | |
| `init_app/1` | `(AppPath)` | |
| `init_app/2` | `(AppPath,AppUrl)` | |
| `init_apps/1` | `(AppsPath)` | |
| `init_apps/2` | `(AppsPath,AppUrl)` | |
| `refresh_app/1` | `(AppPath)` | |
| `refresh_app/2` | `(AppPath,AppUrl)` | |
| `refresh_apps/1` | `(AppsPath)` | |
| `refresh_apps/2` | `(AppsPath,AppUrl)` | |
| `rename_and_refresh_app/2` | `(AppPath,PrevName)` | |
| `rename_and_refresh_app/3` | `(AppPath,PrevName,AppUrl)` | |
| `rename_app/4` | `(AppId,PrevName,NewName,AccountId) | (AppId,PrevName,NewName,_) | (_AppId,_PrevName,_NewName,[])` | |
| `set_app_description/2` | `(AppId,Value)` | |
| `set_app_extended_description/2` | `(AppId,Value)` | |
| `set_app_features/2` | `(AppId,Value)` | |
| `set_app_field/3` | `(AppId,Field,Value)` | |
| `set_app_icon/2` | `(AppId,PathToPNGIcon)` | |
| `set_app_label/2` | `(AppId,Value)` | |
| `set_app_screenshots/2` | `(AppId,PathToScreenshotsFolder)` | |
