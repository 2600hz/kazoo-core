# Enforcing Secure Password

By default Kazoo is not enforcing a secure password. System administrator can opt-in to force the password strength
requirement for users in their entire system.

The enforcement is implemented as a list of regular expressions. Each regular expression should
return a match. Non match means the regex is rejecting the password as it is not secure.

## Password strength configuration

There are a couple of configurations to control this password strength enforcer:

- Enabling password strength enforcer:
  - `sup kapps_config set_boolean auth.password should_enforce_strength true`
    - To disable use same command but set it to `false`
- Preventing setting the same old password, ff you need to force users to not use the same password again:
    - `sup kapps_config set_boolean auth.password should_prevent_reuse true`
      - To disable use same command but set it to `false`
- Password strength regular expressions, this setting is JSON object, with key being a friendly name for regex and value is an object holding regex to run:
    - Config key: `strength_regexes`
    - Config doc id:
        - For global: database `system_config` and doc id is `auth.password`
        - For per reseller/account: database is the reseller/account database and doc id
          is `configs_auth.password`
    - If you change the CouchDB doc directly don't forget to flush the cache or if you changed an account directly:
      - `sup kapps_config flush auth.password`

### Regular Expressions for Password Strength

The JSON object structure is like below:

```json
{
    "{REGEX_NAME}": {
        "regex": "{REGEX}",
        "message": "{MESSAGE}"
    }
}
```

Where:

- `REGEX_NAME`: a short name for regex
- `REGEX`: This is the regex that should match. If no match, it adds an error to list and reject the password
  - Please pay attention that you must escape the regex string properly otherwise it won't work.
    - For example the a regex similiar to `"[-_.,<>!?@#$%^&*=+(){}[\\]/\\\\|;:'\"]"` for special characters, must escapes the following:
      - `]` must be escaped: `\\]`
      - For literal `\` it must be escaped as `\\\\`
      - `"` must be escape as `\"`
- `MESSAGE`: This is a short error message to return to the user explaining why the password is being rejected.

#### Default Regular Expressions

```json
{
  "strength_regexes": {
    "minimum_length": {
      "regex": "^.{10,}$",
      "message": "minimum password length is 10 characters"
    },
    "lower_case": {
      "regex": "[a-z]",
      "message": "at least one lower case character is required"
    },
    "upper_case": {
      "regex": "[A-Z]",
      "message": "at least one upper case character is required"
    },
    "digit": {
      "regex": "[0-9]",
      "message": "at least one digit is required"
    },
    "special": {
      "regex": "[^a-zA-Z0-9]",
      "message": "at least one special character is required"
    }
  }
}
```
