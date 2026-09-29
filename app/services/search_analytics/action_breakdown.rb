# frozen_string_literal: true

module SearchAnalytics
  # Additive read contract: old journey fingerprints and totals stay unchanged.
  # Expand identifiers in PostgreSQL, never materialize their sets in the web process.
  class ActionBreakdown
    def self.call(...) = new(...).call

    def initialize(service:, dates:, period:, definitions:, payload:, materialized: false)
      @service = service
      @dates = dates
      @period = period
      @definitions = definitions
      @payload = payload
      @materialized = materialized
    end

    def call
      journey_dates = current_dates('search_journeys')
      collected = current_dates('search_actions') & journey_dates
      available = collected.any?
      rows = available ? db.fetch(counts_sql).all.index_by { |row| row[:bucket] } : {}
      {
        'available' => available,
        'coverage' => {
          'complete' => collected == @dates,
          'expected_days' => @dates.size,
          'collected_days' => collected.size,
          'missing_dates' => (@dates - collected).map(&:iso8601),
        },
        'summary' => if @payload.dig('availability', 'journey_metrics')
                       counts(@payload.dig('summary', 'searches'), rows[nil], available:)
                     end,
        'trend' => @payload.dig('trends', 'volume').filter_map do |bucket|
          total = bucket[@period.view]
          next if total.nil?

          counts(total, rows[bucket['bucket']], available: collected.include?(Date.iso8601(bucket['bucket'].first(10))))
            .merge('bucket' => bucket['bucket'])
        end,
      }
    end

  private

    def db = SearchAnalyticsQueryResult.db

    def records(name)
      SearchAnalyticsQueryResult.where(service: @service, reporting_date: @dates, name:, fingerprint: @definitions.fetch(name))
    end

    def current_dates(name) = records(name).select_map(:reporting_date).sort

    def counts(total, row, available:)
      navigation = available ? (row&.fetch(:navigation, 0) || 0) : 0
      search = available ? (row&.fetch(:search, 0) || 0) : 0
      {
        'total' => total,
        'navigation' => available ? navigation : nil,
        'search' => available ? search : nil,
        'unclassified' => total - navigation - search,
      }
    end

    def counts_sql
      <<~SQL
        WITH starts AS (#{@materialized ? materialized_starts_sql : stored_starts_sql}),
        actions AS (
          SELECT k.key, bit_or(CASE j.row->>'search_action'
            WHEN 'navigation' THEN 1 WHEN 'search' THEN 2 ELSE 4 END) AS action
          FROM (#{records('search_actions').select(:rows).sql}) r
          CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
          CROSS JOIN LATERAL jsonb_array_elements_text(j.row->'journey_keys') k(key)
          WHERE j.row->>'request_source' = 'frontend' #{type_filter}
          GROUP BY k.key
        )
        SELECT to_char(bucket, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS bucket,
          count(DISTINCT starts.key) FILTER (WHERE actions.action = 1) AS navigation,
          count(DISTINCT starts.key) FILTER (WHERE actions.action = 2) AS search
        FROM starts LEFT JOIN actions ON actions.key = starts.key
        GROUP BY GROUPING SETS ((bucket), ())
      SQL
    end

    def stored_starts_sql
      <<~SQL
        SELECT k.key,
          date_trunc(#{db.literal(@period.bucket_size)}, (j.row->>'@timestamp')::timestamptz AT TIME ZONE 'UTC') AS bucket
        FROM (#{records('search_journeys').select(:rows).sql}) r
        CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
        CROSS JOIN LATERAL jsonb_array_elements_text(j.row->'journey_keys') k(key)
        WHERE j.row->>'request_source' = 'frontend' #{type_filter}
      SQL
    end

    def materialized_starts_sql
      hours = MaterializedProjection::VIEW_HOURS.fetch(@period.view)
      source = DailyJourney.where(service: @service, reporting_date: current_dates('search_journeys')).select(:journey_key, :reporting_date, hours).sql
      if @period.single_day?
        <<~SQL
          SELECT encode(journey_key, 'hex') AS key, reporting_date::timestamp + make_interval(hours => h) AS bucket
          FROM (#{source}) d CROSS JOIN generate_series(0, 23) h
          WHERE (#{hours} & (1::bigint << h)) > 0
        SQL
      else
        <<~SQL
          SELECT encode(journey_key, 'hex') AS key, reporting_date::timestamp AS bucket
          FROM (#{source}) d WHERE #{hours} > 0
        SQL
      end
    end

    def type_filter
      types = CloudwatchSnapshotQuery::VIEW_SEARCH_TYPES[@period.view]
      types ? "AND j.row->>'search_type' IN #{db.literal(types)}" : ''
    end
  end
end
