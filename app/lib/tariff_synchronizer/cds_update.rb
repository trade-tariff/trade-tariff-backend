module TariffSynchronizer
  class CdsUpdate < BaseUpdate
    REGEX_CDS_SEQUENCE = /^tariff_dailyExtract_v1_(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})T\d+\.gzip$/

    class << self
      def correct_filename_sequence?
        pending_seq = oldest_pending&.filename_sequence
        applied_seq = most_recent_applied&.filename_sequence

        return true if pending_seq.blank? || applied_seq.blank?

        pending_seq == applied_seq + 1.day
      end

      def download(date)
        CdsUpdateDownloader.new(date).perform
      end

      def downloaded_todays_file?
        with_issue_date(Time.zone.yesterday).count.positive?
      end

      def update_type
        :cds
      end
    end

    def clear_errors
      # CDS errors table has been dropped; nothing to clear.
    end

    def import!
      staging_manager = CdsImporter::StagingManager.new
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @oplog_inserts = CdsImporter.new(self, staging_manager:).import

      # Atomically promote all staged rows into the real oplog tables.
      # This transaction is short: the data is already on disk in the UNLOGGED
      # staging tables, so it is just a bulk INSERT … SELECT per table.
      staging_manager.promote!

      check_oplog_inserts
      mark_as_applied
      store_oplog_inserts

      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
      Instrumentation.file_import_completed(filename:, duration_ms:)
    ensure
      # Drop staging tables whether the import succeeded or failed.
      # If promote! was never called (error during parsing), the real oplog
      # tables are untouched and no partial data is visible.
      staging_manager&.cleanup
    end

    # Extract Date from filename
    def filename_sequence
      sequence_date = filename&.match(REGEX_CDS_SEQUENCE)
                              &.captures
                              &.map(&:to_i) # [yyyy, mm, dd]

      Date.new(*sequence_date)
    end

    alias_method :file_date, :filename_sequence

    def to_param
      filename.sub('.gzip', '')
    end

    private

    def check_oplog_inserts
      return if filesize <= TradeTariffBackend.empty_file_size_threshold
      return if @oplog_inserts[:total_count].positive?

      alert_potential_failed_import
    end

    def store_oplog_inserts
      self.inserts = @oplog_inserts.to_json

      save
    end

    def alert_potential_failed_import
      NewRelic::Agent.notice_error \
        "Empty CDS update - Issue Date: #{issue_date}: Applied: #{Time.zone.today}"
    end
  end
end
