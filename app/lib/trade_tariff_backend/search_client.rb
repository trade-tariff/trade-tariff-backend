require 'hashie'

module TradeTariffBackend
  class SearchClient < SimpleDelegator
    # Raised if Elasticsearch returns an error from query
    QueryError = Class.new(StandardError)

    class Response < Hashie::Mash
      disable_warnings

      # Need to wrap object in array because serializer gem does Array(obj) and it breaks Hashie::Mash object
      # See changes https://github.com/jsonapi-serializer/jsonapi-serializer/commit/f62a5bf1622fd2da0278e2fef0e8d4342b97e7cc
      def to_a
        Array.wrap(self)
      end
    end

    attr_reader :indexed_models
    attr_reader :index_page_size
    attr_reader :search_operation_options
    attr_reader :namespace

    delegate :search_index_for, to: TradeTariffBackend

    def initialize(search_client, options = {})
      @indexed_models = options.fetch(:indexed_models, [])
      @index_page_size = options.fetch(:index_page_size, 1000)
      @search_operation_options = options.fetch(:search_operation_options, {})
      @namespace = options.fetch(:namespace, 'search')

      super(search_client)
    end

    def search(*)
      Response.new(super)
    end

    def msearch(*)
      Response.new(super)
    end

    def reindex
      indexed_models.each do |model|
        search_index_for(namespace, model).tap do |index|
          drop_index(index)
          create_index(index)
          build_index(model)
        end
      end
    end

    def update
      indexed_models.each do |model|
        search_index_for(namespace, model).tap do |index|
          create_index(index)
          build_index(model)
        end
      end
    end

    def create_index(index)
      indices.create(index: index.name, body: index.definition) unless indices.exists(index: index.name)
    end

    def drop_index(index)
      indices.delete(index: index.name) if indices.exists(index: index.name)
    end

    def build_index(model)
      total_pages = (model.dataset.count / index_page_size.to_f).ceil
      (1..total_pages).each do |page_number|
        BuildIndexPageWorker.perform_async(namespace, model.to_s, page_number, index_page_size)
      end
    end

    def index(model)
      search_index_for(namespace, model.class).tap do |model_index|
        super({
          index: model_index.name,
          id: model.id,
          body: TradeTariffBackend.model_serializer_for(namespace, model_index.model).new(model).as_json
        }.merge(search_operation_options))
      end
    end

    def delete(model)
      search_index_for(namespace, model.class).tap do |model_index|
        super({
          index: model_index.name,
          id: model.id
        }.merge(search_operation_options))
      end
    end
  end
end
