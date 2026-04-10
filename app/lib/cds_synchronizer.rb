class CdsSynchronizer
  extend TariffSynchronizer

  delegate :download_todays_file?, to: TariffSynchronizer::CdsUpdate

  # 1 - does not raise exception during record save
  #   - logs cds error with xml node, record errors and exception
  cattr_accessor :cds_logger_enabled
  self.cds_logger_enabled = (ENV['TARIFF_CDS_LOGGER'].to_i == 1)

  # set initial update date
  # Initial dump date + 1 day
  cattr_accessor :initial_update_date
  self.initial_update_date = Date.new(2020, 9, 1)

  class << self
    def download
      unless sync_variables_set?
        TariffSynchronizer::Instrumentation.sync_run_failed(
          phase: 'download',
          error_class: 'ConfigurationError',
          error_message: 'Missing: Tariff sync environment variables: HMRC_API_HOST, HMRC_CLIENT_ID and HMRC_CLIENT_SECRET.',
        )
        return
      end

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'download')

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        TariffSynchronizer::CdsUpdate.sync(initial_date: initial_update_date)

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        TariffSynchronizer::Instrumentation.download_completed(
          duration_ms:,
          files_count: TariffSynchronizer::CdsUpdate.pending.count,
        )
      end
    end

    def apply
      apply_updates(CdsUpdate)
    end

    def rollback(rollback_date, keep: false)
      rollback_updates(CdsUpdate, rollback_date, keep:)
    end

    def sync_variables_set?
      ENV['HMRC_API_HOST'].present? && ENV['HMRC_CLIENT_ID'].present? && ENV['HMRC_CLIENT_SECRET'].present?
    end
  end
end
