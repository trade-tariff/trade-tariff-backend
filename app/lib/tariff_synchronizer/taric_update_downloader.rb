module TariffSynchronizer
  # Download pending updates TARIC files
  class TaricUpdateDownloader
    delegate :taric_query_url_template, :taric_update_url_template, :host, to: TaricSynchronizer

    attr_reader :date, :url

    def initialize(date)
      @date = date
      @url = date_api_url
    end

    def perform
      return if check_date_already_downloaded?

      Instrumentation.file_import_started(filename: "taric_check_#{date.iso8601}")
      send("create_record_for_#{response.state}_response")
    end

    private

    def response
      @response ||= TariffUpdatesRequester.perform(date_api_url)
    end

    def check_date_already_downloaded?
      TaricUpdate.find(issue_date: date).present?
    end

    def create_record_for_successful_response
      file_api_urls.each do |update|
        TariffDownloader.new(update[:filename], update[:url], date, TariffSynchronizer::TaricUpdate).perform
      end
    end

    def create_record_for_empty_response
      update_or_create(BaseUpdate::FAILED_STATE, missing_filename)
      TariffLogger.blank_update(date:, url:)
    end

    def create_record_for_exceeded_response
      update_or_create(BaseUpdate::FAILED_STATE, missing_filename)
      TariffLogger.retry_exceeded(date, url)
    end

    # We do not create records for missing updates (see dynamic send method in perform)
    def create_record_for_not_found_response; end

    def missing_filename
      "#{date}_taric"
    end

    def update_or_create(state, file_name)
      TariffSynchronizer::TaricUpdate.find_or_create(filename: file_name,
                                                     issue_date: date)
        .update(state:)
    end

    def date_api_url
      sprintf(taric_query_url_template, host:, date: date.strftime('%Y%m%d'))
    end

    def file_api_urls
      response
        .content
        .split("\n")
        .map { |name| name.gsub(/[^0-9a-zA-Z.]/i, '') }
        .map { |name| { filename: "#{date}_#{name}", url: sprintf(taric_update_url_template, host:, filename: name) } }
    end
  end
end
