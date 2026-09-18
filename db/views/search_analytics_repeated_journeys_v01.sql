CREATE MATERIALIZED VIEW search_analytics_repeated_journeys AS
SELECT d.service,
  d.reporting_date,
  d.journey_key,
  d.all_hours,
  d.classic_hours,
  d.internal_hours,
  d.terminal,
  d.flags
FROM search_analytics_daily_journeys d
JOIN search_analytics_repeated_journey_keys k USING (service, journey_key)
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_repeated_journeys_identity
  ON search_analytics_repeated_journeys (service, reporting_date, journey_key);
