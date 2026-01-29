module Api
  module Admin
    module GoodsNomenclatureLabels
      class StatsSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature_label_stats
        set_id { 'stats' }

        attributes :total_goods_nomenclatures,
                   :descriptions_count,
                   :known_brands_count,
                   :colloquial_terms_count,
                   :synonyms_count,
                   :ai_created_only,
                   :human_edited
      end
    end
  end
end
