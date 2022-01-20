module TariffSynchronizer
  class CdsUpdate < BaseUpdate
    EMPTY_FILE_SIZE_THRESHOLD = 500
    REGEX_CDS_SEQUENCE = /^tariff_dailyExtract_v1_(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})T\d+\.gzip$/

    class << self
      def correct_recent_filename_sequence?
        pending_seq = last_pending&.filename_sequence
        applied_seq = last_applied&.filename_sequence

        return true if pending_seq.blank? || applied_seq.blank?

        pending_seq == applied_seq + 1.day
      end

      def download(date)
        CdsUpdateDownloader.new(date).perform
      end

      def update_type
        :cds
      end
    end

    attr_reader :oplog_inserts

    def import!
      instrument('apply_cds.tariff_synchronizer', filename: filename) do
        @oplog_inserts = CdsImporter.new(self).import
        check_oplog_inserts
        mark_as_applied
      end
    end

    # Extract Date from filename
    def filename_sequence
      sequence_date = filename&.match(REGEX_CDS_SEQUENCE)
                              &.captures
                              &.map(&:to_i) # [yyyy, mm, dd]

      Date.new(*sequence_date)
    end

    private

    def self.validate_file!(_gzip_string)
      true
    end

    def check_oplog_inserts
      return if filesize <= EMPTY_FILE_SIZE_THRESHOLD
      return if oplog_inserts.values.sum > 0

      alert_potential_failed_import
    end

    def alert_potential_failed_import
      Sentry.capture_message \
        "Empty CDS update - Issue Date: #{issue_date}: Applied: #{Time.zone.today}"
    end
  end
end
