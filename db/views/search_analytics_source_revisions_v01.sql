CREATE MATERIALIZED VIEW search_analytics_source_revisions AS
SELECT id,
  service,
  reporting_date,
  name,
  fingerprint,
  collected_at,
  1 AS definition_version
FROM search_analytics_query_results
WHERE name IN ('search_journeys', 'journey_outcomes')
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_source_revisions_identity
  ON search_analytics_source_revisions (service, reporting_date, name);
