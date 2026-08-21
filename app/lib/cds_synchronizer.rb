module TariffSynchronizer
  class CdsSynchronizer
    extend TariffSynchronizer

    # 1 - does not raise exception during record save
    #   - logs cds error with xml node, record errors and exception
    cattr_accessor :cds_logger_enabled
    self.cds_logger_enabled = (ENV['TARIFF_CDS_LOGGER'].to_i == 1)

    # set initial update date
    # Initial dump date + 1 day
    cattr_accessor :initial_update_date
    self.initial_update_date = Date.new(2020, 9, 1)

    class << self
      def update_type
        TariffSynchronizer::CdsUpdate
      end

      def download
        TariffSynchronizer::CdsUpdateDownloader.download(initial_date: initial_update_date)
      end

      def apply
        apply_updates(CdsUpdate)
      end

      def rollback(rollback_date, keep: false)
        rollback_updates(CdsUpdate, rollback_date, keep:)
      end
    end
  end
end
