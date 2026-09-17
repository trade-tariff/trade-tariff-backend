# frozen_string_literal: true

module SearchAnalytics
  class ReadModelResult
    Result = Data.define(:available, :value)
    METADATA = %i[id name reporting_date fingerprint collected_at].freeze
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
      @region = region
      @definitions = DailyQuery.new(reporting_date: @dates.first, region:, log_group_name:, now:).fingerprints
      @required = @definitions.keys - %w[frontend_events journey_outcomes]
    end

    def call
      # An existing caller transaction may have a weaker isolation level. Keep
      # the legacy path rather than claiming a generation-pinned snapshot there.
      return Result.new(available: false, value: nil) if SearchAnalyticsQueryResult.db.in_transaction?

      # Pin source revisions and the generation together. A concurrent rebuild may
      # retire old rows, but MVCC keeps this request's generation visible.
      SearchAnalyticsQueryResult.db.transaction(isolation: :repeatable, read_only: true) do
        metadata = SearchAnalyticsQueryResult.where(service: @service, reporting_date: @dates, name: @definitions.keys).select(*METADATA).all
        compatible = metadata.select { |row| row.fingerprint == @definitions.fetch(row.name) }
        complete = compatible.select { |row| @required.include?(row.name) }.group_by(&:reporting_date).select do |_date, rows|
          rows.map(&:name).sort == @required.sort
        end
        next Result.new(available: true, value: nil) if complete.empty?

        dates = complete.keys.sort
        model = SearchAnalyticsReadModel.latest(service: @service, region: @region)
        next Result.new(available: false, value: nil) unless model&.compatible?(records: compatible, definitions: @definitions, dates:)

        # Keep range reconciliation in memory without changing the pool's defaults.
        # This is per PostgreSQL operation, not a global or worker cache setting.
        SearchAnalyticsQueryResult.db.run("SET LOCAL work_mem = '32MB'")
        Result.new(available: true, value: build(model, compatible, complete, dates))
      end
    end

  private

    def build(model, metadata, complete, dates)
      ids = metadata.reject { |row| PROJECTED.include?(row.name) }.select { |row| dates.include?(row.reporting_date) }.map(&:id)
      frontend, backend = SearchAnalyticsQueryResult.where(id: ids).all.partition { |row| row.name == 'frontend_events' }
      results = (@required - PROJECTED).index_with do |name|
        backend.select { |row| row.name == name }.flat_map { |row| row.rows.to_a }
      end
      projection = ReadModelProjection.new(model:, dates:, period: @period, costs: results.fetch('ai_cost_trend'))
      payload = ReadModelAggregate.new(period: @period, results:, projection:).payload
      attach_outcomes(payload, projection, metadata, dates)
      payload['frontend_events'] = FrontendEvents.call(records: frontend, dates: @dates, supported: @service == 'uk' && @period.view != 'classic')
      payload['coverage'] = {
        'from' => @dates.first.iso8601,
        'to' => @dates.last.iso8601,
        'expected_days' => @dates.size,
        'collected_days' => dates.size,
        'collected_dates' => dates.map(&:iso8601),
        'missing_dates' => (@dates - dates).map(&:iso8601),
        'complete' => dates == @dates,
      }
      payload['summary_statuses']['searches'] = {
        'level' => 'neutral', 'message' => "#{dates.size} of #{@dates.size} complete UTC days collected"
      }
      DailyResults.new(
        service: @service, period: @period.key, view: @period.view, bucket_size: @period.bucket_size,
        generated_at: complete.values.flatten.map(&:collected_at).max,
        data_through: dates.last.to_time(:utc) + 1.day, payload:
      )
    end

    def attach_outcomes(payload, projection, metadata, dates)
      collected = metadata.select { |row| row.name == 'journey_outcomes' && dates.include?(row.reporting_date) }.map(&:reporting_date).sort
      coverage = {
        'complete' => collected == dates,
        'expected_days' => dates.size,
        'collected_days' => collected.size,
        'missing_dates' => (dates - collected).map(&:iso8601),
      }
      outcomes = projection.outcomes(view: @period.view, buckets: payload.fetch('trends').fetch('volume').map { |row| row.fetch('bucket') }, coverage:)
      payload['trends']['outcomes'] = outcomes.fetch('trend')
      payload['journeys']['outcomes'] = outcomes.fetch('summary')
      payload['availability']['journey_outcomes'] = coverage.fetch('complete')
      payload['availability']['journey_outcome_coverage'] = coverage
    end
  end
end
