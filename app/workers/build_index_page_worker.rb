class BuildIndexPageWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  attr_reader :namespace

  def perform(index_namespace, model_name, page_number, page_size)
    @index_namespace = index_namespace
    client = Elasticsearch::Client.new
    model = model_name.constantize
    index = TradeTariffBackend.search_index_for(index_namespace, model)

    client.bulk(
      body: serialize_for(
        :index,
        index,
        index.dataset.paginate(page_number, page_size),
      ),
    )
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
