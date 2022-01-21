require 'tariff_synchronizer/taric_file_name_generator'

module TariffSynchronizer
  # Download pending updates TARIC files
  class TaricUpdateDownloader
    delegate :instrument, :subscribe, to: ActiveSupport::Notifications

    attr_reader :date, :url

    def initialize(date)
      @generator = TaricFileNameGenerator.new(date)
      @date = date
      @url = @generator.url
    end

    def perform
      return if check_date_already_downloaded?

      log_request_to_taric_update
      send("create_record_for_#{response.state}_response")
    end

    private

    def response
      @response ||= TariffUpdatesRequester.perform(url)
    end

    def check_date_already_downloaded?
      TaricUpdate.find(issue_date: date).present?
    end

    def create_record_for_successful_response
      @generator.get_info_from_response(response.content).each do |update|
        TariffDownloader.new(update[:filename], update[:url], date, TariffSynchronizer::TaricUpdate).perform
      end
    end

    def create_record_for_empty_response
      update_or_create(BaseUpdate::FAILED_STATE, missing_filename)
      instrument('blank_update.tariff_synchronizer', date: date, url: url)
    end

    def create_record_for_exceeded_response
      update_or_create(BaseUpdate::FAILED_STATE, missing_filename)
      instrument('retry_exceeded.tariff_synchronizer', date: date, url: url,
                                                       response_content: response.content,
                                                       response_status: response.status)
    end

    # We do not create records for missing updates (see dynamic send method in perform)
    def create_record_for_not_found_response; end

    def missing_filename
      "#{date}_taric"
    end

    def update_or_create(state, file_name)
      TariffSynchronizer::TaricUpdate.find_or_create(filename: file_name, issue_date: date)
                                     .update(state: state)
    end

    def log_request_to_taric_update
      instrument('get_taric_update_name.tariff_synchronizer', date: date, url: url)
    end
  end
end
