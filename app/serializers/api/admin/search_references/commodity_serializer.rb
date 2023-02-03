module Api
  module Admin
    module SearchReferences
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id,
                   :validity_start_date,
                   :validity_end_date,
                   :description

        has_one :section, serializer: Api::Admin::SearchReferences::SectionSerializer
        has_one :chapter, serializer: Api::Admin::SearchReferences::ChapterSerializer
        has_one :heading, serializer: Api::Admin::SearchReferences::HeadingSerializer
      end
    end
  end
end
