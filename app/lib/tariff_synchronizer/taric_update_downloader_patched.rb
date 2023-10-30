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

      response = download(@update)

      # Download this years updates until we encounter a failure
      while response.success?
        @update = @update.next_update

        response = download(@update)
      end

      # Once we've exhausted this year's updates, try the next years - in most circumstances there will not be one
      download(@update.next_rollover_update)
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
        TaricSynchronizer.taric_update_url_template,
        host: TaricSynchronizer.host,
        filename: update.url_filename,
      )
    end
  end
end
