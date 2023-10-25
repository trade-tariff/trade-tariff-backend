module Api
  module Admin
    module Chapters
      class ChapterSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :producline_suffix,
                   :headings_from,
                   :headings_to,
                   :description,
                   :section_id

        attribute :chapter_note_id do |chapter|
          chapter.chapter_note.try(:id)
        end

        attribute :section_id do |chapter|
          chapter.section.id
        end

        has_one :chapter_note, serializer: Api::Admin::Chapters::ChapterNoteSerializer, id_method_name: :id, &:chapter_note
        has_many :headings, serializer: Api::Admin::Chapters::HeadingSerializer
        has_one :section, serializer: Api::Admin::Chapters::SectionSerializer
      end
    end
  end
end
