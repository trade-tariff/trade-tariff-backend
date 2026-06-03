module Api
  module Admin
    module Sections
      class SectionSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :id, :numeral, :title, :position, :chapter_from, :chapter_to

        has_many :chapters, serializer: Api::Admin::Sections::ChapterSerializer
        has_one :section_note, serializer: Api::Admin::Sections::SectionNoteSerializer, id_method_name: :id, &:section_note
      end
    end
  end
end
