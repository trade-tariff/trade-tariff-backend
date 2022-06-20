require 'hashie'

module TradeTariffBackend
  class SearchClient < SimpleDelegator
    # Raised if Elasticsearch returns an error from query
    QueryError = Class.new(StandardError)

    attr_reader :indexed_models,
                :index_page_size,
                :search_operation_options,
                :namespace

    delegate :search_index_for, to: TradeTariffBackend

    def initialize(search_client, options = {})
      @indexed_models = options.fetch(:indexed_models, [])
      @index_page_size = options.fetch(:index_page_size, 1000)
      @search_operation_options = options.fetch(:search_operation_options, {})
      @namespace = options.fetch(:namespace, 'search')

      super(search_client)
    end

    def search(*)
      Hashie::TariffMash.new(super)
    end

    def msearch(*)
      Hashie::TariffMash.new(super)
    end

    def reindex_all
      indexed_models.each(&method(:reindex))
    end

    def reindex(model)
      search_index_for(namespace, model).tap do |index|
        drop_index(index)
        create_index(index)
        build_index(index)
      end
    end

    def update_all
      indexed_models.each(&method(:update))
    end

    def update(model)
      search_index_for(namespace, model).tap do |index|
        create_index(index)
        build_index(index)
      end
    end

    def create_index(index)
      indices.create(index: index.name, body: index.definition) unless indices.exists(index: index.name)
    end

    def drop_index(index)
      indices.delete(index: index.name) if indices.exists(index: index.name)
    end

    def build_index(index)
      total_pages = (index.dataset.count / index_page_size.to_f).ceil
      (1..total_pages).each do |page_number|
        BuildIndexPageWorker.perform_async(namespace, index.model_class.to_s, page_number, index_page_size)
      end
    end

    def index(model)
      search_index_for(namespace, model.class).tap do |model_index|
        super({
          index: model_index.name,
          id: model.id,
          body: model_index.serialize_record(model).as_json,
        }.merge(search_operation_options))
      end
    end

    def delete(model)
      search_index_for(namespace, model.class).tap do |model_index|
        super({
          index: model_index.name,
          id: model.id,
        }.merge(search_operation_options))
      end
    end
  end
end
