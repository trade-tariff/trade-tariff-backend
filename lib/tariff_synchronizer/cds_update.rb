module TariffSynchronizer
  class CdsUpdate < BaseUpdate
    class << self
      def download(date)
        CdsUpdateDownloader.new(date).perform
      end

      def update_type
        :cds
      end
    end

    def import!
      instrument('apply_cds.tariff_synchronizer', filename: filename) do
        CdsImporter.new(self).import
        mark_as_applied
      end
    end

    private

    def self.validate_file!(_gzip_string)
      true
    end
  end
end
