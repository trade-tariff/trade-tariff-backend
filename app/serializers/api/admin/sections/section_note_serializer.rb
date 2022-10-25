module Api
  module Admin
    module Sections
      class SectionNoteSerializer
        include JSONAPI::Serializer

        set_type :section_note

        set_id :id

        attributes :section_id, :content
      end
    end
  end
end
