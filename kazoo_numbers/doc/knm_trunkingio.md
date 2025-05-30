# Trunking.io Carrier

The Number Manager Trunking.io carrier module can be used to integrate Kazoo with [Trunking.io](http://trunking.io)
carrier.

This carrier module provides interface to manage your phone numbers in Trunking.io. You may also use numbers from this
carrier module for sending outbound SMS/MMS messages.

## Setup

Here we discuss how to properly configure the system and activate Trunking.io as carrier.

### Configuring number manager

To be able to search numbers using this carrier, you must first add this carrier as available in number manager.

For doing so you need to use maintenance command or update the `number_manager` system configuration directly (and flush
configs afterward).

For example using maintenance commands:

```shell
sup kapps_config set_list_string_append number_manager carrier_modules knm_trunkingio
```

Or if you want to update system config directly in db (you need to flush cache for configs afterward):

```json
       "carrier_modules": [
           "knm_local",
           "knm_bandwidth2"
       ]
```

Now everyone while searching for prefixes, numbers, and Toll-free numbers, the result will also include the records
from Trunking.io. You are still required to configure the Trunking.io carrier module for accessing its API.

### Configuring Trunking.io module

Configuration for this module are stored in `number_manager.trunkingio` category (doc) in the `system_config` database.

You may use maintenance command to set the configuration values or update the doc directly in database and flush
configs.

There are primarily two ways to configure Trunking.io, depend on how you are running your system:

- Shared hosted, per reseller: if your system is multi tenants with different reseller, it is expected for regulatory
  reasons to let each reseller sign up and link with their own Trunking.io. Then reseller and its subaccounts use this
  linked TIO account.
- System-wide, super-duper admin as sole reseller: In this system only super-duper admin needs to link up with TIO, the
  rest of the system is considered the end users and will use this system-wide TIO.

Some configurations are common regardless the type of setup:

| Parameter              | Description                                                                                                                                                 | Required                                                                    | Default                              |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | -------                              |
| `api_url`              | Trunking.io API URL                                                                                                                                         | `false`                                                                     | `https://api.onsip.com/api`          |
| `messaging_api_url`    | Trunking.io Messaging API URL                                                                                                                               | `false`                                                                     | `https://messaging.trunking.io/api`  |
| `mms_retries`          | Maximum retry attempts to fetch MMS media files for incoming MMS message                                                                                    | `false`                                                                     | `1`                                  |
| `enable_provisioning`  | If this parameter is set to `true` then the ability to active numbers will be enabled. If set to `false` then the module will only perform number searches. | `false`                                                                     | `true`                               |
| `enable_provisioning`  | If this parameter is set to `true` then the ability to active numbers will be enabled. If set to `false` then the module will only perform number searches. | `false`                                                                     | `true`                               |
| `sandbox_provisioning` | Intended to be used with `enable_provisioning`. If set to `true` then all number provisioning will pretend to be successful without actually activating.    | `false`                                                                     | `false`                              |

### Setup for per reseller in a shared hosted platforms

In a shared hosted platforms, each direct reseller needs to sign up with Trunking.io individually to provide services to
their subaccounts.

In this setup, the reseller needs to use Commland Trunking.io, or Monster UI Trunking.io applications to initiate the
linking process. The backend `kazoo-trunkingio` is also required to be running.

You will be redirected to Trunking.io for sign up. When your Trunking.io account is approved, your account will be auto
provisioned so now you are able to purchase numbers and make and receive calls, for your own reseller account and all of
your subaccounts.

To set up, a sysadmin/super-duper need:

- Create a global carrier with proper fields
- Add Trunking.io originations/inbound IPs to `ecallmgr` carrier ACLs
- Contact Trunking.io for adding your cluster
  - Provide your cluster ID
  - Provide your public SBCs IPs, to TIO can send calls towards your cluster and authenticate your outbound
  - Provide you cluster's public API URL address
  - For linking resellers
    - `inbound_hook_secret` must be set for both Kazoo knm trunkingio number manager config and
      also in Trunking.io admin dashboard for `AccountEnable`


Example global carrier resource:

```json
{
  // ...
  "require_flags": true,
  "ignore_flags": false,
  "flags": [
    "trunkingio"
  ],
  "custom_sip_headers": {
    "X-Cluster-ID": "{cluster_id}",
    "X-Account-ID": "{direct_reseller_id}"
  },
    "gateways": [
    {
      "progress_timeout": 8,
      "privacy_mode": "sip",
      "server": "199.7.173.177",
      "channel_selection": "ascending",
      "enabled": true,
      "endpoint_type": "sip",
      "force_port": false,
      "invite_format": "route",
      "port": 5060,
      "skype_rr": true
    },
    {
      "progress_timeout": 8,
      "privacy_mode": "sip",
      "server": "199.7.175.177",
      "channel_selection": "ascending",
      "enabled": true,
      "endpoint_type": "sip",
      "force_port": false,
      "invite_format": "route",
      "port": 5060,
      "skype_rr": true
    }
  ],
  // ...
  "pvt_type": "resource"
}
```

Adding Trunking.io as carrier ACLs:

```shell
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_01 199.7.173.180 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_02 199.7.173.181 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_03 199.7.173.182 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_04 199.7.173.183 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_05 199.7.173.184 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_06 199.7.175.180 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_07 199.7.175.181 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_08 199.7.175.182 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_09 199.7.175.183 true
sup -n ecallmgr ecallmgr_maintenance allow_carrier tio_10 199.7.175.184 true
```


Now you need to instruct your reseller to use UI applications to Sign up and link their accounts to Trunking.io.

After approval kazoo will automatically set up the reseller and its subaccounts to use the resource with flag
`trunkingio` and create required inbound IM messaging webhook for the account.

### Setup Trunking.io system-wide

This setup is useful for private clusters which the super-duper account is the sole provider and all subaccounts are end-user and
not reseller.

In this setup, the super-duper admin must sign up with Trunking.io and setup their system.

- To config this way you must set `use_system_tio_account` to `true`.
- Set up a global carrier resource
- Set inbound carrier ACLs, just like shared-hosted above.
- Contact Trunking.io for adding your cluster
  - Provide your cluster ID
  - Provide your public SBCs IPs, to TIO can send calls towards your cluster and authenticate your outbound
  - Provide you cluster's public API URL address
  - For linking resellers
    - `inbound_hook_secret` must be set for both Kazoo knm trunkingio number manager config and also in Trunking.io
      admin dashboard for messaging webhook, messaging webhook is per TIO account, not per number.

This document has the following parameters:

| Parameter                | Description                                                                                                                                                 | Required                                                                    | Default |
| -------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- | ------- |
| `use_system_tio_account` | Indicate this is a system-wide setup, or if set in shared-hosted system means the unlinked accounts can use system-wide                                     | `true`                                                                      | `false` |
| `account_id`             | This is the account-id that is provided by Trunking.io for your account.                                                                                    | `true`                                                                      |         |
| `api_token`              | API token to use for authentication generated for you using Trunking.io admin portal                                                                        | Preferred and required if `username` and `password` are not set.            |         |
| `username`               | Username to log into the API with, as alternative for using API token                                                                                       | If you don't have API token, **both** `username` and `password` is required |         |
| `password`               | Password to log into the API with, as alternative for using API token                                                                                       | If you don't have API token, **both** `username` and `password` is required |         |
| `inbound_hook_secret`    | A shared secret for using for incoming Webhook from TIO, in this scenario this is mostly for IM messaging Webhooks                                        | `true`                                                                      |         |

Example:

```json
{
  "_id": "number_manager.bandwidth2",
  "default": {
    "use_system_tio_account": "true",
    "account_id": "123",
    "api_token": "supersecret",
    "sandbox_provisioning": false,
    "enable_provisioning": true,
    "inbound_hook_secret": "****"
  }
}
```

Super-duper then can create a global resource as usual, for example see below.

Please note, it is recommended to replace `{reseller_id}` with actual account ID of super-duper admin.

```json
{
  // ...
  "custom_sip_headers": {
    "X-Cluster-ID": "{cluster_id}",
    "X-Account-ID": "{reseller_id}"
  },
    "gateways": [
    {
      "progress_timeout": 8,
      "privacy_mode": "sip",
      "server": "199.7.173.177",
      "channel_selection": "ascending",
      "enabled": true,
      "endpoint_type": "sip",
      "force_port": false,
      "invite_format": "route",
      "port": 5060,
      "skype_rr": true
    },
    {
      "progress_timeout": 8,
      "privacy_mode": "sip",
      "server": "199.7.175.177",
      "channel_selection": "ascending",
      "enabled": true,
      "endpoint_type": "sip",
      "force_port": false,
      "invite_format": "route",
      "port": 5060,
      "skype_rr": true
    }
  ],
  // ...
  "pvt_type": "resource"
```

#### Obtaining API Token

You can manage your API token directly using Trunking.io admin portal.

## Configuring Trunking.io for sending and receiving SMS/MMS

Trunking.io numbers are able to used for sending and receiving SMS/MMS.

First cluster operator need to activate IM in system then activate the IM feature for Trunking.io module. After that you
are able to activate SMS or MMS feature per number.

See [Number Messaging Feature](./knm_im.md) to learn more about configuring the system.

### Activating SMS/MMS feature in Trunking.io

Enable IM features in Trunking.io carrier module:

```shell
sup  kapps_config set_boolean number_manager.trunkingio features.sms.enabled true
sup  kapps_config set_boolean number_manager.trunkingio features.mms.enabled true
```

Cluster operator must manually ensure that there are Branding and User Case defined in their Trunking.io account and
each number is assigned a Brand and Use Case, otherwise the SMS/MMS will be rejected by carrier.

For getting an Email notification when IM features enabled for number cluster operator must set these system configs
(replace `{EMAIL_ADRESS}`):

```shell
sup  kapps_config set_string number_manager.trunkingio featuers.sms.activation manual
sup  kapps_config set_string number_manager.trunkingio features.sms.activation_notify_to {EMAIL_ADDRESS}

sup  kapps_config set_string number_manager.trunkingio featuers.mms.activation manual
sup  kapps_config set_string number_manager.trunkingio features.mms.activation_notify_to {EMAIL_ADDRESS}
```

### Inbound messaging for system-wide

Super-duper admin is required to create a Messaging Webhook on Trunking.io portal for their account, this Webhook should be for the whole account and not per number.

The shared-secret MUST be set on kazoo in `inbound_shared_secret`.

### Inbound messaging for shared-hosted and per reseller setup

No action is needed, Kazoo will automatically set up the messaging webhook.

### Outbound messaging

Currently, the sysadmin must set `features.mms.activation_notify_to` to their support agent, and they need to go and
assign a TCR for the number in Trunking.io portal otherwise the outbound SMS will be rejected by carrier.
