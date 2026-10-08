# frozen_string_literal: true

module SearchAnalytics
  # Join hashed identities in PostgreSQL, not large Ruby sets. Both inputs must
  # cover the same dates; clicks can belong to a result journey on another day.
  class SelectionRates
    SOURCE_NAMES = %w[selection_results selection_pages].freeze
    METADATA = %i[id service name reporting_date fingerprint collected_at].freeze

    def self.call(...) = new(...).call

    def initialize(service:, dates:, definitions:)
      @records = SearchAnalyticsQueryResult.where(service:, reporting_date: dates, name: SOURCE_NAMES)
        .select(*METADATA).all.select { |row| row.fingerprint == definitions.fetch(row.name) }
      @dates = dates.uniq.sort
    end

    def call
      collected = SOURCE_NAMES.map { |name| records.select { |row| row.name == name }.map(&:reporting_date) }.reduce(:&).sort
      # A later page visit must not be hidden by an uncollected day.
      totals = collected == @dates ? counts(collected) : {}
      {
        records:,
        coverage: {
          'complete' => collected == @dates,
          'collected_days' => collected.size,
          'expected_days' => @dates.size,
          'missing_dates' => (@dates - collected).map(&:iso8601),
        },
        views: Period::VIEWS.index_with do |view|
          denominator = totals["#{view}_results".to_sym]
          numerator = totals["#{view}_selected".to_sym]
          {
            'result_journeys' => denominator,
            'selected_result_journeys' => numerator,
            'selection_rate' => denominator&.positive? ? numerator.to_f / denominator : nil,
          }
        end,
      }
    end

  private

    attr_reader :records

    def counts(dates)
      ids = SOURCE_NAMES.index_with do |name|
        records.select { |row| row.name == name && dates.include?(row.reporting_date) }.map(&:id)
      end
      # Each stored row holds thousands of journey keys. Read the search type in
      # a MATERIALIZED CTE before the keys are expanded. Otherwise PostgreSQL
      # carries the whole JSONB row with every key into the grouping step, and
      # a 7-day read spills gigabytes to disk. Keys are hex, so "C" collation
      # compares them as bytes without locale rules.
      SearchAnalyticsQueryResult.db.fetch(<<~SQL).first
        WITH result_groups AS MATERIALIZED (
          SELECT observation->>'search_type' = 'classic' AS classic,
            observation->>'search_type' IN ('internal', 'interactive') AS internal,
            observation->'journey_keys' AS keys
          FROM search_analytics_query_results result,
            LATERAL jsonb_array_elements(result.rows) observation
          WHERE result.id IN (#{ids.fetch('selection_results').join(',')})
        ), eligible AS MATERIALIZED (
          SELECT identity.journey_key COLLATE "C" AS journey_key,
            bool_or(result_groups.classic) AS classic,
            bool_or(result_groups.internal) AS internal
          FROM result_groups,
            LATERAL jsonb_array_elements_text(result_groups.keys) identity(journey_key)
          GROUP BY 1
        ), selected AS (
          SELECT DISTINCT identity.journey_key COLLATE "C" AS journey_key
          FROM search_analytics_query_results result,
            LATERAL jsonb_array_elements(result.rows) observation,
            LATERAL jsonb_array_elements_text(observation->'journey_keys') identity(journey_key)
          JOIN eligible ON eligible.journey_key = identity.journey_key
          WHERE result.id IN (#{ids.fetch('selection_pages').join(',')})
        )
        SELECT COUNT(*) AS all_results, COUNT(selected.journey_key) AS all_selected,
          COUNT(*) FILTER (WHERE classic) AS classic_results,
          COUNT(selected.journey_key) FILTER (WHERE classic) AS classic_selected,
          COUNT(*) FILTER (WHERE internal) AS internal_results,
          COUNT(selected.journey_key) FILTER (WHERE internal) AS internal_selected
        FROM eligible LEFT JOIN selected USING (journey_key)
      SQL
    end
  end
end
