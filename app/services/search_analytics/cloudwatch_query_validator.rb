# frozen_string_literal: true

module SearchAnalytics
  class CloudwatchQueryValidator
    LOOKBACK = 5.minutes
    QUERY_MAX_POLLS = CloudwatchSnapshotQuery::QUERY_MAX_POLLS
    QUERY_POLL_INTERVAL_SECONDS = CloudwatchSnapshotQuery::QUERY_POLL_INTERVAL_SECONDS
    TERMINAL_FAILURE_STATUSES = CloudwatchSnapshotQuery::TERMINAL_FAILURE_STATUSES
    ValidationError = Class.new(StandardError)
    QueryError = Class.new(StandardError)

    def self.call(log_group_name:, client: Aws::CloudWatchLogs::Client.new, now: Time.current, output: $stdout, dashboard_queries: {})
      new(log_group_name:, client:, now:, output:, dashboard_queries:).call
    end

    def initialize(log_group_name:, client:, now:, output:, dashboard_queries:)
      @log_group_name = log_group_name
      @client = client
      @now = now
      @output = output
      @dashboard_queries = dashboard_queries
    end

    def call
      failures = []

      distinct_queries.each do |query, references|
        validate_query(query)
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

    attr_reader :log_group_name, :client, :now, :output, :dashboard_queries

    def distinct_queries
      @distinct_queries ||= SnapshotRefresh::PERIODS.each_with_object(Hash.new { |hash, query| hash[query] = [] }) { |period, queries|
        CloudwatchSnapshotQuery.query_definitions(period:, log_group_name:).each do |name, query_string|
          queries[{ query_string:, query_language: 'SQL' }] << "#{period}/#{name}"
        end
      }.tap do |queries|
        dashboard_queries.each { |name, query| queries[query.symbolize_keys] << name }
      end
    end

    def validate_query(query)
      query_string = query.fetch(:query_string)
      query_language = query.fetch(:query_language)
      groups = query_string.scan(/\bFROM\s+`([^`]+)`|\bSOURCE\s+'([^']+)'/i).flatten.compact
      raise QueryError, 'Query references a different log group' unless groups.all? { |group| group == log_group_name }

      query_string = query_string.sub(/\A\s*SOURCE\s+'[^']+'\s*\|\s*/i, '')
      source = query_language == 'SQL' ? {} : { log_group_name: }
      query_id = client.start_query(
        **source,
        start_time: (now - LOOKBACK).to_i,
        end_time: now.to_i,
        query_language:,
        query_string:,
      ).query_id

      await_completion(query_id)
    end

    def await_completion(query_id)
      QUERY_MAX_POLLS.times do |poll|
        status = client.get_query_results(query_id:).status
        return true if status == 'Complete'

        raise QueryError, "CloudWatch query #{status} (query ID: #{query_id})" if TERMINAL_FAILURE_STATUSES.include?(status)

        Kernel.sleep QUERY_POLL_INTERVAL_SECONDS unless poll == QUERY_MAX_POLLS - 1
      end

      raise QueryError, "CloudWatch query timed out while polling (query ID: #{query_id})"
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
