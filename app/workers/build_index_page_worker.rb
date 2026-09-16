class BuildIndexPageWorker
  class IndexingError < StandardError; end

  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  delegate :opensearch_client, to: TradeTariffBackend

  def perform(index_namespace, index_name, page_number, _page_size = nil)
    index_name = "#{index_name}Index" unless index_name.ends_with?('Index')
    index = "#{index_namespace.camelize}::#{index_name}".constantize.new

    index.apply_constraints do
      entries = index.dataset_page(page_number)

      return true if entries.empty?

      response = opensearch_client.bulk(
        body: serialize_for(:index, index, entries),
      )

      # A `_bulk` request answers 200 even when individual documents were
      # rejected, so without this check a page that indexed nothing would
      # report success and leave the index silently short of commodities.
      TradeTariffBackend::BulkResponse.check!(response, "#{index_namespace}/#{index_name} page #{page_number}")
    end
  rescue TradeTariffBackend::BulkResponse::BulkError
    # Already carries the index, the page and the failed document ids, and its
    # class distinguishes transient rejections from permanent failures.
    raise
  rescue StandardError
    raise IndexingError, "Failed building index: #{index_namespace}/#{index_name} - page #{page_number}"
  end

private

  def serialize_for(operation, index, entries)
    entries.each_with_object([]) do |model, memo|
      memo.push(
        operation => {
          _index: index.name,
          _id: index.document_id(model),
          data: index.serialize_record(model),
        },
      )
    end
  end
end
