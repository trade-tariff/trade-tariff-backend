module Api
  module Beta
    class GoodsNomenclatureSerializer
      include JSONAPI::Serializer

      class << self
        def serializer_proc
          proc do |record, _params|
            if record.try(:goods_nomenclature_class)
              "Api::Beta::#{record.goods_nomenclature_class}Serializer".constantize
            else
              Api::Beta::GoodsNomenclatureSerializer
            end
          end
        end
      end

      set_type :goods_nomenclature

      attributes :goods_nomenclature_item_id,
                 :producline_suffix,
                 :formatted_description,
                 :description,
                 :description_indexed,
                 :search_references,
                 :validity_start_date,
                 :validity_end_date,
                 :chapter_id,
                 :score,
                 :declarable

      attribute :search_intercept_terms, if: ->(_) { TradeTariffBackend.beta_search_debug? }

      has_many :ancestors, lazy_load: true, serializer: serializer_proc
    end
  end
end
