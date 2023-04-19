# Engineering notes

Describe using temporal routes within KAZOO Erlang code.

## Loading

First, load the temporal route from the account's database:

```erlang
    {'ok', TemporalRouteDoc} = kz_datamgr:open_cache_doc(AccountId, TemporalRouteId).
```

Next, you will want to know the "local" timezone to use, to adjust the current server time from UTC to the local timezone.

Convert system time to local:

```erlang
    {LocalDate, LocalTime} = kz_time:adjust_utc_datetime(calendar:universal_time(), Timezone),
    LocalSeconds = calendar:datetime_to_gregorian_seconds({LocalDate, LocalTime})
```

Build a `rule` as managed by the `ktr_rule` module:

```erlang
    StartDate = kz_date:from_gregorian_seconds(kzd_temporal_rules:start_date(TemporalRulesDoc, LocalSeconds), Timezone),

    %% note: end date could be undefined
    EndDate = case kzd_temporal_rules:end_date(TemporalRulesDoc) of
        'undefined' -> 'undefined';
        ED -> kz_date:from_gregorian_seconds(ED, Timezone)
    end,

    Rule = ktr_rule:new(ReturnIfMatched, TemporalRouteDoc, StartDate, EndDate)
```

You could have one (or more) of these rules to process.
