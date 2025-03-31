# Trunkingio Carrier

The Number Manager Trunkingio carrier module can be used to integrate Kazoo with [Trunkingio](http://trunking.io) carrier.

This carrier module provides interface to manage your phone numbers in Trunkingio. You may also use numbers from this carrier module
for sending outbound SMS/MMS messages.

## Setup

Here we discuss how to properly configure the system and activate Trunkingio as carrier.

### Configuring number manager

To be able to search numbers using this carrier, you must first add this carrier as available in number manager.

For doing so you need to use maintenance command or update the `number_manager` system configuration directly (and flush configs afterwards).

For example using maintenance commands:

```shell
sup kapps_config set_list_string_append number_manager carrier_modules knm_trunkingio
```

Or if you want to update system config directly in db (you need to flush cache for configs afterwards):

```json
       "carrier_modules": [
           "knm_local",
           "knm_bandwidth2"
       ]
```

Now everyone while searching for prefixes, numbers, and Toll-free numbers, the result will also includes the records from Trunkingio.
You are still require to configure the Trunkingio carrier module for accessing its API.

### Configuring Trunkingio module

Configuration for this module are stored in `number_manager.trunkingio` category (doc) in the `system_config` database. You may use maintenance command to set the
configuration values or update the doc directly in database and flush configs.

This document has the following parameters:


| Parameter | Description | Default |
|-----------|-------------|---------|
| `account_id` | This is the account-id that is provided by Trunkingio for your account. |  |
| `api_token` | API token to use for authentication generated for you using Trunkingio admin portal. Preferred and required if `username` and `password` are not set. |  |
| `username` | Username to log into the api with, as alternative for using API token | If you don't have API token, **both** `username` and `password` is required |  |
| `password` | Password to log into the api with, as alternative for using API token | If you don't have API token, **both** `username` and `password` is required |  |
| `enable_provisioning` | If this parameter is set to `true` then the ability to active numbers will be enabled. If set to `false` then the module will only perform number searches. |  |
| `sandbox_provisioning` | Intended to be used with `enable_provisioning`. If set to `true` then all number provisioning will pretend to be successful without actually activating. |  |

Example:

```json
{
   "_id": "number_manager.bandwidth2",
   "default": {
       "account_id": "123",
       "api_token": "lol",
       "sandbox_provisioning": false,
       "enable_provisioning": true
   }
}
```

#### Obtaining API Token

You can manage your API token directly using Trunkingio admin portal. <!-- Good luck tho -->


## Configuring Trunkingio for sending and receiving SMS/MMS

You are able to use Trunkingio numbers for sending and receiving SMS/MMS.

First you need to activate in system then activate the feature for Trunkingio module. After that you are able to activate SMS or MMS feature per number.

See [Number Messaging Feature](./knm_im.md) to learn more about configuring the system.

### Activating SMS/MMS feature in Trunkingio

!!! note
    Currently you must ensure that you have an active and validated Branding and User Case defined in your Trunkingio account and the number is assigned a Brand, otherwise the SMS/MMS will be rejected by carrier.

Enable IM features in Trunkingio carrier module:

```shell
sup  kapps_config set_boolean number_manager.trunkingio features.sms.enabled true
sup  kapps_config set_boolean number_manager.trunkingio features.mms.enabled true
```
