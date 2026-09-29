# frozen_string_literal: true

module SearchAnalytics
  class ActionQuery
    def self.call(source:, log_stream_filter:)
      <<~SQL
        SELECT search_type, request_source, search_action,
          TO_JSON(COLLECT_SET(request_id)) AS request_ids,
          COUNT(DISTINCT request_id) AS journey_count, COUNT(*) AS event_count
        FROM #{source}
        WHERE #{log_stream_filter} AND service = 'search' AND event = 'search_action_classified'
          AND search_action_version = 2
          AND request_source = 'frontend'
          AND request_id IS NOT NULL AND request_id != ''
        GROUP BY search_type, request_source, search_action, SUBSTRING(request_id, 1, 1)
        LIMIT 10000
      SQL
    end
  end
end
