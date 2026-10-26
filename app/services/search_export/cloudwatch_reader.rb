# frozen_string_literal: true

module SearchExport
  class CloudwatchReader
    Error = Class.new(StandardError)
    Journey = Data.define(:request_id, :query, :expansion_terms, :answers, :end_page_type, :results, :terminal_at, :omitted)
    OpenedPage = Data.define(:commodity_code, :opened_at)
    Result = Data.define(:journeys, :opened_pages)
    LIMIT = 10_000
    RUNTIME_LIMIT = 40.minutes
    SCAN_LIMIT = 500.gigabytes
    LATE_OPEN_WINDOW = 1.day
    EVENTS = %w[evaluation_journey_recorded search_failed search_stage_failed].freeze
    # The frontend accepts only these guided request IDs. Visit queries match
    # short prefixes to stay within the CloudWatch query length limit; the
    # reader then matches complete IDs.
    LINKABLE_REQUEST_ID = /\A[a-zA-Z0-9-]{1,64}\z/
    REQUEST_ID_PREFIX_LENGTH = 8
    # 900 eight-character prefixes keep a visit query within the
    # 10,000-character CloudWatch query limit.
    VISIT_BATCH_SIZE = 900

    def self.call(from:, to:, generated_at:)
      new(from:, to:, generated_at:).call
    end

    def initialize(from:, to:, generated_at:, client: Aws::CloudWatchLogs::Client.new(http_open_timeout: 5, http_read_timeout: 15, retry_limit: 1))
      @start = from.to_time(:utc).to_i
      @finish = (to + 1).to_time(:utc).to_i
      # Integer arithmetic keeps the cutoff numeric; the AWS client sends an
      # ActiveSupport::Duration timestamp as a string, which CloudWatch rejects.
      @cutoff = [@finish + LATE_OPEN_WINDOW.to_i, generated_at.to_i].min
      @client = client
      @journeys = {}
      @first_terminals = {}
      @opened_pages = Hash.new { |hash, key| hash[key] = [] }
      @failed = Set.new
      @scanned_bytes = 0
      @window_bytes = {}
    end

    def call
      @deadline = monotonic_time + RUNTIME_LIMIT
      windows.each { |start, finish| read_window(start, finish, method(:journey_query), method(:consume_event)) }
      plan = visit_plan
      # Each visit query scans its whole day again.
      projected = @scanned_bytes + plan.sum { |start, _finish, batches| batches.size * @window_bytes.fetch(start, 0) }
      raise Error, 'The export would exceed 500 GiB of scanned data. Choose a shorter date range.' if projected > SCAN_LIMIT

      plan.each do |start, finish, batches|
        batches.each do |request_ids|
          read_window(start, finish, ->(from, to) { visit_query(from, to, request_ids) }, method(:consume_visit))
        end
      end
      check_deadline!
      journeys = @journeys.values.sort_by { |journey| [journey.terminal_at, journey.request_id] }.map do |journey|
        journey.with(omitted: journey.omitted || @failed.include?(journey.request_id))
      end
      Result.new(journeys:, opened_pages: @opened_pages.slice(*@journeys.keys))
    rescue Aws::Errors::ServiceError, JSON::ParserError, KeyError, ArgumentError, TypeError
      raise Error, 'Could not read complete journey logs. Please try again.'
    end

  private

    def windows
      (@start...@cutoff).step(1.day.to_i).map { |start| [start, [start + 1.day.to_i, @cutoff].min] }
    end

    def read_window(start, finish, query, consumer)
      check_deadline!
      query_id = @client.start_query(
        log_group_name: "platform-logs-#{TradeTariffBackend.environment}",
        start_time: start, end_time: finish, limit: LIMIT,
        query_string: query.call(start, finish)
      ).query_id
      response = await_results(query_id)
      @window_bytes[start] ||= response.statistics&.bytes_scanned.to_f
      if response.results.size >= LIMIT || response.statistics.records_matched.to_i > response.results.size
        raise Error, 'Too many events in one second. The workbook cannot be exported completely.' if finish - start <= 1

        midpoint = (start + finish) / 2
        read_window(start, midpoint, query, consumer)
        read_window(midpoint, finish, query, consumer)
      else
        response.results.each { |row| consumer.call(row.to_h { |field| [field.field, field.value] }) }
      end
    end

    def journey_query(start, finish)
      <<~QUERY
        fields @timestamp, @message, jsonParse(@message) as entry
        | filter @logStream like /ecs\\/(backend|worker)-#{TradeTariffBackend.service}\\//
        | filter entry.service = "search" and entry.request_source = "frontend"
        | filter entry.event in #{EVENTS.to_json}
        | filter toMillis(@timestamp) >= #{start * 1000} and toMillis(@timestamp) < #{finish * 1000}
        | sort @timestamp asc
        | limit #{LIMIT}
        | display @timestamp, @message
      QUERY
    end

    # Frontend request logs prefix Lograge JSON with Rails log tags. The prefix
    # filter can also match another request ID field; consume_visit rejects it.
    def visit_query(start, finish, request_ids)
      prefixes = request_ids.map { |id| id[0, REQUEST_ID_PREFIX_LENGTH] }.uniq.join('|')
      <<~QUERY
        fields @timestamp, @message
        | filter @logStream like /ecs\\/frontend\\//
        | filter @message like /"controller":"CommoditiesController"/ and @message like /"action":"show"/
        | filter @message like /"request_id":"(#{prefixes})/
        | filter toMillis(@timestamp) >= #{start * 1000} and toMillis(@timestamp) < #{finish * 1000}
        | sort @timestamp asc
        | limit #{LIMIT}
        | display @timestamp, @message
      QUERY
    end

    # Each UTC day needs visits only for journeys whose visit window overlaps it.
    def visit_plan
      journeys = @journeys.values.select { |journey| journey.end_page_type == TerminalPage::RESULT && journey.request_id.to_s.match?(LINKABLE_REQUEST_ID) }
      windows.filter_map do |start, finish|
        request_ids = journeys.filter_map do |journey|
          first = @first_terminals.fetch(journey.request_id)
          journey.request_id if first.to_r < finish && visit_deadline(first).to_i > start
        end
        [start, finish, request_ids.each_slice(VISIT_BATCH_SIZE).to_a] if request_ids.any?
      end
    end

    # A journey's visits count until midnight UTC at the end of the following day.
    def visit_deadline(first_terminal)
      first_terminal.utc.beginning_of_day + 1.day + LATE_OPEN_WINDOW
    end

    def await_results(query_id)
      complete = false
      query_bytes = 0
      loop do
        check_deadline!
        response = @client.get_query_results(query_id:)
        complete = response.status == 'Complete'
        reported_bytes = [response.statistics&.bytes_scanned.to_f, query_bytes].max
        @scanned_bytes += reported_bytes - query_bytes
        query_bytes = reported_bytes
        raise Error, 'The export exceeded 500 GiB of scanned data.' if @scanned_bytes > SCAN_LIMIT

        check_deadline!
        return response if complete
        raise Error, 'CloudWatch could not complete the export query.' unless %w[Scheduled Running].include?(response.status)

        sleep 1
      end
    ensure
      begin
        @client.stop_query(query_id:) unless complete
      rescue Aws::Errors::ServiceError
        # Preserve the original failure; cancellation is best effort.
      end
    end

    def monotonic_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def check_deadline!
      raise Error, 'The export exceeded 40 minutes of log collection.' if monotonic_time >= @deadline
    end

    def consume_event(fields)
      event = JSON.parse(fields.fetch('@message'))
      id = event['request_id']
      return if id.blank?

      case event['event']
      when 'evaluation_journey_recorded'
        record_journey(event, id)
      when 'search_failed', 'search_stage_failed'
        @failed.add(id)
      end
    end

    def consume_visit(fields)
      page = JSON.parse(fields.fetch('@message')[/\{.*\}/m].to_s)
      params = page['params']
      return unless page['controller'] == 'CommoditiesController' && page['action'] == 'show'
      return unless %w[200 304].include?(page['status'].to_s) && params.is_a?(Hash)

      id = params['request_id']
      code = params['id'].to_s
      return unless @journeys.key?(id) && code.present?

      opened_at = Time.find_zone!('UTC').parse(fields.fetch('@timestamp'))
      first = @first_terminals.fetch(id)
      return unless opened_at >= first && opened_at < visit_deadline(first)

      @opened_pages[id] << OpenedPage.new(commodity_code: code, opened_at:)
    end

    def record_journey(event, id)
      return unless event['trace_version'] == JourneyProjection::TRACE_VERSION

      terminal_at = Time.iso8601(event.fetch('terminal_at'))
      return unless terminal_at.to_i >= @start && terminal_at.to_i < @finish && terminal_at.to_i < @cutoff

      @first_terminals[id] = [@first_terminals[id], terminal_at].compact.min
      return if @journeys[id] && @journeys[id].terminal_at > terminal_at

      details = event.fetch('details')
      raise TypeError unless %w[answers results expansion_terms].all? { |field| details.fetch(field).is_a?(Array) }
      raise TypeError unless details['answers'].all? { |answer| answer.is_a?(Hash) && answer['options'].is_a?(Array) }
      raise TypeError unless details['results'].all? { |result| result.is_a?(Hash) }

      @journeys[id] = Journey.new(
        request_id: id, query: event.fetch('query'), terminal_at:,
        expansion_terms: details.fetch('expansion_terms'), answers: details.fetch('answers'),
        results: details.fetch('results'), end_page_type: event.fetch('end_page_type'),
        omitted: event['search_degraded'] == true
      )
    end
  end
end
