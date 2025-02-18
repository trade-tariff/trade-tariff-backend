require 'hashie'

module TradeTariffBackend
  class SearchClient < SimpleDelegator
    SEARCH_SERVER_CONFIG_FILE = Rails.root.join('config/elasticsearch_server_options.yml')

    # Raised if Elasticsearch returns an error from query
    QueryError = Class.new(StandardError)

    cattr_accessor :server_namespace, default: 'tariff'.freeze
    cattr_accessor :search_operation_options, default: {}

    attr_reader :indexes,
                :search_operation_options,
                :namespace

    def initialize(search_client, options = {})
      @indexes = options.fetch(:indexes, [])
      @search_operation_options = options.fetch(
        :search_operation_options,
        self.class.search_operation_options,
      )
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
      indexes.each(&method(:reindex))
    end

    def reindex(index)
      drop_index(index)
      create_index(index)
      build_index(index)
    end

    def update_all
      indexes.each(&method(:update))
    end

    def update(index)
      create_index(index)
      build_index(index)
    end

    def create_index(index)
      indices.create(index: index.name, body: index.definition) unless indices.exists(index: index.name)
    end

    def drop_index(index)
      indices.delete(index: index.name) if indices.exists(index: index.name)
    end

    def build_index(index)
      (1..index.total_pages).each do |page_number|
        BuildIndexPageWorker.perform_async(namespace, index.name_without_namespace, page_number)
      end
    end

    def index(index_class, model)
      model_index = index_class.new

      super({
        index: model_index.name,
        id: model.id,
        body: model_index.serialize_record(model).as_json,
      }.merge(search_operation_options))
    end

    def index_by_name(index_name, model_id, model_json)
      __getobj__.index({
        index: index_name,
        id: model_id,
        body: model_json,
      }.merge(search_operation_options))
    end

    def delete(index_class, model)
      super({
        index: index_class.new.name,
        id: model.id,
      }.merge(search_operation_options))
    end

    def delete_by_name(index_name, model_id)
      __getobj__.delete({
        index: index_name,
        id: model_id,
      }.merge(search_operation_options))
    end
  end
end
