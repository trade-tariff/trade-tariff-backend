module Api
  module Admin
    module GoodsNomenclatureLabels
      class StatsSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature_label_stats
        set_id { 'stats' }

        attributes :total_labels,
                   :with_description,
                   :with_known_brands,
                   :with_colloquial_terms,
                   :with_synonyms,
                   :ai_created_only,
                   :human_edited
      end
    end
  end
end
