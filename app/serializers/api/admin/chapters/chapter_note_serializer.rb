module Api
  module Admin
    module Chapters
      class ChapterNoteSerializer
        include JSONAPI::Serializer

        set_type :chapter_note

        set_id :id

        attributes :section_id, :chapter_id, :content
      end
    end
  end
end
