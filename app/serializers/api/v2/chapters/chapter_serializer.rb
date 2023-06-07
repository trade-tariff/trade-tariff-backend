module Api
  module V2
    module Chapters
      class ChapterSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :description,
                   :formatted_description,
                   :validity_start_date,
                   :validity_end_date,
                   :description_plain

        attribute :chapter_note, if: proc { |chapter| chapter.chapter_note.present? } do |chapter|
          chapter.chapter_note.content
        end

        attribute :forum_url do |chapter|
          chapter.forum_link&.url
        end

        attribute :section_id do |chapter|
          chapter.section.id
        end

        has_one :section, serializer: Api::V2::Chapters::SectionSerializer
        has_many :guides, serializer: Api::V2::GuideSerializer
        has_many :headings, serializer: Api::V2::Chapters::HeadingSerializer
      end
    end
  end
end
