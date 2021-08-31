class BuildIndexPageWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  attr_reader :namespace

  def perform(namespace, model_name, page_number, page_size)
    @namespace = namespace
    client = Elasticsearch::Client.new
    model = model_name.constantize
    index = TradeTariffBackend.search_index_for(namespace, model)

    client.bulk(
      body: serialize_for(
        :index,
        index,
        model.dataset.paginate(page_number, page_size)
      )
    )
  end

  private

  def serialize_for(operation, index, entries)
    entries.each_with_object([]) do |model, memo|
      memo.push(
        operation => {
          _index: index.name,
          _id: model.id,
          data: TradeTariffBackend.model_serializer_for(namespace, index.model).new(model).as_json
        }
      )
    end
  end
end
