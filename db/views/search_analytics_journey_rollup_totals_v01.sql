CREATE MATERIALIZED VIEW search_analytics_journey_rollup_totals AS
SELECT service,
  reporting_date,
  view,
  bucket_size,
  bucket,
  count(*) AS journeys,
  count(*) FILTER (WHERE status = 'completed') AS completed,
  count(*) FILTER (WHERE status = 'failed') AS failed,
  count(*) FILTER (WHERE status = 'nonterminal') AS nonterminal,
  count(*) FILTER (WHERE status = 'unknown') AS unknown,
  count(*) FILTER (WHERE (flags & 1) > 0) AS selected,
  count(*) FILTER (WHERE (flags & 2) > 0) AS zero_result
FROM search_analytics_journey_rollup_rows
GROUP BY service, reporting_date, view, bucket_size, bucket
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_journey_rollup_totals_identity
  ON search_analytics_journey_rollup_totals (service, reporting_date, view, bucket_size, bucket);
