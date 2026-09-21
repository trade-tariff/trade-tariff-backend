# frozen_string_literal: true

module SearchAnalytics
  class MaterializedResult
    Result = Data.define(:available, :value)
    METADATA = %i[id service name reporting_date fingerprint collected_at].freeze
    PROJECTED = %w[search_journeys journey_outcomes search_term_improvements item_id_improvements].freeze

    def self.call(...) = new(...).call

    def initialize(period:, region:, log_group_name:, date_range:, now:)
      if date_range
        date_range = DateRange.parse(from: date_range.from.iso8601, to: date_range.to.iso8601, now:)
        period = Period.for_range(date_range:, view: period.view)
      end
      @period = period
      last_date = now.utc.to_date - 1
      @dates = date_range ? date_range.dates : ((last_date - (period.duration / 1.day).to_i + 1)..last_date).to_a
      @service = TradeTariffBackend.service
      @definitions = DailyQuery.new(reporting_date: @dates.first, region:, log_group_name:, now:).fingerprints
      @required = @definitions.keys - %w[frontend_events journey_outcomes]
    end

    def call
      # An existing caller transaction may have a weaker isolation level. Keep
      # the legacy path rather than claiming a snapshot of live source and views.
      return Result.new(available: false, value: nil) if SearchAnalyticsQueryResult.db.in_transaction?

      # Pin source revisions and materialized views together. A concurrent
      # refresh may replace view contents, but MVCC keeps this snapshot visible.
      SearchAnalyticsQueryResult.db.transaction(isolation: :repeatable, read_only: true) do
        metadata = SearchAnalyticsQueryResult.where(service: @service, reporting_date: @dates, name: @definitions.keys).select(*METADATA).all
        compatible = metadata.select { |row| row.fingerprint == @definitions.fetch(row.name) }
        present = compatible.select { |row| @required.include?(row.name) }
        next Result.new(available: true, value: nil) if present.empty? && compatible.empty?
        next Result.new(available: false, value: nil) if present.empty?

        journey_dates = present.select { |row| row.name == 'search_journeys' }.map(&:reporting_date).uniq.sort
        next Result.new(available: false, value: nil) if journey_dates.empty?
        next Result.new(available: false, value: nil) unless MaterializedViews.ready?
        next Result.new(available: false, value: nil) unless MaterializedViews.compatible?(
          records: compatible, definitions: @definitions, dates: journey_dates, service: @service,
        )

        # Keep range reconciliation in memory without changing the pool's defaults.
        # This is per PostgreSQL operation, not a global or worker cache setting.
        SearchAnalyticsQueryResult.db.run("SET LOCAL work_mem = '32MB'")
        Result.new(available: true, value: build(compatible, present, journey_dates))
      end
    end

  private

    def build(compatible, present, dates)
      ids = compatible.reject { |row| PROJECTED.include?(row.name) }.map(&:id)
      frontend, backend = SearchAnalyticsQueryResult.where(id: ids).all.partition { |row| row.name == 'frontend_events' }
      results = (@required - PROJECTED).index_with do |name|
        backend.select { |row| row.name == name }.flat_map { |row| row.rows.to_a }
      end
      query_dates = @required.index_with do |name|
        present.select { |row| row.name == name }.map(&:reporting_date).uniq.sort
      end
      frontend_dates = compatible.select { |row| row.name == 'frontend_events' }.map(&:reporting_date)
      collected_dates = (present.map(&:reporting_date) + frontend_dates).uniq.sort
      projection = MaterializedProjection.new(
        service: @service,
        dates:,
        period: @period,
        costs: results.fetch('ai_cost_trend'),
        cost_fingerprint: @definitions.fetch('ai_cost_trend'),
        outcome_fingerprint: @definitions.fetch('journey_outcomes'),
        term_dates: (query_dates['search_term_improvements'] + query_dates['item_id_improvements']).uniq.sort,
        cost_dates: query_dates['ai_cost_trend'],
        term_fingerprints: @definitions.slice('item_id_improvements', 'search_term_improvements'),
      )
      payload = MaterializedAggregate.new(period: @period, results:, projection:, query_dates:).payload
      attach_outcomes(payload, projection, compatible, dates)
      payload['frontend_events'] = FrontendEvents.call(records: frontend, dates: @dates, supported: @service == 'uk' && @period.view != 'classic')
      payload['coverage'] = DailyResults.coverage(
        dates: @dates, collected_dates:, records: present, required: @required,
      )
      payload['summary_statuses']['searches'] = {
        'level' => 'neutral', 'message' => "#{collected_dates.size} of #{@dates.size} UTC days have stored results"
      }
      DailyResults.new(
        service: @service, period: @period.key, view: @period.view, bucket_size: @period.bucket_size,
        generated_at: (present + compatible.select { |row| row.name == 'frontend_events' }).map(&:collected_at).max,
        data_through: collected_dates.last.to_time(:utc) + 1.day, payload:
      )
    end

    def attach_outcomes(payload, projection, compatible, dates)
      collected = compatible.select { |row| row.name == 'journey_outcomes' && dates.include?(row.reporting_date) }.map(&:reporting_date).sort
      coverage = {
        'complete' => collected == dates,
        'expected_days' => dates.size,
        'collected_days' => collected.size,
        'missing_dates' => (dates - collected).map(&:iso8601),
      }
      outcomes = projection.outcomes(view: @period.view, buckets: payload.fetch('trends').fetch('volume').map { |row| row.fetch('bucket') }, coverage:)
      payload['trends']['outcomes'] = outcomes.fetch('trend')
      payload['journeys']['outcomes'] = outcomes.fetch('summary')
      payload['journeys']['question_counts'] = coverage.fetch('complete') ? projection.question_counts : []
      payload['availability']['journey_outcomes'] = coverage.fetch('complete')
      payload['availability']['journey_outcome_coverage'] = coverage
    end
  end
end
