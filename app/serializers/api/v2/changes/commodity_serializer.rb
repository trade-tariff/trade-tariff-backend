module Api
  module V2
    module Changes
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :goods_nomenclature_sid

        attributes :description, :goods_nomenclature_item_id, :validity_start_date, :validity_end_date

        attribute :flibble do |commodity|
          "flooble"
        end
      end
    end
  end
end
