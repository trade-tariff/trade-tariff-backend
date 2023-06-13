class BuildIndexPageWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  delegate :opensearch_client, to: TradeTariffBackend

  def perform(index_namespace, index_name, page_number, _page_size = nil)
    ::SequelRails::Railties::LogSubscriber.reset_count

    index_name = "#{index_name}Index" unless index_name.ends_with?('Index')
    index = "#{index_namespace.camelize}::#{index_name}".constantize.new
    entries = index.dataset_page(page_number)

    return true if entries.empty?

    opensearch_client.bulk(
      body: serialize_for(:index, index, entries),
    )

    Rails.logger.info("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
  end

  private

  def serialize_for(operation, index, entries)
    entries.each_with_object([]) do |model, memo|
      memo.push(
        operation => {
          _index: index.name,
          _id: model.id,
          data: index.serialize_record(model),
        },
      )
    end
  end
end
