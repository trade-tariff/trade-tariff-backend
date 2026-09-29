# frozen_string_literal: true

Sequel.migration do # rubocop:disable Metrics/BlockLength
  up do
    run <<~SQL
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_classic_outcome_counts;
      DROP VIEW IF EXISTS search_analytics_classic_outcome_rows;
    SQL
    run File.read(File.expand_path('../views/search_analytics_classic_outcome_counts_v01.sql', __dir__))
  end

  down do # rubocop:disable Metrics/BlockLength
    run 'DROP MATERIALIZED VIEW IF EXISTS search_analytics_classic_outcome_counts'
    run <<~SQL
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

      CREATE MATERIALIZED VIEW search_analytics_classic_outcome_counts AS
      SELECT service, reporting_date, outcome, SUM(searches)::bigint AS searches
      FROM (
        SELECT r.service,
          r.reporting_date,
          j.row->>'outcome' AS outcome,
          (j.row->>'searches')::bigint AS searches
        FROM search_analytics_query_results r
        CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
        WHERE r.name = 'classic_outcomes'
          AND j.row->>'outcome' IN ('results', 'no_results')
          AND j.row->>'searches' ~ '^[0-9]+$'
        UNION ALL
        SELECT service,
          reporting_date,
          CASE WHEN result_count = 0 THEN 'no_results' ELSE 'results' END AS outcome,
          1 AS searches
        FROM (
          SELECT DISTINCT ON (service, reporting_date, journey_key)
            service,
            reporting_date,
            result_count
          FROM search_analytics_classic_outcome_rows
          ORDER BY service, reporting_date, journey_key, observed_at DESC
        ) AS classified
      ) AS combined
      GROUP BY service, reporting_date, outcome
      WITH NO DATA;

      CREATE UNIQUE INDEX search_analytics_classic_outcome_counts_identity
        ON search_analytics_classic_outcome_counts (service, reporting_date, outcome);
    SQL
  end
end # rubocop:enable Metrics/BlockLength
