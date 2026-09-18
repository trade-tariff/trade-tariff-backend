CREATE VIEW search_analytics_repeated_journey_keys AS
SELECT service, journey_key
FROM search_analytics_daily_journeys
GROUP BY service, journey_key
HAVING count(*) > 1;
