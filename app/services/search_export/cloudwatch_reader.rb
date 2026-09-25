# frozen_string_literal: true

module SearchExport
  class CloudwatchReader
    Error = Class.new(StandardError)
    Journey = Data.define(:request_id, :query, :expansion_terms, :answers, :end_page_type, :results, :terminal_at, :omitted)
    Click = Data.define(:commodity_code, :clicked_at)
    Result = Data.define(:journeys, :clicks)
    LIMIT = 10_000
    MAX_QUERIES = 512
    MAX_BYTES = 100.megabytes
    DEADLINE = 10.minutes
    LATE_CLICK_WINDOW = 1.day
    EVENTS = %w[evaluation_journey_recorded result_selected search_failed search_stage_failed].freeze

    def self.call(from:, to:, generated_at:)
      new(from:, to:, generated_at:).call
    end

    def initialize(from:, to:, generated_at:, client: Aws::CloudWatchLogs::Client.new(http_open_timeout: 5, http_read_timeout: 15, retry_limit: 1))
      @start = from.to_time(:utc).to_i
      @finish = (to + 1).to_time(:utc).to_i
      @cutoff = [@finish + LATE_CLICK_WINDOW, generated_at.to_i].min
      @client = client
      @queries = 0
      @bytes = 0
      @journeys = {}
      @selections = Hash.new { |hash, key| hash[key] = [] }
      @failed = Set.new
    end

    def call
      @deadline = monotonic_time + DEADLINE
      (@start...@cutoff).step(1.day.to_i) do |start|
        read_window(start, [start + 1.day.to_i, @cutoff].min)
      end
      journeys = @journeys.values.sort_by { |journey| [journey.terminal_at, journey.request_id] }.map do |journey|
        journey.with(omitted: journey.omitted || @failed.include?(journey.request_id))
      end
      Result.new(journeys:, clicks: @selections.slice(*@journeys.keys))
    rescue Aws::Errors::ServiceError, JSON::ParserError, KeyError, ArgumentError, TypeError
      raise Error, 'Could not read complete journey logs. Please try again with a shorter date range.'
    end

  private

    def read_window(start, finish)
      @queries += 1
      raise Error, 'Too many log queries. Please shorten the date range.' if @queries > MAX_QUERIES

      check_deadline!
      query_id = @client.start_query(
        log_group_name: "platform-logs-#{TradeTariffBackend.environment}",
        start_time: start, end_time: finish, limit: LIMIT,
        query_string: query(start, finish)
      ).query_id
      response = await_results(query_id)
      if response.results.size >= LIMIT || response.statistics.records_matched.to_i > response.results.size
        raise Error, 'Too many events in one second. The workbook cannot be exported completely.' if finish - start <= 1

        midpoint = (start + finish) / 2
        read_window(start, midpoint)
        read_window(midpoint, finish)
      else
        response.results.each { |row| consume(row) }
      end
    end

    def query(start, finish)
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

    def await_results(query_id)
      complete = false
      loop do
        check_deadline!
        response = @client.get_query_results(query_id:)
        if response.status == 'Complete'
          complete = true
          return response
        end
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

    def consume(row)
      fields = row.to_h { |field| [field.field, field.value] }
      message = fields.fetch('@message')
      @bytes += message.bytesize
      raise Error, 'Log results are too large. Please shorten the date range.' if @bytes > MAX_BYTES

      event = JSON.parse(message)
      id = event['request_id']
      return if id.blank?

      timestamp = Time.find_zone!('UTC').parse(fields.fetch('@timestamp'))
      case event['event']
      when 'evaluation_journey_recorded'
        record_journey(event, id)
      when 'result_selected'
        @selections[id] << Click.new(commodity_code: event.fetch('goods_nomenclature_item_id'), clicked_at: timestamp)
      when 'search_failed', 'search_stage_failed'
        @failed.add(id)
      end
    end

    def record_journey(event, id)
      return unless event['trace_version'] == JourneyProjection::TRACE_VERSION

      terminal_at = Time.iso8601(event.fetch('terminal_at'))
      return unless terminal_at.to_i >= @start && terminal_at.to_i < @finish && terminal_at.to_i < @cutoff
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
      raise Error, 'Too many journeys. Please shorten the date range.' if @journeys.size > Workbook::MAX_ROWS
    end

    def check_deadline!
      raise Error, 'CloudWatch export timed out. Please shorten the date range.' if monotonic_time >= @deadline
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
