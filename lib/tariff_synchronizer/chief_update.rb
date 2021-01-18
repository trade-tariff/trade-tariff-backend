require 'csv'
module TariffSynchronizer
  class ChiefUpdate < BaseUpdate
    class << self
      def download(date)
        generator = ChiefFileNameGenerator.new(date)
        TariffDownloader.new(generator.name, generator.url, date, self).perform
      end

      def update_type
        :chief
      end
    end

    def import!
      instrument('apply_chief.tariff_synchronizer', filename: filename) do
        ChiefImporter.new(self).import
        mark_as_applied
      end

      ::ChiefTransformer.instance.invoke(:update, self)
    end

  private

    def self.validate_file!(cvs_string)
      begin
        CSV.parse(cvs_string)
      rescue CSV::MalformedCSVError => e
        raise InvalidContents.new(e.message, e)
      end
    end
  end
end
