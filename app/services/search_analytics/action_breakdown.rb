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

    # Each stored row holds thousands of journey keys. Read the fields of a row
    # in a MATERIALIZED CTE before its keys are expanded. Otherwise PostgreSQL
    # carries the whole JSONB row with every key into the grouping step, and a
    # 7-day read spills gigabytes to disk. Keys are hex, so "C" collation
    # compares them as bytes without locale rules.
    def counts_sql
      <<~SQL
        WITH #{@materialized ? materialized_starts_ctes : stored_starts_ctes},
        action_groups AS MATERIALIZED (
          SELECT CASE j.row->>'search_action' WHEN 'navigation' THEN 1 WHEN 'search' THEN 2 ELSE 4 END AS action,
            j.row->'journey_keys' AS keys
          FROM (#{records('search_actions').select(:rows).sql}) r
          CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
          WHERE j.row->>'request_source' = 'frontend' #{type_filter}
        ),
        actions AS (
          SELECT k.key COLLATE "C" AS key, bit_or(g.action) AS action
          FROM action_groups g
          CROSS JOIN LATERAL jsonb_array_elements_text(g.keys) k(key)
          GROUP BY 1
        )
        SELECT to_char(bucket, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS bucket,
          count(DISTINCT starts.key) FILTER (WHERE actions.action = 1) AS navigation,
          count(DISTINCT starts.key) FILTER (WHERE actions.action = 2) AS search
        FROM starts LEFT JOIN actions ON actions.key = starts.key
        GROUP BY GROUPING SETS ((bucket), ())
      SQL
    end

    def stored_starts_ctes
      # CloudWatch buckets are UTC, including values without a timezone suffix.
      <<~SQL
        journey_groups AS MATERIALIZED (
          SELECT date_trunc(#{db.literal(@period.bucket_size)}, (j.row->>'@timestamp')::timestamp) AS bucket,
            j.row->'journey_keys' AS keys
          FROM (#{records('search_journeys').select(:rows).sql}) r
          CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
          WHERE j.row->>'request_source' = 'frontend' #{type_filter}
        ),
        starts AS (
          SELECT k.key COLLATE "C" AS key, g.bucket
          FROM journey_groups g
          CROSS JOIN LATERAL jsonb_array_elements_text(g.keys) k(key)
        )
      SQL
    end

    def materialized_starts_ctes
      hours = MaterializedProjection::VIEW_HOURS.fetch(@period.view)
      source = DailyJourney.where(service: @service, reporting_date: current_dates('search_journeys')).select(:journey_key, :reporting_date, hours).sql
      if @period.single_day?
        <<~SQL
          starts AS (
            SELECT encode(journey_key, 'hex') COLLATE "C" AS key, reporting_date::timestamp + make_interval(hours => h) AS bucket
            FROM (#{source}) d CROSS JOIN generate_series(0, 23) h
            WHERE (#{hours} & (1::bigint << h)) > 0
          )
        SQL
      else
        <<~SQL
          starts AS (
            SELECT encode(journey_key, 'hex') COLLATE "C" AS key, reporting_date::timestamp AS bucket
            FROM (#{source}) d WHERE #{hours} > 0
          )
        SQL
      end
    end

    def type_filter
      types = CloudwatchSnapshotQuery::VIEW_SEARCH_TYPES[@period.view]
      types ? "AND j.row->>'search_type' IN #{db.literal(types)}" : ''
    end
  end
end
