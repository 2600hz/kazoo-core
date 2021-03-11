# View changes overview

Here is a summary of changes to the views in Kazoo 5. As part of cleaning up, we removed old and used views, and normalized the common tasks of views (like list by DocId in `crossbar_listing` views) in a single uniform views. Also to indexing performance reason system core views are getting move to a single design document as far as possible.

There would be a mechanism for applications to add their own design/views.

Also to Kazoo 5 is providing an abstraction over the way we retrieve the views data. The views accessors has been added as a standard way to access the data. The idea is that this accessors are providing the high level concept of entities and the database drivers are implementing the way to retrieving the data from the database.

```
[kzd modules] --> [kzv modules] --> [kazoo data and storage system] --> [database/storage driver]
```

## Benefits of less design document

CouchDB will spawning at least one `couchjs` OS process for _each_ design document per each _shard_. And during indexing,the documents would be pass to all these processes. That's a lot of encoding/decoding JSON object and I/O usages.

To see this in a big picture, take a single account database as example:

* There are approximately around 40 design documents in account db.
* If we have a 3 zone CouchDB cluster, that is at least 120 `couchjs` process in each server!
* A huge amount of the design documents are a just a single `crossbar_listing` view, with one propose: emit the document Id for that specific document type.
* If we move all those `crossbar_listing` to a single design document which emits by `[doc.pvt_type, doc._id]` we would get ride of at least 25 views and around 15 design documents.
* We also can have other generic views which are emitting by numbers in documents, names, owner ids and etc.
* Some views are doing the exact same thing
* With that changes now there is a lot of single view design documents, which we can simply move them to that single design documents.

### Pros

* This changes alone moved the functionality of ~30 design documents to a single
* Reduce the count of `couchjs` to 30 processes in each server
* Helps with indexing incrementally
* Less encoding/decoding JSON
* Less I/O
* Potentially helps the index to be always updated
* And less pressure on system memory (less `couchjs` processes)

### Cons

The downsize is the longer time to create the index file for the first time, and more importantly if you change a single view in that design document, that would force the re-creating the whole index file again.

## View Changes

Most of he views are move the `crossbar_listings` design document. This is all in account db right now, but if it is successful we would considering doing the same for all other databases.

Also there were some unused views which has been remove.

### Moved views

Here is a list of views that has been moved to `crossbar_listings` various views. Since the emitted key may have been changes it lists the old and the new keys to help migrate your code easily.

