INSERT INTO search_analytics_journey_rollups (
  read_model_id, reporting_date, view, bucket_size, bucket,
  journeys, completed, failed, nonterminal, unknown, selected, zero_result
)
WITH single_day AS MATERIALIZED (
  SELECT d.*,
    CASE WHEN (d.terminal & 3) = 1 THEN 'completed'
         WHEN (d.terminal & 3) = 2 THEN 'failed'
         WHEN d.terminal IS NOT NULL OR (d.flags & 8) > 0 THEN 'unknown'
         WHEN (d.flags & 4) > 0 THEN 'nonterminal' ELSE 'unknown' END AS status
  FROM search_analytics_journey_days d
  WHERE d.read_model_id = {{read_model_id}}
    AND d.reporting_date = {{reporting_date}}
    AND NOT EXISTS (
      SELECT 1 FROM search_analytics_multi_day_keys m WHERE m.journey_key = d.journey_key
    )
), buckets AS (
  SELECT reporting_date, v.view, 'day' AS bucket_size, reporting_date::timestamp AS bucket, status, flags
  FROM single_day
  CROSS JOIN LATERAL (VALUES ('all', all_hours), ('classic', classic_hours), ('internal', internal_hours)) v(view, hours)
  WHERE hours > 0
  UNION ALL
  SELECT reporting_date, v.view, 'hour', reporting_date::timestamp + make_interval(hours => h), status, flags
  FROM single_day
  CROSS JOIN LATERAL (VALUES ('all', all_hours), ('classic', classic_hours), ('internal', internal_hours)) v(view, hours)
  CROSS JOIN generate_series(0, 23) h
  WHERE (hours & (1::bigint << h)) > 0
)
SELECT {{read_model_id}}, reporting_date, view, bucket_size, bucket,
  count(*) AS journeys,
  count(*) FILTER (WHERE status = 'completed') AS completed,
  count(*) FILTER (WHERE status = 'failed') AS failed,
  count(*) FILTER (WHERE status = 'nonterminal') AS nonterminal,
  count(*) FILTER (WHERE status = 'unknown') AS unknown,
  count(*) FILTER (WHERE (flags & 1) > 0) AS selected,
  count(*) FILTER (WHERE (flags & 2) > 0) AS zero_result
FROM buckets
GROUP BY reporting_date, view, bucket_size, bucket;
