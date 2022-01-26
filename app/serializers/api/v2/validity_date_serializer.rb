module Api
  module V2
    class ValidityDateSerializer
      include JSONAPI::Serializer

      set_type :validity_date
      set_id   :validity_date_id

      attributes :goods_nomenclature_item_id, :validity_start_date, :validity_end_date
    end
  end
end
