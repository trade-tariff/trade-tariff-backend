module Api
  module V2
    module Sections
      class SectionSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :id, :numeral, :title, :position, :chapter_from, :chapter_to, :description_plain

        attribute :section_note, if: proc { |section| section.section_note.present? } do |section|
          section.section_note.content
        end

        has_many :chapters, serializer: Api::V2::Sections::ChapterSerializer
      end
    end
  end
end
