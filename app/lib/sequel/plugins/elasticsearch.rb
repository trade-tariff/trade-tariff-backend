# Index models in Elasticsearch after create/update and remove from index
# after destroy
module Sequel
  module Plugins
    module Elasticsearch
      def self.configure(model, options = {})
        index = options[:index] || Search.const_get("#{model}Index")
        model.elasticsearch_indexes = Array.wrap(index)
      end

      module ClassMethods
        attr_accessor :elasticsearch_indexes
      end

      module InstanceMethods
        def after_create
          super

          self.class.elasticsearch_indexes.each do |index_class|
            TradeTariffBackend.search_client.index(index_class, self)
          rescue ::Elasticsearch::Transport::Transport::Errors::NotFound
            false
          end
        end

        def after_update
          super

          self.class.elasticsearch_indexes.each do |index_class|
            TradeTariffBackend.search_client.index(index_class, self)
          rescue ::Elasticsearch::Transport::Transport::Errors::NotFound
            false
          end
        end

        def after_destroy
          super

          self.class.elasticsearch_indexes.each do |index_class|
            TradeTariffBackend.search_client.delete(index_class, self)
          rescue ::Elasticsearch::Transport::Transport::Errors::NotFound
            false
          end
        end
      end
    end
  end
end
