# Instant Messaging Services

Describes how to enable and configure Service plans. IM feature must also be activate per carrier module
in Number Manager.

Depending on how you want to and charge for SMS and MMS features, you may choose to either
use define a Service Plan with IM and assign this Plan to accounts or accept the IM service without any plan.

## Using Service Plan for IM

Each Service Plan can have an `im` parameter defined with relevant data to activate and charges for
IM activities.

Services and Number Manager will get and merge all plans assigned to the account to get the final
answer for the amount to charge and enablement of IM services.

The parameters are as followed:

- `sms.enabled`: Indicates the SMS functionality is enabled by this plan.
- `sms.rate.inbound`: The flat rate amount for charging when receiving a SMS. If not set, defaults to `0.007`.
- `sms.rate.outbound`: The flat rate amount for charging when sending a SMS. If not set, defaults to `0.007`.
- `mms.rate.inbound`: The flat rate amount for charging when receiving a MMS. If not set, defaults to `0.015`.
- `mms.rate.outbound`: The flat rate amount for charging when sending a MMS. If not set, defaults to `0.015`.

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
    },
  }
}
```

## Activate IM when account has no IM plan assigned

If you want to allow any account that has no IM Service Plan assigned to them be able use IM service
you may want to use this setting.

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
