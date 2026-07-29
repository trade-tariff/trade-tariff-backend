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

      def update_type
        :cds
      end
    end

    def clear_errors
      # CDS errors table has been dropped; nothing to clear.
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
  end
end
