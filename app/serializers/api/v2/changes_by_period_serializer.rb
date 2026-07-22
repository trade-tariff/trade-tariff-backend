module Api
  module V2
    class ChangesByPeriodSerializer
      include JSONAPI::Serializer

      set_type :change

      set_id :id

      attributes :goods_nomenclature_item_id,
                 :goods_nomenclature_sid,
                 :productline_suffix,
                 :end_line,
                 :change_type,
                 :change_date
    end
  end
end
