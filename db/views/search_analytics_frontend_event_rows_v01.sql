CREATE VIEW search_analytics_frontend_event_rows AS
SELECT r.service,
  r.reporting_date,
  decode(CASE WHEN j.row->>'journey_key' ~ '^[0-9a-f]{64}$' THEN j.row->>'journey_key' ELSE 'invalid journey key' END, 'hex') AS journey_key,
  CASE WHEN j.row->>'event_key' ~ '^[0-9a-f]{64}$' THEN decode(j.row->>'event_key', 'hex') END AS event_key,
  CASE WHEN j.row->>'question_key' ~ '^[0-9a-f]{64}$' THEN decode(j.row->>'question_key', 'hex') END AS question_key,
  (j.row->>'observed_at')::timestamptz AS observed_at,
  j.row->>'outcome' AS outcome,
  COALESCE(j.row->>'destination', '') AS destination,
  COALESCE(j.row->>'response_source', '') AS response_source
FROM search_analytics_query_results r
CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
WHERE r.name = 'frontend_events'
  AND j.row->>'journey_key' IS NOT NULL
  AND j.row->>'observed_at' IS NOT NULL;
