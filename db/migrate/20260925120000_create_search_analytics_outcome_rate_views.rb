# frozen_string_literal: true

Sequel.migration do
  up do
    %w[
      search_analytics_frontend_event_rows
      search_analytics_frontend_event_occurrences
      search_analytics_guided_outcome_counts
      search_analytics_question_outcome_counts
      search_analytics_classic_outcome_counts
      search_analytics_outcome_source_revisions
    ].each do |name|
      run File.read(File.expand_path("../views/#{name}_v01.sql", __dir__))
    end
  end

  down do
    run <<~SQL
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_outcome_source_revisions;
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_classic_outcome_counts;
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_question_outcome_counts;
      DROP MATERIALIZED VIEW IF EXISTS search_analytics_guided_outcome_counts;
      DROP VIEW IF EXISTS search_analytics_classic_outcome_rows;
      DROP VIEW IF EXISTS search_analytics_frontend_event_occurrences;
      DROP VIEW IF EXISTS search_analytics_frontend_event_rows;
    SQL
  end
end
