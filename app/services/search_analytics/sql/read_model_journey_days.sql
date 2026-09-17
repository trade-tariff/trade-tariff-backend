INSERT INTO search_analytics_journey_days (
  read_model_id, reporting_date, journey_key, all_hours, classic_hours, internal_hours, terminal, flags
)
WITH groups AS MATERIALIZED (
  SELECT r.reporting_date, j.row->'journey_keys' AS keys,
    CASE WHEN r.name = 'search_journeys' AND j.row->>'request_source' = 'frontend'
      THEN 1::bigint << extract(hour FROM (j.row->>'@timestamp')::timestamptz AT TIME ZONE 'UTC')::int ELSE 0 END AS hours,
    j.row->>'search_type' AS search_type,
    CASE WHEN r.name = 'journey_outcomes' AND j.row->>'terminal_state' != 'none' THEN
      ((extract(epoch FROM (j.row->>'window_end')::timestamptz) * 1000000)::bigint << 2) |
      CASE j.row->>'terminal_state' WHEN 'completed' THEN 1 WHEN 'failed' THEN 2 ELSE 3 END END AS terminal,
    CASE WHEN r.name = 'journey_outcomes' THEN
      (CASE WHEN (j.row->>'selected')::int > 0 THEN 1 ELSE 0 END) |
      (CASE WHEN (j.row->>'zero_result')::int > 0 THEN 2 ELSE 0 END) |
      (CASE WHEN (j.row->>'questions_seen')::int > 0 THEN 4 ELSE 0 END) |
      (CASE WHEN (j.row->>'unknown_seen')::int > 0 THEN 8 ELSE 0 END)
      ELSE 0 END AS flags
  FROM search_analytics_query_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
  WHERE r.service = {{service}}
    AND r.reporting_date = {{reporting_date}}
    AND (
      (r.name = 'search_journeys' AND r.fingerprint = {{search_journeys_fingerprint}})
      OR (r.name = 'journey_outcomes' AND r.fingerprint = {{journey_outcomes_fingerprint}})
    )
), observations AS MATERIALIZED (
  SELECT reporting_date,
    decode(CASE WHEN k.key ~ '^[0-9a-f]{64}$' THEN k.key ELSE 'invalid journey key' END, 'hex') AS journey_key,
    hours,
    CASE WHEN search_type = 'classic' THEN hours ELSE 0 END AS classic_hours,
    CASE WHEN search_type IN ('internal', 'interactive') THEN hours ELSE 0 END AS internal_hours,
    terminal, flags
  FROM groups CROSS JOIN LATERAL jsonb_array_elements_text(keys) k(key)
)
SELECT {{read_model_id}}, reporting_date, journey_key,
  bit_or(hours) AS all_hours,
  bit_or(classic_hours) AS classic_hours,
  bit_or(internal_hours) AS internal_hours,
  search_analytics_latest_state(terminal) AS terminal,
  bit_or(flags) AS flags
FROM observations
GROUP BY reporting_date, journey_key;
