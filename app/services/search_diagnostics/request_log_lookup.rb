module SearchDiagnostics
  class RequestLogLookup
    QueryError = Class.new(StandardError)

    DEFAULT_LOOKBACK_HOURS = 72
    MAX_LOOKBACK_HOURS = 168
    DEFAULT_LIMIT = 200
    MAX_LIMIT = 500
    QUERY_POLL_INTERVAL_SECONDS = 1
    QUERY_MAX_POLLS = 30
    SEARCH_LOG_GROUP_NAME = "platform-logs-#{TradeTariffBackend.environment}".freeze

    Result = Data.define(:request_id, :log_group_name, :start_time, :end_time, :events)
    Event = Data.define(:timestamp, :event, :search_type, :message, :fields)

    def self.call(request_id:, lookback_hours: nil, limit: nil)
      new(request_id:, lookback_hours:, limit:).call
    end

    def self.client
      @client ||= Aws::CloudWatchLogs::Client.new
    end

    def initialize(request_id:, lookback_hours: nil, limit: nil, client: self.class.client, now: Time.current)
      @request_id = request_id.to_s.strip
      @lookback_hours = bounded_integer(lookback_hours, default: DEFAULT_LOOKBACK_HOURS, min: 1, max: MAX_LOOKBACK_HOURS)
      @limit = bounded_integer(limit, default: DEFAULT_LIMIT, min: 1, max: MAX_LIMIT)
      @client = client
      @now = now

      raise ArgumentError, 'request_id is required' if @request_id.blank?
    end

    def call
      query_id = client.start_query(
        log_group_name: SEARCH_LOG_GROUP_NAME,
        start_time: start_time.to_i,
        end_time: end_time.to_i,
        query_string: cloudwatch_query,
      ).query_id

      Result.new(
        request_id:,
        log_group_name: SEARCH_LOG_GROUP_NAME,
        start_time: start_time.iso8601,
        end_time: end_time.iso8601,
        events: await_query_results(query_id).map { |row| event_from(row) },
      )
    rescue Aws::Errors::ServiceError
      raise
    rescue QueryError
      raise
    rescue StandardError => e
      raise QueryError, e.message
    end

    private

    attr_reader :request_id, :lookback_hours, :limit, :client, :now

    def start_time
      @start_time ||= now - lookback_hours.hours
    end

    def end_time
      now
    end

    def await_query_results(query_id)
      QUERY_MAX_POLLS.times do
        response = client.get_query_results(query_id:)
        return response.results if response.status == 'Complete'

        raise QueryError, "CloudWatch query #{response.status}" if %w[Failed Cancelled Timeout Unknown].include?(response.status)

        Kernel.sleep QUERY_POLL_INTERVAL_SECONDS
      end

      raise QueryError, 'CloudWatch query timed out while polling'
    end

    def event_from(row)
      raw_fields = row.to_h { |field| [field.field, field.value] }
      message = raw_fields['@message']
      fields = parsed_message_fields(message)
        .merge(raw_fields.except('@message', '@timestamp', '@ptr'))
        .compact_blank

      Event.new(
        timestamp: raw_fields['@timestamp'] || fields['timestamp'],
        event: fields['event'],
        search_type: fields['search_type'],
        message:,
        fields:,
      )
    end

    def parsed_message_fields(message)
      return {} if message.blank?

      JSON.parse(message)
    rescue JSON::ParserError
      {}
    end

    def bounded_integer(value, default:, min:, max:)
      return default if value.blank?

      Integer(value).clamp(min, max)
    rescue ArgumentError, TypeError
      default
    end

    def cloudwatch_query
      <<~QUERY
        fields @timestamp, @message, event, request_id, search_type, trace_version, query, base_query, effective_query, original_query, expanded_query, refined_query, added_answers, reason, result_count, max_score, total_duration_ms, duration_ms, leg, status, retrieval_method, stage, iteration, match_source, matched_value, target_type, target_id, target_endpoint, goods_nomenclature_item_id, goods_nomenclature_sid, goods_nomenclature_class, model, response_type, attempt_number, question_count, logged_question_count, questions_truncated, answer_count, candidate_count, logged_candidate_count, candidates_truncated, ranked_answer_count, logged_ranked_answer_count, ranked_answers_truncated, confidence_levels, ranking_source, final_result_type, results_type, total_attempts, total_questions, result_limit, error_type, error_message, error_message_truncated, details, description_intercept_matched, description_intercept_term, description_intercept_excluded, description_intercept_filtering, description_intercept_filter_prefix_count, description_intercept_guidance_level, description_intercept_guidance_location, description_intercept_escalate_to_webchat, matched, term, excluded, filtering, filter_prefix_count, guidance_level, guidance_location, escalate_to_webchat
        | filter service = "search" and request_id = #{request_id.to_json}
        | sort @timestamp asc
        | limit #{limit}
      QUERY
    end
  end
end
