module Api
  module Admin
    module Headings
      class HeadingSerializer
        include JSONAPI::Serializer

        set_type :heading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id,
                   :description,
                   :search_references_count

        has_one :chapter, serializer: Api::Admin::Headings::ChapterSerializer

        has_many :commodities, serializer: Api::Admin::Headings::CommoditySerializer
      end
    end
  end
end
