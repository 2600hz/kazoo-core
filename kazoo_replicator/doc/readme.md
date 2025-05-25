# KAZOO REPLICATOR

Replicate the data between two couchdb nodes.

## HOW IT WORKS

we can pass some arguments and let the replication begin

start by creating a replication job  
`sup replicator create`  
`sup replicator create optionalname`

it will return a job id, use that job id to fill out other parameters for db

### Fill out replication job info

```bash
sup replicator set $id from_host $COUCHURL
sup replicator set $id from_username $USERNAME
sup replicator set $id from_password $PASSWORD
sup replicator set $id from_port default to 5984
sup replicator set $id to_host $COUCHURL
sup replicator set $id to_username $USERNAME
sup replicator set $id to_password $PASSWORD
sup replicator set $id to_port default to 5984
sup replicator set $id worker_node to
sup replicator set $id continuous true
sup replicator add $id $masteraccountid
sup replicator add $id $reselleraccountid
sup replicator add $id $accountid3
```

* From CouchURL - url or ip of couch node. db1.kazoo.aio  
* From username - username of from node  
* From password - password of from node  
* To CouchURL - url or ip of couch node. 10.62.11.100  
* To and From port - if not using Haproxy no need to add value for ports they will be autopopulated.  
* Worker Node - Node which will push or pull the replication jobs. Usually To node which is node we are copying data to.  
The value will be from when we want to create job which does master master replication back to our main db cluster from the backup server.  
It is possible to have a third worked node carry on all the replication jobs but that isn't currently supported.  
* Continuous - defaults to false, whether to keep sync alive or oneshot sync.

#### Account based replication
In case where only replication of few accounts is needed

Make sure any master or reseller account leading up to replicated accounts is used.
By default all system dbs will be replicated.

```bash
sup replicator add $id $masteraccountid
sup replicator add $id $reselleraccountid
sup replicator add $id $accountid3
```

### Other commands to interact with jobs

`sup replicator status`
show the current status for all the replication jobs

`sup replicator status id`
show the current status for all replications for a particular job

`sup replicator stop id`
stop the current replication

`sup replicator start id`
start the selected replication

`sup replicator update`
update job with latest dbs

`sup replicator delete id`
delete the complete replication job

`sup replicator stop_all`
stop all replication jobs

`sup replicator delete_all`
delete all replication jobs
