# CouchDB views

Some random stuff about CouchDB views in Data Manager. Since Data Manager 4.3+, the way that views are read for creating
new database or refreshing existing views has been changed.

## Create and registering the design documents

For creating read the CouchDB doc:

- [Introduction to Views](https://docs.couchdb.org/en/stable/ddocs/views/intro.html)
- [Design Documents](https://docs.couchdb.org/en/stable/ddocs/ddocs.html) Reference
- Learn about [View Collation](https://docs.couchdb.org/en/stable/ddocs/views/collation.html)

It is expected for you to create each design documents in the same format that it gets saved into database. This
includes having `_id` parameter too.

### Registering views

Previously the design documents was read from each apps folder for saving and refresh. But now it is expected the apps
to _register_ all of their design docs in app startup to be saved in a system database. Data Manager will use that
system database to get the list of design documents to be save/refreshed for a database.

You design document JSON files MUST have `kazoo` parameter. Data Manager will use the info provided in this section to
determine how to save the design document into `system_data` and which databases this view must be saved/refreshed.

After creating the design document file and added `kazoo` parameters, to register the view call either for these
functions in your application module during start:

- `kz_datamgr:register_view/2`: This accepts the application name as `atom` as first argument, and either the design doc
  path (relative to `priv/couchdb`) or its full `JObj` as `{_DocId, JObj}`
- `kz_datamgr:register_views/2`: Same as above, except it accepts a list of views (relative file path or full `JObj`) as
  second argument
- `kz_datamgr:register_views_from_folder/2`: You most commonly want to use this, will accept a path to a directory as
  second argument and will read and register any JSON file in that directory.
- `kz_datamgr:register_views_from_folder/1`: Equivalent to `kz_datamgr:register_views_from_folder(App, "views")`

We highly suggest to add this to your maintenance commands module to it is callable by system admins during runtime.

After the registration, then time `kapps_mainentece:refresh/{0,1}` runs, it will use the registered views.

#### `kazoo` parameters

This parameters defines only `view_map`, which is a list of JSON , describing which databases must have this design
document.

For example, the following will save the `_design/haha_you_fooled` to only `accounts` database:

```json
{
  "_id": "_design/haha_you_fooled",
  "kazoo": {
    "view_map": [
      {
        "database": "accounts"
      }
    ]
  }
}
```

Each JSON object of the `view_map` can have **only ONE** of the these keys:

- `classification`: The classification of the databases that must ave this design document
- `database`: The actual name of the database to put this design document

You can multiple `view_map[]` objects, but **NEVER** have the BOTH `classification` and `database` in the same object!
Not doing so will result in error during registration.

You may also want to follow the suggestion in [Filename convention](#filename-convention) below.

Examples:

```json
{
  "_id": "_design/maintenance",
  "kazoo": {
    "view_map": [
      {
        "classification": "account"
      },
      {
        "classification": "acdc"
      },
      {
        "classification": "aggregate"
      },
      {
        "classification": "modb"
      },
      {
        "classification": "yodb"
      },
      {
        "classification": "numbers"
      },
      {
        "classification": "ratedeck"
      },
      {
        "classification": "resource_selectors"
      },
      {
        "classification": "system"
      }
    ]
  }
}
```

More complex example:

```json
{
  "_id": "_design/media",
  "kazoo": {
    "view_map": [
      {
        "database": "system_media"
      },
      {
        "classification": "account"
      }
    ]
  }
}
```

#### Filename convention

Applications can create their design documents in `priv/couchdb/views` folder. Each design document must be created as a
separate JSON file under that folder. The Design doc file name is same name as its ID with `_design/` prefix. So for
example `_design/account` becomes `account.json`.

As a consideration:

- If you have two different design documents (with different views) but they have same ID, use their db classification
  as prefix for file name. For example Webhooks has different views:
  - `account-webhooks.json` from Webhooks app goes to account's databases
  - `webhooksdb-webhooks.json` from Webhooks app goes to `webhooks` database (not technically db classification, but you
    get the idea)
  - `webhooks.json` from modb app goes to account's MODBs

**If the views goes to multiple databases use `multi_db`**. For example, this view have a `view_map`, with different
`database`, and uses this avoid filename collision: `applications/stepswitch/priv/couchdb/views/multi_db-resources.json`

**Double check the design doc ID is correct. **No need to apply the classification to the ID.\*\*\*\*

#### Registered views in `system_data`

Registered views are saved to `system_data` database. The docs are save as-it after `view_map` validation passes.

The doc ID follows this pattern to avoid design name collision: `{ClassId}-{AppName}-{DesignName}`.

- `ClassId`: Base in view_maps view it could be:
  - The database name if there is only one object in `view_map`
  - The database classification if there is only one object in `view_map`
  - `multi_db` id there are multiple objects in `view_map`
- `AppName`: application name that this design doc is registered for.
- `DesignName`: the design name without `_design/` prefix

Two views in `system_data` are used by Data Manager for registered views:

- `views/registered`: Used for creating the view when a `kz_datamgr:get_results` has `{error, not_found}` error, using
  the database name, classification, and view the name (`design_name/view_name`).
- `views/views_by_classification`: Used for getting a list of views when refreshing the database views or creating the
  database.

## View indexing options

Data Manager has now a new system config `design_docs` to configure parameters to set on Design documents when saving
(refreshing) it to the Db.

The config type is JSON object allowing you to set any supported extra parameters on Design doc, most importantly
`autoupdate`.

The configs is per some keys and is attempted in this order:

- A pair of Db classification and the view's ID (without `_design/` prefix)
- The database classification
- A system-wide config to apply to in case all above are `undefined`.

After setting the config, you need to refresh the database (all or the specific affected databases):

```shell
sup kapps_maintenance refresh
```

Note: Make sure to flush config with `sup kapps_config flush` if data got changed on db.

### Disable auto indexing

This is to disable background indexing of couch views and can be set in `design_docs` system config.

`autoupdate: false`

It has been observed during our production in multiple clusters, that view blah blah blah blah explain why??? Justify
why setting this value and how this improves it.

### System-wide default value for `design_docs`

```json
{
  "id": "design_docs",
  "default": {
    "options": {
      "autoupdate": false
    }
  }
}
```

### Setting `design_docs` per view or database classification

The JSON is nested with following values:

Here design name is without the `_design/` part e.g. `_design/accounts` will be `accounts`.

```json
{
  "id": "design_docs",
  "default": {
    "classifications": {
      "{CLASSIFICATION}": {
        "options": {}
      }
    },
    "views": {
      "{classification}": {
        "{design_name}": {
          "options": {}
        }
      }
    }
  }
}
```
