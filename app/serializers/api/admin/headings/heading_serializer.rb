module Api
  module Admin
    module Headings
      class HeadingSerializer
        include JSONAPI::Serializer

        set_type :heading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :description

        attribute :search_references_count do |heading|
          heading.search_references.count
        end

        has_one :chapter, serializer: Api::Admin::Headings::ChapterSerializer, id_method_name: :goods_nomenclature_sid, &:chapter

        has_many :commodities, serializer: Api::Admin::Headings::CommoditySerializer, id_method_name: :admin_id, &:commodities
      end
    end
  end
end
