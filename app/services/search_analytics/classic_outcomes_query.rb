# frozen_string_literal: true

module SearchAnalytics
  # Frontend-origin classic fuzzy completions. Empty means total result_count 0.
  # Exact matches and the commodity-only zero metric are not this population.
  class ClassicOutcomesQuery
    OUTCOMES = %w[results no_results].freeze

    def self.call(source:, log_stream_filter:)
      <<~SQL
        SELECT request_id, `@timestamp` AS observed_at, result_count, 1 AS event_count
        FROM #{source}
        WHERE #{log_stream_filter}
          AND service = 'search' AND event = 'search_completed'
          AND search_type = 'classic' AND results_type = 'fuzzy_search'
          AND request_source = 'frontend'
          AND result_count >= 0
          AND request_id IS NOT NULL AND request_id != ''
        LIMIT #{DailyQuery::ROW_LIMIT}
      SQL
    end

    # Keep the latest completion per search, then store only the two daily counts.
    # The CloudWatch rows are not persisted.
    def self.collapse(rows)
      return [] if rows.empty?

      latest = {}
      rows.each do |row|
        key = row['journey_key']
        next if key.blank? || !row['result_count'].to_s.match?(/\A\d+\z/)

        current = latest[key]
        latest[key] = row if current.nil? || row['observed_at'].to_s >= current['observed_at'].to_s
      end
      counts = latest.values.group_by { |row| row['result_count'].to_i.zero? ? 'no_results' : 'results' }
      OUTCOMES.map do |outcome|
        searches = counts.fetch(outcome, []).size
        { 'outcome' => outcome, 'searches' => searches, 'event_count' => searches }
      end
    end
  end
end
