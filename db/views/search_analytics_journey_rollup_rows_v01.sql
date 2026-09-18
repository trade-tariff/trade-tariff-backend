CREATE VIEW search_analytics_journey_rollup_rows AS
WITH single_day AS (
  SELECT d.*,
    CASE WHEN (d.terminal & 3) = 1 THEN 'completed'
         WHEN (d.terminal & 3) = 2 THEN 'failed'
         WHEN d.terminal IS NOT NULL OR (d.flags & 8) > 0 THEN 'unknown'
         WHEN (d.flags & 4) > 0 THEN 'nonterminal'
         ELSE 'unknown' END AS status
  FROM search_analytics_daily_journeys d
  WHERE NOT EXISTS (
    SELECT 1
    FROM search_analytics_repeated_journey_keys k
    WHERE k.service = d.service AND k.journey_key = d.journey_key
  )
)
SELECT service,
  reporting_date,
  v.view,
  'day'::text AS bucket_size,
  reporting_date::timestamp AS bucket,
  status,
  flags
FROM single_day
CROSS JOIN LATERAL (
  VALUES ('all', all_hours), ('classic', classic_hours), ('internal', internal_hours)
) v(view, hours)
WHERE hours > 0
UNION ALL
SELECT service,
  reporting_date,
  v.view,
  'hour'::text,
  reporting_date::timestamp + make_interval(hours => h),
  status,
  flags
FROM single_day
CROSS JOIN LATERAL (
  VALUES ('all', all_hours), ('classic', classic_hours), ('internal', internal_hours)
) v(view, hours)
CROSS JOIN generate_series(0, 23) h
WHERE (hours & (1::bigint << h)) > 0;
