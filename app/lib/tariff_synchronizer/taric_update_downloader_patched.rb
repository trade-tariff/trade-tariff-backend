module TariffSynchronizer
  # Download pending updates TARIC files
  #
  # This behaves slighlty differently from the TaricUpdateDownloader in that it downloads updates based off of the
  # most recent update filename sequence.
  #
  # This should be removed once the Taric api responds correctly
  class TaricUpdateDownloaderPatched
    def initialize(update)
      @local_filename = update.filename
      @issue_date = update.issue_date
      @url_filename = update.url_filename
    end

    def perform
      return if check_file_already_downloaded?

      TariffDownloader.new(@local_filename, url, @issue_date, TariffSynchronizer::TaricUpdate).perform
    end

    private

    def check_file_already_downloaded?
      TaricUpdate.find(filename: @local_filename).present?
    end

    def url
      sprintf(
        TariffSynchronizer.taric_update_url_template,
        host: TariffSynchronizer.host,
        filename: @url_filename,
      )
    end
  end
end
