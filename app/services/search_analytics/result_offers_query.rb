# frozen_string_literal: true

module SearchAnalytics
  class ResultOffersQuery
    def self.call(source:, log_stream_filter:)
      <<~SQL
        SELECT result_rank, confidence, COUNT(*) AS event_count
        FROM #{source}
        WHERE #{log_stream_filter} AND service = 'search'
          AND event = 'result_offered' AND search_type = 'interactive'
          AND request_source = 'frontend'
          AND result_rank > 0
          AND #{ClassicHybridFilter.call(source:, log_stream_filter:)}
        GROUP BY result_rank, confidence
        LIMIT 10000
      SQL
    end
  end
end
