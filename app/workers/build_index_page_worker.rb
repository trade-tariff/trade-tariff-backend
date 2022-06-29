class BuildIndexPageWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform(index_namespace, index_name, page_number, page_size)
    client = Elasticsearch::Client.new
    index_name = "#{index_name}Index" unless index_name.ends_with?('Index')
    index = "#{index_namespace.camelize}::#{index_name}".constantize.new

    client.bulk(
      body: serialize_for(
        :index,
        index,
        index.dataset.eager(index.eager_load_graph).paginate(page_number, page_size),
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
