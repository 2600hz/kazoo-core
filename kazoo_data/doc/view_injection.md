##Disable autoindexing on couchdb

`autoupdate: false`
This is to disable background indexing of couch views.

System config db will now contain documents to configure this value.

`design_docs` doc will contain the json

```json
  "id": "design_docs",
  "default": {
    "options": {
      "default": {
        "autoupdate": false
      },
      "classifications": {
        "system": {
          "options": {
            "autoupdate": false
          }
        },
        "account": {
          "options": {
            "autoupdate": false
          }
        }
        "modb": {
          "options": {
            "autoupdate": false
          }
        }
      },
      "views": {
        "system": {
          "system_configs": {
            "options": {
              "autoupdate": false
            }
          },
          "maintenance": {
            "options": {
              "autoupdate": false
            }
          },
        }
      }
    }
  }
```

The json is nested with following values.

```json
{
  "id": "design_docs",
  "default": {
    "options": {},
    "classifications": {
      "{CLASSIFICATION}": { "options": {}}}
    },
    "views": {
      "{classification}": {
        "{design_name}": { "options": {}}}
      }
    }
  }
}
```

The preference for the options value goes from design_doc_id > classification > default.

Here design name is without the `_design/` part e.g. `_design/accounts` will be `accounts`

to refresh views `sup kapps_maintenance refresh` can be used.
make sure to flush kapps config with `sup kapps_config flush` if data got changed on db.