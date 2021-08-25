module Api
  module Admin
    module SearchReferences
      class HeadingSerializer
        include JSONAPI::Serializer

        set_type :heading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :validity_start_date,
                   :validity_end_date, :description

        has_one :section, serializer: Api::Admin::SearchReferences::SectionSerializer
        has_one :chapter, serializer: Api::Admin::SearchReferences::ChapterSerializer
      end
    end
  end
end
