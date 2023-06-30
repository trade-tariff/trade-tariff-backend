class BuildIndexByHeadingWorker
  class IndexingError < StandardError; end

  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  delegate :opensearch_client, to: TradeTariffBackend

  def perform(index_namespace, index_name, heading_sid)
    # TOOD: Implement me
  end
end
