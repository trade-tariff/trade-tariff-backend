CREATE MATERIALIZED VIEW search_analytics_guided_outcome_counts AS
WITH starts AS (
  SELECT DISTINCT service, reporting_date, journey_key
  FROM search_analytics_frontend_event_occurrences
  WHERE outcome = 'initial_submitted'
), terminals AS (
  SELECT DISTINCT ON (service, reporting_date, journey_key)
    service,
    reporting_date,
    journey_key,
    CASE
      WHEN outcome = 'dont_know' THEN 'dont_know'
      WHEN destination IN ('results', 'no_results', 'unknown_results', 'blocking_guidance') THEN destination
      WHEN destination IN ('input_error', 'backend_error') THEN 'error'
    END AS outcome
  FROM search_analytics_frontend_event_occurrences
  WHERE outcome = 'dont_know'
    OR (
      outcome = 'page_visible'
      AND destination IN ('results', 'no_results', 'unknown_results', 'blocking_guidance', 'input_error', 'backend_error')
    )
  ORDER BY service, reporting_date, journey_key, observed_at DESC, outcome
)
SELECT starts.service,
  starts.reporting_date,
  COALESCE(terminals.outcome, 'abandonment') AS outcome,
  COUNT(*)::bigint AS journeys
FROM starts
LEFT JOIN terminals USING (service, reporting_date, journey_key)
GROUP BY starts.service, starts.reporting_date, COALESCE(terminals.outcome, 'abandonment')
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_guided_outcome_counts_identity
  ON search_analytics_guided_outcome_counts (service, reporting_date, outcome);
