class BuildIndexByHeadingWorker
  class IndexingError < StandardError; end

  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  delegate :opensearch_client, to: TradeTariffBackend

  def perform(index_name, heading_short_code)
    index = index_name.constantize.new
    index.apply_constraints do
      entries = index.dataset_heading(heading_short_code)

      return true if entries.empty?

      opensearch_client.bulk(
        body: serialize_for(:index, index, entries),
      )
    end
  rescue StandardError
    raise IndexingError, "Failed building index: #{index_name} - heading #{heading_short_code}"
  end

  private

  def serialize_for(operation, index, entries)
    entries.each_with_object([]) do |serializable, memo|
      memo.push(
        operation => {
          _index: index.name,
          _id: serializable.id,
          data: index.serialize_record(serializable),
        },
      )
    end
  end
end
