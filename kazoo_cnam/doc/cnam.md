# CNAM - Caller ID Name

CNAM is a service provided by various companies that take the caller's number and return the "correct" caller ID name.

{% BRAND_NAME %} can be configured to do this lookup (sometimes called a CNAM dip) using different providers (like Telnyx or OpenCNAM).

## System configuration

The CNAM provider and settings are controlled in the `system_config/cnam` document.

### Provider settings

- `default.provider`: Configured to use `opencnam` (which means `cnam_opencnam` module exists in {% BRAND_NAME %} and exports `request/2`). Change to match the {% BRAND_NAME %} CNAM module of choice.

### Customizable {% BRAND_NAME %} settings

- `default.disable_normalize`: when set to `true`, the caller's number is used as provided by the upstream carrier. No attempt to normalize to E164 is made.
- `default.cnam_expires`: How long, in seconds, should a CNAM result be cached by {% BRAND_NAME %}.

### Customizable HTTP request settings

- `default.http_url` is a customizable URL. Variables to be filled in are denoted by `{{VARIABLE_NAME}}`.
- `default.http_body` is a template-able field which will add a request body to the CNAM provider.
- `default.http_method` to set the HTTP verb to use for the request (defaults to a GET)
- `default.http_content_type_header` is the value for the `Content-Type` HTTP header which should match the `http_body` (if any).
- `default.http_user_agent_header` is the value sent in the `User-Agent` HTTP header.
- `default.http_connect_timeout_ms` is the TCP connection timeout, in milliseconds. The time the provider takes to accept the HTTP connection will add to the caller's PDD (post-dial delay) experience and {% BRAND_NAME %}'s processing of the call.
- `default.http_basic_auth_username` and `default.http_basic_auth_password` if the provider requires HTTP Basic Auth


### OpenCNAM specific settings

```json
{"default":{
   "provider":"opencnam"
   ,"http_url":"https://api.opencnam.com/v2/phone/{{phone_number}}"
 }
}
```

### Telnyx specific settings

```json
{"default":{
   "provider":"telnyx"
   ,"http_url":"https://data.telnyx.com/cnam/v1/caller-information?tn={{phone_number}}"
   ,"http_token_auth_token":"{TELNYX_AUTH_TOKEN}"
 }
}
```

If `default.http_token_auth_token` is defined, an `Authorization` HTTP header will be included with this value.

## CNAM Dips in {% BRAND_NAME %}

When a call comes into FreeSWITCH from a resource (upstream carrier), a `directory` fetch request is sent to {% BRAND_NAME %}.

A series of checks are then performed to determine if a CNAM dip is needed. If any step is 'true', no CNAM dip will occur

1. Is the call from an anonymous caller?
2. Is the caller ID number reconcilable (matching the `reconcile_regex` in `system_config/number_manager`)?
3. Does the called number have `inbound_cnam` feature configured?

At this point, the CNAM provider module configured will be called to lookup the CID Name using the CID number of the caller.

## Debugging tips

### Check system configuration

If nothing is configured yet:

```bash
sup kazoo_cnam_maintenance info
no CNAM provider configured
```

OpenCNAM default configs:

```bash
CNAM settings in play:
 cnam_expires              | 900
 disable_normalize         | false
 http_accept_header        | text/pbx,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
 http_basic_auth_password  |
 http_basic_auth_username  |
 http_body                 |
 http_connect_timeout_ms   | 500
 http_content_type_header  | application/json
 http_method               | get
 http_url                  | https://api.opencnam.com/v2/phone/{{phone_number}}
 http_user_agent_header    | Kazoo CNAM
 provider                  | opencnam
```

### Check a CID number against the CNAM provider

```bash
sup kazoo_cnam_maintenance lookup 4158867900
CNAM lookup for 4158867900 has result 'CORTE MADERA CA'
```
