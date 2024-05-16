# Kazoo Versions

`kapps_versions` contains functions for querying, analyzing, and reporting the versions of Kazoo apps deployed in a given environment. This module is then used to implement two new `kapps_maintenance` commands:

- `show_kapps_versions`: prints the names and versions of all Kazoo apps on all nodes
- `check_kapps_versions`: prints warnings if multiple versions of a Kazoo app are found in the environment

### The Data Model
`kapps_versions` relies on a new record, `#node_app_version{}`, which holds the node, app name, app version, app description, and startup time.

Generally speaking, the functions in `kapps_versions` operate on lists and maps containing `#node_app_version{}` records. A common type referenced in the code is a `group_map()` which is a map (potentially deeply nested) where the innermost value is a list of `#node_app_version{}`.  Group maps are intended to model hierarchies of categories.

`kapps_versions` contains functions for filtering, mapping, and folding lists and group maps.  All of these functions take plain functions as arguments, just like the `lists` and `maps` modules; many also support a shorthand notation where atoms can be used to indicate mapping and predicate functions built into `kapps_version`.

While most of the built-in mapping and predicate functions operate on `#node_app_version{}` records, it is important to note that the filtering and grouping functions of `kapps_versions` can be applied to _any_ type -- one need only supply the appropriate mapping and predicate functions.  The shorthand notation is easily extended to include new functions.

### How Version Information Is Gathered

Each node running `kazoo_nodes` broadcasts a heartbeat message via AMQP.  Historically, this message included only the names and startup times of Kazoo applications running on the node.  In this PR, the list of running apps and their startup times is merged with the list of Kazoo apps _loaded_ on the node to produce a list of `#node_app_version{}`.  This list is added to the heartbeat payload in a new field called `kapps_loaded`.

The `kapps_loaded` list is not guaranteed to contain a version string or a startup time for every app.  Here's why:

1. FreeSWITCH doesn't report its version or startup time. If such a `#node_app_version{}` is in the list, it means that FreeSWITCH is in the environment and was running recently.
2. Versions of Kazoo apps that predate this PR will not report their versions. For these records, the version will be `<<"unknown">>`.
3. Kazoo apps that have been stopped or were never started may have a startup time of `undefined`.

### Some Examples

#### List all the versions on all the nodes:
```erlang
L = kapps_versions:list().
```

#### Filter for a particular node, the hard way:
```erlang
F1 = fun(#node_app_version{node=N}) -> N =:= 'kazoo_apps@aio.craterhill.io' end.
kapps_versions:filter([F1], L).
```

#### Filter for a particular node, the easy way:
```erlang
kapps_versions:filter([{'node', <<"kazoo_apps@aio.craterhill.io">>}], L).
```
Notice that filters are supplied in a list.  The list is interpreted as a logical `and`.  For example, to get all the apps on a particular node where the version is less than 5.0:
```erlang
 kapps_versions:filter([{'node', <<"kazoo_apps@aio.craterhill.io">>}, {'version_lt', <<"5.0">>}], L).
```
#### Compound Filters

Logical expressions are supported with the predicates `and`, `or`, and `not`:
```erlang
kapps_versions:filter([{'or', [{'name', <<"webhooks">>}, {'name', <<"trunkstore">>}]}], L).
[#node_app_version{node = 'kazoo_apps@smflt006.craterhill.io',
                   name = <<"webhooks">>,
                   description = <<"Webhooks: HTTP events from KAZOO to you">>,
                   version = <<"4.0.0">>,startup = 63852778295},
 #node_app_version{node = 'kazoo_apps@smflt006.craterhill.io',
                   name = <<"trunkstore">>,
                   description = <<"Trunkstore: Authentication and SIP Routing for PBXes">>,
                   version = <<"4.0.0">>,startup = 63852778295},
 #node_app_version{node = 'kazoo_apps@aio.craterhill.io',
                   name = <<"trunkstore">>,description = <<"unknown">>,
                   version = <<"unknown">>,startup = 63852169274},
 #node_app_version{node = 'kazoo_apps@aio.craterhill.io',
                   name = <<"webhooks">>,description = <<"unknown">>,
                   version = <<"unknown">>,startup = 63852169274}]
```

