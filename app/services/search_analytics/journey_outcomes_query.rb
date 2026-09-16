# frozen_string_literal: true

module SearchAnalytics
  class JourneyOutcomesQuery
    def self.call(source:, log_stream_filter:, zero_result_condition:)
      terminal = <<~SQL.squish
        event = 'search_completed' AND result_count >= 0 AND
        (search_type = 'classic' OR search_type = 'classification' OR ((search_type = 'interactive' OR search_type = 'internal') AND
          (final_result_type = 'answers' OR final_result_type = 'error' OR
            ((final_result_type IS NULL OR final_result_type = '') AND
              (results_type = 'exact_match' OR results_type = 'opensearch' OR results_type = 'vector' OR results_type = 'hybrid')))))
      SQL
      state = <<~SQL.squish
        CASE WHEN completed_at IS NOT NULL AND completed_at = failed_at THEN 'conflict'
          WHEN completed_at IS NOT NULL AND (failed_at IS NULL OR completed_at > failed_at) THEN 'completed'
          WHEN failed_at IS NOT NULL THEN 'failed' ELSE 'none' END
      SQL
      <<~SQL
        SELECT #{state} AS terminal_state, questions_seen, unknown_seen, selected, zero_result,
          TO_JSON(COLLECT_SET(request_id)) AS request_ids, COUNT(*) AS journey_count,
          SUM(observed_events) AS event_count
        FROM (
          SELECT request_id, COUNT(*) AS observed_events,
            MAX(CASE WHEN #{terminal} THEN `@timestamp` ELSE NULL END) AS completed_at,
            MAX(CASE WHEN event = 'search_failed' THEN `@timestamp` ELSE NULL END) AS failed_at,
            MAX(CASE WHEN event = 'search_completed' AND final_result_type = 'questions' THEN 1 ELSE 0 END) AS questions_seen,
            MAX(CASE WHEN event = 'search_completed' AND NOT COALESCE((#{terminal}) OR final_result_type = 'questions', false) THEN 1 ELSE 0 END) AS unknown_seen,
            MAX(CASE WHEN event = 'result_selected' THEN 1 ELSE 0 END) AS selected,
            MAX(CASE WHEN #{terminal} AND (#{zero_result_condition} OR (search_type = 'classification' AND result_count = 0)) AND (search_degraded IS NULL OR search_degraded = false) THEN 1 ELSE 0 END) AS zero_result
          FROM #{source}
          WHERE #{log_stream_filter} AND service = 'search'
            AND event IN ('search_completed', 'search_failed', 'result_selected')
            AND request_id IS NOT NULL AND request_id != ''
          GROUP BY request_id
        ) AS observations
        GROUP BY #{state}, questions_seen, unknown_seen, selected, zero_result, SUBSTRING(request_id, 1, 1)
        LIMIT 10000
      SQL
    end
  end
end
