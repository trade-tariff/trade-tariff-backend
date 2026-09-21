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
      return if backend_records.empty? && frontend_records.empty?

      # Each matching query contributes its own days. A missing or stale group is a
      # coverage gap for that widget, not a reason to hide the others. This path
      # never executes the collector or its cache fetch.
      collected_dates = (backend_records + frontend_records).map(&:reporting_date).uniq.sort
      query_dates = required.index_with do |name|
        backend_records.select { |row| row.name == name }.map(&:reporting_date).uniq.sort
      end
      results = required.index_with do |name|
        backend_records.select { |row| row.name == name }.flat_map { |row| row.rows.to_a }
      end
      payload = DailyAggregate.new(period:, results:, query_dates:).payload
      journey_dates = query_dates.fetch('search_journeys')
      outcomes = JourneyOutcomes.call(
        journeys: JourneyMetrics.new(rows: results.fetch('search_journeys'), period:),
        records: SearchAnalyticsQueryResult.where(service:, name: 'journey_outcomes', fingerprint: definitions.fetch('journey_outcomes')),
        dates: journey_dates, buckets: payload.fetch('trends').fetch('volume').map { |row| row.fetch('bucket') }
      )
      payload['trends']['outcomes'] = outcomes.fetch('trend')
      payload['journeys']['outcomes'] = outcomes.fetch('summary')
      payload['journeys']['question_counts'] = outcomes.fetch('question_counts')
      payload['availability']['journey_outcomes'] = outcomes.dig('coverage', 'complete')
      payload['availability']['journey_outcome_coverage'] = outcomes.fetch('coverage')
      payload['frontend_events'] = FrontendEvents.call(
        records: frontend_records, dates:,
        supported: service == 'uk' && period.view != 'classic'
      )
      payload['coverage'] = coverage(dates:, collected_dates:, records: backend_records, required:)
      payload['summary_statuses']['searches'] = {
        'level' => 'neutral', 'message' => "#{collected_dates.size} of #{dates.size} UTC days have stored results"
      }
      new(
        service:, period: period.key, view: period.view, bucket_size: period.bucket_size,
        generated_at: (backend_records + frontend_records).map(&:collected_at).max,
        data_through: collected_dates.last.to_time(:utc) + 1.day, payload:
      )
    end

    def self.coverage(dates:, collected_dates:, records:, required:)
      present = records.group_by(&:name).transform_values { |rows| rows.map(&:reporting_date).uniq.sort }
      queries = required.index_with do |name|
        got = present.fetch(name, [])
        missing = dates - got
        {
          'collected_days' => got.size,
          'collected_dates' => got.map(&:iso8601),
          'missing_dates' => missing.map(&:iso8601),
          'complete' => missing.empty?,
        }
      end
      {
        'from' => dates.first.iso8601,
        'to' => dates.last.iso8601,
        'expected_days' => dates.size,
        'collected_days' => collected_dates.size,
        'collected_dates' => collected_dates.map(&:iso8601),
        'missing_dates' => (dates - collected_dates).map(&:iso8601),
        'complete' => queries.values.all? { |row| row.fetch('complete') },
        'queries' => queries,
      }
    end
  end
end