#### Organize `L` into groups by node name, the hard way:
```erlang
M1 = fun(#node_app_version{node=N}) -> N end.
kapps_versions:groups_by([M1], L).
```
The result is a map where the keys are nodes and the values are lists of `#node_app_version{}`, for example:
```erlang
#{'ecallmgr@aio.craterhill.io' =>
      [#node_app_version{node = 'ecallmgr@aio.craterhill.io',
                         name = <<"ecallmgr_extension">>,description = <<"unknown">>,
                         version = <<"unknown">>,startup = 63852169262},
       #node_app_version{node = 'ecallmgr@aio.craterhill.io',
                         name = <<"ecallmgr">>,description = <<"unknown">>,
                         version = <<"unknown">>,startup = 63852169261}],
  'freeswitch@aio.craterhill.io' =>
      [#node_app_version{node = 'freeswitch@aio.craterhill.io',
                         name = <<"freeswitch">>,description = <<"unknown">>,
                         version = <<"unknown">>,startup = undefined}],
  'kamailio@aio.craterhill.io' =>
      [#node_app_version{node = 'kamailio@aio.craterhill.io',
                         name = <<"kamailio">>,description = <<"unknown">>,
                         version = <<"unknown">>,startup = 63852169246}],
  'kazoo_apps@aio.craterhill.io' =>
      [#node_app_version{node = 'kazoo_apps@aio.craterhill.io',
                         name = <<"webhooks">>,description = <<"unknown">>,
                         version = <<"unknown">>,startup = 63852169274},
       ...
      ],
  ...
}
```
#### Grouping by node, the easy way:
```erlang
kapps_versions:groups_by(['node'], L).
```
Group maps can be arbitrarily deep.  Given 1 mapping function, the output is a map of lists.  Given 2 mapping functions, the output is a map of maps of lists.  Given N mapping functions, the output is a map of maps N keys deep, and the value is a list.  For example, grouping by node and version (the easy way):
```erlang
kapps_versions:groups_by(['node', 'version'], L).
```

The result looks like this:
```erlang
#{'ecallmgr@aio.craterhill.io' =>
      #{<<"unknown">> =>
            [#node_app_version{node = 'ecallmgr@aio.craterhill.io',
                               name = <<"ecallmgr_extension">>,description = <<"unknown">>,
                               version = <<"unknown">>,startup = 63852169262},
             #node_app_version{node = 'ecallmgr@aio.craterhill.io',
                               name = <<"ecallmgr">>,description = <<"unknown">>,
                               version = <<"unknown">>,startup = 63852169261}]},
  'freeswitch@aio.craterhill.io' =>
      #{<<"unknown">> =>
            [#node_app_version{node = 'freeswitch@aio.craterhill.io',
                               name = <<"freeswitch">>,description = <<"unknown">>,
                               version = <<"unknown">>,startup = undefined}]},
  'kamailio@aio.craterhill.io' =>
      #{<<"unknown">> =>
            [#node_app_version{node = 'kamailio@aio.craterhill.io',
                               name = <<"kamailio">>,description = <<"unknown">>,
                               version = <<"unknown">>,startup = 63852169246}]},
  'kazoo_apps@aio.craterhill.io' =>
      #{<<"unknown">> =>
            [#node_app_version{node = 'kazoo_apps@aio.craterhill.io',
                               name = <<"webhooks">>,description = <<"unknown">>,
                               version = <<"unknown">>,startup = 63852169274},
         ...
      ]
   }
...
]
```
**Order matters!**  `groups_by(['node', 'version'], L)` is not the same as `groups_by(['version', 'node'], L)`.

#### Filtering Groups

Group maps can also be filtered using the `filter_groups/2` function.  This function takes a list of predicates and a group map and produces a group map containing only the groups for which all the predicates are true.  For example, to find all of the nodes where both Webhooks and Trunkstore are running:
```erlang
L2 = kapps_versions:filter([{'names', [<<"webhooks">>, <<"trunkstore">>]}], L).
G1 = kapps_versions:groups_by(['node'], L2]).
kapps_versions:filter_groups([{'count', 2}], G1).
```
This same result can be achieved more succinctly using `groups_by/3`:

```erlang
L2 = kapps_versions:filter([{'names', [<<"webhooks">>, <<"trunkstore">>]}], L).
kapps_versions:groups_by(['node'], L2, [{'count', 2}]).
```
