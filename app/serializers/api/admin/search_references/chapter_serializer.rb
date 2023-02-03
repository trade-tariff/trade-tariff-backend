module Api
  module Admin
    module SearchReferences
      class ChapterSerializer
        include JSONAPI::Serializer
        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id,
                   :validity_start_date,
                   :validity_end_date,
                   :description

        has_one :section, serializer: Api::Admin::SearchReferences::SectionSerializer
      end
    end
  end
end
