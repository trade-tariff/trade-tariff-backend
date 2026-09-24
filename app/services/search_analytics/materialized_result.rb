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

        unless MaterializedViews.compatible?(records: compatible, definitions: @definitions, dates: journey_dates, service: @service)
          Rails.logger.warn({ message: 'search_analytics_materialized_views_stale', service: @service, dates: journey_dates.map(&:iso8601) })
          next Result.new(available: false, value: nil)
        end

        # Keep range reconciliation in memory without changing the pool's defaults.
        # This is per PostgreSQL operation, not a global or worker cache setting.
        SearchAnalyticsQueryResult.db.run("SET LOCAL work_mem = '32MB'")
        Result.new(available: true, value: build(compatible, present, journey_dates, metadata))
      end
    end

  private

    def build(compatible, present, dates, metadata)
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
        term_dates: (query_dates['search_term_improvements'] + query_dates['item_id_improvements']).uniq.sort,
        cost_dates: query_dates['ai_cost_trend'],
        term_fingerprints: @definitions.slice('item_id_improvements', 'search_term_improvements'),
      )
      payload = MaterializedAggregate.new(period: @period, results:, projection:, query_dates:).payload
      attach_outcomes(payload, projection, metadata, dates)
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

    def attach_outcomes(payload, projection, metadata, dates)
      stored = metadata.select { |row| row.name == 'journey_outcomes' && dates.include?(row.reporting_date) }
      collected = stored.map(&:reporting_date).uniq.sort
      current = stored.select { |row| row.fingerprint == @definitions.fetch('journey_outcomes') }.map(&:reporting_date).uniq.sort
      coverage = {
        'complete' => dates.any? && collected == dates,
        'expected_days' => dates.size,
        'collected_days' => collected.size,
        'missing_dates' => (dates - collected).map(&:iso8601),
      }
      buckets = payload.fetch('trends').fetch('volume').map { |row| row.fetch('bucket') }.select do |bucket|
        collected.include?(Time.find_zone!('UTC').parse(bucket).to_date)
      end
      outcomes = projection.outcomes(view: @period.view, buckets:, coverage:)
      payload['trends']['outcomes'] = outcomes.fetch('trend')
      payload['journeys']['outcomes'] = current == dates ? outcomes.fetch('summary') : nil
      payload['availability']['journey_outcomes'] = collected.any?
      payload['availability']['journey_outcome_coverage'] = coverage
    end
  end
end
