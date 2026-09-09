# frozen_string_literal: true

module SearchAnalytics
  class CloudwatchSnapshotQuery
    QUERY_POLL_INTERVAL_SECONDS = ENV.fetch('SEARCH_ANALYTICS_QUERY_POLL_INTERVAL_SECONDS', 1).to_f
    QUERY_MAX_POLLS = ENV.fetch('SEARCH_ANALYTICS_QUERY_MAX_POLLS', 60).to_i
    IMPROVEMENT_TERM_LIMIT = 100
    TERMINAL_FAILURE_STATUSES = %w[Failed Cancelled Timeout Unknown].freeze
    SEARCH_LOG_GROUP_NAME = "platform-logs-#{TradeTariffBackend.environment}".freeze
    VIEW_SEARCH_TYPES = {
      'classic' => %w[classic],
      'internal' => %w[interactive internal],
    }.freeze
    AGGREGATED_COST_FIELDS = %w[
      input_cost_usd
      cached_input_cost_usd
      cache_write_input_cost_usd
      output_cost_usd
      embedding_cost_usd
      total_cost_usd
      average_cost_usd
      p50_cost_usd
      p90_cost_usd
      assisted_searches
      input_tokens
      cached_input_tokens
      cache_write_input_tokens
      output_tokens
      total_tokens
      calls
      priced_calls
      unpriced_calls
    ].index_by { |field| "aggregated_#{field}" }.freeze
    VIEWS = %w[all classic internal].freeze
    REQUEST_SOURCES = %w[frontend backend_only unknown].freeze
    QueryError = Class.new(StandardError)

    def self.call(period:, client: self.client, now: Time.current, log_group_name: SEARCH_LOG_GROUP_NAME) = new(period:, client:, now:, log_group_name:).call

    def self.query_definitions(period:, log_group_name: SEARCH_LOG_GROUP_NAME) = new(period:, client: nil, log_group_name:).query_definitions

    def self.client = @client ||= Aws::CloudWatchLogs::Client.new

    def initialize(period:, client: self.class.client, now: Time.current, log_group_name: SEARCH_LOG_GROUP_NAME)
      @period = Period.for(period:, view: 'all')
      @client = client
      @now = now
      @log_group_name = log_group_name
    end

    def call
      queries = query_definitions
      aggregate = Aggregate.new(
        period:,
        volume_rows: run_query(queries.fetch('volume')),
        zero_result_rows: run_query(queries.fetch('zero_results')),
        summary_all_latency_rows: run_query(queries.fetch('summary_all_latency')),
        summary_view_latency_rows: run_query(queries.fetch('summary_view_latency')),
        source_all_latency_rows: run_query(queries.fetch('source_all_latency')),
        source_view_latency_rows: run_query(queries.fetch('source_view_latency')),
        ai_cost_summary_rows: run_query(queries.fetch('ai_cost_summary')),
        ai_cost_trend_rows: run_query(queries.fetch('ai_cost_trend')),
        selection_rows: %w[classic internal].flat_map { |view| run_query(queries.fetch("#{view}_selections")).map { |row| row.merge('selectable_search_type' => view) } },
        selection_trend_rows: %w[classic internal].flat_map { |view| run_query(queries.fetch("#{view}_selection_trend")).map { |row| row.merge('selectable_search_type' => view) } },
        improvement_term_rows: {
          'search_terms' => 'search_term_improvements',
          'item_ids' => 'item_id_improvements',
        }.flat_map { |term_type, name| run_query(queries.fetch(name)).map { |row| row.merge('term_type' => term_type) } },
      )

      VIEWS.index_with { |view| aggregate.payload_for(view) }
    rescue Aws::Errors::ServiceError, QueryError
      raise
    rescue StandardError => e
      raise QueryError, e.message
    end

    def query_definitions
      {
        'volume' => volume_query,
        'zero_results' => zero_result_query,
        'summary_all_latency' => summary_all_latency_query,
        'summary_view_latency' => summary_view_latency_query,
        'source_all_latency' => source_all_latency_query,
        'source_view_latency' => source_view_latency_query,
        'ai_cost_summary' => ai_cost_summary_query,
        'ai_cost_trend' => ai_cost_trend_query,
        'classic_selections' => selection_queries.fetch('classic'),
        'internal_selections' => selection_queries.fetch('internal'),
        'classic_selection_trend' => selection_trend_queries.fetch('classic'),
        'internal_selection_trend' => selection_trend_queries.fetch('internal'),
        'search_term_improvements' => improvement_term_queries.fetch('search_terms'),
        'item_id_improvements' => improvement_term_queries.fetch('item_ids'),
      }
    end

  private

    attr_reader :period, :client, :now, :log_group_name

    def run_query(query_string)
      query_id = client.start_query(
        query_language: 'SQL',
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

        raise QueryError, "CloudWatch query #{response.status}" if TERMINAL_FAILURE_STATUSES.include?(response.status)

        Kernel.sleep QUERY_POLL_INTERVAL_SECONDS
      end

      raise QueryError, 'CloudWatch query timed out while polling'
    end

    def parsed_row(row) = row.to_h { |field| [normalise_field(field.field), field.value] }

    def normalise_field(field)
      return '@timestamp' if field.to_s.start_with?('bin(')

      AGGREGATED_COST_FIELDS.fetch(field, field)
    end

    def bucket_expression = "DATE_TRUNC('#{bucket_period}', `@timestamp`)"

    def bucket_period = period.bucket_size == 'hour' ? 'HOUR' : 'DAY'

    def source = "`#{log_group_name}`"

    def base_search_filter = "service = 'search' AND event IN ('search_completed', 'search_failed')"

    def log_stream_filter = "`@logStream` LIKE '%ecs/backend-#{TradeTariffBackend.service}/%'"

    def request_exclusion_filter
      Rails.root.join('app/services/search_analytics/request_exclusion_filter.sql.tftpl').read
        .gsub('${log_group_name}', log_group_name)
        .gsub('${scope_condition}', log_stream_filter)
    end

    def volume_query
      <<~QUERY
        SELECT #{bucket_expression} AS `@timestamp`, search_type, event,
          COALESCE(request_source, 'unknown') AS request_source, COUNT(*) AS searches
        FROM #{source} WHERE #{log_stream_filter} AND #{base_search_filter} AND #{request_exclusion_filter}
        GROUP BY #{bucket_expression}, search_type, event, COALESCE(request_source, 'unknown')
      QUERY
    end

    # Keep empty-commodity semantics in sync with terraform/modules/search_*_dashboard.
    def zero_result_condition
      <<~CONDITION.squish
        ((search_type = 'classic' AND (
          (commodity_result_count IS NOT NULL AND commodity_result_count = 0 AND (results_type IS NULL OR results_type != 'exact_search'))
          OR (commodity_result_count IS NULL AND result_count = 0)))
        OR ((search_type = 'interactive' OR search_type = 'internal') AND result_count = 0))
      CONDITION
    end

    def zero_result_query
      <<~QUERY
        SELECT #{bucket_expression} AS `@timestamp`, search_type,
          COALESCE(request_source, 'unknown') AS request_source, COUNT(*) AS zero_results
        FROM #{source} WHERE #{log_stream_filter} AND service = 'search' AND event = 'search_completed'
          AND #{zero_result_condition} AND #{request_exclusion_filter}
        GROUP BY #{bucket_expression}, search_type, COALESCE(request_source, 'unknown')
      QUERY
    end

    def summary_all_latency_query = latency_query

    def summary_view_latency_query = latency_query('search_type')

    def source_all_latency_query = latency_query("COALESCE(request_source, 'unknown') AS request_source")

    def source_view_latency_query = latency_query("search_type, COALESCE(request_source, 'unknown') AS request_source")

    def latency_query(dimensions = nil)
      <<~QUERY
        SELECT PERCENTILE_APPROX(total_duration_ms, 0.9) AS p90_latency_ms#{", #{dimensions}" if dimensions}
        FROM #{source} WHERE #{log_stream_filter} AND #{base_search_filter}
          AND total_duration_ms IS NOT NULL AND #{request_exclusion_filter}
        #{"GROUP BY #{dimensions.delete_suffix(' AS request_source')}" if dimensions}
      QUERY
    end

    def ai_cost_summary_query
      <<~QUERY
        SELECT SUM(request_cost_usd) AS aggregated_total_cost_usd,
          AVG(request_cost_usd) AS aggregated_average_cost_usd,
          PERCENTILE_APPROX(request_cost_usd, 0.5) AS aggregated_p50_cost_usd,
          PERCENTILE_APPROX(request_cost_usd, 0.9) AS aggregated_p90_cost_usd,
          COUNT(*) AS aggregated_assisted_searches,
          SUM(request_priced_calls) AS aggregated_priced_calls,
          SUM(request_unpriced_calls) AS aggregated_unpriced_calls
        FROM (
          SELECT request_id,
            SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN total_cost_usd ELSE 0 END) AS request_cost_usd,
            SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN 1 ELSE 0 END) AS request_priced_calls,
            SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN 0 ELSE 1 END) AS request_unpriced_calls
          FROM #{source} WHERE #{log_stream_filter} AND #{search_ai_cost_filter}
          GROUP BY request_id
        ) AS request_costs
        WHERE #{request_exclusion_filter}
      QUERY
    end

    def ai_cost_trend_query
      <<~QUERY
        SELECT #{bucket_expression} AS `@timestamp`, event_kind,
          SUM(CASE WHEN pricing_known = true AND service = 'search' THEN input_cost_usd ELSE 0 END) AS aggregated_input_cost_usd,
          SUM(CASE WHEN pricing_known = true AND service = 'search' THEN cached_input_cost_usd ELSE 0 END) AS aggregated_cached_input_cost_usd,
          SUM(CASE WHEN pricing_known = true AND service = 'search' THEN cache_write_input_cost_usd ELSE 0 END) AS aggregated_cache_write_input_cost_usd,
          SUM(CASE WHEN pricing_known = true AND service = 'search' THEN output_cost_usd ELSE 0 END) AS aggregated_output_cost_usd,
          SUM(CASE WHEN pricing_known = true AND service = 'ai_usage' THEN total_cost_usd ELSE 0 END) AS aggregated_embedding_cost_usd,
          SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN total_cost_usd ELSE 0 END) AS aggregated_total_cost_usd,
          SUM(input_tokens) AS aggregated_input_tokens, SUM(cached_input_tokens) AS aggregated_cached_input_tokens,
          SUM(cache_write_input_tokens) AS aggregated_cache_write_input_tokens, SUM(output_tokens) AS aggregated_output_tokens,
          SUM(total_tokens) AS aggregated_total_tokens, COUNT(*) AS aggregated_calls,
          SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN 1 ELSE 0 END) AS aggregated_priced_calls,
          SUM(CASE WHEN pricing_known = true AND total_cost_usd IS NOT NULL THEN 0 ELSE 1 END) AS aggregated_unpriced_calls
        FROM #{source} WHERE #{log_stream_filter} AND #{search_ai_cost_filter} AND #{request_exclusion_filter}
        GROUP BY #{bucket_expression}, event_kind
      QUERY
    end

    def search_ai_cost_filter
      <<~FILTER.squish
        request_id IS NOT NULL AND total_tokens IS NOT NULL
        AND event IN ('api_call_completed', 'embedding_api_call_completed', 'embedding_api_call_failed')
        AND ((service = 'search' AND event = 'api_call_completed') OR
          (service = 'ai_usage' AND event IN ('embedding_api_call_completed', 'embedding_api_call_failed') AND event_kind = 'vector_search_query_embedding'))
      FILTER
    end

    def selection_queries(trend: false)
      {
        'classic' => selection_query("search_type = 'classic' AND results_type = 'fuzzy_search'", trend:),
        'internal' => selection_query("search_type IN ('interactive', 'internal') AND results_type IN ('opensearch', 'vector', 'hybrid')", trend:),
      }
    end

    # JSON extraction preserves request_source when SQL prunes fields outside GROUP BY.
    def selection_query(selectable_condition, trend:)
      dimension = trend ? "DATE_TRUNC('#{bucket_period}', latest_timestamp)" : 'source'
      <<~QUERY
        SELECT SUM(result_selections) AS selected, SUM(selectable_searches) AS selectable,
          #{dimension} AS #{trend ? '`@timestamp`' : 'source'}
        FROM (
          SELECT request_id, SUM(CASE WHEN event = 'result_selected' THEN 1 ELSE 0 END) AS result_selections,
            SUM(CASE WHEN event = 'search_completed' AND result_count > 0 AND #{selectable_condition} THEN 1 ELSE 0 END) AS selectable_searches,
            MIN_BY(COALESCE(GET_JSON_OBJECT(`@message`, '$.request_source'), 'unknown'), `@timestamp`) AS source, MAX(`@timestamp`) AS latest_timestamp
          FROM #{source} WHERE #{log_stream_filter} AND service = 'search' AND request_id IS NOT NULL
            AND (event = 'result_selected' OR (event = 'search_completed' AND result_count > 0 AND #{selectable_condition}))
          GROUP BY request_id
        ) AS request_selections
        WHERE selectable_searches > 0 AND #{request_exclusion_filter}
        GROUP BY #{dimension}
      QUERY
    end

    def selection_trend_queries = selection_queries(trend: true)

    def improvement_term_queries
      {
        'search_terms' => improvement_terms_query(term_filter: "query NOT RLIKE '^[0-9 .-]+$'"),
        'item_ids' => improvement_terms_query(term_filter: "query RLIKE '^[0-9 .-]+$'"),
      }
    end

    def improvement_terms_query(term_filter:)
      <<~QUERY
        SELECT query, search_type, COUNT(*) AS zero_results
        FROM #{source} WHERE #{log_stream_filter} AND service = 'search' AND event = 'search_completed'
          AND #{zero_result_condition} AND query IS NOT NULL AND #{term_filter} AND #{request_exclusion_filter}
        GROUP BY query, search_type ORDER BY zero_results DESC LIMIT #{IMPROVEMENT_TERM_LIMIT * VIEWS.size}
      QUERY
    end

    class Aggregate
      def initialize(period:, volume_rows:, zero_result_rows:, summary_all_latency_rows:, summary_view_latency_rows:, source_all_latency_rows:, source_view_latency_rows:, ai_cost_summary_rows:, ai_cost_trend_rows:, selection_rows:, selection_trend_rows:, improvement_term_rows:)
        @period = period
        @volume_rows = volume_rows
        @zero_result_rows = zero_result_rows
        @summary_all_latency_rows = summary_all_latency_rows
        @summary_view_latency_rows = summary_view_latency_rows
        @source_all_latency_rows = source_all_latency_rows
        @source_view_latency_rows = source_view_latency_rows
        @ai_cost_summary_rows = ai_cost_summary_rows
        @ai_cost_trend_rows = ai_cost_trend_rows
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
          'request_sources' => request_sources(view),
          'ai_costs' => ai_costs(view),
          'improvement_terms' => improvement_terms(view),
        }
      end

    private

      attr_reader :period, :volume_rows, :zero_result_rows, :summary_all_latency_rows, :summary_view_latency_rows, :source_all_latency_rows, :source_view_latency_rows, :ai_cost_summary_rows, :ai_cost_trend_rows, :selection_rows, :selection_trend_rows, :improvement_term_rows

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

      def ai_costs(view)
        return empty_ai_costs if view == 'classic'

        {
          'summary' => ai_cost_summary,
          'trend' => ai_cost_trend,
          'operations' => ai_cost_operations,
        }
      end

      def empty_ai_costs
        {
          'summary' => ai_cost_summary({}),
          'trend' => [],
          'operations' => [],
        }
      end

      def ai_cost_summary(row = ai_cost_summary_rows.first || {})
        priced_calls = integer(row['priced_calls'])
        unpriced_calls = integer(row['unpriced_calls'])
        calls = priced_calls + unpriced_calls

        {
          'total_cost_usd' => decimal_number(row['total_cost_usd']),
          'assisted_searches' => integer(row['assisted_searches']),
          'average_cost_usd' => decimal_number(row['average_cost_usd']),
          'p50_cost_usd' => decimal_number(row['p50_cost_usd']),
          'p90_cost_usd' => decimal_number(row['p90_cost_usd']),
          'priced_calls' => priced_calls,
          'unpriced_calls' => unpriced_calls,
          'pricing_coverage' => calls.positive? ? (priced_calls.to_f / calls).round(4) : nil,
          'complete' => unpriced_calls.zero?,
        }
      end

      def ai_cost_trend
        buckets.map do |bucket|
          rows = ai_cost_trend_rows.select { |row| iso8601(row['@timestamp']) == bucket }

          {
            'bucket' => bucket,
            'input_cost_usd' => sum_decimal(rows, 'input_cost_usd'),
            'cached_input_cost_usd' => sum_decimal(rows, 'cached_input_cost_usd'),
            'cache_write_input_cost_usd' => sum_decimal(rows, 'cache_write_input_cost_usd'),
            'output_cost_usd' => sum_decimal(rows, 'output_cost_usd'),
            'embedding_cost_usd' => sum_decimal(rows, 'embedding_cost_usd'),
            'total_cost_usd' => sum_decimal(rows, 'total_cost_usd'),
          }
        end
      end

      def ai_cost_operations
        rows_by_event_kind = ai_cost_trend_rows.group_by { |row| row['event_kind'].to_s }

        operations = rows_by_event_kind.filter_map do |event_kind, rows|
          next if event_kind.blank?

          {
            'event_kind' => event_kind,
            'calls' => sum_integer(rows, 'calls'),
            'input_tokens' => sum_integer(rows, 'input_tokens'),
            'cached_input_tokens' => sum_integer(rows, 'cached_input_tokens'),
            'cache_write_input_tokens' => sum_integer(rows, 'cache_write_input_tokens'),
            'output_tokens' => sum_integer(rows, 'output_tokens'),
            'total_tokens' => sum_integer(rows, 'total_tokens'),
            'input_cost_usd' => sum_decimal(rows, 'input_cost_usd'),
            'cached_input_cost_usd' => sum_decimal(rows, 'cached_input_cost_usd'),
            'cache_write_input_cost_usd' => sum_decimal(rows, 'cache_write_input_cost_usd'),
            'output_cost_usd' => sum_decimal(rows, 'output_cost_usd'),
            'embedding_cost_usd' => sum_decimal(rows, 'embedding_cost_usd'),
            'total_cost_usd' => sum_decimal(rows, 'total_cost_usd'),
            'priced_calls' => sum_integer(rows, 'priced_calls'),
            'unpriced_calls' => sum_integer(rows, 'unpriced_calls'),
          }
        end

        operations.sort_by { |row| [-row['total_cost_usd'], row['event_kind']] }
      end

      def volume_trend
        buckets.map do |bucket|
          {
            'bucket' => bucket,
            'all' => bucket_search_count(bucket, 'all'),
            'classic' => bucket_search_count(bucket, 'classic'),
            'internal' => bucket_search_count(bucket, 'internal'),
            'frontend' => bucket_search_count(bucket, 'all', request_source: 'frontend'),
            'backend_only' => bucket_search_count(bucket, 'all', request_source: 'backend_only'),
            'unknown' => bucket_search_count(bucket, 'all', request_source: 'unknown'),
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

      def request_sources(view)
        REQUEST_SOURCES.index_with { |source| comparison_for(view, request_source: source) }
      end

      def comparison_for(view, request_source: nil)
        searches = search_count(view, request_source:)
        completed = completed_count(view, request_source:)
        zero_results = zero_result_count(view, request_source:)

        {
          'searches' => searches,
          'failure_rate' => rate(failed_count(view, request_source:), searches),
          'zero_result_rate' => rate(zero_results, completed),
          'selection_rate' => rate(selection_count(view, request_source:), selectable_count(view, request_source:)),
          'p90_latency_ms' => latency_for(view, request_source:),
        }
      end

      def improvement_terms(view)
        grouped_terms(view)
          .group_by { |term| term['term_type'] }
          .values
          .flat_map { |terms|
            terms
              .sort_by { |term| [-term['zero_results'], term['query']] }
              .first(IMPROVEMENT_TERM_LIMIT)
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
          'failure_rate' => {
            'level' => 'neutral',
            'message' => 'Known failed or degraded requests are excluded',
          },
          'zero_result_rate' => status_for_zero_result_rate(current_summary.fetch('zero_result_rate')),
          'selection_rate' => status_for_selection_rate(current_summary.fetch('selection_rate')),
          'p90_latency_ms' => status_for_latency(current_summary.fetch('p90_latency_ms')),
        }
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

      def search_count(view, request_source: nil) = filtered_rows(volume_rows, view, request_source:).sum { |row| integer(row['searches']) }

      def failed_count(view, request_source: nil)
        filtered_rows(volume_rows, view, request_source:).sum { |row| row['event'] == 'search_failed' ? integer(row['searches']) : 0 }
      end

      def completed_count(view, request_source: nil)
        filtered_rows(volume_rows, view, request_source:).sum { |row| row['event'] == 'search_completed' ? integer(row['searches']) : 0 }
      end

      def zero_result_count(view, request_source: nil) = filtered_rows(zero_result_rows, view, request_source:).sum { |row| integer(row['zero_results']) }

      def selection_count(view, request_source: nil) = filtered_rows(selection_rows, view, request_source:).sum { |row| integer(row['selected']) }

      def selectable_count(view, request_source: nil) = filtered_rows(selection_rows, view, request_source:).sum { |row| integer(row['selectable']) }

      def latency_for(view, request_source: nil)
        rows = latency_rows_for(view, request_source:)

        rows.map { |row| integer(row['p90_latency_ms']) }.max || 0
      end

      def latency_rows_for(view, request_source: nil)
        if request_source
          return filtered_rows(source_all_latency_rows, view, request_source:) if view == 'all'

          filtered_rows(source_view_latency_rows, view, request_source:)
        elsif view == 'all'
          summary_all_latency_rows
        else
          filtered_rows(summary_view_latency_rows, view)
        end
      end

      def bucket_search_count(bucket, view, request_source: nil)
        filtered_rows(volume_rows, view, request_source:).sum { |row| iso8601(row['@timestamp']) == bucket ? integer(row['searches']) : 0 }
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
        @buckets ||= (volume_rows + zero_result_rows + selection_trend_rows + ai_cost_trend_rows)
          .filter_map { |row| iso8601(row['@timestamp']) }
          .uniq
          .sort
      end

      def filtered_rows(rows, view, request_source: nil)
        rows = rows.select { |row| source_key(row) == request_source } if request_source

        return rows if view == 'all'

        rows.select { |row| row_matches_view?(row, view) }
      end

      # Selection queries return `source` because CloudWatch rejects regrouping by
      # an aggregate alias that reuses the original field name `request_source`.
      def source_key(row) = row['request_source'].presence || row['source'].presence || 'unknown'

      def row_matches_view?(row, view) = VIEW_SEARCH_TYPES.fetch(view, [view]).include?(row_search_type(row))

      def row_search_type(row) = row['search_type'] || row['selectable_search_type']

      def rate(numerator, denominator)
        return 0.0 if denominator.zero?

        (numerator.to_f / denominator).round(2)
      end

      def integer(value)
        Float(value || 0).to_i
      rescue ArgumentError, TypeError
        0
      end

      def sum_integer(rows, key) = rows.sum { |row| integer(row[key]) }

      def sum_decimal(rows, key) = decimal_number(rows.sum { |row| decimal(row[key]) })

      def decimal_number(value) = decimal(value).round(8).to_f

      def decimal(value)
        BigDecimal(value.to_s)
      rescue ArgumentError, TypeError
        0.to_d
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
