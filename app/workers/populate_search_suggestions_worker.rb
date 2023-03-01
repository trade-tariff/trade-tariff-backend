class PopulateSearchSuggestionsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform
    logger.info 'Running PopulateSearchSuggestionsWorker for populating search suggestions'
    SearchSuggestionPopulatorService.new.call
    logger.info 'PopulateSearchSuggestionsWorker complete!'
  end
end
