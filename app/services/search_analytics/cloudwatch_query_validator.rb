# frozen_string_literal: true

module SearchAnalytics
  class CloudwatchQueryValidator
    LOOKBACK = 5.minutes
    QUERY_MAX_POLLS = 60
    QUERY_POLL_INTERVAL_SECONDS = 1
    TERMINAL_FAILURE_STATUSES = %w[Failed Cancelled Timeout Unknown].freeze
    ValidationError = Class.new(StandardError)
    QueryError = Class.new(StandardError)

    def self.call(log_group_name:, client: Aws::CloudWatchLogs::Client.new, now: Time.current, output: $stdout)
      new(log_group_name:, client:, now:, output:).call
    end

    def initialize(log_group_name:, client:, now:, output:)
      @log_group_name = log_group_name
      @client = client
      @now = now
      @output = output
    end

    def call
      failures = []

      distinct_queries.each do |query_string, references|
        validate_query(query_string)
        output.puts("Validated #{references.join(', ')}")
      rescue Aws::CloudWatchLogs::Errors::MalformedQueryException => e
        failures << "#{references.join(', ')}: #{compile_error_message(e)}"
      rescue QueryError => e
        failures << "#{references.join(', ')}: #{e.message}"
      end

      raise ValidationError, failures.join("\n") if failures.any?

      output.puts("Validated #{distinct_queries.size} distinct CloudWatch queries")
      true
    end

  private

    attr_reader :log_group_name, :client, :now, :output

    def distinct_queries
      @distinct_queries ||= SnapshotRefresh::PERIODS.each_with_object(Hash.new { |hash, query| hash[query] = [] }) do |period, queries|
        CloudwatchSnapshotQuery.query_definitions(period:).each do |name, query_string|
          queries[query_string] << "#{period}/#{name}"
        end
      end
    end

    def validate_query(query_string)
      query_id = client.start_query(
        log_group_name:,
        start_time: (now - LOOKBACK).to_i,
        end_time: now.to_i,
        query_language: 'CWLI',
        query_string:,
      ).query_id

      await_completion(query_id)
    end

    def await_completion(query_id)
      QUERY_MAX_POLLS.times do
        status = client.get_query_results(query_id:).status
        return if status == 'Complete'

        raise QueryError, "CloudWatch query #{status}" if TERMINAL_FAILURE_STATUSES.include?(status)

        Kernel.sleep QUERY_POLL_INTERVAL_SECONDS
      end

      raise QueryError, 'CloudWatch query timed out while polling'
    end

    def compile_error_message(error)
      compile_error = error.query_compile_error
      return error.message unless compile_error

      location = compile_error.location
      return compile_error.message unless location

      "#{compile_error.message} (characters #{location.start_char_offset}-#{location.end_char_offset})"
    end
  end
end
