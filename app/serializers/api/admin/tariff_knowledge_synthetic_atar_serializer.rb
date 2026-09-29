module Api
  module Admin
    class TariffKnowledgeSyntheticAtarSerializer
      include JSONAPI::Serializer

      set_type :tariff_knowledge_synthetic_atar

      attributes :chapter,
                 :real_user_search,
                 :times_searched,
                 :likely_heading,
                 :description,
                 :goods_nomenclature_item_id,
                 :notes,
                 :completed_by,
                 :created_at,
                 :updated_at
    end
  end
end
