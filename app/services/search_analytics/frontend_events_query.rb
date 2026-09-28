# frozen_string_literal: true

module SearchAnalytics
  class FrontendEventsQuery
    STREAM_FILTER = "`@logStream` LIKE '%ecs/frontend/%'"
    OUTCOMES = %w[question results no_results unknown_results blocking_guidance input_error backend_error].freeze
    ACTIONS = %w[result_selected dont_know].freeze
    RATE_OUTCOMES = %w[initial_submitted answer_accepted].freeze

    def self.call(source:, service:)
      outcomes = (OUTCOMES + ACTIONS + RATE_OUTCOMES + %w[page_visible]).map { |value| "'#{value}'" }.join(', ')
      event_id = "CASE WHEN event_id IS NULL OR event_id = '' THEN NULL ELSE event_id END"
      question_id = "CASE WHEN question_id IS NULL OR question_id = '' THEN NULL ELSE question_id END"
      response_source = "CASE WHEN response_source IS NULL OR response_source = '' THEN NULL ELSE response_source END"
      <<~SQL
        SELECT request_id, #{event_id} AS event_id, MIN(`@timestamp`) AS observed_at,
          DATE_TRUNC('HOUR', MIN(`@timestamp`)) AS `@timestamp`, outcome,
          COALESCE(destination, '') AS destination, COUNT(*) AS event_count,
          MAX(question_count) AS reported_questions,
          browser_session_id, result_rank, confidence,
          #{question_id} AS question_id, #{response_source} AS response_source,
          SUM(CASE WHEN outcome = 'page_visible' AND client_navigation_ms >= 0 AND client_navigation_ms <= 86400000 THEN client_navigation_ms ELSE 0 END) AS navigation_total_ms,
          SUM(CASE WHEN outcome = 'page_visible' AND client_navigation_ms >= 0 AND client_navigation_ms <= 86400000 THEN 1 ELSE 0 END) AS navigation_observations
        FROM (
          SELECT `@timestamp`, #{json_field('request_id')} AS request_id,
            #{json_field('event')} AS event, #{json_field('outcome')} AS outcome,
            #{json_field('destination')} AS destination,
            #{json_field('browser_session_id')} AS browser_session_id,
            #{json_field('event_id')} AS event_id,
            #{json_field('question_id')} AS question_id,
            #{json_field('response_source')} AS response_source,
            #{json_field('service')} AS service,
            CAST(#{json_field('schema_version')} AS BIGINT) AS schema_version,
            CAST(#{json_field('question_count')} AS BIGINT) AS question_count,
            CAST(#{json_field('result_rank')} AS BIGINT) AS result_rank,
            #{json_field('confidence')} AS confidence,
            CAST(#{json_field('client_navigation_ms')} AS BIGINT) AS client_navigation_ms
          FROM #{source} WHERE #{STREAM_FILTER} AND `@message` LIKE '%guided_search.journey%'
        ) AS frontend_events
        WHERE event = 'guided_search.journey' AND schema_version = 1
          AND request_id IS NOT NULL AND request_id != ''
          AND (service IS NULL OR service = '' OR service = '#{service}')
          AND outcome IN (#{outcomes})
        GROUP BY request_id, #{event_id},
          CASE WHEN #{event_id} IS NULL THEN `@timestamp` ELSE CAST('1970-01-01 00:00:00' AS TIMESTAMP) END,
          outcome, COALESCE(destination, ''), result_rank, confidence, browser_session_id,
          #{question_id}, #{response_source}
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
