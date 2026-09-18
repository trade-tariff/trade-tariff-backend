CREATE MATERIALIZED VIEW search_analytics_daily_journeys AS
SELECT service,
  reporting_date,
  journey_key,
  bit_or(all_hours) AS all_hours,
  bit_or(classic_hours) AS classic_hours,
  bit_or(internal_hours) AS internal_hours,
  search_analytics_mv_latest_state(terminal) AS terminal,
  bit_or(flags) AS flags
FROM search_analytics_journey_observation_rows
GROUP BY service, reporting_date, journey_key
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_daily_journeys_identity
  ON search_analytics_daily_journeys (service, reporting_date, journey_key);
