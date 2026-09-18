# frozen_string_literal: true

module SearchAnalytics
  class MaterializedProjection
    SERIES = JourneyOutcomes::SERIES

    def initialize(service:, dates:, period:, costs:)
      @db = SearchAnalyticsQueryResult.db
      @dates = dates.map { |date| @db.literal(date) }.join(',')
      @service = @db.literal(service)
      @period = period
      @costs = costs
      sums = (%w[journeys] + SERIES).map { |name| "sum(#{name})::bigint AS #{name}" }.join(',')
      counts = counts_sql('flags')
      bucket = period.single_day? ? 'd.reporting_date::timestamp + make_interval(hours=>h)' : 'd.reporting_date::timestamp'
      hours_join = period.single_day? ? 'CROSS JOIN generate_series(0,23) h' : ''
      seen = period.single_day? ? '(hours & (1::bigint << h))>0' : 'hours>0'
      sql = <<~SQL
        WITH chosen AS MATERIALIZED (
          SELECT * FROM search_analytics_repeated_journeys WHERE service = #{@service} AND reporting_date IN (#{@dates})
        ), states AS MATERIALIZED (
          SELECT journey_key, bit_or(all_hours)>0 AS all_seen,
            bit_or(classic_hours)>0 AS classic_seen, bit_or(internal_hours)>0 AS internal_seen,
            search_analytics_mv_latest_state(terminal) AS terminal, bit_or(flags) AS flags
          FROM chosen GROUP BY journey_key
        ), classified AS MATERIALIZED (
          SELECT *, CASE WHEN (terminal & 3)=1 THEN 'completed'
            WHEN (terminal & 3)=2 THEN 'failed'
            WHEN terminal IS NOT NULL OR (flags & 8)>0 THEN 'unknown'
            WHEN (flags & 4)>0 THEN 'nonterminal' ELSE 'unknown' END AS status
          FROM states
        ), multi_summary AS (
          SELECT view, NULL::timestamp AS bucket, #{counts}
          FROM classified CROSS JOIN LATERAL
            (VALUES ('all',all_seen),('classic',classic_seen),('internal',internal_seen)) v(view,seen)
          WHERE seen GROUP BY view
        ), multi_trend AS (
          SELECT view, #{bucket} AS bucket, #{counts_sql('c.flags')}
          FROM chosen d JOIN classified c USING(journey_key)
          CROSS JOIN LATERAL
            (VALUES ('all',d.all_hours),('classic',d.classic_hours),('internal',d.internal_hours)) v(view,hours)
          #{hours_join}
          WHERE #{seen} GROUP BY view, bucket
        ), combined AS (
          SELECT view, NULL::timestamp AS bucket, #{sums}
          FROM search_analytics_journey_rollup_totals WHERE service = #{@service} AND reporting_date IN (#{@dates}) AND bucket_size='day' GROUP BY view
          UNION ALL
          SELECT view, bucket, #{(%w[journeys] + SERIES).join(',')}
          FROM search_analytics_journey_rollup_totals WHERE service = #{@service} AND reporting_date IN (#{@dates}) AND bucket_size='#{period.bucket_size}'
          UNION ALL SELECT * FROM multi_summary
          UNION ALL SELECT * FROM multi_trend
        )
        SELECT view, to_char(bucket, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS bucket, #{sums}
        FROM combined GROUP BY view,bucket ORDER BY bucket,view
      SQL
      @rows = @db.fetch(sql).all.map { |row| row.transform_keys(&:to_s) }
    end

    def summary(view)
      @rows.find { |row| row['view'] == view && row['bucket'].nil? } || (%w[journeys] + SERIES).index_with { 0 }
    end

    def trend
      @trend ||= @rows.reject { |row| row['bucket'].nil? }.group_by { |row| row['bucket'] }.sort.map do |bucket, rows|
        { 'bucket' => bucket }.merge(SearchAnalytics::Period::VIEWS.index_with { |view| rows.find { |row| row['view'] == view }&.fetch('journeys') || 0 })
      end
    end

    def outcomes(view:, buckets:, coverage:)
      by_bucket = @rows.select { |row| row['view'] == view && row['bucket'] }.index_by { |row| row['bucket'] }
      { 'coverage' => coverage,
        'summary' => coverage['complete'] ? summary(view).slice(*SERIES) : nil,
        'trend' => coverage['complete'] ? buckets.map { |bucket| { 'bucket' => bucket }.merge(SERIES.index_with { |key| by_bucket[bucket]&.fetch(key) || 0 }) } : [] }
    end

    def terms
      types = SearchAnalytics::CloudwatchSnapshotQuery::VIEW_SEARCH_TYPES[@period.view]
      filter = types ? "AND j.row->>'search_type' IN (#{types.map { |type| @db.literal(type) }.join(',')})" : ''
      @db.fetch(<<~SQL).all.map { |row| row.transform_keys(&:to_s) }
        WITH totals AS (
          SELECT j.row->>'query' AS query,
            CASE r.name WHEN 'item_id_improvements' THEN 'item_ids' ELSE 'search_terms' END AS term_type,
            sum(CASE WHEN j.row->>'zero_results' ~ '^[[:space:]]*[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?[[:space:]]*$'
              THEN trunc((j.row->>'zero_results')::double precision)::bigint ELSE 0 END)::bigint AS zero_results
          FROM search_analytics_query_results r
          CROSS JOIN LATERAL jsonb_array_elements(r.rows) j(row)
          WHERE r.service=#{@service} AND r.reporting_date IN (#{@dates})
            AND r.name IN ('item_id_improvements','search_term_improvements')
            AND j.row->>'query' IS NOT NULL AND j.row->>'query' !~ '^[[:space:]]*$'
            #{filter}
          GROUP BY query,term_type
        ), ranked AS (
          SELECT *,row_number() OVER(PARTITION BY term_type ORDER BY zero_results DESC,query COLLATE "C") AS rank
          FROM totals
        )
        SELECT query,term_type,zero_results FROM ranked
        WHERE rank<=#{CloudwatchSnapshotQuery::IMPROVEMENT_TERM_LIMIT} ORDER BY term_type COLLATE "C",zero_results DESC,query COLLATE "C"
      SQL
    end

    def cost_keys
      return {} if @costs.empty?

      column = { 'all' => 'all_hours', 'classic' => 'classic_hours', 'internal' => 'internal_hours' }.fetch(@period.view)
      keys = @costs.map { |row| row.fetch('journey_key') }.uniq.map { |key| "decode(#{@db.literal(key)},'hex')" }.join(',')
      @db.fetch("SELECT DISTINCT encode(journey_key,'hex') AS key FROM search_analytics_daily_journeys WHERE service = #{@service} AND reporting_date IN (#{@dates}) AND #{column}>0 AND journey_key IN (#{keys})").all.to_h { |row| [row[:key], true] }
    end

  private

    def counts_sql(flags)
      counts = SERIES.map do |name|
        predicate = case name
                    when 'selected' then "(#{flags} & 1)>0"
                    when 'zero_result' then "(#{flags} & 2)>0"
                    else "status='#{name}'"
                    end
        "count(*) FILTER (WHERE #{predicate}) AS #{name}"
      end
      ['count(*) AS journeys', *counts].join(',')
    end
  end
end
