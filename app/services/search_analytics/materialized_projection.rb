# frozen_string_literal: true

module SearchAnalytics
  # rubocop:disable Style/NumericPredicate
  class MaterializedProjection
    SERIES = JourneyOutcomes::SERIES
    VIEW_HOURS = {
      'all' => :all_hours,
      'classic' => :classic_hours,
      'internal' => :internal_hours,
    }.freeze
    VIEW_SEEN = {
      'all' => :all_seen,
      'classic' => :classic_seen,
      'internal' => :internal_seen,
    }.freeze
    NUMERIC = /^\s*[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\s*$/

    def initialize(service:, dates:, period:, costs:, cost_fingerprint:, outcome_fingerprint:)
      @service = service
      @dates = dates
      @period = period
      @costs = costs
      @cost_fingerprint = cost_fingerprint
      @outcome_fingerprint = outcome_fingerprint
      @rows = window_rows
    end

    def summary(view)
      @rows.find { |row| row['view'] == view && row['bucket'].nil? } || (%w[journeys] + SERIES).index_with { 0 }
    end

    def trend
      @trend ||= @rows.reject { |row| row['bucket'].nil? }.group_by { |row| row['bucket'] }.sort.map do |bucket, rows|
        { 'bucket' => bucket }.merge(SearchAnalytics::Period::VIEWS.index_with { |name| rows.find { |row| row['view'] == name }&.fetch('journeys') || 0 })
      end
    end

    def outcomes(view:, buckets:, coverage:)
      by_bucket = @rows.select { |row| row['view'] == view && row['bucket'] }.index_by { |row| row['bucket'] }
      { 'coverage' => coverage,
        'summary' => coverage['complete'] ? summary(view).slice(*SERIES) : nil,
        'trend' => coverage['complete'] ? buckets.map { |bucket| { 'bucket' => bucket }.merge(SERIES.index_with { |key| by_bucket[bucket]&.fetch(key) || 0 }) } : [] }
    end

    def terms
      query = row_text(:term_row, 'query')
      search_type = row_text(:term_row, 'search_type')
      zero_text = row_text(:term_row, 'zero_results')
      types = SearchAnalytics::CloudwatchSnapshotQuery::VIEW_SEARCH_TYPES[@period.view]
      totals = json_elements(:term_row)
        .where(Sequel[:query_result][:service] => @service, Sequel[:query_result][:reporting_date] => @dates, Sequel[:query_result][:name] => %w[item_id_improvements search_term_improvements])
        .exclude(query => nil)
        .exclude(query =~ /^\s*$/)
      totals = totals.where(search_type => types) if types
      totals = totals.select(
        query.as(:query),
        Sequel.case([[Sequel[:query_result][:name] =~ 'item_id_improvements', 'item_ids']], 'search_terms').as(:term_type),
        Sequel.function(:sum, Sequel.case([[zero_text =~ NUMERIC, Sequel.function(:trunc, Sequel.cast(zero_text, 'double precision')).cast(:bigint)]], 0)).cast(:bigint).as(:zero_results),
      ).group(:query, :term_type)

      ranked = db[:totals].select_all.select_append(
        Sequel.function(:row_number).over(
          partition: :term_type,
          order: [Sequel.desc(:zero_results), collate_c(:query)],
        ).as(:rank),
      )

      db[:ranked]
        .select(:query, :term_type, :zero_results)
        .where { rank <= CloudwatchSnapshotQuery::IMPROVEMENT_TERM_LIMIT }
        .order(collate_c(:term_type), Sequel.desc(:zero_results), collate_c(:query))
        .with(:totals, totals)
        .with(:ranked, ranked)
        .all
        .map { |row| row.transform_keys(&:to_s) }
    end

    def question_counts
      hours = VIEW_HOURS.fetch(@period.view)
      questions = Sequel.function(:jsonb_extract_path_text, Sequel[:outcome][:row], 'total_questions')
      keys = Sequel.function(:jsonb_extract_path, Sequel[:outcome][:row], 'journey_keys')
      asked = json_elements(:outcome)
        .join_table(:cross, Sequel.function(:jsonb_array_elements_text, keys).as(:journey_hex, [:key]), nil, table_alias: :journey_hex, lateral: true)
        .where(Sequel[:query_result][:service] => @service, Sequel[:query_result][:reporting_date] => @dates, Sequel[:query_result][:name] => 'journey_outcomes', Sequel[:query_result][:fingerprint] => @outcome_fingerprint)
        .select(
          Sequel[:journey_hex][:key].as(:journey_key),
          Sequel.function(:max, Sequel.case([[questions =~ NUMERIC, Sequel.cast(questions, :bigint)]], nil)).as(:total_questions),
        )
        .group(Sequel[:journey_hex][:key])
        .as_hash(:journey_key, :total_questions)
      DailyJourney.where(service: @service, reporting_date: @dates).where { Sequel[hours] > 0 }
        .select_map(Sequel.function(:encode, :journey_key, 'hex'))
        .uniq
        .map { |key| asked[key] }
        .tally
        .sort_by { |total, _count| total || -1 }
        .map { |total, journeys| { 'questions' => total, 'journeys' => journeys } }
    end

    def cost_keys
      return {} if @costs.empty?

      hours = VIEW_HOURS.fetch(@period.view)
      key = row_text(:cost_row, 'journey_key')
      json_elements(:cost_row)
        .join_table(:inner, DailyJourney.table_name, {
          Sequel[:journey][:service] => Sequel[:query_result][:service],
          Sequel[:journey][:journey_key] => Sequel.function(:decode, key, 'hex'),
        }, table_alias: :journey)
        .where(Sequel[:query_result][:service] => @service, Sequel[:query_result][:reporting_date] => @dates, Sequel[:journey][:reporting_date] => @dates, Sequel[:query_result][:name] => 'ai_cost_trend', Sequel[:query_result][:fingerprint] => @cost_fingerprint)
        .exclude(key => nil)
        .where { Sequel[:journey][hours] > 0 }
        .select(Sequel.function(:encode, Sequel[:journey][:journey_key], 'hex').as(:key))
        .distinct
        .from_self(alias: :matched)
        .select_map(:key)
        .index_with(true)
    end

  private

    def db = RepeatedJourney.db

    def window_rows
      chosen = RepeatedJourney.where(service: @service, reporting_date: @dates)
      states = db[:chosen].select(
        :journey_key,
        (Sequel.function(:bit_or, :all_hours) > 0).as(:all_seen),
        (Sequel.function(:bit_or, :classic_hours) > 0).as(:classic_seen),
        (Sequel.function(:bit_or, :internal_hours) > 0).as(:internal_seen),
        Sequel.function(:search_analytics_mv_latest_state, :terminal).as(:terminal),
        Sequel.function(:bit_or, :flags).as(:flags),
      ).group(:journey_key)
      classified = db[:states].select(Sequel[:states].*, status_case.as(:status))
      combined = day_totals.union(grain_totals, all: true, from_self: false)
        .union(multi_summary, all: true, from_self: false)
        .union(multi_trend, all: true, from_self: false)

      db[:combined]
        .select(:view, Sequel.function(:to_char, :bucket, 'YYYY-MM-DD"T"HH24:MI:SS"Z"').as(:bucket), *sum_columns)
        .group(:view, :bucket)
        .order(:bucket, :view)
        .with(:chosen, chosen, materialized: true)
        .with(:states, states, materialized: true)
        .with(:classified, classified, materialized: true)
        .with(:multi_summary, multi_summary)
        .with(:multi_trend, multi_trend)
        .with(:combined, combined)
        .all
        .map { |row| row.transform_keys(&:to_s) }
    end

    def multi_summary
      db[:classified]
        .select(Sequel[:origin][:view], Sequel.cast(nil, :timestamp).as(:bucket), *count_columns(Sequel[:classified][:flags]))
        .join_table(:inner, seen_values.lateral, { Sequel[:origin][:seen] => true }, table_alias: :origin)
        .group(Sequel[:origin][:view])
    end

    def multi_trend
      dataset = db[:chosen].from_self(alias: :repeated)
        .join(:classified, journey_key: :journey_key)
        .select(Sequel[:origin][:view], trend_bucket.as(:bucket), *count_columns(Sequel[:classified][:flags]))
        .join_table(:inner, hour_values.lateral, true, table_alias: :origin)
      dataset = dataset.cross_join(db.from { Sequel.function(:generate_series, 0, 23).as(:hour_of_day) }) if @period.single_day?
      dataset.where(hour_present).group(Sequel[:origin][:view], trend_bucket)
    end

    def day_totals
      JourneyRollupTotal
        .where(service: @service, reporting_date: @dates, bucket_size: 'day')
        .select(:view, Sequel.cast(nil, :timestamp).as(:bucket), *sum_columns)
        .group(:view)
    end

    def grain_totals
      JourneyRollupTotal
        .where(service: @service, reporting_date: @dates, bucket_size: @period.bucket_size)
        .select(:view, :bucket, *(%i[journeys] + SERIES.map(&:to_sym)))
    end

    def seen_values
      VIEW_SEEN.map { |view, column|
        db.select(Sequel.as(view, :view), Sequel[:classified][column].as(:seen))
      }.reduce { |left, right| left.union(right, all: true, from_self: false) }
    end

    def hour_values
      VIEW_HOURS.map { |view, column|
        db.select(Sequel.as(view, :view), Sequel[:repeated][column].as(:hours))
      }.reduce { |left, right| left.union(right, all: true, from_self: false) }
    end

    def trend_bucket
      date = Sequel.cast(Sequel[:repeated][:reporting_date], :timestamp)
      return date unless @period.single_day?

      date + Sequel.lit('make_interval(hours => hour_of_day)')
    end

    def hour_present
      return Sequel[:origin][:hours] > 0 unless @period.single_day?

      Sequel.lit('(origin.hours & (CAST(1 AS bigint) << hour_of_day)) > 0')
    end

    def status_case
      bits = Sequel[:terminal].sql_number & 3
      Sequel.case(
        [
          [bits =~ 1, 'completed'],
          [bits =~ 2, 'failed'],
          [Sequel.|({ Sequel[:terminal] !~ nil => true }, (Sequel[:flags].sql_number & 8) > 0), 'unknown'],
          [(Sequel[:flags].sql_number & 4) > 0, 'nonterminal'],
        ],
        'unknown',
      )
    end

    def count_columns(flags)
      status = Sequel.qualify(flags.table, :status)
      [
        Sequel.function(:count).*.as(:journeys),
        *SERIES.map do |name|
          predicate = case name
                      when 'selected' then (flags.sql_number & 1) > 0
                      when 'zero_result' then (flags.sql_number & 2) > 0
                      else status =~ name
                      end
          Sequel.function(:count).*.filter(predicate).as(name)
        end,
      ]
    end

    def sum_columns
      (%w[journeys] + SERIES).map do |name|
        Sequel.function(:sum, name.to_sym).cast(:bigint).as(name)
      end
    end

    def json_elements(row_alias)
      db.from(Sequel[SearchAnalyticsQueryResult.table_name].as(:query_result)).join_table(
        :cross,
        Sequel.function(:jsonb_array_elements, Sequel[:query_result][:rows]).as(row_alias, [:row]),
        nil,
        table_alias: row_alias,
        lateral: true,
      )
    end

    def row_text(row_alias, key)
      Sequel.function(:jsonb_extract_path_text, Sequel[row_alias][:row], key)
    end

    def collate_c(column)
      Sequel.lit('? COLLATE "C"', column)
    end
  end
  # rubocop:enable Style/NumericPredicate
end
