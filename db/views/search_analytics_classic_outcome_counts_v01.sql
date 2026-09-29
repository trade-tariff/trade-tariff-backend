CREATE MATERIALIZED VIEW search_analytics_classic_outcome_counts AS
SELECT r.service,
  r.reporting_date,
  j.row->>'outcome' AS outcome,
  SUM((j.row->>'searches')::bigint) AS searches
FROM search_analytics_query_results r
CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
WHERE r.name = 'classic_outcomes'
  AND j.row->>'outcome' IN ('results', 'no_results')
  AND j.row->>'searches' ~ '^[0-9]+$'
GROUP BY r.service, r.reporting_date, j.row->>'outcome'
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_classic_outcome_counts_identity
  ON search_analytics_classic_outcome_counts (service, reporting_date, outcome);
