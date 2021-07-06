module Api
  module V2
    class ChangesSerializer
      include JSONAPI::Serializer

      set_type :change

      set_id :goods_nomenclature_sid

      attributes :goods_nomenclature_sid, :goods_nomenclature_item_id,
                 :productline_suffix, :end_line, :change_type, :change_date
    end
  end
end
