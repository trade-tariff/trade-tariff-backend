require_relative '../lib/self_text_generator/instrumentation'
require_relative '../lib/self_text_generator/logger'

class GenerateSelfTextReindexWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform
    SelfTextGenerator::Instrumentation.reindex_started

    index = Search::GoodsNomenclatureIndex.new
    update_search_index(index)

    SelfTextGenerator::Instrumentation.reindex_completed
  end

private

  def update_search_index(index) = TradeTariffBackend.search_client.update(index)
end
