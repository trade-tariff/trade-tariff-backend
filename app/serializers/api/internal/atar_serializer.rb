module Api
  module Internal
    class AtarSerializer
      include JSONAPI::Serializer

      set_type :atar
      set_id :ref

      attributes :ref,
                 :commodity_code,
                 :goods_nomenclature_item_id,
                 :description,
                 :justification,
                 :keywords,
                 :validity_start_date,
                 :validity_end_date,
                 :source_url,
                 :fetched_at,
                 :updated_at
    end
  end
end
