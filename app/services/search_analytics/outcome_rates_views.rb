# frozen_string_literal: true

module SearchAnalytics
  # Outcome-rate views are separate from the journey dashboard views. An
  # unpopulated outcome matview must not make the existing dashboard unready.
  class OutcomeRatesViews
    VERSION = 1
    SOURCE_NAMES = %w[frontend_events classic_outcomes].freeze
    MODELS = [
      GuidedOutcomeCount,
      QuestionOutcomeCount,
      ClassicOutcomeCount,
      OutcomeSourceRevision,
    ].freeze
    MATVIEWS = MODELS.map { |model| model.table_name.to_s }.freeze
    LOCK_NAMESPACE = 'search_analytics_outcome_rate_views'

    def self.ready? = new.ready?
    def self.refresh!(...) = new.refresh!(...)

    def ready?
      populated?
    end

    def refresh!(concurrently: true, wait: false, force: false, only_if_populated: false)
      if db.in_transaction?
        raise ArgumentError, 'Outcome rate view refresh must own its repeatable-read transaction'
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
        SELECT matview.relname, matview.relispopulated
        FROM pg_class matview
        JOIN pg_namespace namespace ON namespace.oid = matview.relnamespace
        WHERE namespace.nspname = current_schema()
          AND matview.relkind = 'm'
          AND matview.relname IN (#{names})
      SQL
      rows.size == MATVIEWS.size && rows.all? { |row| row.fetch(:relispopulated) }
    end

    def source_revisions_match_live?
      live_source_metadata == snapshot_source_metadata
    end

    def live_source_metadata
      SearchAnalyticsQueryResult
        .where(name: SOURCE_NAMES)
        .select(:id, :service, :reporting_date, :name, :fingerprint, :collected_at)
        .order(:service, :reporting_date, :name, :id)
        .all
        .map { |row| source_identity(row, VERSION) }
    end

    def snapshot_source_metadata
      OutcomeSourceRevision
        .select(:id, :service, :reporting_date, :name, :fingerprint, :collected_at, :definition_version)
        .order(:service, :reporting_date, :name, :id)
        .all
        .map { |row| source_identity(row, row[:definition_version]) }
    end

    def source_identity(row, version)
      [
        row[:id],
        row[:service],
        row[:reporting_date].to_date,
        row[:name],
        row[:fingerprint],
        row[:collected_at].utc.iso8601(6),
        version,
      ]
    end

    def refresh_matviews(concurrently:)
      MODELS.each { |model| model.refresh!(concurrently:) }
    end

    def apply_local_settings
      db.run("SET LOCAL TIME ZONE 'UTC'")
      db.run("SET LOCAL work_mem = '256MB'")
      db.run("SET LOCAL temp_file_limit = '4GB'")
      db.run("SET LOCAL statement_timeout = '15min'")
    end

    def lock_id
      Digest::SHA256.digest([LOCK_NAMESPACE, db.get(Sequel.function(:current_schema))].to_json).unpack1('q>')
    end

    def db = GuidedOutcomeCount.db
  end
end
