# frozen_string_literal: true

module SearchAnalytics
  class CloudwatchQuery
    QueryError = Class.new(StandardError)

    QUERY_POLL_INTERVAL_SECONDS = 1
    QUERY_MAX_POLLS = 30
    RAW_RESULT_LIMIT = 10_000
    TERMINAL_FAILURE_STATUSES = %w[Failed Cancelled Timeout].freeze
    SEARCH_LOG_GROUP_NAME = "platform-logs-#{TradeTariffBackend.environment}".freeze

    def self.call(period:, view: 'all', client: self.client, now: Time.current)
      new(period:, view:, client:, now:).call
    end

    def self.client
      @client ||= Aws::CloudWatchLogs::Client.new
    end

    def initialize(period:, view: 'all', client: self.class.client, now: Time.current)
      @period = Period.for(period:, view:)
      @client = client
      @now = now
    end

    def call
      query_id = client.start_query(
        log_group_name: SEARCH_LOG_GROUP_NAME,
        start_time: start_time.to_i,
        end_time: end_time.to_i,
        limit: RAW_RESULT_LIMIT,
        query_string: cloudwatch_query,
      ).query_id

      await_query_results(query_id).map { |row| parsed_row(row) }
    rescue Aws::Errors::ServiceError
      raise
    rescue QueryError
      raise
    rescue StandardError => e
      raise QueryError, e.message
    end

    private

    attr_reader :period, :client, :now

    def start_time
      now - period.duration
    end

    def end_time
      now
    end

    def await_query_results(query_id)
      QUERY_MAX_POLLS.times do
        response = client.get_query_results(query_id:)
        if response.status == 'Complete'
          raise QueryError, 'CloudWatch query reached the raw result limit; use an aggregated query for this period' if response.results.size >= RAW_RESULT_LIMIT

          return response.results
        end

        raise QueryError, "CloudWatch query #{response.status}" if TERMINAL_FAILURE_STATUSES.include?(response.status)

        Kernel.sleep QUERY_POLL_INTERVAL_SECONDS
      end

      raise QueryError, 'CloudWatch query timed out while polling'
    end

    def parsed_row(row)
      raw_fields = row.to_h { |field| [field.field, field.value] }
      parsed_message_fields(raw_fields['@message'])
        .merge(raw_fields.except('@message', '@ptr'))
        .compact_blank
    end

    def parsed_message_fields(message)
      return {} if message.blank?

      JSON.parse(message)
    rescue JSON::ParserError
      {}
    end

    def cloudwatch_query
      <<~QUERY
        fields @timestamp, @message, event, request_id, search_type, query, result_count, total_duration_ms, duration_ms, match_source, matched_value, target_type, target_id, error_type, error_message
        | filter service = "search" and event in ["search_completed", "search_failed", "result_selected", "exact_match_selected", "fuzzy_results_returned", "api_call_completed", "retrieval_leg_completed", "retrieval_results_returned", "description_intercept_checked"]
        | sort @timestamp asc
      QUERY
    end
  end
end
