CREATE VIEW search_analytics_frontend_event_occurrences AS
SELECT service,
  reporting_date,
  journey_key,
  event_key,
  question_key,
  observed_at,
  outcome,
  destination,
  response_source
FROM (
  SELECT DISTINCT ON (service, reporting_date, event_key)
    service,
    reporting_date,
    journey_key,
    event_key,
    question_key,
    observed_at,
    outcome,
    destination,
    response_source
  FROM search_analytics_frontend_event_rows
  WHERE event_key IS NOT NULL
  ORDER BY service, reporting_date, event_key, observed_at ASC, outcome
) AS deduplicated_events
UNION ALL
SELECT service,
  reporting_date,
  journey_key,
  event_key,
  question_key,
  observed_at,
  outcome,
  destination,
  response_source
FROM search_analytics_frontend_event_rows
WHERE event_key IS NULL;
