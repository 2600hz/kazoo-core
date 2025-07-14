# Number Messaging Feature

To activate SMS/MMS for a number, the number MUST be assigned to an account and be `in_service` state. If both
conditions are valid, there are some configurations needed to be done by cluster operator to make SMS and MMS feature be
available to their customers.

### SMS/MMS feature is enabled in Services

You must ensure IM service is activated for the account's Service Plans before. See
[Messaging IM Services](../../kazoo_services/doc/messaging-im-services.md).

### Activating SMS/MMS feature in Number Manager

Make sure Number Manager `features` config is configured and includes `sms` and `mms`:

```shell
sup  kapps_config set_list_string_append number_manager features.allow sms
sup  kapps_config set_list_string_append number_manager features.allow mms
```

### SMS/MMS feature settings per carrier

IM feature must be activated per carrier. Each carrier module can provide settings and configuration either through
their source code or as system configuration to make IM feature available for that carrier in Number Manager.

Carrier module system configs are usually stored as `number_manager.knm_{CARRIER}` which `{CARRRIER}` indicates the name
of carrier or carrier module.

The expected SMS settings parameters are:

- `features.sms.enabled`: Indicate the feature is enabled to not
- `featuers.sms.activation`: Indicates if a manual steps are required to be done by the cluster operator after feature
  is enabled for the number in Number Manager. Accepted values are:
  - `auto`: Default value, indicates the activation is automatic and no action is required from cluster operator
  - `manual`: If true, indicates the customer is expected to manually perform other actions required to make this
    feature fully functional. See `activation_notify_to` too.
- `features.sms.activation_notify_to`: An Email address, in case if a manual activation is required, to send an Email
  notification (Number Feature Manual Action) to cluster operator to notify them they need to perform some actions to
  make this fully functional. This is the email address of a person that manages the cluster numbers in upstream carriers.

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

## See also

- IM feature in [Trunking.io Carrier](https://docs.2600hz.com/git/2600hz/kazoo-core/kazoo_numbers/doc/knm_trunkingio.md)
