module SearchDiagnostics
  class RelatedRequests
    SESSION_ID_FORMAT = /\Av1:[0-9a-f]{64}\z/
    EXPERIMENT_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/
    REQUEST_ID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    MAX_REQUESTS = 20
    SCAN_LIMIT = 200

    Request = Data.define(:request_id, :occurred_at, :query, :experiment, :browser_session_id)
    Result = Data.define(:browser_session_id, :experiment, :requests)

    def self.for_search_request(request_id:, lookback_hours: nil, client: RequestLogLookup.client, now: Time.current)
      new(lookback_hours:, client:, now:).for_search_request(request_id)
    end

    def self.for_filter(browser_session_id: nil, experiment: nil, lookback_hours: nil, client: RequestLogLookup.client, now: Time.current)
      new(lookback_hours:, client:, now:).for_filter(browser_session_id:, experiment:)
    end

    def initialize(lookback_hours:, client:, now:)
      @lookback_hours = bounded_integer(
        lookback_hours,
        default: RequestLogLookup::DEFAULT_LOOKBACK_HOURS,
        min: 1,
        max: RequestLogLookup::MAX_LOOKBACK_HOURS,
      )
      @client = client
      @now = now
    end

    def for_search_request(request_id)
      request_id = request_id.to_s
      return empty_result unless request_id.match?(REQUEST_ID_FORMAT)

      session_id, experiment = session_for(request_id)
      return Result.new(browser_session_id: nil, experiment:, requests: []) if session_id.blank?

      requests = requests_for_session(session_id).reject { |request| request.request_id == request_id }
      Result.new(browser_session_id: session_id, experiment:, requests:)
    end

    def for_filter(browser_session_id:, experiment:)
      session_id = browser_session_id.to_s.presence
      label = experiment.to_s.presence
      raise ArgumentError, 'browser_session_id or experiment is required' if session_id.blank? && label.blank?
      raise ArgumentError, 'browser_session_id is invalid' if session_id.present? && !session_id.match?(SESSION_ID_FORMAT)
      raise ArgumentError, 'experiment is invalid' if label.present? && !label.match?(EXPERIMENT_FORMAT)

      requests = if session_id.present?
                   requests_for_session(session_id)
                 else
                   requests_for_experiment(label)
                 end
      Result.new(browser_session_id: session_id, experiment: label, requests:)
    end

  private

    attr_reader :lookback_hours, :client, :now

    def empty_result
      Result.new(browser_session_id: nil, experiment: nil, requests: [])
    end

    def session_for(request_id)
      rows = query_rows(<<~QUERY)
        fields @timestamp, @message
        | filter @message like /#{request_id}/ and @message like /browser_session_id/
        | sort @timestamp asc
        | limit 20
      QUERY

      rows.each do |row|
        fields = message_fields(row['@message'])
        session_id = fields['browser_session_id'].to_s
        next unless session_id.match?(SESSION_ID_FORMAT)
        next unless fields['search_request_id'] == request_id || journey_request?(fields, request_id)

        return [session_id, fields['experiment'].presence || fields['experiment_label'].presence]
      end

      [nil, nil]
    end

    def requests_for_session(session_id)
      rows = query_rows(<<~QUERY)
        fields @timestamp, @message
        | filter @message like /#{session_id}/
        | filter @message like /search_request_id/ or @message like /guided_search\\.journey/
        | sort @timestamp desc
        | limit #{SCAN_LIMIT}
      QUERY

      collect_requests(rows, browser_session_id: session_id)
    end

    def requests_for_experiment(experiment)
      rows = query_rows(<<~QUERY)
        fields @timestamp, @message, request_id, query, experiment
        | filter service = "search" and event = "search_started" and experiment = #{experiment.to_json}
        | sort @timestamp desc
        | limit #{SCAN_LIMIT}
      QUERY

      collect_requests(rows, experiment:)
    end

    def collect_requests(rows, browser_session_id: nil, experiment: nil)
      requests = {}

      rows.each do |row|
        fields = message_fields(row['@message']).merge(row.except('@message', '@timestamp', '@ptr'))
        request_id = search_request_id(fields)
        next unless request_id&.match?(REQUEST_ID_FORMAT)

        current = requests[request_id]
        occurred_at = row['@timestamp'].presence || fields['timestamp'].presence
        query = fields['query'].presence || nested_query(fields)
        label = experiment.presence || fields['experiment'].presence || fields['experiment_label'].presence
        session_id = browser_session_id.presence || fields['browser_session_id'].presence
        next if current && current.query.present? && query.blank?

        requests[request_id] = Request.new(
          request_id:,
          occurred_at: current&.occurred_at || occurred_at,
          query: current&.query.presence || query,
          experiment: label,
          browser_session_id: session_id,
        )
      end

      requests.values.first(MAX_REQUESTS)
    end

    def search_request_id(fields)
      return fields['search_request_id'].presence if fields['search_request_id'].present?
      return fields['request_id'].presence if %w[guided_search.journey search_started].include?(fields['event'])

      nil
    end

    def journey_request?(fields, request_id)
      fields['event'] == 'guided_search.journey' && fields['request_id'] == request_id
    end

    def nested_query(fields)
      params = fields['params']
      return unless params.is_a?(Hash)

      params['q'].presence || params.dig('search', 'q').presence
    end

    def message_fields(message)
      return {} if message.blank?

      json = message[message.index('{')..]
      return {} if json.blank?

      parsed = JSON.parse(json)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def query_rows(query_string)
      query_id = client.start_query(
        log_group_name: RequestLogLookup::SEARCH_LOG_GROUP_NAME,
        start_time: (now - lookback_hours.hours).to_i,
        end_time: now.to_i,
        query_string:,
      ).query_id

      await_query_results(query_id).map { |row| row.to_h { |field| [field.field, field.value] } }
    end

    def await_query_results(query_id)
      RequestLogLookup::QUERY_MAX_POLLS.times do
        response = client.get_query_results(query_id:)
        return response.results if response.status == 'Complete'

        if %w[Failed Cancelled Timeout Unknown].include?(response.status)
          raise RequestLogLookup::QueryError, "CloudWatch query #{response.status}"
        end

        Kernel.sleep RequestLogLookup::QUERY_POLL_INTERVAL_SECONDS
      end

      raise RequestLogLookup::QueryError, 'CloudWatch query timed out while polling'
    end

    def bounded_integer(value, default:, min:, max:)
      return default if value.blank?

      Integer(value).clamp(min, max)
    rescue ArgumentError, TypeError
      default
    end
  end
end
