DROP TABLE IF EXISTS pg_temp.search_analytics_multi_day_keys;
CREATE TEMP TABLE search_analytics_multi_day_keys ON COMMIT DROP AS
SELECT journey_key
FROM search_analytics_journey_days
WHERE read_model_id = {{read_model_id}}
GROUP BY journey_key
HAVING count(*) > 1;
CREATE UNIQUE INDEX search_analytics_multi_day_keys_identity ON pg_temp.search_analytics_multi_day_keys (journey_key);
