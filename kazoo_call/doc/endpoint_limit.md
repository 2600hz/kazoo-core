# Endpoint Limit

Allows caller to know whether or not, the given endpoint has reached its limit by comparing given
endpoint's limit with the current number of ongoing calls for the given endpoint.

This example assumes the endpoint already exists with _limit=1_ configuration:

```
{ok, Endpoint} = kz_endpoint:get(EndpointId, AccountId),
EndpointId = kz_doc:id(Endpoint),
EndpointType = kzd_endpoint:type(Endpoint),
EndpointLimit = kzd_call_limits:max_concurrent(kzd_endpoint:call_limits(Endpoint)),

%% Having this environment, issue a request to check if the endpoint has reached its limit.
%% It should not, because there are not ongoing calls for this endpoint, yet.
false = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),

%% Now, place a call from/to Endpoint. The check should now return true because the endpoint's limit
%% was set to 1 and there is already 1 ongoing call for this Endpoint.
true = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit),

%% Hangup the call, the check should now return false because there are not calls associated to this
%% endpoint anymore.
false = kapps_endpoint_limit:has_reached_limit(EndpointId, EndpointType, EndpointLimit).
```
