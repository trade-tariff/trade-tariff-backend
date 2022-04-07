module Api
  module Admin
    module Chapters
      class ChapterNoteSerializer
        include JSONAPI::Serializer

        set_type :chapter_note

        set_id :id

        attributes :section_id, :chapter_id, :content

        def serialized_errors
          errors = @resource.errors.flat_map do |attribute, error|
            { title: attribute, detail: error }
          end

          { errors: }
        end
      end
    end
  end
end
