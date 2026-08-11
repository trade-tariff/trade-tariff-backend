module TariffSynchronizer
  class CdsUpdateImporter
    def self.perform(cds_update)
      new(cds_update).import!
    end

    def initialize(cds_update)
      @cds_update = cds_update
    end

    def import!
      staging_manager = CdsImporter::StagingManager.new
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      oplog_inserts = CdsImporter.new(@cds_update, staging_manager:).import

      staging_manager.promote!

      check_oplog_inserts(oplog_inserts)
      @cds_update.mark_as_applied
      store_oplog_inserts(oplog_inserts)

      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
      Instrumentation.file_import_completed(filename: @cds_update.filename, duration_ms:)
    ensure
      staging_manager&.cleanup
    end

  private

    def check_oplog_inserts(oplog_inserts)
      return if @cds_update.filesize <= TradeTariffBackend.empty_file_size_threshold
      return if oplog_inserts[:total_count].positive?

      alert_potential_failed_import
    end

    def store_oplog_inserts(oplog_inserts)
      @cds_update.inserts = oplog_inserts.to_json
      @cds_update.save
    end

    def alert_potential_failed_import
      NewRelic::Agent.notice_error \
        "Empty CDS update - Issue Date: #{@cds_update.issue_date}: Applied: #{Time.zone.today}"
    end
  end
end
