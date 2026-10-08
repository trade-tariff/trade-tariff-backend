# frozen_string_literal: true

module SearchAnalytics
  # Opt-in daily collection. The existing rolling snapshot collector is unchanged.
  class DailyQuery < CloudwatchSnapshotQuery
    ROW_LIMIT = 10_000
    MAX_PARTITIONS = 127
    PROCESSING_VERSION = 1
    # Recollect classic counts from the broken timestamp rewrite without
    # invalidating unrelated query groups that still contain valid history.
    QUERY_PROCESSING_VERSIONS = { 'classic_outcomes' => 2 }.freeze
    IDENTIFIER_QUERIES = %w[search_journeys journey_outcomes search_actions selection_results selection_pages].freeze

    attr_reader :reporting_date

    def self.call(...) = new(...).call

    def initialize(reporting_date:, region:, log_group_name: SEARCH_LOG_GROUP_NAME, client: nil, queries: nil, force: false, now: Time.current)
      unless reporting_date.instance_of?(Date) && reporting_date < now.utc.to_date
        raise ArgumentError, 'Choose a completed UTC reporting date'
      end
      raise ArgumentError, 'Region must be explicit' if region.blank?
      raise ArgumentError, 'Invalid log group name' unless log_group_name.match?(/\A[.\-_\/#a-zA-Z0-9]+\z/)

      @reporting_date = reporting_date
      @region = region
      @service = TradeTariffBackend.service
      @selected = queries
      @force = force
      super(period: '24h', client:, now: reporting_date.to_time(:utc) + 1.day, log_group_name:)
      if queries && (queries.empty? || (queries - query_definitions.keys).any?)
        raise ArgumentError, 'Select known daily query names'
      end
    end

    def fingerprints
      query_definitions.to_h do |name, sql|
        version = QUERY_PROCESSING_VERSIONS.fetch(name, PROCESSING_VERSION)
        [name, Digest::SHA256.hexdigest([version, @service, @region, sql].to_json)]
      end
    end

    def plan
      fingerprints.to_h do |name, fingerprint|
        available = SearchAnalyticsQueryResult.where(service: @service, reporting_date:, name:, fingerprint:).any?
        action = if @selected && !@selected.include?(name)
                   'skip'
                 elsif available && !forced?(name)
                   'reuse'
                 elsif @selected.nil? || @selected.include?(name)
                   'run'
                 end
        [name, action]
      end
    end

    def call
      versions = fingerprints
      definitions = query_definitions
      definitions = definitions.slice(*@selected) if @selected
      definitions.to_h do |name, sql|
        rows = SearchAnalyticsQueryResult.fetch(service: @service, reporting_date:, name:, fingerprint: versions.fetch(name), force: forced?(name)) do
          collect(name, sql)
        end
        [name, rows]
      end
    end

    def query_definitions
      definitions = {
        'volume' => volume_query,
        'latency_histogram' => latency_histogram_query,
        'ai_cost_trend' => ai_cost_trend_query,
        'classic_selection_trend' => selection_query("search_type = 'classic' AND results_type = 'fuzzy_search'"),
        'internal_selection_trend' => selection_query("(search_type = 'interactive' OR search_type = 'internal') AND results_type IN ('opensearch', 'vector', 'hybrid')"),
        'search_term_improvements' => improvement_terms_query(term_filter: "query NOT RLIKE '^[0-9 .-]+$'"),
        'item_id_improvements' => improvement_terms_query(term_filter: "query RLIKE '^[0-9 .-]+$'"),
        'search_journeys' => JourneyQueries.new(source:, log_stream_filter:).journeys,
        'search_actions' => ActionQuery.call(source:, log_stream_filter:),
      }
      # Guided frontend events have no service field and are emitted for UK only.
      definitions['frontend_events'] = FrontendEventsQuery.call(source:, service: @service) if @service == 'uk'
      definitions['journey_outcomes'] = JourneyOutcomesQuery.call(source:, log_stream_filter:, zero_result_condition:)
      definitions['classic_outcomes'] = ClassicOutcomesQuery.call(source:, log_stream_filter:)
      definitions['search_results'] = search_results_query
      definitions['selection_results'] = SelectionQuery.results(source:, log_stream_filter:, request_exclusion_filter:)
      definitions['selection_pages'] = SelectionQuery.selections(source:)
      definitions
    end

    # Shared by collection and syntax validation so both compile the same bounds.
    def bounded_query(sql, start_at:, end_at:)
      # Keep failure cohorts scoped to the full day while partitioning metrics.
      metric_scope = true
      stream_filter = sql.include?(FrontendEventsQuery::STREAM_FILTER) ? FrontendEventsQuery::STREAM_FILTER : log_stream_filter
      sql.gsub(stream_filter) do
        bounds = metric_scope ? window_filter(start_at, end_at) : window_filter(now - 1.day, now)
        metric_scope = false
        "#{stream_filter} AND #{bounds}"
      end
    end

  private

    def client = @client ||= Aws::CloudWatchLogs::Client.new(region: @region, retry_limit: 0)
    def forced?(name) = @force && (@selected.nil? || @selected.include?(name))

    def collect(name, sql)
      @partition_count = 0
      rows = if IDENTIFIER_QUERIES.include?(name)
               8.times.flat_map do |index|
                 start_at = now - 1.day + index * 3.hours
                 partition(name, sql, start_at, start_at + 3.hours)
               end
             else
               partition(name, sql, now - 1.day, now)
             end
      if IDENTIFIER_QUERIES.include?(name)
        rows.map do |row|
          ids = JSON.parse(row.fetch('request_ids'))
          unless ids.is_a?(Array) && ids.all? { |id| id.is_a?(String) && id.present? } && ids.uniq.size == Integer(row.fetch('journey_count'))
            raise QueryError, 'Incomplete journey identifier set'
          end

          row.except('request_ids', 'journey_count').merge('journey_keys' => ids.map { |id| Digest::SHA256.hexdigest(id) })
        end
      elsif name.start_with?('ai_cost_')
        rows.map { |row| hashed_request_row(row) }
      elsif name == 'frontend_events'
        rows.map { |row| hashed_request_row(row, identifier_keys: %w[event_id question_id], observed: true) }
      elsif name == 'classic_outcomes'
        ClassicOutcomesQuery.collapse(rows.map { |row| hashed_request_row(row, observed: true) })
      else
        rows
      end
    end

    def hashed_request_row(row, identifier_keys: [], observed: false)
      id = row.fetch('request_id')
      raise QueryError, 'Missing request identifier' if id.blank?

      hashed = row.except('request_id', 'browser_session_id', 'submission_id', *identifier_keys).merge('journey_key' => Digest::SHA256.hexdigest(id))
      identifier_keys.each do |key|
        digest = identifier_digest(row[key])
        hashed["#{key.delete_suffix('_id')}_key"] = digest if digest
      end
      session = row['browser_session_id']
      hashed['session_key'] = Digest::SHA256.hexdigest(session) if session.to_s.match?(/\Av1:[0-9a-f]{64}\z/)
      hashed['observed_at'] = normalise_observed_at(row) if observed
      hashed
    end

    def identifier_digest(value)
      text = value.to_s
      return if text.blank? || !text.match?(/\A[a-zA-Z0-9-]{1,64}\z/)

      Digest::SHA256.hexdigest(text)
    end

    def normalise_observed_at(row)
      raw = row['observed_at'].presence || row['@timestamp']
      time = Time.find_zone!('UTC').parse(raw.to_s)
      raise QueryError, 'Missing event time' unless time

      time.utc.iso8601(6)
    end

    def partition(name, sql, start_at, end_at)
      @partition_count += 1
      raise QueryError, "#{name} exceeded its partition limit" if @partition_count > MAX_PARTITIONS

      rows, matched = execute_window(sql, start_at, end_at)
      complete = rows.size < ROW_LIMIT
      # CloudWatch reports the failure subquery's records_matched for this query,
      # not its result cohort. Its exact distinct-ID count is checked below.
      if (IDENTIFIER_QUERIES + %w[frontend_events classic_outcomes] - %w[selection_results]).include?(name)
        raise QueryError, 'Missing journey completeness statistics' if matched.nil?

        count_field = name == 'search_journeys' ? 'started_events' : 'event_count'
        complete &&= rows.sum { |row| Integer(row.fetch(count_field)) } == matched
      end
      complete &&= rows.all? { |row| complete_identifier_set?(row) } if (IDENTIFIER_QUERIES - %w[search_journeys]).include?(name)
      if complete
        return rows unless name == 'journey_outcomes'

        return rows.map { |row| row.merge('window_start' => start_at.utc.iso8601, 'window_end' => end_at.utc.iso8601) }
      end

      raise QueryError, 'Latency histogram reached its row limit' if name == 'latency_histogram'
      raise QueryError, "#{name} is incomplete within one second" if end_at - start_at <= 1
      raise QueryError, 'Selection results reached their row limit' if name.end_with?('_selection_trend')

      middle = start_at + ((end_at - start_at) / 2).floor
      partition(name, sql, start_at, middle) + partition(name, sql, middle, end_at)
    end

    def complete_identifier_set?(row)
      ids = JSON.parse(row.fetch('request_ids'))
      ids.is_a?(Array) && ids.all? { |id| id.is_a?(String) && id.present? } && ids.uniq.size == Integer(row.fetch('journey_count'))
    rescue JSON::ParserError, ArgumentError
      false
    end

    def execute_window(sql, start_at, end_at)
      query_id = response = nil
      bounded = bounded_query(sql, start_at:, end_at:)
      scan_start, scan_end = sql.include?(request_exclusion_filter) ? [now - 1.day, now] : [start_at, end_at]
      query_id = client.start_query(query_language: 'SQL', start_time: scan_start.to_i, end_time: scan_end.to_i, query_string: bounded).query_id
      QUERY_MAX_POLLS.times do
        response = client.get_query_results(query_id:)
        return [response.results.map { |row| parsed_row(row) }, response.statistics&.records_matched] if response.status == 'Complete'

        raise QueryError, "CloudWatch query #{response.status}" if TERMINAL_FAILURE_STATUSES.include?(response.status)

        Kernel.sleep QUERY_POLL_INTERVAL_SECONDS
      end
      raise QueryError, 'CloudWatch query timed out'
    rescue StandardError, Interrupt
      if query_id && !(%w[Complete] + TERMINAL_FAILURE_STATUSES).include?(response&.status)
        begin
          client.stop_query(query_id:)
        rescue StandardError
          # Cancellation is best effort; do not mask the original failure.
        end
      end
      raise
    end

    def window_filter(start_at, end_at)
      # CloudWatch can rewrite SQL timestamp literals into QL string comparisons
      # that match no events. Numeric bounds retain the half-open second windows.
      "UNIX_TIMESTAMP(`@timestamp`) >= #{start_at.to_i} AND UNIX_TIMESTAMP(`@timestamp`) < #{end_at.to_i}"
    end

    def log_stream_filter
      "(`@logStream` LIKE '%ecs/backend-#{@service}/%' OR `@logStream` LIKE '%ecs/worker-#{@service}/%')"
    end

    def normalise_field(field) = field == 'cost_operation' ? 'event_kind' : super

    def volume_query
      <<~SQL
        SELECT #{bucket_expression} AS `@timestamp`, search_type, event,
          COALESCE(request_source, 'unknown') AS request_source, COUNT(*) AS searches,
          SUM(CASE WHEN event = 'search_completed' AND #{zero_result_condition} THEN 1 ELSE 0 END) AS zero_results
        FROM #{source} WHERE #{log_stream_filter} AND #{base_search_filter} AND #{request_exclusion_filter}
        GROUP BY #{bucket_expression}, search_type, event, COALESCE(request_source, 'unknown')
      SQL
    end

    def search_results_query
      <<~SQL
        SELECT search_type, request_source, COUNT(*) AS searches,
          SUM(CASE WHEN result_count = 0 THEN 1 ELSE 0 END) AS zero_results
        FROM #{source}
        WHERE #{log_stream_filter} AND service = 'search' AND event = 'search_completed'
          AND request_source = 'frontend' AND result_count >= 0
          AND (search_degraded IS NULL OR search_degraded = false)
          AND ((search_type = 'classic' AND results_type = 'fuzzy_search')
            OR (search_type IN ('internal', 'interactive') AND results_type IN ('opensearch', 'vector', 'hybrid')
              AND (final_result_type IS NULL OR final_result_type = '' OR final_result_type = 'answers')))
          AND #{request_exclusion_filter}
        GROUP BY search_type, request_source
      SQL
    end

    def latency_histogram_query
      bucket = "CASE WHEN total_duration_ms = 0 THEN #{LatencyHistogram::ZERO_BUCKET} ELSE FLOOR(LN(total_duration_ms) / #{LatencyHistogram::LOG_BASE}) END"
      <<~SQL
        SELECT search_type, #{bucket} AS latency_bucket, COUNT(*) AS observations
        FROM #{source} WHERE #{log_stream_filter} AND #{base_search_filter}
          AND total_duration_ms >= 0 AND #{request_exclusion_filter}
        GROUP BY search_type, #{bucket}
        LIMIT #{ROW_LIMIT}
      SQL
    end

    def search_ai_cost_filter
      <<~SQL.squish
        ((service = 'search' AND event = 'api_call_completed') OR
          (service = 'ai_usage' AND (event = 'embedding_api_call_completed' OR event = 'embedding_api_call_failed') AND event_kind = 'vector_search_query_embedding'))
      SQL
    end

    def ai_cost_trend_query
      <<~QUERY
        SELECT request_id, #{bucket_expression} AS `@timestamp`, COALESCE(event_kind, operation, 'unknown') AS cost_operation,
          COALESCE(model, 'unknown') AS model,
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
        FROM #{source} WHERE #{log_stream_filter} AND #{search_ai_cost_filter} AND request_id IS NOT NULL AND request_id != ''
        GROUP BY request_id, #{bucket_expression}, COALESCE(event_kind, operation, 'unknown'), COALESCE(model, 'unknown')
        LIMIT #{ROW_LIMIT}
      QUERY
    end

    def selection_query(condition)
      <<~SQL
        SELECT SUM(result_selections) AS selected, SUM(selectable_searches) AS selectable,
          DATE_TRUNC('HOUR', latest_timestamp) AS `@timestamp`, source
        FROM (
          SELECT request_id, SUM(CASE WHEN event = 'result_selected' THEN 1 ELSE 0 END) AS result_selections,
            SUM(CASE WHEN event = 'search_completed' AND result_count > 0 AND #{condition} THEN 1 ELSE 0 END) AS selectable_searches,
            MIN_BY(COALESCE(GET_JSON_OBJECT(`@message`, '$.request_source'), 'unknown'), `@timestamp`) AS source, MAX(`@timestamp`) AS latest_timestamp
          FROM #{source} WHERE #{log_stream_filter} AND service = 'search' AND request_id IS NOT NULL
            AND (event = 'result_selected' OR (event = 'search_completed' AND result_count > 0 AND #{condition}))
          GROUP BY request_id
        ) AS request_selections
        WHERE selectable_searches > 0 AND #{request_exclusion_filter}
        GROUP BY DATE_TRUNC('HOUR', latest_timestamp), source
        LIMIT #{ROW_LIMIT}
      SQL
    end

    def improvement_terms_query(term_filter:)
      <<~SQL
        SELECT query, search_type, COUNT(*) AS zero_results
        FROM #{source} WHERE #{log_stream_filter} AND service = 'search' AND event = 'search_completed'
          AND #{zero_result_condition} AND query IS NOT NULL AND #{term_filter} AND #{request_exclusion_filter}
        GROUP BY query, search_type LIMIT #{ROW_LIMIT}
      SQL
    end
  end
end