| Old view                                                                                                          | New View                                                                                                                   |
|-------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| __Name__: `apps_store/crossbar_listing`          <br/> __Key:__ `Name`                                            | __Name__: `crossbar_listings/by_type_name`                 <br/> __Key:__ `[DocType, Name]`                                |
| __Name__: `attributes/endpoints_lookup`          <br/> __Key:__ `[CallerIdNumber, CallerIdType]`                  | __Name__: `crossbar_listings/endpoints_lookup`             <br/> __Key:__ `[CallerIdNumber, CallerIdType]`                 |
| __Name__: `attributes/groups`                    <br/> __Key:__ `null`                                            | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `attributes/hotdesk_id`                <br/> __Key:__ `HotDeskId`                                       | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, HotDeskId]`                           |
| __Name__: `attributes/hotdesk_users`             <br/> __Key:__ `OwnerId`                                         | __Name__: `crossbar_listings/by_type_ownerid`              <br/> __Key:__ `[DocType, OwnerId]`                             |
| __Name__: `attributes/mailbox_number`            <br/> __Key:__ `Number`                                          | __Name__: `crossbar_listings/by_type_number`               <br/> __Key:__ `[DocType, Number]`                              |
| __Name__: `attributes/owned`                     <br/> __Key:__ `[OwnerId, DocType]`                              | __Name__: `crossbar_listings/by_ownerid_type`              <br/> __Key:__ `[OwnerId, DocType]`                             |
| __Name__: `attributes/owner`                     <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/owners_by_docid_type`         <br/> __Key:__ `[DocId, DocType]`                               |
| __Name__: `attributes/sip_username`              <br/> __Key:__ `Username`                                        | __Name__: `crossbar_listings/by_sip_usernames`             <br/> __Key:__ `Username`                                       |
| __Name__: `attributes/temporal_rules`            <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `auth/providers_by_type`               <br/> __Key:__ `[ProviderType, DocId]`                           | __Name__: `crossbar_listings/auth_providers_type`          <br/> __Key:__ `[ProviderType, DocId]`                          |
| __Name__: `blacklists/crossbar_listing`          <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `callflows/crossbar_listing`           <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `callflows/listing_by_number`          <br/> __Key:__ `Number`                                          | __Name__: `crossbar_listings/by_type_number`               <br/> __Key:__ `[DocType, Number]`                              |
| __Name__: `callflows/listing_by_pattern`         <br/> __Key:__ `Pattern`                                         | __Name__: `crossbar_listings/flow_patterns`                <br/> __Key:__ `[DocType, Pattern]`                             |
| __Name__: `callflows/msisdn`                     <br/> __Key:__ `[FlowModule, FlowDataId, Number]`                | __Name__: `crossbar_listings/flow_msisdn`                  <br/> __Key:__ `[DocType, FlowModule, FlowDataId, Number]`      |
| __Name__: `click2call/crossbar_listing`          <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `conference/listing_by_number`         <br/> __Key:__ `Number`                                          | __Name__: `crossbar_listings/by_type_number`               <br/> __Key:__ `[DocType, Number]`                              |
| __Name__: `conferences/crossbar_listing`         <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `contact_list/excluded`                <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/contact_list_excluded`        <br/> __Key:__ `DocId`                                          |
| __Name__: `contact_list/extensions`              <br/> __Key:__ one of `"extension"`, `"custom"`, `"featurecode"` | __Name__: `crossbar_listings/contact_list_extensions`      <br/> __Key:__ one of `"extension"`, `"custom"`,`"featurecode"` |
| __Name__: `contact_list/names`                   <br/> __Key:__ `null`                                            | __Name__: `crossbar_listings/contact_list_names`           <br/> __Key:__ `null`                                           |
| __Name__: `devices/crossbar_listing`             <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `devices/listing_by_macaddress`        <br/> __Key:__ `MacAddress`                                      | __Name__: `crossbar_listings/device_mac_addresses`         <br/> __Key:__ `MacAddress`                                     |
| __Name__: `devices/listing_by_owner`             <br/> __Key:__ `OwnerId`                                         | __Name__: `crossbar_listings/by_type_ownerid`              <br/> __Key:__ `[DocType, OwnerId]`                             |
| __Name__: `devices/listing_by_presence_id`       <br/> __Key:__ `PresenceId`                                      | __Name__: `crossbar_listings/device_presence_ids`          <br/> __Key:__ `PresenceId`                                     |
| __Name__: `devices/sip_credentials`              <br/> __Key:__ `Username`                                        | __Name__: `crossbar_listings/by_sip_credentials`           <br/> __Key:__ `Username`                                       |
| __Name__: `directories/crossbar_listing`         <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `directories/users_listing`            <br/> __Key:__ `[DirectoryId, DocId]`                            | __Name__: `crossbar_listings/owners_by_docid_type`         <br/> __Key:__ `[DirectoryId, DocType]`                         |
| __Name__: `faxbox/crossbar_listing`              <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `faxbox/email_permissions`             <br/> __Key:__ `PermissionTag`                                   | __Name__: `crossbar_listings/faxbox_email_permissions`     <br/> __Key:__ `PermissionTag`                                  |
| __Name__: `faxbox/list_by_ownerid`               <br/> __Key:__ `OwnerId`                                         | __Name__: `crossbar_listings/by_type_ownerid`              <br/> __Key:__ `[DocType, OwnerId]`                             |
| __Name__: `groups/crossbar_listing`              <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `groups/crossbar_listing_by_user`      <br/> __Key:__ `UserId`                                          | __Name__: `crossbar_listings/by_type_ownerid`              <br/> __Key:__ `[DocType, OwnerId]`                             |
| __Name__: `hotdesks/crossbar_listing`            <br/> __Key:__ `OwnerId`                                         | __Name__: `crossbar_listings/by_type_ownerid`              <br/> __Key:__ `[DocType, OwnerId]`                             |
| __Name__: `lists/crossbar_listing`               <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `lists/entries`                        <br/> __Key:__ `ListId`                                          | __Name__: `crossbar_listings/list_entries`                 <br/> __Key:__ `ListId`                                         |
| __Name__: `lists/match_prefix_in_list`           <br/> __Key:__ `[ListId, Prefix]`                                | __Name__: `crossbar_listings/list_prefixes`                <br/> __Key:__ `[ListId, Prefix]`                               |
| __Name__: `lists/regexps_in_list`                <br/> __Key:__ `ListId`                                          | __Name__: `crossbar_listings/list_patterns`                <br/> __Key:__ `ListId`                                         |
| __Name__: `menus/crossbar_listing`               <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `message/crossbar_listing`             <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `message/listing_by_number`            <br/> __Key:__ `Number`                                          | __Name__: `crossbar_listings/by_type_number`               <br/> __Key:__ `[DocType, Number]`                              |
| __Name__: `message/listing_by_pattern`           <br/> __Key:__ `Pattern`                                         | __Name__: `crossbar_listings/flow_patterns`                <br/> __Key:__ `[DocType, Pattern]`                             |
| __Name__: `message/msisdn`                        <br/> __Key:__ `[FlowModule, FlowDataId, Number]`                | __Name__: `crossbar_listings/flow_msisdn`                  <br/> __Key:__ `[DocType, FlowModule, FlowDataId, Number]`      |
| __Name__: `metaflows/crossbar_listing`           <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `mobile/listing_by_mdn`                <br/> __Key:__ `MDN`                                             | __Name__: `crossbar_listings/mobile_mdns`                  <br/> __Key:__ `MDN`                                            |
| __Name__: `notifications/crossbar_listing`       <br/> __Key:__ `Name`                                            | __Name__: `crossbar_listings/by_type_name`                 <br/> __Key:__ `[DocType, Name]`                                |
| __Name__: `parking/parked_call`                  <br/> __Key:__ `ParkSlotCallId`                                  | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `['parked_call_id', CallId]`                     |
| __Name__: `parking/parked_calls`                 <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `phone_numbers/crossbar_listing`       <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `rate_limits/crossbar_listing`         <br/> __Key:__ `[QueryName, SipMethod]`                          | __Name__: `crossbar_listings/rate_limits`                  <br/> __Key:__ `[QueryName, SipMethod]`                         |
| __Name__: `rate_limits/list_by_owner`            <br/> __Key:__ `OwnerId`                                         | __Name__: `crossbar_listings/by_type_ownerid`              <br/> __Key:__ `[DocType, OwnerId]`                             |
| __Name__: `resources/crossbar_listing`           <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `resources/listing_by_id`              <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `resources/resource_templates`         <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `service_plans/crossbar_listing`       <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `temporal_rules_sets/crossbar_listing` <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `temporal_rules/crossbar_listing`      <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `trunkstore/crossbar_listing`          <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `trunkstore/lookup_did`                <br/> __Key:__ `Number`                                          | __Name__: `crossbar_listings/by_type_number`               <br/> __Key:__ `[DocType, Number]`                              |
| __Name__: `users/creds_by_md5`                   <br/> __Key:__ `Cred`                                            | __Name__: `crossbar_listings/user_creds_md5`               <br/> __Key:__ `Cred`                                           |
| __Name__: `users/creds_by_sha`                   <br/> __Key:__ `Cred`                                            | __Name__: `crossbar_listings/user_creds_sha1`              <br/> __Key:__ `Cred`                                           |
| __Name__: `users/crossbar_listing`               <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `users/list_by_email`                  <br/> __Key:__ `EmailAddress`                                    | __Name__: `crossbar_listings/user_emails`                  <br/> __Key:__ `EmailAddress`                                   |
| __Name__: `users/list_by_hotdesk_id`             <br/> __Key:__ `HotDeskId`                                       | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, HotDeskId]`                           |
| __Name__: `users/list_by_id`                     <br/> __Key:__ `DocId`                                           | __Name__: `crossbar_listings/by_type_id`                   <br/> __Key:__ `[DocType, DocId]`                               |
| __Name__: `users/list_by_username`               <br/> __Key:__ `Username`                                        | __Name__: `crossbar_listings/user_usernames`               <br/> __Key:__ `Username`                                       |
| __Name__: `vmboxes/crossbar_listing`             <br/> __Key:__ `Name`                                            | __Name__: `crossbar_listings/by_type_name`                 <br/> __Key:__ `[DocType, Name]`                                |
| __Name__: `vmboxes/listing_by_mailbox`           <br/> __Key:__ `NumberInt`                                       | __Name__: `crossbar_listings/by_type_number`               <br/> __Key:__ `[DocType, Number]`                              |

### Removed Views

Here is a list of all unused views that have been removed.

* `access_lists/crossbar_listing`
* `account/listing_by_id`
* `account/listing_by_name`
* `account/listing_by_realm`
* `attributes/active_resources_by_rules`
* `conferences/listing_by_name`
* `faxbox/cloud`
* `faxbox/email_address`
* `faxes/crossbar_listing`
* `faxes/list_by_faxbox`
* `faxes/list_by_ownerid`
* `lists/match_prefix`
* `pivot/crossbar_listing`
* `pivot/debug_listing`
* `pivot/first_iteration`
* `resources/listing_active_by_rules`
* `servers/crossbar_listing`
* `servers/list_deployment_roles`
* `vmboxes/legacy_msg_by_timestamp`
* `whitelabel/crossbar_listing`
