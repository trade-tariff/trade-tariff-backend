module TariffSynchronizer
  # Download pending updates TARIC files
  #
  # This behaves slighlty differently from the TaricUpdateDownloader in that it downloads updates based off of the
  # most recent update filename sequence and continues trying new updates until the api responds with not found.
  #
  # This should be removed once the Taric api responds correctly
  class TaricUpdateDownloaderPatched
    def initialize(update)
      @update = update
    end

    def perform
      return if update_exists?

      downloader = download(@update)

      while downloader.success?
        @update = @update.next_update

        downloader = download(@update)
      end
    end

    private

    def download(update)
      TariffDownloader.new(
        update.filename,
        url_for(update),
        update.issue_date,
        TariffSynchronizer::TaricUpdate,
      ).tap(&:perform)
    end

    def update_exists?
      TaricUpdate.find(filename: @update.filename).present?
    end

    def url_for(update)
      sprintf(
        TariffSynchronizer.taric_update_url_template,
        host: TariffSynchronizer.host,
        filename: update.url_filename,
      )
    end
  end
end
