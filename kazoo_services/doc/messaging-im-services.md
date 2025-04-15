# Instant Messaging Services

This page describes how to cluster operator can enable and configure IM in Services. IM feature must also be activated
per carrier module in [Number Manager](../../kazoo_numbers/doc/knm_im.md).

Depending on how you want to charge customers for SMS and MMS features, you may choose to either:

- Define a Service Plan with IM section and assign this Plan to accounts
- Let accounts/resellers use the IM service without any IM section in their plans

## Using Service Plan for IM

Each Service Plan can have an `im` field defined with relevant data to activate and charges for IM activities.

Services will get and merge all plans assigned to the account to get the final answer for the amount to charge and
enablement of IM services.

Reseller can define Service Plans and assign it to their customers (sub-accounts). Or cluster operator can define a top level
Plan and assigned them to reseller/accounts.

The parameters are configurable for both type of IM, `sms` and `mms`. The parameters are as followed:

- `enabled`: Indicates this type of IM functionality is enabled by this plan.
- `rate.inbound`: The flat rate amount for charging when receiving message. If not set, defaults to `0.007` for SMS and `0.015` for MMS.
- `rate.outbound`: The flat rate amount for charging when sending a message. If not set, defaults to `0.007` for SMS and `0.015` for MMS.

For example:

```json
{
  "im": {
    "sms": {
      "enabled": true,
      "rate": {
        "inbound": 0.007,
        "outbound": 0.007
      }
    },
    "mms": {
      "enabled": true,
      "rate": {
        "inbound": 0.015,
        "outbound": 0.015
      }
    }
  }
}
```

## Activate IM when account has no IM plan assigned

If you want to allow any account that has no IM Service Plan assigned to them be able use IM service you may want to use
this setting. Cluster operator can only enable this.

If enabled this, the default flat rate mentioned above still applies:

- `0.007` for inbound/outbound SMS
- `0.015` for inbound/outbound MMS

For allowing normal sub-accounts with no IM plan assign use IM services cluster-wide use this maintenance command:

```shell
sup kapps_config set_boolean services.im policy.no_plan.account.sms.enabled true
sup kapps_config set_boolean services.im policy.no_plan.account.mms.enabled true
```

For allowing normal reseller-accounts with no IM plan assign use IM services cluster-wide use this maintenance command:

```shell
sup kapps_config set_boolean services.im policy.no_plan.reseller.sms.enabled true
sup kapps_config set_boolean services.im policy.no_plan.reseller.mms.enabled true
```
