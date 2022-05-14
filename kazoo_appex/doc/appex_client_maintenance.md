## SUP-able functions

| Function | Arguments | Description |
| -------- | --------- | ----------- |
| `link_cluster/1` | `(AccessCode)` | |
| `link_cluster/2` | `(AccessCode,ClusterName)` | |
| `listing/0` |  | |
| `loaded/0` |  | |
| `refresh/0` |  | |
| `set_cluster_secret/1` | `(ClusterSecret)` | |
| `unlink_cluster/0` |  | |


### `link_cluster/1`, `link_cluster/2`

Easy commands to link your cluster to 260Hz Marketplace. To link your cluster follow these steps:

* start by getting an Access Code by login to [2600Hz Marketplace](https://marketplace.2600hz.com)
* Go to Manage Accounts -> Manage Cluster
* Generate an Access Code and copy
* Use Monster UI App Exchange -> Marketplace Connector
* or run one of these maintenance commands like:

```
sup appex_client_maintenance link_cluster "{YOUR_ACCESS_CODE}"

# you can also give your cluster a name to identify on Marketplace:
sup appex_client_maintenance link_cluster "{YOUR_ACCESS_CODE}" "{CLUSTER_NAME}"
```

### `unlink_cluster/0`

Use this command to unlink your cluster from 2600Hz Marketplace.

> Caution: This process can not be undone, your purchased app will canceled.

### `set_cluster_secret/1`

Use this command to set your new Marketplace secret to Kazoo Appex can connect to store.

* If you did not initiated the process, login to [2600Hz Marketplace](https://marketplace.2600hz.com)
* Go to Manage Accounts -> Manage Cluster
* Regenerate a new Cluster Secret and copy it
* Use this command to set your new cluster secret:

```
sup appex_client_maintenance set_cluster_secret "{YOUR_NEW_CLUSTER_SECRET}"
```
