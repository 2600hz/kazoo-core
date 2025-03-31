# Number Messaging Feature

To activate SMS/MMS for a number, the number MUST be assigned and be `in_service` state.
If both condition are valid then there are some configuration needed to be done to make SMS and MMS feature be available to
enabled in a number.


### Activating SMS/MMS feature in Services

You must ensure IM service is activated in accounts Service Plans to before allowing them to send and receive SMS and MMS. See [Messaging IM Services](/core/kazoo_services/doc/messaging-im-services.md).

### Activating SMS/MMS feature in Number Manager

Make sure Number Manager `features` config is configured and includes `sms` and `mms`:

```shell
sup  kapps_config set_list_string_append number_manager features.allow sms
sup  kapps_config set_list_string_append number_manager features.allow mms
```

### SMS/MMS feature settings per carrier

IM feature must be activated per carrier. Each carrier module can provide settings and configuration either through their source code
or as system configuration to make IM feature available for that carrier in number manager.

Carrier module system configs are usually stored as `number_manager.knm_{CARRIER}` which `{CARRRIER}` indicates the name of carrier or carrier module.

The expected SMS settings parameters are:

- `features.sms.enabled`: Indicate the feature is enabled to not
- `featuers.sms.activation`: Indicates if a manual steps are required to be done by the customer after feature is enabled for the number in Number Manager. Accepted values are:
    - `auto`: Default value, indicates the activation is automatic and no action is required from customer
    - `manual`: If true, indicates the customer is expected to manually perform other actions required to make this feature fully functional. See `activation_notify_to` too.
- `features.sms.activation_notify_to`: Indicates, in case if a manual activation is required, to send an Email notification (Number Feature Manual Action) to customer to notify them they need to perform some actions to make this fully functional.

<!-- teletype has no message how and what steps are needed, just the name of features need manual steps -->

The MMS settings are same as above, just replace `sms` with `mms`.

For example:

```json
{
  "features": {
    "sms": {
      "enabled": true
    },
    "mms": {
      "enabled": true
    }
  }
}
```
