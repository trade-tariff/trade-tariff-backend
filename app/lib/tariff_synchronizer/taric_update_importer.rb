module TariffSynchronizer
  class TaricUpdateImporter
    def self.perform(taric_update)
      new(taric_update).import!
    end

    def initialize(taric_update)
      @taric_update = taric_update
    end

    def import!
      staging_manager = StagingManager.new
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @oplog_inserts = TaricImporter.new(@taric_update, staging_manager:).import
      # Atomically promote all staged rows into the real oplog tables.
      # This transaction is short: the data is already on disk in the UNLOGGED
      # staging tables, so it is just a bulk INSERT … SELECT per table.
      staging_manager.promote!

      check_oplog_inserts
      store_oplog_inserts
      @taric_update.mark_as_applied

      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
      Instrumentation.file_import_completed(filename: @taric_update.filename, duration_ms:)
    ensure
      # Drop staging tables whether the import succeeded or failed.
      # If promote! was never called (error during parsing), the real oplog
      # tables are untouched and no partial data is visible.
      staging_manager&.cleanup
    end

  private

    def check_oplog_inserts
      total_count = @oplog_inserts&.fetch(:total_count, 0).to_i
      return if total_count.positive?

      alert_potential_failed_import
    end

    def alert_potential_failed_import
      NewRelic::Agent.notice_error \
        "Empty TARIC update - Issue Date: #{@taric_update.issue_date}: Applied: #{Time.zone.today}"
    end

    def store_oplog_inserts
      @taric_update.inserts = @oplog_inserts.to_json
      @taric_update.save
    end
  end
end
