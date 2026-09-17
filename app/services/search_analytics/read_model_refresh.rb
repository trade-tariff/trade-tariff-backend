# frozen_string_literal: true

module SearchAnalytics
  class ReadModelRefresh
    SQL_DIR = Pathname.new(__dir__).join('sql')
    LOCK_NAMESPACE = 'search_analytics_read_model'

    def self.call(...) = new(...).call

    def initialize(region:, from: nil, to: nil, now: Time.current, log_group_name: DailyQuery::SEARCH_LOG_GROUP_NAME)
      raise ArgumentError, 'Region must be explicit' if region.blank?

      @region = region
      @now = now
      @log_group_name = log_group_name
      @explicit_range = !from.nil? || !to.nil?
      @dates = dates_for(from:, to:)
    end

    def call
      if db.in_transaction?
        raise ArgumentError, 'Read model rebuild must own its repeatable-read transaction'
      end

      service = TradeTariffBackend.service
      db.with_advisory_lock(lock_id(service)) do
        db.transaction(isolation: :repeatable) do
          definitions = DailyQuery.new(reporting_date: @dates.last, region: @region, log_group_name: @log_group_name, now: @now).fingerprints
          records = source_records(service, definitions)
          latest = SearchAnalyticsReadModel.latest(service:, region: @region)
          if latest&.compatible?(records:, definitions:, dates: @dates)
            latest
          else
            prevent_narrowing(latest)
            apply_local_settings
            build(service:, definitions:, records:)
          end
        end
      end
    end

  private

    def dates_for(from:, to:)
      return default_dates if from.nil? && to.nil?
      raise DateRange::InvalidRange, 'Enter both From and To dates in YYYY-MM-DD format.' if from.nil? || to.nil?

      DateRange.parse(from: iso_date(from), to: iso_date(to), now: @now).dates
    end

    def default_dates
      last = @now.utc.to_date - 1
      ((last - (DateRange::MAX_DAYS - 1))..last).to_a
    end

    def iso_date(value) = value.is_a?(Date) ? value.iso8601 : value

    def source_records(service, definitions)
      SearchAnalyticsQueryResult
        .where(service:, reporting_date: @dates, name: SearchAnalyticsReadModel::SOURCE_NAMES)
        .select(:id, :service, :reporting_date, :name, :fingerprint, :collected_at)
        .all
        .select { |record| record.fingerprint == definitions.fetch(record.name) }
    end

    def prevent_narrowing(latest)
      return unless @explicit_range && latest
      return if (latest.source_versions.keys - @dates.map(&:iso8601)).empty?

      raise DateRange::InvalidRange, 'Include all existing read-model dates or use the default rebuild window.'
    end

    def build(service:, definitions:, records:)
      fingerprints = definitions.slice(*SearchAnalyticsReadModel::SOURCE_NAMES)
      model = SearchAnalyticsReadModel.create(
        service:,
        region: @region,
        version: SearchAnalyticsReadModel::VERSION,
        fingerprints: Sequel.pg_jsonb(fingerprints),
        source_versions: Sequel.pg_jsonb(SearchAnalyticsReadModel.versions(records)),
        built_at: @now,
      )
      dates_with_rows = records.map(&:reporting_date).uniq.sort
      dates_with_rows.each { |date| run_sql('journey_days', sql_binds(model, fingerprints, date)) }
      run_sql('keys', read_model_id: model.id) if dates_with_rows.any?
      dates_with_rows.each do |date|
        binds = sql_binds(model, fingerprints, date)
        run_sql('rollups', binds)
        run_sql('multi_day_observations', binds)
      end
      SearchAnalyticsReadModel.where(service:, region: @region).exclude(id: model.id).delete
      model
    end

    def sql_binds(model, fingerprints, date)
      {
        read_model_id: model.id,
        service: model.service,
        reporting_date: date,
        search_journeys_fingerprint: fingerprints.fetch('search_journeys'),
        journey_outcomes_fingerprint: fingerprints.fetch('journey_outcomes'),
      }
    end

    def run_sql(name, binds)
      sql = SQL_DIR.join("read_model_#{name}.sql").read.gsub(/\{\{(\w+)\}\}/) do
        db.literal(binds.fetch(Regexp.last_match(1).to_sym))
      end
      db.run(sql)
    end

    def apply_local_settings
      db.run("SET LOCAL TIME ZONE 'UTC'")
      db.run("SET LOCAL work_mem = '64MB'")
      # temp_file_limit requires a role that may SET it. Do not drop this bound.
      db.run("SET LOCAL temp_file_limit = '4GB'")
      db.run("SET LOCAL statement_timeout = '120s'")
    end

    def lock_id(service)
      Digest::SHA256.digest([LOCK_NAMESPACE, service].to_json).unpack1('q>')
    end

    def db = SearchAnalyticsReadModel.db
  end
end
