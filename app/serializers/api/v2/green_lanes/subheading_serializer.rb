module Api
  module V2
    module GreenLanes
      class SubheadingSerializer
        include JSONAPI::Serializer

        set_type :subheading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :description,
                   :formatted_description,
                   :validity_start_date,
                   :validity_end_date,
                   :description_plain,
                   :producline_suffix
      end
    end
  end
end