module TariffSynchronizer
  class CdsSnapshotUpdate < BaseUpdate
    class << self
      def sync(date)
        download(date)
      end

      def download(date)
        CdsSnapshotDownloader.new(date).perform
      end

      def update_type
        :cds_snapshot
      end
    end

    def import!
      CdsSnapshotImporter.new(self).import
      mark_as_applied

      Rails.logger.info "Applied CDS snapshot #{filename}"
    end
  end
end
