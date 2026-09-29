# frozen_string_literal: true

module SearchAnalytics
  class SelectionQuery
    def self.results(source:, log_stream_filter:, request_exclusion_filter:)
      <<~SQL
        SELECT search_type, TO_JSON(COLLECT_SET(request_id)) AS request_ids,
          COUNT(DISTINCT request_id) AS journey_count, COUNT(*) AS event_count
        FROM #{source}
        WHERE #{log_stream_filter} AND service = 'search' AND event = 'search_completed'
          AND request_source = 'frontend' AND request_id IS NOT NULL AND request_id != ''
          AND result_count > 0 AND (search_degraded IS NULL OR search_degraded = false)
          AND ((search_type = 'classic' AND results_type = 'fuzzy_search')
            OR (search_type IN ('internal', 'interactive') AND results_type IN ('opensearch', 'vector', 'hybrid')
              AND (final_result_type IS NULL OR final_result_type = '' OR final_result_type = 'answers')))
          AND #{request_exclusion_filter}
        GROUP BY search_type, SUBSTRING(request_id, 1, 1)
        LIMIT 10000
      SQL
    end

    def self.selections(source:)
      <<~SQL
        SELECT TO_JSON(COLLECT_SET(request_id)) AS request_ids,
          COUNT(DISTINCT request_id) AS journey_count, COUNT(*) AS event_count
        FROM (
          SELECT #{json_field('params.request_id')} AS request_id,
            #{json_field('controller')} AS page_controller,
            #{json_field('action')} AS page_action,
            #{json_field('status')} AS page_status
          FROM #{source} WHERE #{FrontendEventsQuery::STREAM_FILTER}
        ) AS result_pages
        WHERE request_id IS NOT NULL AND request_id != ''
          AND page_controller IN ('CommoditiesController', 'HeadingsController', 'ChaptersController')
          AND page_action = 'show' AND page_status IN ('200', '304')
        GROUP BY SUBSTRING(request_id, 1, 1)
        LIMIT 10000
      SQL
    end

    def self.json_field(name)
      "GET_JSON_OBJECT(REGEXP_EXTRACT(`@message`, '([{].*[}])', 1), '$.#{name}')"
    end
    private_class_method :json_field
  end
end
