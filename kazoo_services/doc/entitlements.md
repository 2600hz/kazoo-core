# Entitlements

We start with a system-level capability (or capabilities):

```json
{
  "_id": "entitlements",
  "capabilities": {
    "{CAPABILITY_ID}": {
      "enabled": true,
      "name": "friendly name"
    }
  },
  "pvt_account_id": "{MASTER_ACCOUNT_ID}"
}
```

Here `{CAPABILITY_ID}` is an arbitrary string, can be 32-char UUID or the name of the capability or whatever.

Top-level entitlements are stored in the master account and have an implicit enrollment in all enabled capabilities.

## Account enrollment

An account's capabilities are determined by the parent account's enabled capabilities combined with the parent account's enrollments in those capabilities. If a parent does not have a capability enabled, or the parent has not enrolled in the capability, the child account will not see it as an option for enrolling.

An account may enroll in a capability currently offered but if any ancestor account unenrolls or disables the capability, this is reflected in the account's entitlements.

## Calculating Account entitlements

Given an account C with parent B and top-level account A:

- Fetch C's account tree -> [A, B]
- Remove top-level account and append C -> [B, C]
- Fetch A's capabilities (top-level has implied enrollments in all enabled capabilities)
- Fold over the tree `[B, C]` to create a list of calculated entitlements, using `[{A_Caps, A_Caps}]` as initial accumulator
  - Resulting list should be [{C_Cap, C_Enroll}, {B_Cap, B_Enroll}, {A_Cap, A_Cap}]
  - Head of list is the account's calculated capabilities and enrollments
  - Filter out disabled capabilities and enrollments, and set both into an `entitlements` doc to return

The fold works by fetching the account's configured entitlements (B first, then C) and, using the head of the accumulator list (which would be the parent of the current account), fold over the parent account's capabilities.

- If the parent capability is disabled or the parent enrollment is disabled, mark the account's capability and enrollment as disabled
- If both the parent capability and enrollment are enabled:
  - get the account's enrollment in the capability
    - if undefined, treat the capability as available but unenrolled
    - if false, mark the capability and enrollment as disabled
    - if true, mark the capability as enabled (enrollmen is already configured enabled)

The account's capabilities and enrollments then become the parent for the next account.

### Examples

#### Only top-level capability defined
*Configured*
A: {"capabilities":{"{CAP_ID}":{"enabled":true}}}
B: {}
C: {}

*Computed*
A: {"capabilities":{"{CAP_ID}":{"enabled":true}}}
B: {"capabilities":{"{CAP_ID}":{"enabled":true}}, "enrollments:{}}
C: {"capabilities":{}, "enrollments":{}}

#### Reseller is enrolled
*Configured*
A: {"capabilities":{"{CAP_ID}":{"enabled":true}}}
B: {"enrollments":{"{CAP_ID}":{"enabled":true}}}
C: {}

*Computed*
A: {"capabilities":{"{CAP_ID}":{"enabled":true}}}
B: {"capabilities":{"{CAP_ID}":{"enabled":true}}, "enrollments:{"{CAP_ID}":{"enabled":true}}}
C: {"capabilities":{"{CAP_ID}":{"enabled":true}}}, "enrollments":{}}

#### Account is enrolled
*Configured*
A: {"capabilities":{"{CAP_ID}":{"enabled":true}}}
B: {"enrollments":{"{CAP_ID}":{"enabled":true}}}
C: {"enrollments":{"{CAP_ID}":{"enabled":true}}}

*Computed*
A: {"capabilities":{"{CAP_ID}":{"enabled":true}}}
B: {"capabilities":{"{CAP_ID}":{"enabled":true}}, "enrollments:{"{CAP_ID}":{"enabled":true}}}
C: {"capabilities":{"{CAP_ID}":{"enabled":true}}, "enrollments:{"{CAP_ID}":{"enabled":true}}}

#### Reseller unenrolls

*Configured*
| Account | Capability | Enrollment |
|---------|------------|------------|
| A       | True       |            |
| B       |            | False      |
| C       |            | True       |

*Computed*

| Account | Capability | Enrollment |
|---------|------------|------------|
| A       | True       | True       |
| B       | True       | False      |
| C       | False      | False      |

## User enrollments

A user in an account can enroll in a capability as well. The only change is the initial list of accounts to fold over becomes `[B, C, UserInCEntitlements]`. When a user's entitlements are fetched, it is appended to the account's tree, but otherwise calculating of entitlements follows the above with the account C being the parent capabliities and enrollments when calculating the user's.

## Account overlays

Account overlays are entitlement docs for a sub-account, stored in the reseller's account DB, and take precedence over an account's entitlements configured in the account's DB.

The account's entitlements are merged into the overlay entitlements (with the overlay taking priority), and entitlement computation continues as normal.
