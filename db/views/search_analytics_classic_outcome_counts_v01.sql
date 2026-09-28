CREATE MATERIALIZED VIEW search_analytics_classic_outcome_counts AS
SELECT service, reporting_date, outcome, SUM(searches)::bigint AS searches
FROM (
  SELECT r.service,
    r.reporting_date,
    j.row->>'outcome' AS outcome,
    (j.row->>'searches')::bigint AS searches
  FROM search_analytics_query_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
  WHERE r.name = 'classic_outcomes'
    AND j.row->>'outcome' IN ('results', 'no_results')
    AND j.row->>'searches' ~ '^[0-9]+$'
  UNION ALL
  SELECT service,
    reporting_date,
    CASE WHEN result_count = 0 THEN 'no_results' ELSE 'results' END AS outcome,
    1 AS searches
  FROM (
    SELECT DISTINCT ON (service, reporting_date, journey_key)
      service,
      reporting_date,
      result_count
    FROM search_analytics_classic_outcome_rows
    ORDER BY service, reporting_date, journey_key, observed_at DESC
  ) AS classified
) AS combined
GROUP BY service, reporting_date, outcome
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_classic_outcome_counts_identity
  ON search_analytics_classic_outcome_counts (service, reporting_date, outcome);
