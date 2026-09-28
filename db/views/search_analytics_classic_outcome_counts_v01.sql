CREATE MATERIALIZED VIEW search_analytics_classic_outcome_counts AS
WITH classified AS (
  SELECT DISTINCT ON (service, reporting_date, journey_key)
    service,
    reporting_date,
    CASE WHEN result_count = 0 THEN 'no_results' ELSE 'results' END AS outcome
  FROM search_analytics_classic_outcome_rows
  ORDER BY service, reporting_date, journey_key, observed_at DESC
)
SELECT service, reporting_date, outcome, COUNT(*)::bigint AS searches
FROM classified
GROUP BY service, reporting_date, outcome
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_classic_outcome_counts_identity
  ON search_analytics_classic_outcome_counts (service, reporting_date, outcome);
