module Api
  module V2
    class DeltasSerializer
      include JSONAPI::Serializer

      set_type :delta

      set_id :goods_nomenclature_sid

      attributes :goods_nomenclature_sid, :goods_nomenclature_item_id,
                 :productline_suffix, :end_line, :delta_type, :delta_date
    end
  end
end
