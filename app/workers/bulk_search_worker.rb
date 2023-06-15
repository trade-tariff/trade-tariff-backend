class BulkSearchWorker
  include Sidekiq::Worker

  sidekiq_options queue: :bulk_search, retry: false

  delegate :redis, :v2_search_client, to: TradeTariffBackend

  def perform(id)
    Rails.logger.info("BulkSearchWorker: #{id} - #{BulkSearch.find(id)}")
    BulkSearchService.new(id).call
    Rails.logger.info("BulkSearchWorker: #{id} - #{BulkSearch.find(id)}")
  rescue StandardError => e
    BulkSearch.find(id).failed!

    Rails.logger.error(e)
  end
end
