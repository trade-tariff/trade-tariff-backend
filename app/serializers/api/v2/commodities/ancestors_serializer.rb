module Api
  module V2
    module Commodities
      class AncestorsSerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :goods_nomenclature_sid

        attributes :producline_suffix, :description, :number_indents, :goods_nomenclature_item_id,
                   :formatted_description, :description_plain, :validity_start_date,
                   :validity_end_date
      end
    end
  end
end
