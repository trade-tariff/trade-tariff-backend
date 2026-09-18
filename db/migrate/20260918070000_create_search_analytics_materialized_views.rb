# frozen_string_literal: true

Sequel.migration do # rubocop:disable Metrics/BlockLength
  up do
    %w[
      search_analytics_mv_latest_state
      search_analytics_journey_observation_rows
      search_analytics_daily_journeys
      search_analytics_repeated_journey_keys
      search_analytics_repeated_journeys
      search_analytics_journey_rollup_rows
      search_analytics_journey_rollup_totals
      search_analytics_source_revisions
    ].each do |name|
      run File.read(File.expand_path("../views/#{name}_v01.sql", __dir__))
    end
  end

  down do
    run <<~SQL
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_source_revisions;
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_journey_rollup_totals;
      DROP VIEW IF EXISTS search_analytics_journey_rollup_rows;
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_repeated_journeys;
      DROP VIEW IF EXISTS search_analytics_repeated_journey_keys;
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_daily_journeys;
      DROP VIEW IF EXISTS search_analytics_journey_observation_rows;
      DROP AGGREGATE IF EXISTS search_analytics_mv_latest_state(bigint);
      DROP FUNCTION IF EXISTS search_analytics_mv_latest_state(bigint, bigint);
    SQL
  end
end # rubocop:enable Metrics/BlockLength
