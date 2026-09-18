# frozen_string_literal: true

module SearchAnalytics
  class MaterializedViews
    VERSION = 1
    SOURCE_NAMES = %w[search_journeys journey_outcomes].freeze
    MATVIEWS = %w[
      search_analytics_daily_journeys
      search_analytics_repeated_journeys
      search_analytics_journey_rollup_totals
      search_analytics_source_revisions
    ].freeze
    LOCK_NAMESPACE = 'search_analytics_materialized_views'

    def self.ready? = new.ready?
    def self.compatible?(...) = new.compatible?(...)
    def self.refresh!(...) = new.refresh!(...)

    def ready?
      populated?
    end

    def compatible?(records:, definitions:, dates:, service:)
      return false unless ready?

      snapshot = source_revisions_dataset.where(service:).all
      return false if snapshot.any? { |row| row.fetch(:definition_version) != VERSION }

      current = lambda { |row|
        dates.include?(reporting_date(row)) && row[:fingerprint] == definitions[source_name(row)]
      }
      live = records.select { |row| row[:service] == service && SOURCE_NAMES.include?(source_name(row)) && current.call(row) }
      expected = snapshot.select(&current).map { |row| source_identity(row, row[:definition_version]) }
      live.map { |row| source_identity(row, VERSION) }.sort == expected.sort
    end

    def refresh!(concurrently: true, wait: false, force: false, only_if_populated: false)
      if db.in_transaction?
        raise ArgumentError, 'Materialized view refresh must own its repeatable-read transaction'
      end

      db.with_advisory_lock(lock_id, wait:) do
        populated = populated?
        next false if only_if_populated && !populated

        db.transaction(isolation: :repeatable) do
          if !force && populated && source_revisions_match_live?
            false
          else
            apply_local_settings
            refresh_matviews(concurrently: concurrently && populated)
            true
          end
        end
      end
    end

  private

    def populated?
      names = MATVIEWS.map { |name| db.literal(name) }.join(', ')
      rows = db.fetch(<<~SQL).all
        SELECT c.relname, c.relispopulated
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = current_schema()
          AND c.relkind = 'm'
          AND c.relname IN (#{names})
      SQL
      rows.size == MATVIEWS.size && rows.all? { |row| row.fetch(:relispopulated) }
    end

    def source_revisions_match_live?
      live_source_metadata == snapshot_source_metadata
    end

    def live_source_metadata
      db[:search_analytics_query_results]
        .where(name: SOURCE_NAMES)
        .select(:id, :service, :reporting_date, :name, :fingerprint, :collected_at)
        .order(:service, :reporting_date, :name, :id)
        .all
        .map { |row| source_identity(row, VERSION) }
    end

    def snapshot_source_metadata
      source_revisions_dataset
        .select(:id, :service, :reporting_date, :name, :fingerprint, :collected_at, :definition_version)
        .order(:service, :reporting_date, :name, :id)
        .all
        .map { |row| source_identity(row, row[:definition_version]) }
    end

    def source_revisions_dataset
      db[:search_analytics_source_revisions]
    end

    def source_identity(row, version = row[:definition_version])
      [
        row[:id],
        row[:service],
        reporting_date(row),
        source_name(row),
        row[:fingerprint],
        collected_at(row),
        version,
      ]
    end

    def source_name(row) = row[:name]
    def reporting_date(row) = row[:reporting_date].to_date
    def collected_at(row) = row[:collected_at].utc.iso8601(6)

    def refresh_matviews(concurrently:)
      keyword = concurrently ? ' CONCURRENTLY' : ''
      MATVIEWS.each do |name|
        db.run("REFRESH MATERIALIZED VIEW#{keyword} #{name}")
      end
    end

    def apply_local_settings
      db.run("SET LOCAL TIME ZONE 'UTC'")
      db.run("SET LOCAL work_mem = '64MB'")
      db.run("SET LOCAL temp_file_limit = '4GB'")
      db.run("SET LOCAL statement_timeout = '120s'")
    end

    def lock_id
      Digest::SHA256.digest([LOCK_NAMESPACE, db.get(Sequel.function(:current_schema))].to_json).unpack1('q>')
    end

    def db = SearchAnalyticsQueryResult.db
  end
end
