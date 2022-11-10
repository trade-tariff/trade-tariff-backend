module Api
  module V2
    module Sections
      class ChapterSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :headings_from,
                   :headings_to,
                   :description,
                   :formatted_description,
                   :validity_start_date,
                   :validity_end_date

        has_many :guides, serializer: Api::V2::GuideSerializer
      end
    end
  end
end
