# frozen_string_literal: true

module SearchAnalytics
  class FrontendEventsQuery
    STREAM_FILTER = "`@logStream` LIKE '%ecs/frontend/%'"
    OUTCOMES = %w[question results no_results unknown_results blocking_guidance input_error backend_error].freeze
    ACTIONS = %w[result_selected dont_know].freeze

    def self.call(source:)
      outcomes = (OUTCOMES + ACTIONS + %w[page_visible]).map { |value| "'#{value}'" }.join(', ')
      <<~SQL
        SELECT request_id, DATE_TRUNC('HOUR', `@timestamp`) AS `@timestamp`, outcome,
          COALESCE(destination, '') AS destination, COUNT(*) AS event_count,
          MAX(question_count) AS reported_questions,
          MAX(browser_session_id) AS browser_session_id,
          MAX(result_rank) AS result_rank, MAX(confidence) AS confidence,
          SUM(CASE WHEN outcome = 'page_visible' AND client_navigation_ms >= 0 AND client_navigation_ms <= 86400000 THEN client_navigation_ms ELSE 0 END) AS navigation_total_ms,
          SUM(CASE WHEN outcome = 'page_visible' AND client_navigation_ms >= 0 AND client_navigation_ms <= 86400000 THEN 1 ELSE 0 END) AS navigation_observations
        FROM (
          SELECT `@timestamp`, #{json_field('request_id')} AS request_id,
            #{json_field('event')} AS event, #{json_field('outcome')} AS outcome,
            #{json_field('destination')} AS destination,
            #{json_field('browser_session_id')} AS browser_session_id,
            CAST(#{json_field('schema_version')} AS BIGINT) AS schema_version,
            CAST(#{json_field('question_count')} AS BIGINT) AS question_count,
            CAST(#{json_field('result_rank')} AS BIGINT) AS result_rank,
            #{json_field('confidence')} AS confidence,
            CAST(#{json_field('client_navigation_ms')} AS BIGINT) AS client_navigation_ms
          FROM #{source} WHERE #{STREAM_FILTER} AND `@message` LIKE '%guided_search.journey%'
        ) AS frontend_events
        WHERE event = 'guided_search.journey' AND schema_version = 1
          AND request_id IS NOT NULL AND request_id != '' AND outcome IN (#{outcomes})
        GROUP BY request_id, DATE_TRUNC('HOUR', `@timestamp`), outcome, COALESCE(destination, '')
        LIMIT 10000
      SQL
    end

    # Rails prefixes these JSON messages with severity, request ID and country.
    def self.json_field(name)
      "GET_JSON_OBJECT(REGEXP_EXTRACT(`@message`, '([{].*[}])', 1), '$.#{name}')"
    end
    private_class_method :json_field
  end
end
