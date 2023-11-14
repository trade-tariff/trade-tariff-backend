module Api
  module V2
    module Commodities
      class ChapterSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :description, :formatted_description,
                   :validity_start_date, :validity_end_date

        attribute :chapter_note, if: proc { |chapter| chapter.chapter_note.present? } do |chapter|
          chapter.chapter_note.content
        end

        has_many :guides, serializer: Api::V2::GuideSerializer
      end
    end
  end
end
