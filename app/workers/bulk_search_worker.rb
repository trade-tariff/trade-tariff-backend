class BulkSearchWorker
  include Sidekiq::Worker

  sidekiq_options queue: :bulk_search, retry: false

  delegate :redis, :v2_search_client, to: TradeTariffBackend

  def perform(id)
    Rails.logger.info("BulkSearchWorker: #{id} - #{BulkSearch.find(id)}")
    BulkSearchService.new(id).call
    Rails.logger.info("BulkSearchWorker: #{id} - #{BulkSearch.find(id)}")
  rescue StandardError => e
    update_status(id, :error)

    Rails.logger.error(e)
  end

  private

  def update_status(id, status)
    result = BulkSearch.find(id)
    result.status = status

    redis.set(
      result.id,
      Zlib::Deflate.deflate(result.to_json),
      ex: BulkSearch::TWO_HOURS,
    )
  end
end


