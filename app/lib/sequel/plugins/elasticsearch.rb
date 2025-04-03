# Index models in Elasticsearch after create/update and remove from index
# after destroy
module Sequel
  module Plugins
    module Elasticsearch
      def self.configure(model, options = {})
        index = options[:index] || Search.const_get("#{model}Index")
        if index == ''
          # this is a temporary fix to skip FullChemical looking for it's own index
          model.elasticsearch_indexes = []
        else
          model.elasticsearch_indexes = Array.wrap(index)
          model.elasticsearch_index = index.new
        end
      end

      module ClassMethods
        attr_accessor :elasticsearch_indexes, :elasticsearch_index
      end

      module InstanceMethods
        if Rails.env.test?
          def after_create
            super

            self.class.elasticsearch_indexes.each do |index_class|
              TradeTariffBackend.search_client.index(index_class, self)
            rescue ::OpenSearch::Transport::Transport::Errors::NotFound
              false
            end

            add_goods_nomenclature_index
          end

          def after_update
            super

            self.class.elasticsearch_indexes.each do |index_class|
              TradeTariffBackend.search_client.index(index_class, self)
            rescue ::OpenSearch::Transport::Transport::Errors::NotFound
              false
            end

            add_goods_nomenclature_index
          end

          def after_destroy
            super

            self.class.elasticsearch_indexes.each do |index_class|
              TradeTariffBackend.search_client.delete(index_class, self)
            rescue ::OpenSearch::Transport::Transport::Errors::NotFound
              false
            end

            delete_goods_nomenclature_index
          end

          private

          def add_goods_nomenclature_index
            index_name = Search::GoodsNomenclatureIndex.new.name

            if is_a?(GoodsNomenclature)
              TradeTariffBackend.search_client.index_by_name(index_name, id, Search::GoodsNomenclatureSerializer.new(self).as_json)
            elsif instance_of?(SearchReference)
              TradeTariffBackend.search_client.index_by_name(index_name, referenced.id, Search::GoodsNomenclatureSerializer.new(referenced.reload).as_json)
            elsif instance_of?(FullChemical) && goods_nomenclature.present?
              TradeTariffBackend.search_client.index_by_name(index_name, goods_nomenclature.id, Search::GoodsNomenclatureSerializer.new(goods_nomenclature.reload).as_json)
            end
          end

          def delete_goods_nomenclature_index
            index_name = Search::GoodsNomenclatureIndex.new.name

            if is_a?(GoodsNomenclature)
              TradeTariffBackend.search_client.delete_by_name(index_name, id)
            elsif instance_of?(SearchReference)
              TradeTariffBackend.search_client.index_by_name(index_name, referenced.id, Search::GoodsNomenclatureSerializer.new(referenced.reload).as_json)
            elsif instance_of?(FullChemical) && goods_nomenclature.present?
              TradeTariffBackend.search_client.index_by_name(index_name, goods_nomenclature.id, Search::GoodsNomenclatureSerializer.new(goods_nomenclature.reload).as_json)
            end
          end
        end
      end
    end
  end
end
