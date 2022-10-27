# Endpoint Limit

**NOTE**: This functionality is only meant to be used for endpoints with a limitation already set,
it does not work for devices without limitation.

This new functionality allows to keep track of concurrent calls per endpoint by exposing an API to
`reserve`, `release`, and list `reservations`.

The way this restriction works is, when a request to create a new reservation is made, the code will
get the maximum concurrent calls limit for the given endpoint and owner (if any) and will count the
current numbers of reservations for this endpoint and its owner (if any) and will compare it with
their limits. If current number of reservations (for both, the endpoint and the owner, if any)
is lower than the limit, it creates a new reservation for the endpoint and returns a tuple in the
form `{ok, reservation_id, current_reservations_count, available_reservations_count}`. If limit was
reached, the reservation will be denied and a tuple in the form `{error, 486}` will be returned.

When building the endpoint, the lowest limit from the endpoint itself, the owner (if endpoint=device
and assigned), and the account the endpoint belongs to, will be set to the endpoint. Check
`kz_endpoint_tests:call_limits_test_/0` for some examples.

For the following example, *AccountId* and *EndpointId* (unassigned) existence is assumed, the
endpoint with a limitation of 2 maximum concurrent calls.

```erlang
AccounId = <<"account012345">>,
EndpointId = <<"device012345">>, %% Unassigned device.

%% Creating reservations
{ok, ReservationId0, 1, 1} = kapps_endpoint_limit_ra:reserve(AccountId, EndpointId),
{ok, ReservationId1, 2, 0} = kapps_endpoint_limit_ra:reserve(AccountId, EndpointId),
{error, 486} = kapps_endpoint_limit_ra:reserve(AccountId, UserId),  %% Because device's limit was reached.

%% Listing reservations:
EndpointMap = #{'uuids' := [ReservationId1, ReservationId0], 'limit' := 2},
%% - All
{ok, #{AccountId := #{EndpointId := EndpointMap}}} = kapps_endpoint_limit_ra:reservations(),
%% - Per Account
{ok, #{EndpointId := EndpointMap}} = kapps_endpoint_limit_ra:reservations(AccountId),
%% - Per Account->endpoint_id
{ok, [ReservationId1, ReservationId0]} = kapps_endpoint_limit_ra:reservations(AccountId, EndpointId),

%% Releasing reservations
{ok, 1, 1} = kapps_endpoint_limit_ra:release(ReservationId0),
{ok, 0, 2} = kapps_endpoint_limit_ra:release(ReservationId1).
```

Now, let us take a look at an scenario where the endpoint is a device, and this device has an owner.
For this scenario, as well as for the previous scenario, AccountId, OwnersId, and EndpointId existence
is assumed. In this scenario, owners's limit=1 and device's limit=2.

```erlang
OwnerLimit = 1,
AccounId = <<"account012345">>,
OwnerId = <<"Owner012345">>,
EndpointId = <<"device012345">>, %% Assigned to OwnerId.

%% Creating reservations
%% The number of available spots in this response is zero, because when the endpoint was built, it
%% was assigned the lowest limit between its own configuration and its owner configuration, owner's
%% limit in this case. Which results in both the Owner and the device having the same limit value.
{ok, ReservationId, 1, 0} = kapps_endpoint_limit_ra:reserve(AccountId, EndpointId),
{error, 486} = kapps_endpoint_limit_ra:reserve(AccountId, UserId), %% Because owner's limit was reached.

%% Listing reservations:
%% Since the device is assigned, when a reservation is made, the reservation is also linked to the
%% device's owner.
%% - All
EndpointMap = #{'uuids' := [ReservationId], 'limit' := OwnerLimit},
%% In this case, both have the same limit, just because the reservation is being made for the device,
%% the device has an owner, and the owner has a lower limit than the device itself.
{ok, #{AccountId := #{EndpointId := EndpointMap
                     ,OwnerId := EndpointMap
                     }}} = kapps_endpoint_limit_ra:reservations(),
%% - Per Account
{ok, #{EndpointId := EndpointLimit
      ,OwnerId := EndpointLimit
      }} = kapps_endpoint_limit_ra:reservations(AccountId),
%% - Per Account->endpoint_id
{ok, [ReservationId]} = kapps_endpoint_limit_ra:reservations(AccountId, EndpointId),
{ok, [ReservationId]} = kapps_endpoint_limit_ra:reservations(AccountId, OwnerId),

%% Releasing reservations
{ok, 0, OwnerLimit} = kapps_endpoint_limit_ra:release(ReservationId0),
```
