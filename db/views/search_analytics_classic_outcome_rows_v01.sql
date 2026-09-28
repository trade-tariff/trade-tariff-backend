CREATE VIEW search_analytics_classic_outcome_rows AS
SELECT r.service,
  r.reporting_date,
  decode(CASE WHEN j.row->>'journey_key' ~ '^[0-9a-f]{64}$' THEN j.row->>'journey_key' ELSE 'invalid journey key' END, 'hex') AS journey_key,
  (j.row->>'observed_at')::timestamptz AS observed_at,
  (j.row->>'result_count')::bigint AS result_count
FROM search_analytics_query_results r
CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
WHERE r.name = 'classic_outcomes'
  AND j.row->>'journey_key' ~ '^[0-9a-f]{64}$'
  AND j.row->>'observed_at' IS NOT NULL
  AND j.row->>'result_count' ~ '^[0-9]+$'
  AND (j.row->>'result_count')::bigint >= 0;
