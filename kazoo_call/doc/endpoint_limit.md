# Endpoint Limit

Allows caller to know whether or not, the given endpoint has reached its limit by comparing given
endpoint's limit with the current number of channels being used by the given endpoint.

The implementation requires 3 parameters to be provided:
- EndpointId
- EndpointType
- EndpointLimit

This new functionality may be used via AMQP by building the request object and sending it via
`kapi_call:publish_enforce_endpoint_limit_req/1` or via `kapps_endpoint_limit:has_reached_limit/3` API.

This example assumes the endpoint already exists with _limit=1_ configuration:

```
{ok, Endpoint} = kz_endpoint:get(EndpointId, AccountId),
EndpointId = kz_doc:id(Endpoint),
EndpointType = kzd_endpoint:type(Endpoint),
EndpointLimit = kzd_call_limits:max_concurrent(kzd_endpoint:call_limits(Endpoint)),

%% Having this environment, issue a request to check if the endpoint has reached its limit.
%% It should not, because there are not channels being used by this endpoint, yet.
false = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),

%% Now, place a call from/to Endpoint. The check should now return true because the endpoint's limit
%% was set to 1 and there is already 1 channel being used by this Endpoint.
true = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),

%% Hangup the call, the check should now return false because there are not channels associated to this
%% endpoint anymore.
false = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),



%% Same thing applies for users and accounts.
%% Assuming EndpointId has an owner.
OwnerId = kzd_endpoint:owner_id(Endpoint),
{ok, Owner} = kz_endpoint:get(OwnerId, AccountId),
%% Assumed to be 2 in this example.
OwnerLimit = kzd_call_limits:max_concurrent(kzd_endpoint:call_limits(Owner)),

%% Since EndpointId does not have any on going calls, response should be false for both.
false = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),
false = kapps_endpoint_limit:has_reached_limit(OwnerId, <<"user">>, OwnerLimit),

%% If a call is placed from/to EndpointId, check should return true when quering for endpoint's limit
%% and false, when querying for user's limit because user has a limit=2 and only 1 channels is in use.
true = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),
false = kapps_endpoint_limit:has_reached_limit(OwnerId, <<"user">>, OwnerLimit),

%% If call is hung up, response should be false again because not channels are being by either,
%% the endpoint, or the user.
false = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),
false = kapps_endpoint_limit:has_reached_limit(OwnerId, <<"user">>, OwnerLimit),
```
