# frozen_string_literal: true

module SearchAnalytics
  class DailyResults < Data.define(:service, :period, :view, :bucket_size, :generated_at, :data_through, :payload)
    def self.call(period:, region:, log_group_name: DailyQuery::SEARCH_LOG_GROUP_NAME, date_range: nil, now: Time.current)
      projected = MaterializedResult.call(period:, region:, log_group_name:, date_range:, now:)
      return projected.value if projected.available

      legacy_call(period:, region:, log_group_name:, date_range:, now:)
    end

    def self.legacy_call(period:, region:, log_group_name: DailyQuery::SEARCH_LOG_GROUP_NAME, date_range: nil, now: Time.current)
      if date_range
        date_range = DateRange.parse(from: date_range.from.iso8601, to: date_range.to.iso8601, now:)
        period = Period.for_range(date_range:, view: period.view)
      end
      last_date = now.utc.to_date - 1
      dates = date_range ? date_range.dates : ((last_date - (period.duration / 1.day).to_i + 1)..last_date).to_a
      service = TradeTariffBackend.service
      definitions = DailyQuery.new(reporting_date: dates.first, region:, log_group_name:, now:).fingerprints
      # Costs describe activity inside the selected UTC dates, not the lifetime
      # cost of a journey. Later calls belong to their own reporting dates.
      records = SearchAnalyticsQueryResult.where(service:, reporting_date: dates, name: definitions.keys - %w[journey_outcomes]).all
      compatible = records.select { |row| row.fingerprint == definitions.fetch(row.name) }
      frontend_records, backend_records = compatible.partition { |row| row.name == 'frontend_events' }
      required = definitions.keys - %w[frontend_events journey_outcomes]
      complete = backend_records.group_by(&:reporting_date).select { |_date, rows| rows.map(&:name).sort == required.sort }
      return if complete.empty?

      # Only full compatible days contribute; a failed query is a coverage gap,
      # not a zero value. This path never executes the collector or its cache fetch.
      collected_dates = complete.keys.sort
      rows = complete.values.flatten
      results = required.index_with do |name|
        rows.select { |row| row.name == name }.flat_map { |row| row.rows.to_a }
      end
      payload = DailyAggregate.new(period:, results:).payload
      outcomes = JourneyOutcomes.call(
        journeys: JourneyMetrics.new(rows: results.fetch('search_journeys'), period:),
        records: SearchAnalyticsQueryResult.where(service:, name: 'journey_outcomes', fingerprint: definitions.fetch('journey_outcomes')),
        dates: collected_dates, buckets: payload.fetch('trends').fetch('volume').map { |row| row.fetch('bucket') }
      )
      payload['trends']['outcomes'] = outcomes.fetch('trend')
      payload['journeys']['outcomes'] = outcomes.fetch('summary')
      payload['availability']['journey_outcomes'] = outcomes.dig('coverage', 'complete')
      payload['availability']['journey_outcome_coverage'] = outcomes.fetch('coverage')
      payload['frontend_events'] = FrontendEvents.call(
        records: frontend_records.select { |row| collected_dates.include?(row.reporting_date) }, dates:,
        supported: service == 'uk' && period.view != 'classic'
      )
      missing = dates - collected_dates
      payload['coverage'] = {
        'from' => dates.first.iso8601,
        'to' => dates.last.iso8601,
        'expected_days' => dates.size,
        'collected_days' => collected_dates.size,
        'collected_dates' => collected_dates.map(&:iso8601),
        'missing_dates' => missing.map(&:iso8601),
        'complete' => missing.empty?,
      }
      payload['summary_statuses']['searches'] = {
        'level' => 'neutral', 'message' => "#{collected_dates.size} of #{dates.size} complete UTC days collected"
      }
      new(
        service:, period: period.key, view: period.view, bucket_size: period.bucket_size,
        generated_at: rows.map(&:collected_at).max,
        data_through: collected_dates.last.to_time(:utc) + 1.day, payload:
      )
    end
  end
end
