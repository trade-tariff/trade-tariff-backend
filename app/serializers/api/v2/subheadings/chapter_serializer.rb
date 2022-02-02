module Api
  module V2
    module Subheadings
      class ChapterSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :description, :formatted_description,
                   :chapter_note

        attribute :forum_url do |chapter|
          chapter.forum_link&.url
        end

        has_many :guides, serializer: Api::V2::GuideSerializer
      end
    end
  end
end
