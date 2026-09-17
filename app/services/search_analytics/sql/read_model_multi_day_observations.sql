INSERT INTO search_analytics_multi_day_observations (
  read_model_id, reporting_date, journey_key, all_hours, classic_hours, internal_hours, terminal, flags
)
SELECT d.read_model_id, d.reporting_date, d.journey_key, d.all_hours, d.classic_hours, d.internal_hours, d.terminal, d.flags
FROM search_analytics_journey_days d
JOIN search_analytics_multi_day_keys m USING (journey_key)
WHERE d.read_model_id = {{read_model_id}}
  AND d.reporting_date = {{reporting_date}};
