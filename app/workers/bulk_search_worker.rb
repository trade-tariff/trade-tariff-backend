class BulkSearchWorker
  include Sidekiq::Worker

  sidekiq_options queue: :bulk_search, retry: false

  delegate :redis, :v2_search_client, to: TradeTariffBackend

  def perform(id)
    BulkSearchService.new(id).call
  rescue StandardError
    BulkSearch::ResultCollection.find(id).failed!

    raise
  end
end
