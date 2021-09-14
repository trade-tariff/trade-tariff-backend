module TariffSynchronizer
  class CdsUpdate < BaseUpdate
    EMPTY_FILE_SIZE_THRESHOLD = 500

    class << self
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
      Raven.capture_message \
        "Empty CDS update - Issue Date: #{issue_date}: Applied: #{Time.zone.today}"
    end
  end
end
