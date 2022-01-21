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
      @generator = TaricFileNameGeneratorPatched.new(update.url_filename)
    end

    def perform
      return if check_file_already_downloaded?

      TariffDownloader.new(@local_filename, @generator.url, @issue_date, TariffSynchronizer::TaricUpdate).perform
    end

    private

    def check_file_already_downloaded?
      TaricUpdate.find(filename: @local_filename).present?
    end
  end
end
