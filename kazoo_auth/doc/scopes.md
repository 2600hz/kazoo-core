# PROD-145: Add read-only scope to Kazoo authentication

This PR introduces several modules for the definition and enforcement of authentication scopes within the `kazoo_auth` workflow.

Currently, API restrictions are enforced using token restrictions which define resource and verb privileges for crossbar to use during request validation.  The provided backend modules are designed to be used with token restrictions and preserve any existing permission sets.

Scope enforcement is disabled by default and merges scopes with token restrictions in flight and does not modify the token restrictions definitions.

#### Related PRs
* [kazoo-core #25](https://github.com/2600hz/kazoo-core/pull/25)
* [kazoo-crossbar #23](https://github.com/2600hz/kazoo-crossbar/pull/23)

#### Administration Notes

#### Enabling Scope Enforcement

To enable scope enforcement, set `iam.enforce_scopes` to **true** in the `system_config/crossbar.auth`.  

For additional configuration details, consult the [Configuration](kazoo_auth/doc/scopes.md) documentation.

#### Database Maintenance
On startup, the `kazoo_auth_app` will create the `iam` database, load views, as well as the default scopes from their fixture files. 

Additionally, the new schema `scopes.json` should be automatically loaded on startup by crossbar.

## <a href="#config">Configuration</a>

Scope enforcement is **disabled** by default and was to can be enabled for crossbar in `crossbar.auth` database document.

| Key | Description | Default |
|-----|-------------|---------|
| **iam.enforce_scopes** | whether crossbar should honor scope claims | **false**
| **iam.scope_backend** | backend to use to map to token restrictions | **cb\_tr\_scope\_backend**
 

**Example:** system_config/crossbar.auth
```json
{
  ...
  
  "default": {
    ...
    
    "iam": {
          "enforce_scopes": true,
          "scope_backend": "cb_tr_scope_backend"
      }
    }    
    ...
}
```

## <a href="#usage">Usage</a>
Scopes and scope filtering can be requested during the authentication process.

**Example:** Read Only Scope
```sh
curl --request PUT \
  --url http://{CROSSBAR_URI}:8000/v2/user_auth \
  --header 'content-type: application/json' \
  --data '{
  "data": {
    "credentials": {CREDENTIAL_MD5},
    "method": "md5",
    "account_name": "A",
    "scope": "read_only"
  }
}'
```

**Example:** Filtered Scope
```sh
curl --request PUT \
  --url http://{CROSSBAR_URI}:8000/v2/user_auth \
  --header 'content-type: application/json' \
  --data '{
  "data": {
    "credentials": {CREDENTIAL_MD5},
    "method": "md5",
    "account_name": "A",
    "scope": "users:read devices:read"
  }
}'
```

**Example:** JWT Claims Payload
```json
{
  "iss": "kazoo",
  "identity_sig": "J3nbmw1iGPTphckoQPNzoDMWaF8hcWeeJaKe4VtYAjg",
  "email": "admin@admin.com",
  "method": "cb_user_auth",
  "owner_id": "ec8f7df47f8785b1af20273d3eb532c6",
  "account_id": "f9ed304ee54a8df8ef9e528c0496d51e",
  "scope": "email identity openid read_only role",
  "exp": 1592934900,
  "preferred_username": "admin@admin.com",
  "updated_at": 63759120691,
  "given_name": "admin",
  "family_name": "admin",
  "_read_only": true,
  "priv_level": "user"
}
```

## <a href="#backend">Kazoo Scope Backend</a>
A new OTP behaviour, `kz_scope_backend`, has been added which allows you to create a custom mapping module for scopes and their behaviors.

At this time the only available backend is the `cb_tr_scope_backend` which attempts to map API related scopes to the `token_restrictions` database.

### cb\_tr\_scope\_backend
This backend utilizes crossbar token restrictions and attempts to merge any scopes defined in the JWT with the restrictions defined for the requesting owner.

## <a href="#">Kazoo Scope Database</a>
By default scopes are stored in a new system database called `iam`.

These scopes can be queried using the `kz_scope_db` abstraction, which defaults to using the couchdb or `kazoo_scope_db_local` module.  `kz_scope_db` is also an OTP behaviour which can be used to create additional modules allowing you to derive scope definitions from other databases, auth providers, or even directory services.

Several scopes are pre-defined to handle system as well as begin to factor out OIDC metadata into standardized claims.

### Available Scopes
Default scopes and their claims are automatically added to the JWT during authentication in order to maintain backwards compatibility.

#### System Scopes
* identity<sup>1</sup>
* role<sup>1</sup>
* read_only

<sup>1</sup> _indicates a default scope_

##### identity
The identity scope is a default system scope responsible for adding owner and account claims to the JWT token.

**Example:** JWT Claims
```json
{
  ...  
  "method": "cb_user_auth",
  "owner_id": "ec8f7df47f8785b1af20273d3eb532c6",
  "account_id": "f9ed304ee54a8df8ef9e528c0496d51e",
  ...
}
```

##### role
The `role` scope is a default scope attempts to extract the owner's role and add it as a claim.

**Example:** JWT Claims
```json
{
  ...
  "priv_level": "user"
  ...
}
```

##### read_only
The `read_only` scope is an optional scope that will create a token that can only perform read operations against permitted resources.

**Example:** JWT Claims
```json
{
  ...
  "_read_only": true,
  ...
}
```

##### OpenID Connect Scopes
* openid<sup>1</sup>
* profile
* email

<sup>1</sup> _indicates a default scope_

#### openid
The `openid` scope is responsible for populating the defined claims for this OIDC scope.

**Example:** JWT Claims
```json
{
  ...
  "iss": "kazoo",  
  "scope": "email identity openid role",
  "exp": 1592935012,
  ...
}
```

#### profile
The `profile`  scope is responsible for populating the defined claims for this OIDC scope.

**Example:** JWT Claims
```json
{
  ...
  "preferred_username": "admin@admin.com",
  "updated_at": 63759120691,
  "given_name": "admin",
  "family_name": "admin",
  ...
}
```

##### email
The `email` scope is responsible for populating the defined claims for this OIDC scope.

**Example:** JWT Claims
```json
{
  ...
  "email": "admin@admin.com",
  ...
}
```
