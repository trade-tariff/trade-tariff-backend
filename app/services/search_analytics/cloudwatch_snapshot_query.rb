# frozen_string_literal: true

module SearchAnalytics
  class CloudwatchSnapshotQuery
    QUERY_POLL_INTERVAL_SECONDS = ENV.fetch('SEARCH_ANALYTICS_QUERY_POLL_INTERVAL_SECONDS', 1).to_f
    QUERY_MAX_POLLS = ENV.fetch('SEARCH_ANALYTICS_QUERY_MAX_POLLS', 60).to_i
    TERMINAL_FAILURE_STATUSES = %w[Failed Cancelled Timeout].freeze
    SEARCH_LOG_GROUP_NAME = "platform-logs-#{TradeTariffBackend.environment}".freeze
    SEARCH_EVENTS = %w[search_completed search_failed].freeze
    VIEW_SEARCH_TYPES = {
      'classic' => %w[classic],
      'internal' => %w[interactive internal],
    }.freeze
    VIEWS = %w[all classic internal].freeze

    def self.call(period:, client: self.client, now: Time.current)
      new(period:, client:, now:).call
    end

    def self.client
      @client ||= Aws::CloudWatchLogs::Client.new
    end

    def initialize(period:, client: self.class.client, now: Time.current)
      @period = Period.for(period:, view: 'all')
      @client = client
      @now = now
    end

    def call
      aggregate = Aggregate.new(
        period:,
        volume_rows: run_query(volume_query),
        zero_result_rows: run_query(zero_result_query),
        all_latency_rows: run_query(all_latency_query),
        view_latency_rows: run_query(view_latency_query),
        selection_rows: selection_queries.flat_map { |view, query| run_query(query).map { |row| row.merge('selectable_search_type' => view) } },
        selection_trend_rows: selection_trend_queries.flat_map { |view, query| run_query(query).map { |row| row.merge('selectable_search_type' => view) } },
        improvement_term_rows: improvement_term_queries.flat_map { |term_type, query| run_query(query).map { |row| row.merge('term_type' => term_type) } },
      )

      VIEWS.index_with { |view| aggregate.payload_for(view) }
    rescue Aws::Errors::ServiceError
      raise
    rescue StandardError => e
      raise CloudwatchQuery::QueryError, e.message
    end

    private

    attr_reader :period, :client, :now

    def run_query(query_string)
      query_id = client.start_query(
        log_group_name: SEARCH_LOG_GROUP_NAME,
        start_time: (now - period.duration).to_i,
        end_time: now.to_i,
        query_string: query_string,
      ).query_id

      await_query_results(query_id).map { |row| parsed_row(row) }
    end

    def await_query_results(query_id)
      QUERY_MAX_POLLS.times do
        response = client.get_query_results(query_id:)
        return response.results if response.status == 'Complete'

        raise CloudwatchQuery::QueryError, "CloudWatch query #{response.status}" if TERMINAL_FAILURE_STATUSES.include?(response.status)

        Kernel.sleep QUERY_POLL_INTERVAL_SECONDS
      end

      raise CloudwatchQuery::QueryError, 'CloudWatch query timed out while polling'
    end

    def parsed_row(row)
      row.to_h { |field| [normalise_field(field.field), field.value] }
    end

    def normalise_field(field)
      return '@timestamp' if field.to_s.start_with?('bin(')

      field
    end

    def bucket_expression
      period.bucket_size == 'hour' ? 'bin(1h)' : 'bin(1d)'
    end

    def bucket_period
      period.bucket_size == 'hour' ? '1h' : '1d'
    end

    def base_search_filter
      'filter service = "search" and event in ["search_completed", "search_failed"]'
    end

    def log_stream_filter
      %(filter @logStream like "ecs/backend-#{TradeTariffBackend.service}/")
    end

    def volume_query
      <<~QUERY
        fields @timestamp, event, search_type
        | #{log_stream_filter}
        | #{base_search_filter}
        | stats count(*) as searches by #{bucket_expression}, search_type, event
      QUERY
    end

    def zero_result_query
      <<~QUERY
        fields @timestamp, event, search_type, result_count
        | #{log_stream_filter}
        | filter service = "search" and event = "search_completed" and result_count = 0
        | stats count(*) as zero_results by #{bucket_expression}, search_type
      QUERY
    end

    def all_latency_query
      <<~QUERY
        fields event, total_duration_ms
        | #{log_stream_filter}
        | #{base_search_filter} and ispresent(total_duration_ms)
        | stats pct(total_duration_ms, 90) as p90_latency_ms
      QUERY
    end

    def view_latency_query
      <<~QUERY
        fields event, search_type, total_duration_ms
        | #{log_stream_filter}
        | #{base_search_filter} and ispresent(total_duration_ms)
        | stats pct(total_duration_ms, 90) as p90_latency_ms by search_type
      QUERY
    end

    def selection_queries
      {
        'classic' => selection_query(
          'search_type = "classic" and results_type = "fuzzy_search"',
        ),
        'internal' => selection_query(
          '(search_type = "interactive" or search_type = "internal") and (results_type = "opensearch" or results_type = "vector" or results_type = "hybrid")',
        ),
      }
    end

    def selection_query(selectable_condition)
      <<~QUERY
        fields request_id, event, search_type, result_count, results_type
        | #{log_stream_filter}
        | filter service = "search" and ispresent(request_id) and (event = "result_selected" or (event = "search_completed" and result_count > 0 and #{selectable_condition}))
        | fields if(event = "result_selected", 1, 0) as result_selection_marker
        | fields if(event = "search_completed" and result_count > 0 and #{selectable_condition}, 1, 0) as selectable_search_marker
        | stats sum(result_selection_marker) as result_selections,
            sum(selectable_search_marker) as selectable_searches by request_id
        | filter selectable_searches > 0
        | stats sum(result_selections) as selected, sum(selectable_searches) as selectable
      QUERY
    end

    def selection_trend_queries
      selection_queries.transform_values do |query|
        query
          .sub(
            'sum(selectable_search_marker) as selectable_searches by request_id',
            'sum(selectable_search_marker) as selectable_searches, max(@timestamp) as @t by request_id',
          )
          .sub(
            '| stats sum(result_selections) as selected, sum(selectable_searches) as selectable',
            "| stats sum(result_selections) as selected by datefloor(@t, #{bucket_period}) as @timestamp",
          )
      end
    end

    def improvement_term_queries
      {
        'search_terms' => improvement_terms_query(term_filter: 'query not like /^[0-9 .-]+$/'),
        'item_ids' => improvement_terms_query(term_filter: 'query like /^[0-9 .-]+$/'),
      }
    end

    def improvement_terms_query(term_filter: nil)
      [
        <<~QUERY,
          fields query, search_type, result_count
          | #{log_stream_filter}
          | filter service = "search" and event = "search_completed" and result_count = 0 and ispresent(query)
        QUERY
        ("| filter #{term_filter}\n" if term_filter.present?),
        <<~QUERY,
          | stats count(*) as zero_results by query, search_type
          | sort zero_results desc
          | limit #{SnapshotBuilder::IMPROVEMENT_TERM_LIMIT * VIEWS.size}
        QUERY
      ].compact.join
    end

    class Aggregate
      def initialize(period:, volume_rows:, zero_result_rows:, all_latency_rows:, view_latency_rows:, selection_rows:, selection_trend_rows:, improvement_term_rows:)
        @period = period
        @volume_rows = volume_rows
        @zero_result_rows = zero_result_rows
        @all_latency_rows = all_latency_rows
        @view_latency_rows = view_latency_rows
        @selection_rows = selection_rows
        @selection_trend_rows = selection_trend_rows
        @improvement_term_rows = improvement_term_rows
      end

      def payload_for(view)
        {
          'summary' => summary(view),
          'summary_statuses' => summary_statuses(view),
          'trends' => trends(view),
          'comparisons' => comparisons,
          'improvement_terms' => improvement_terms(view),
        }
      end

      private

      attr_reader :period, :volume_rows, :zero_result_rows, :all_latency_rows, :view_latency_rows, :selection_rows, :selection_trend_rows, :improvement_term_rows

      def summary(view)
        searches = search_count(view)
        completed = completed_count(view)
        zero_results = zero_result_count(view)

        {
          'searches' => searches,
          'failure_rate' => rate(failed_count(view), searches),
          'zero_result_rate' => rate(zero_results, completed),
          'selection_rate' => rate(selection_count(view), selectable_count(view)),
          'p90_latency_ms' => latency_for(view),
        }
      end

      def trends(view)
        {
          'volume' => volume_trend,
          'outcomes' => outcome_trend(view),
        }
      end

      def volume_trend
        buckets.map do |bucket|
          {
            'bucket' => bucket,
            'all' => bucket_search_count(bucket, 'all'),
            'classic' => bucket_search_count(bucket, 'classic'),
            'internal' => bucket_search_count(bucket, 'internal'),
          }
        end
      end

      def outcome_trend(view)
        buckets.map do |bucket|
          {
            'bucket' => bucket,
            'completed' => bucket_event_count(bucket, view, 'search_completed'),
            'failed' => bucket_event_count(bucket, view, 'search_failed'),
            'zero_result' => bucket_zero_result_count(bucket, view),
            'selected' => bucket_selection_count(bucket, view),
          }
        end
      end

      def comparisons
        {
          'classic' => comparison_for('classic'),
          'internal' => comparison_for('internal'),
        }
      end

      def comparison_for(view)
        searches = search_count(view)
        completed = completed_count(view)
        zero_results = zero_result_count(view)

        {
          'searches' => searches,
          'zero_result_rate' => rate(zero_results, completed),
          'selection_rate' => rate(selection_count(view), selectable_count(view)),
          'p90_latency_ms' => latency_for(view),
        }
      end

      def improvement_terms(view)
        grouped_terms(view)
          .group_by { |term| term['term_type'] }
          .values
          .flat_map { |terms|
            terms
              .sort_by { |term| [-term['zero_results'], term['query']] }
              .first(SnapshotBuilder::IMPROVEMENT_TERM_LIMIT)
          }
          .sort_by { |term| [term['term_type'], -term['zero_results'], term['query']] }
      end

      def grouped_terms(view)
        distinct_improvement_term_rows(view).group_by { |row| row['query'].to_s }.filter_map do |query, rows|
          next if query.blank?

          zero_results = rows.sum { |row| integer(row['zero_results']) }

          {
            'query' => query,
            'zero_results' => zero_results,
            'term_type' => rows.first['term_type'],
          }
        end
      end

      def distinct_improvement_term_rows(view)
        filtered_rows(improvement_term_rows, view)
          .group_by { |row| [row['query'].to_s, row['search_type'].to_s, row['term_type'].to_s] }
          .values
          .map { |rows| rows.max_by { |row| integer(row['zero_results']) } }
      end

      def summary_statuses(view)
        current_summary = summary(view)

        {
          'searches' => {
            'level' => 'neutral',
            'message' => 'Search volume is available for this period',
          },
          'failure_rate' => status_for_failure_rate(current_summary.fetch('failure_rate')),
          'zero_result_rate' => status_for_zero_result_rate(current_summary.fetch('zero_result_rate')),
          'selection_rate' => status_for_selection_rate(current_summary.fetch('selection_rate')),
          'p90_latency_ms' => status_for_latency(current_summary.fetch('p90_latency_ms')),
        }
      end

      def status_for_failure_rate(value)
        case value
        when 0...0.02 then { 'level' => 'good', 'message' => 'Failures are low' }
        when 0.02...0.05 then { 'level' => 'watch', 'message' => 'Failures are slightly higher than usual' }
        else { 'level' => 'problem', 'message' => 'Failures are higher than expected' }
        end
      end

      def status_for_zero_result_rate(value)
        case value
        when 0...0.1 then { 'level' => 'good', 'message' => 'Most searches are returning results' }
        when 0.1...0.2 then { 'level' => 'watch', 'message' => 'Zero-result searches are slightly higher than usual' }
        else { 'level' => 'problem', 'message' => 'Many searches are returning no results' }
        end
      end

      def status_for_selection_rate(value)
        if value >= 0.25
          { 'level' => 'good', 'message' => 'Selections are tracking eligible searches' }
        else
          { 'level' => 'watch', 'message' => 'Fewer searches are leading to selections' }
        end
      end

      def status_for_latency(value)
        case value
        when 0..1_000 then { 'level' => 'good', 'message' => 'Most searches are completing quickly' }
        when 1_001..3_000 then { 'level' => 'watch', 'message' => 'Some searches are taking longer than usual' }
        else { 'level' => 'problem', 'message' => 'Searches are taking too long' }
        end
      end

      def search_count(view)
        filtered_rows(volume_rows, view).sum { |row| integer(row['searches']) }
      end

      def failed_count(view)
        filtered_rows(volume_rows, view).sum { |row| row['event'] == 'search_failed' ? integer(row['searches']) : 0 }
      end

      def completed_count(view)
        filtered_rows(volume_rows, view).sum { |row| row['event'] == 'search_completed' ? integer(row['searches']) : 0 }
      end

      def zero_result_count(view)
        filtered_rows(zero_result_rows, view).sum { |row| integer(row['zero_results']) }
      end

      def selection_count(view)
        filtered_rows(selection_rows, view).sum { |row| integer(row['selected']) }
      end

      def selectable_count(view)
        filtered_rows(selection_rows, view).sum { |row| integer(row['selectable']) }
      end

      def latency_for(view)
        return integer(all_latency_rows.first&.fetch('p90_latency_ms', nil)) if view == 'all'

        filtered_rows(view_latency_rows, view).map { |row| integer(row['p90_latency_ms']) }.max || 0
      end

      def bucket_search_count(bucket, view)
        filtered_rows(volume_rows, view).sum { |row| iso8601(row['@timestamp']) == bucket ? integer(row['searches']) : 0 }
      end

      def bucket_event_count(bucket, view, event)
        filtered_rows(volume_rows, view).sum do |row|
          iso8601(row['@timestamp']) == bucket && row['event'] == event ? integer(row['searches']) : 0
        end
      end

      def bucket_zero_result_count(bucket, view)
        filtered_rows(zero_result_rows, view).sum { |row| iso8601(row['@timestamp']) == bucket ? integer(row['zero_results']) : 0 }
      end

      def bucket_selection_count(bucket, view)
        filtered_rows(selection_trend_rows, view).sum { |row| iso8601(row['@timestamp']) == bucket ? integer(row['selected']) : 0 }
      end

      def buckets
        @buckets ||= (volume_rows + zero_result_rows + selection_trend_rows)
          .filter_map { |row| iso8601(row['@timestamp']) }
          .uniq
          .sort
      end

      def filtered_rows(rows, view)
        return rows if view == 'all'

        rows.select { |row| row_matches_view?(row, view) }
      end

      def row_matches_view?(row, view)
        VIEW_SEARCH_TYPES.fetch(view, [view]).include?(row_search_type(row))
      end

      def row_search_type(row)
        row['search_type'] || row['selectable_search_type']
      end

      def rate(numerator, denominator)
        return 0.0 if denominator.zero?

        (numerator.to_f / denominator).round(2)
      end

      def integer(value)
        Integer(value || 0)
      rescue ArgumentError, TypeError
        0
      end

      def iso8601(value)
        return if value.blank?

        Time.zone.parse(value.to_s).iso8601
      rescue ArgumentError
        value.to_s
      end
    end
  end
end
