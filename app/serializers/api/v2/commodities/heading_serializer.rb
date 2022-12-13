module Api
  module V2
    module Commodities
      class HeadingSerializer
        include JSONAPI::Serializer

        set_type :heading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :description, :formatted_description,
                   :description_plain, :validity_start_date, :validity_end_date
      end
    end
  end
end
