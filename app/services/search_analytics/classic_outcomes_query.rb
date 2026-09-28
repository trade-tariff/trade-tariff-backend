# frozen_string_literal: true

module SearchAnalytics
  # Frontend-origin classic fuzzy completions. Empty means total result_count 0.
  # Exact matches and the commodity-only zero metric are not this population.
  class ClassicOutcomesQuery
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
  end
end
