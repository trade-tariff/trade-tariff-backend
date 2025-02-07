module TariffSynchronizer
  class CdsUpdate < BaseUpdate
    EMPTY_FILE_SIZE_THRESHOLD = 500
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

    def import!
      @oplog_inserts = CdsImporter.new(self).import

      check_oplog_inserts
      mark_as_applied
      store_oplog_inserts

      Rails.logger.info "Applied CDS update #{filename}"
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
      return if filesize <= EMPTY_FILE_SIZE_THRESHOLD
      return if @oplog_inserts[:total_count].positive?

      alert_potential_failed_import
    end

    def store_oplog_inserts
      self.inserts = @oplog_inserts.to_json

      save
    end

    def alert_potential_failed_import
      Sentry.capture_message \
        "Empty CDS update - Issue Date: #{issue_date}: Applied: #{Time.zone.today}"
    end
  end
end
