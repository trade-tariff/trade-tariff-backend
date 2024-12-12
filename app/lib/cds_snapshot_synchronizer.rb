class CdsSnapshotSynchronizer
  extend TariffSynchronizer

  class << self
    def download
      return Rails.logger.error 'Missing: Tariff sync enviroment variables: HMRC_API_HOST, HMRC_CLIENT_ID and HMRC_CLIENT_SECRET.' unless sync_variables_set?

      TradeTariffBackend.with_redis_lock do
        begin
          TariffSynchronizer::CdsSnapshotUpdate.sync(Time.zone.today)
        rescue TariffUpdatesRequester::DownloadException => e
          TariffLogger.failed_download(exception: e)
          raise e.original
        end
        Rails.logger.info 'Finished downloading updates'
      end
    end

    def apply
      # The sync task is run on multiple machines to avoid more than one process
      # running the apply task it is wrapped with a redis lock
      TradeTariffBackend.with_redis_lock do
        perform_update(CdsSnapshotUpdate, Time.zone.today)
      end
    rescue Redlock::LockError
      Rails.logger.warn 'Failed to acquire Redis lock for update application'
    end

    def sync_variables_set?
      ENV['HMRC_API_HOST'].present? && ENV['HMRC_CLIENT_ID'].present? && ENV['HMRC_CLIENT_SECRET'].present?
    end
  end
end
