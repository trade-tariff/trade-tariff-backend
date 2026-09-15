# frozen_string_literal: true

module SearchAnalytics
  class JourneyQueries
    def initialize(source:, log_stream_filter:)
      @source = source
      @stream = log_stream_filter
    end

    def journeys
      <<~SQL
        SELECT search_type, request_source, DATE_TRUNC('HOUR', `@timestamp`) AS `@timestamp`,
          TO_JSON(COLLECT_SET(request_id)) AS request_ids,
          COUNT(DISTINCT request_id) AS journey_count, COUNT(*) AS started_events
        FROM #{@source}
        WHERE #{@stream} AND service = 'search' AND event = 'search_started'
          AND request_source = 'frontend'
          AND request_id IS NOT NULL AND request_id != ''
        GROUP BY search_type, request_source, DATE_TRUNC('HOUR', `@timestamp`), SUBSTRING(request_id, 1, 1)
        LIMIT 10000
      SQL
    end

    def cost_summary(cost_filter:)
      <<~SQL
        SELECT request_id,
          SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN total_cost_usd ELSE 0 END) AS aggregated_total_cost_usd,
          SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN 1 ELSE 0 END) AS aggregated_priced_calls,
          SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN 0 ELSE 1 END) AS aggregated_unpriced_calls
        FROM #{@source}
        WHERE #{@stream} AND request_id IS NOT NULL AND request_id != '' AND (#{cost_filter})
        GROUP BY request_id
        LIMIT 10000
      SQL
    end
  end
end
