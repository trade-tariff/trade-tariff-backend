module TariffSynchronizer
  class TaricUpdate < BaseUpdate
    class << self
      def download(date)
        TaricUpdateDownloader.new(date).perform
      end

      def update_type
        :taric
      end
    end

    def import!
      instrument('apply_taric.tariff_synchronizer', filename: filename) do
        TaricImporter.new(self).import
        mark_as_applied
      end
    end

  private

    def self.validate_file!(xml_string)
      Ox.parse(xml_string)
    rescue Ox::ParseError => e
      raise InvalidContents.new(e.message, e)
    end
  end
end
